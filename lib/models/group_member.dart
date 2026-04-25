class GroupMember {
  final String id;
  final String name;
  final String email;
  final String role;

  GroupMember({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'member',
    );
  }
}
