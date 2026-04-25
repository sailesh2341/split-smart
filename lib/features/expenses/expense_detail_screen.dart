import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/expense.dart';
import '../auth/state/user_provider.dart';
import '../groups/data/splitsmart_api.dart';
import '../payments/payment_redirect.dart';
import '../requests/request_dialog.dart';
import 'widgets/file_viewer.dart';

class ExpenseDetailArgs {
  final List<Expense> expenses;
  final int index;

  const ExpenseDetailArgs({required this.expenses, required this.index});
}

class ExpenseDetailScreen extends ConsumerStatefulWidget {
  final ExpenseDetailArgs args;

  const ExpenseDetailScreen({super.key, required this.args});

  @override
  ConsumerState<ExpenseDetailScreen> createState() =>
      _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends ConsumerState<ExpenseDetailScreen> {
  late final PageController controller;
  late List<Expense> expenses;
  late int currentIndex;
  bool hasChanges = false;

  @override
  void initState() {
    super.initState();
    expenses = [...widget.args.expenses];
    currentIndex = widget.args.index;
    controller = PageController(initialPage: currentIndex);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider).valueOrNull;
    final expense = expenses[currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(expense.description),
        leading: BackButton(
          onPressed: () => Navigator.pop(context, hasChanges),
        ),
      ),
      body: PageView.builder(
        controller: controller,
        itemCount: expenses.length,
        onPageChanged: (index) => setState(() => currentIndex = index),
        itemBuilder: (context, index) {
          final item = expenses[index];
          return Column(
            children: [
              Expanded(child: FileViewer(files: item.files)),
              _ExpenseActions(
                expense: item,
                isOwner: user != null && item.createdBy == user.id,
                onMarkedPaid: () {
                  setState(() {
                    expenses[index] = item.copyWith(status: 'PAID');
                    hasChanges = true;
                  });
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ExpenseActions extends ConsumerWidget {
  final Expense expense;
  final bool isOwner;
  final VoidCallback onMarkedPaid;

  const _ExpenseActions({
    required this.expense,
    required this.isOwner,
    required this.onMarkedPaid,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '₹${expense.amount.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(expense.orderType),
          const SizedBox(height: 6),
          Text('Status: ${expense.status}'),
          if (expense.splits.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Split details',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            ...expense.splits.map(
              (split) => Text(
                '${split.name.isEmpty ? split.email : split.name}: ₹${split.shareAmount.toStringAsFixed(2)}',
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.account_balance_wallet),
              label: const Text('Pay via UPI'),
              onPressed: () async {
                final opened = await PaymentRedirect.openUpi(
                  upiId: 'user@upi',
                  amount: expense.amount,
                );
                if (!opened && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'No UPI app found. Install PhonePe/GPay/Paytm or test on a real phone.',
                      ),
                    ),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 8),
          if (isOwner)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: expense.status == 'PAID'
                    ? null
                    : () async {
                        try {
                          await ref
                              .read(splitSmartApiProvider)
                              .markPaid(expense.id);
                          onMarkedPaid();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Marked as paid')),
                            );
                          }
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error.toString())),
                            );
                          }
                        }
                      },
                child: const Text('Mark as Paid'),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: () async {
                  final sent = await showDialog<bool>(
                    context: context,
                    builder: (_) => RequestDialog(expenseId: expense.id),
                  );
                  if (sent == true && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Request sent to expense owner'),
                      ),
                    );
                  }
                },
                child: const Text('Request Change / Paid'),
              ),
            ),
        ],
      ),
    );
  }
}
