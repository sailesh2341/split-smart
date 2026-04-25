class AppGroup {
  final String id;
  final String name;

  const AppGroup({required this.id, required this.name});

  factory AppGroup.fromJson(Map<String, dynamic> json) {
    return AppGroup(id: json['id'].toString(), name: json['name'].toString());
  }
}
