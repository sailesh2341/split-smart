import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../models/expense.dart';
import '../expense_detail_screen.dart';

class ExpenseCard extends StatelessWidget {
  final Expense expense;
  final List<Expense> expenses;
  final int index;
  final VoidCallback? onChanged;

  const ExpenseCard({
    super.key,
    required this.expense,
    required this.expenses,
    required this.index,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(expense.description),
        subtitle: Text('${expense.orderType} • ${expense.status}'),
        leading: const Icon(Icons.receipt_long),
        trailing: Text('₹${expense.amount.toStringAsFixed(2)}'),
        onTap: () async {
          final changed = await context.push<bool>(
            '/expense',
            extra: ExpenseDetailArgs(expenses: expenses, index: index),
          );
          if (changed == true && context.mounted) {
            onChanged?.call();
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Expenses updated')));
          }
        },
      ),
    );
  }
}
