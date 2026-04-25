import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense_request.dart';

final requestProvider =
    StateNotifierProvider<RequestNotifier, List<ExpenseRequest>>(
      (ref) => RequestNotifier(),
    );

class RequestNotifier extends StateNotifier<List<ExpenseRequest>> {
  RequestNotifier() : super([]);

  void addRequest(ExpenseRequest request) {
    state = [...state, request];
  }

  void approve(String expenseId) {
    state = state.where((r) => r.expenseId != expenseId).toList();
  }
}
