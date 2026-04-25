import '../../models/expense.dart';

class Permissions {
  static bool canEditExpense({
    required Expense expense,
    required String currentUserId,
  }) {
    return expense.createdBy == currentUserId;
  }

  static bool canMarkPaid({
    required Expense expense,
    required String currentUserId,
  }) {
    return expense.createdBy == currentUserId;
  }

  static bool canRequestChange({
    required Expense expense,
    required String currentUserId,
  }) {
    return expense.createdBy != currentUserId;
  }
}
