import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/app_group.dart';
import '../../models/expense.dart';
import '../expenses/widgets/expense_card.dart';
import 'data/splitsmart_api.dart';

class GroupExpensesScreen extends ConsumerStatefulWidget {
  final AppGroup group;

  const GroupExpensesScreen({super.key, required this.group});

  @override
  ConsumerState<GroupExpensesScreen> createState() =>
      _GroupExpensesScreenState();
}

class _GroupExpensesScreenState extends ConsumerState<GroupExpensesScreen> {
  final Set<String> selectedOrderTypes = {};
  late Future<List<Expense>> expensesFuture;
  late Future<List<String>> orderTypesFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final api = ref.read(splitSmartApiProvider);
    expensesFuture = api.listExpenses(
      groupId: widget.group.id,
      orderTypes: selectedOrderTypes.toList(),
    );
    orderTypesFuture = api.listOrderTypes(widget.group.id);
  }

  void _refresh() {
    setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group.name),
        actions: [
          IconButton(
            tooltip: 'Add member',
            icon: const Icon(Icons.person_add_alt),
            onPressed: () => _showAddMemberDialog(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await context.push<bool>(
            '/add-expense',
            extra: widget.group,
          );
          if (created == true) {
            _refresh();
          }
        },
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FutureBuilder<List<String>>(
              future: orderTypesFuture,
              builder: (context, snapshot) {
                final orderTypes = snapshot.data ?? [];
                if (orderTypes.isEmpty) {
                  return const Text('No order types yet');
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: orderTypes.map((type) {
                    return FilterChip(
                      label: Text(type),
                      selected: selectedOrderTypes.contains(type),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            selectedOrderTypes.add(type);
                          } else {
                            selectedOrderTypes.remove(type);
                          }
                          _reload();
                        });
                      },
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<Expense>>(
              future: expensesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Text('Failed to load expenses: ${snapshot.error}');
                }
                final expenses = snapshot.data ?? [];
                if (expenses.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Center(child: Text('No expenses yet')),
                  );
                }
                return Column(
                  children: [
                    for (var index = 0; index < expenses.length; index++)
                      ExpenseCard(
                        expense: expenses[index],
                        expenses: expenses,
                        index: index,
                        onChanged: _refresh,
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddMemberDialog(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var adding = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add member'),
              content: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Registered user email',
                ),
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
              ),
              actions: [
                TextButton(
                  onPressed: adding ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: adding
                      ? null
                      : () async {
                          final email = controller.text.trim();
                          if (email.isEmpty) {
                            return;
                          }
                          setDialogState(() => adding = true);
                          try {
                            await ref
                                .read(splitSmartApiProvider)
                                .addGroupMember(
                                  groupId: widget.group.id,
                                  email: email,
                                );
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(content: Text('Member added')),
                              );
                            }
                          } catch (error) {
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(content: Text(error.toString())),
                              );
                            }
                          } finally {
                            if (dialogContext.mounted) {
                              setDialogState(() => adding = false);
                            }
                          }
                        },
                  child: adding
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
