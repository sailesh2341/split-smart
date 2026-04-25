import 'expense_file.dart';
import 'expense_split.dart';

class Expense {
  final String id;
  final String groupId;
  final String createdBy;
  final double amount;
  final String description;
  final String orderType;
  final String status;
  final List<ExpenseFile> files;
  final List<ExpenseSplit> splits;

  Expense({
    required this.id,
    required this.groupId,
    required this.createdBy,
    required this.amount,
    required this.description,
    required this.orderType,
    required this.status,
    required this.files,
    required this.splits,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    final filesJson = json['files'];
    final files = filesJson is List
        ? filesJson
              .whereType<Map<String, dynamic>>()
              .map(ExpenseFile.fromJson)
              .toList()
        : <ExpenseFile>[];
    final splitsJson = json['splits'];
    final splits = splitsJson is List
        ? splitsJson
              .whereType<Map<String, dynamic>>()
              .map(ExpenseSplit.fromJson)
              .toList()
        : <ExpenseSplit>[];

    return Expense(
      id: json['id'].toString(),
      groupId: json['group_id'].toString(),
      createdBy: json['created_by'].toString(),
      amount: double.parse(json['amount'].toString()),
      description: json['description'].toString(),
      orderType: json['order_type'].toString(),
      status: json['status'].toString(),
      files: files,
      splits: splits,
    );
  }

  Expense copyWith({
    String? id,
    String? groupId,
    String? createdBy,
    double? amount,
    String? description,
    String? orderType,
    String? status,
    List<ExpenseFile>? files,
    List<ExpenseSplit>? splits,
  }) {
    return Expense(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      createdBy: createdBy ?? this.createdBy,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      orderType: orderType ?? this.orderType,
      status: status ?? this.status,
      files: files ?? this.files,
      splits: splits ?? this.splits,
    );
  }
}
