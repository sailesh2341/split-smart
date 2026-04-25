import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/expense_request_item.dart';
import '../groups/data/splitsmart_api.dart';

class RequestsScreen extends ConsumerWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(expenseRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Requests'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(expenseRequestsProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(expenseRequestsProvider),
        child: requestsAsync.when(
          data: (requests) {
            if (requests.isEmpty) {
              return const _EmptyRequests();
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _RequestCard(request: requests[index]);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [Text('Failed to load requests: $error')],
          ),
        ),
      ),
    );
  }
}

class _EmptyRequests extends StatelessWidget {
  const _EmptyRequests();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        SizedBox(height: 160),
        Center(child: Text('No requests yet')),
      ],
    );
  }
}

class _RequestCard extends ConsumerStatefulWidget {
  final ExpenseRequestItem request;

  const _RequestCard({required this.request});

  @override
  ConsumerState<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<_RequestCard> {
  bool handling = false;

  Future<void> handle({required bool approved}) async {
    setState(() => handling = true);
    try {
      final api = ref.read(splitSmartApiProvider);
      if (approved) {
        await api.approveRequest(widget.request.id);
      } else {
        await api.rejectRequest(widget.request.id);
      }
      ref.invalidate(expenseRequestsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approved ? 'Request approved' : 'Request rejected'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => handling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final proof = request.payload['proof_url']?.toString();
    final note = request.payload['note']?.toString();
    final isPending = request.status == 'PENDING';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _labelForType(request.type),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(label: Text(request.status)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Expense: ${request.expenseDescription.isEmpty ? request.expenseId : request.expenseDescription}',
            ),
            const SizedBox(height: 4),
            Text('Amount: ₹${request.expenseAmount.toStringAsFixed(2)}'),
            const SizedBox(height: 4),
            Text(
              'Requested by: ${request.requestedByName.isEmpty ? request.requestedBy : request.requestedByName}',
            ),
            if (proof != null && proof.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Proof: $proof'),
            ],
            if (request.type == 'MODIFY') ...[
              const SizedBox(height: 8),
              Text(_modifySummary(request.payload)),
            ],
            if (note != null && note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Note: $note'),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: !isPending || handling
                        ? null
                        : () => handle(approved: false),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: !isPending || handling
                        ? null
                        : () => handle(approved: true),
                    child: handling
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _labelForType(String type) {
    switch (type) {
      case 'MARK_PAID':
        return 'Mark bill as paid';
      case 'DELETE':
        return 'Delete expense';
      case 'MODIFY':
        return 'Modify expense';
      default:
        return type;
    }
  }

  String _modifySummary(Map<String, dynamic> payload) {
    final parts = <String>[];
    if (payload['amount'] != null) {
      parts.add('New amount: ₹${payload['amount']}');
    }
    if (payload['description'] != null) {
      parts.add('New description: ${payload['description']}');
    }
    if (payload['order_type'] != null) {
      parts.add('New order type: ${payload['order_type']}');
    }
    return parts.isEmpty ? 'No modification fields provided' : parts.join('\n');
  }
}
