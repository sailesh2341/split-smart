import 'package:flutter_riverpod/flutter_riverpod.dart';

final filterProvider = StateNotifierProvider<FilterNotifier, Set<String>>(
  (ref) => FilterNotifier(),
);

class FilterNotifier extends StateNotifier<Set<String>> {
  FilterNotifier() : super({});

  void toggle(String type) {
    if (state.contains(type)) {
      state = {...state}..remove(type);
    } else {
      state = {...state, type};
    }
  }
}
