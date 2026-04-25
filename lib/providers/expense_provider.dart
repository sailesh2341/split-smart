import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense.dart';

final expenseProvider = StateNotifierProvider<ExpenseNotifier, List<Expense>>(
  (ref) => ExpenseNotifier(),
);

class ExpenseNotifier extends StateNotifier<List<Expense>> {
  ExpenseNotifier() : super([]);

  void addExpense(Expense expense) {
    state = [...state, expense];
  }

  void setExpenses(List<Expense> expenses) {
    state = expenses;
  }
}
