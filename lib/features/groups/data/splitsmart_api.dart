import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/jwt_storage.dart';
import '../../../models/app_group.dart';
import '../../../models/expense.dart';
import '../../../models/expense_file.dart';
import '../../../models/expense_request_item.dart';
import '../../../models/expense_split.dart';
import '../../../models/group_member.dart';

final splitSmartApiProvider = Provider<SplitSmartApi>((ref) {
  return SplitSmartApi(ref.read(jwtStorageProvider));
});

class SplitSmartApi {
  final JwtStorage _storage;
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'http://10.0.2.2:8080',
      headers: {'Content-Type': 'application/json'},
      responseType: ResponseType.plain,
    ),
  );

  SplitSmartApi(this._storage);

  Future<List<AppGroup>> listGroups() async {
    final body = await _get('/api/groups');
    final items = body is List ? body : <dynamic>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map(AppGroup.fromJson)
        .toList();
  }

  Future<AppGroup> createGroup(String name) async {
    final body = await _post('/api/groups', {'name': name});
    return AppGroup.fromJson(body as Map<String, dynamic>);
  }

  Future<void> addGroupMember({
    required String groupId,
    required String email,
  }) async {
    await _post('/api/groups/$groupId/members', {'email': email});
  }

  Future<List<GroupMember>> listGroupMembers(String groupId) async {
    final body = await _get('/api/groups/$groupId/members');
    final items = body is List ? body : <dynamic>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map(GroupMember.fromJson)
        .toList();
  }

  Future<List<String>> listOrderTypes(String groupId) async {
    final body = await _get('/api/groups/$groupId/order-types');
    final items = body is List ? body : <dynamic>[];
    return items.map((item) => item.toString()).toList();
  }

  Future<List<Expense>> listExpenses({
    required String groupId,
    List<String> orderTypes = const [],
  }) async {
    final query = orderTypes.isEmpty
        ? ''
        : '?order_types=${Uri.encodeQueryComponent(orderTypes.join(','))}';
    final body = await _get('/api/groups/$groupId/expenses$query');
    final items = body is List ? body : <dynamic>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map(Expense.fromJson)
        .toList();
  }

  Future<Expense> createExpense({
    required String groupId,
    required double amount,
    required String description,
    required String orderType,
    required List<ExpenseFile> files,
    required List<ExpenseSplit> splits,
  }) async {
    final body = await _post('/api/groups/$groupId/expenses', {
      'amount': amount,
      'description': description,
      'order_type': orderType,
      'files': files.map((file) => file.toJson()).toList(),
      'splits': splits.map((split) => split.toJson()).toList(),
    });
    return Expense.fromJson(body as Map<String, dynamic>);
  }

  Future<ExpenseFile> uploadAttachment(File file) async {
    final token = await _requiredToken();
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: file.path.split('/').last,
      ),
    });
    final res = await _dio.post(
      '/api/uploads',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    final body = _decode(res.data);
    return ExpenseFile.fromJson(body as Map<String, dynamic>);
  }

  Future<void> markPaid(String expenseId) async {
    await _post('/api/expenses/$expenseId/mark-paid', {});
  }

  Future<void> createExpenseRequest({
    required String expenseId,
    required String type,
    required Map<String, dynamic> payload,
  }) async {
    await _post('/api/expenses/$expenseId/requests', {
      'type': type,
      'payload': payload,
    });
  }

  Future<List<ExpenseRequestItem>> listRequests() async {
    final body = await _get('/api/requests');
    final items = body is List ? body : <dynamic>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map(ExpenseRequestItem.fromJson)
        .toList();
  }

  Future<void> approveRequest(String requestId) async {
    await _post('/api/requests/$requestId/approve', {});
  }

  Future<void> rejectRequest(String requestId) async {
    await _post('/api/requests/$requestId/reject', {});
  }

  Future<dynamic> _get(String path) async {
    final token = await _requiredToken();
    final res = await _dio.get(
      path,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return _decode(res.data);
  }

  Future<dynamic> _post(String path, Map<String, dynamic> data) async {
    final token = await _requiredToken();
    final res = await _dio.post(
      path,
      data: jsonEncode(data),
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return _decode(res.data);
  }

  Future<String> _requiredToken() async {
    final token = await _storage.read();
    if (token == null) {
      throw Exception('Not authenticated');
    }
    return token;
  }

  dynamic _decode(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return jsonDecode(value);
    }
    return value;
  }
}

final groupsProvider = FutureProvider<List<AppGroup>>((ref) async {
  return ref.read(splitSmartApiProvider).listGroups();
});

final expenseRequestsProvider = FutureProvider<List<ExpenseRequestItem>>((
  ref,
) async {
  return ref.read(splitSmartApiProvider).listRequests();
});
