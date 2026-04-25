import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/state/auth_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    final isLoading = authState.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Home (Logged In)"),
      ),
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : ElevatedButton(
                onPressed: () {
                  ref.read(authControllerProvider.notifier).logout();
                },
                child: const Text("Logout"),
              ),
      ),
    );
  }
}
