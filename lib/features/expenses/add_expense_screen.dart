import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/app_group.dart';
import '../../models/expense_file.dart';
import '../../models/expense_split.dart';
import '../../models/group_member.dart';
import '../groups/data/splitsmart_api.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  final AppGroup group;

  const AddExpenseScreen({super.key, required this.group});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final amountCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final orderCtrl = TextEditingController();
  final List<ExpenseFile> files = [];
  final Set<String> selectedMemberIds = {};
  late Future<List<GroupMember>> membersFuture;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    membersFuture = _loadMembers();
  }

  Future<List<GroupMember>> _loadMembers() async {
    final members = await ref
        .read(splitSmartApiProvider)
        .listGroupMembers(widget.group.id);
    if (mounted && selectedMemberIds.isEmpty) {
      setState(() {
        selectedMemberIds.addAll(members.map((member) => member.id));
      });
    }
    return members;
  }

  @override
  void dispose() {
    amountCtrl.dispose();
    descCtrl.dispose();
    orderCtrl.dispose();
    super.dispose();
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) {
      return;
    }

    setState(() {
      files.add(ExpenseFile(url: image.path, type: 'image'));
    });
  }

  Future<void> pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    final path = result?.files.single.path;
    if (path == null) {
      return;
    }

    setState(() {
      files.add(ExpenseFile(url: path, type: 'pdf'));
    });
  }

  Future<void> saveExpense() async {
    final amount = double.tryParse(amountCtrl.text.trim());
    final description = descCtrl.text.trim();
    final orderType = orderCtrl.text.trim();

    if (amount == null ||
        amount <= 0 ||
        description.isEmpty ||
        orderType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter amount, description, and order type'),
        ),
      );
      return;
    }

    setState(() => saving = true);
    try {
      final uploadedFiles = <ExpenseFile>[];
      for (final file in files) {
        final isRemote =
            file.url.startsWith('http://') || file.url.startsWith('https://');
        if (isRemote) {
          uploadedFiles.add(file);
        } else {
          uploadedFiles.add(
            await ref
                .read(splitSmartApiProvider)
                .uploadAttachment(File(file.url)),
          );
        }
      }

      final memberIds = selectedMemberIds.toList();
      if (memberIds.isEmpty) {
        throw Exception('Select at least one split member');
      }
      final totalCents = (amount * 100).round();
      final baseCents = totalCents ~/ memberIds.length;
      final remainder = totalCents % memberIds.length;
      final splits = <ExpenseSplit>[];
      for (var index = 0; index < memberIds.length; index++) {
        final cents = baseCents + (index < remainder ? 1 : 0);
        final share = cents / 100;
        splits.add(
          ExpenseSplit(
            userId: memberIds[index],
            name: '',
            email: '',
            shareAmount: share,
            paid: false,
          ),
        );
      }

      await ref
          .read(splitSmartApiProvider)
          .createExpense(
            groupId: widget.group.id,
            amount: amount,
            description: description,
            orderType: orderType,
            files: uploadedFiles,
            splits: splits,
          );
      if (mounted) {
        context.pop(true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add expense • ${widget.group.name}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Amount'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descCtrl,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: orderCtrl,
            decoration: const InputDecoration(
              labelText: 'Order type',
              helperText: 'Example: Groceries, Home Essentials, Electricity',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: saving ? null : pickImage,
                  icon: const Icon(Icons.image),
                  label: const Text('Attach Image'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: saving ? null : pickPdf,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Attach PDF'),
                ),
              ),
            ],
          ),
          if (files.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...files.indexed.map((entry) {
              final index = entry.$1;
              final file = entry.$2;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  file.type == 'pdf' ? Icons.picture_as_pdf : Icons.image,
                ),
                title: Text(file.url.split('/').last),
                subtitle: Text(file.type.toUpperCase()),
                trailing: IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.close),
                  onPressed: saving
                      ? null
                      : () => setState(() => files.removeAt(index)),
                ),
              );
            }),
          ],
          const SizedBox(height: 16),
          Text('Split between', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          FutureBuilder<List<GroupMember>>(
            future: membersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator();
              }
              if (snapshot.hasError) {
                return Text('Failed to load members: ${snapshot.error}');
              }
              final members = snapshot.data ?? [];
              if (members.isEmpty) {
                return const Text('No members found');
              }
              return Column(
                children: members.map((member) {
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(member.name),
                    subtitle: Text(member.email),
                    value: selectedMemberIds.contains(member.id),
                    onChanged: saving
                        ? null
                        : (selected) {
                            setState(() {
                              if (selected == true) {
                                selectedMemberIds.add(member.id);
                              } else {
                                selectedMemberIds.remove(member.id);
                              }
                            });
                          },
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: saving ? null : saveExpense,
            child: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save Expense'),
          ),
        ],
      ),
    );
  }
}
