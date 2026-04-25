class AuthState {
  final bool isAuthenticated;
  final bool isLoading;

  const AuthState({required this.isAuthenticated, required this.isLoading});

  factory AuthState.initial() =>
      const AuthState(isAuthenticated: false, isLoading: true);

  AuthState copyWith({bool? isAuthenticated, bool? isLoading}) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
