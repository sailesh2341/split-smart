import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/state/auth_controller.dart';
import '../../auth/state/user_provider.dart';
import '../../groups/data/splitsmart_api.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider);
    final groupsAsync = ref.watch(groupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SplitSmart'),
        actions: [
          IconButton(
            tooltip: 'Requests',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/requests'),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(userProvider);
          ref.invalidate(groupsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            userAsync.when(
              data: (user) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, ${user.name}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(user.email),
                ],
              ),
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('Profile error: $error'),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text('Groups', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  tooltip: 'Create group',
                  icon: const Icon(Icons.add),
                  onPressed: () => _showCreateGroupDialog(context, ref),
                ),
              ],
            ),
            groupsAsync.when(
              data: (groups) {
                if (groups.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Center(child: Text('Create your first group')),
                  );
                }

                return Column(
                  children: groups
                      .map(
                        (group) => ListTile(
                          title: Text(group.name),
                          leading: const Icon(Icons.group),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push('/group', extra: group),
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text('Groups error: $error'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateGroupDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Create group'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Group name'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) {
                  return;
                }
                await ref.read(splitSmartApiProvider).createGroup(name);
                ref.invalidate(groupsProvider);
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }
}
