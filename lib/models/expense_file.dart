class ExpenseFile {
  final String url;
  final String type;

  ExpenseFile({required this.url, required this.type});

  factory ExpenseFile.fromJson(Map<String, dynamic> json) {
    return ExpenseFile(
      url: json['url'].toString(),
      type: json['type'].toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'url': url, 'type': type};
  }
}
