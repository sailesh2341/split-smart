import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/expense_file.dart';
import '../groups/data/splitsmart_api.dart';

class RequestDialog extends ConsumerStatefulWidget {
  final String expenseId;

  const RequestDialog({super.key, required this.expenseId});

  @override
  ConsumerState<RequestDialog> createState() => _RequestDialogState();
}

class _RequestDialogState extends ConsumerState<RequestDialog> {
  String requestType = 'MARK_PAID';
  final amountCtrl = TextEditingController();
  final descriptionCtrl = TextEditingController();
  final orderTypeCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  ExpenseFile? proofFile;
  bool sending = false;

  @override
  void dispose() {
    amountCtrl.dispose();
    descriptionCtrl.dispose();
    orderTypeCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  Future<void> pickProof() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
    );
    final path = result?.files.single.path;
    if (path == null) {
      return;
    }
    final extension = path.split('.').last.toLowerCase();
    setState(() {
      proofFile = ExpenseFile(
        url: path,
        type: extension == 'pdf' ? 'pdf' : 'image',
      );
    });
  }

  Future<void> submit() async {
    setState(() => sending = true);
    try {
      final payload = <String, dynamic>{
        if (noteCtrl.text.trim().isNotEmpty) 'note': noteCtrl.text.trim(),
      };

      if (proofFile != null) {
        final uploadedProof = await ref
            .read(splitSmartApiProvider)
            .uploadAttachment(File(proofFile!.url));
        payload['proof_url'] = uploadedProof.url;
        payload['proof_type'] = uploadedProof.type;
      }

      if (requestType == 'MODIFY') {
        final amount = double.tryParse(amountCtrl.text.trim());
        if (amount != null && amount > 0) {
          payload['amount'] = amount;
        }
        if (descriptionCtrl.text.trim().isNotEmpty) {
          payload['description'] = descriptionCtrl.text.trim();
        }
        if (orderTypeCtrl.text.trim().isNotEmpty) {
          payload['order_type'] = orderTypeCtrl.text.trim();
        }
        if (!payload.containsKey('amount') &&
            !payload.containsKey('description') &&
            !payload.containsKey('order_type')) {
          throw Exception('Enter at least one modify field');
        }
      }

      await ref
          .read(splitSmartApiProvider)
          .createExpenseRequest(
            expenseId: widget.expenseId,
            type: requestType,
            payload: payload,
          );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Request action'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: requestType,
              decoration: const InputDecoration(labelText: 'Request type'),
              items: const [
                DropdownMenuItem(value: 'MARK_PAID', child: Text('Mark paid')),
                DropdownMenuItem(
                  value: 'DELETE',
                  child: Text('Delete expense'),
                ),
                DropdownMenuItem(
                  value: 'MODIFY',
                  child: Text('Modify expense'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => requestType = value);
                }
              },
            ),
            const SizedBox(height: 12),
            if (requestType == 'MODIFY') ...[
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'New amount',
                  helperText: 'Optional',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionCtrl,
                decoration: const InputDecoration(
                  labelText: 'New description',
                  helperText: 'Optional',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: orderTypeCtrl,
                decoration: const InputDecoration(
                  labelText: 'New order type',
                  helperText: 'Optional',
                ),
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton.icon(
              onPressed: sending ? null : pickProof,
              icon: const Icon(Icons.attach_file),
              label: Text(
                proofFile == null ? 'Attach payment proof' : 'Proof attached',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Note',
                helperText: 'Example: Paid via cash / please correct amount',
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: sending ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: sending ? null : submit,
          child: sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send'),
        ),
      ],
    );
  }
}
