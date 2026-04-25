class ExpenseSplit {
  final String userId;
  final String name;
  final String email;
  final double shareAmount;
  final bool paid;

  ExpenseSplit({
    required this.userId,
    required this.name,
    required this.email,
    required this.shareAmount,
    required this.paid,
  });

  factory ExpenseSplit.fromJson(Map<String, dynamic> json) {
    return ExpenseSplit(
      userId: json['user_id'].toString(),
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      shareAmount: double.parse(json['share_amount'].toString()),
      paid: json['paid'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {'user_id': userId, 'share_amount': shareAmount};
  }
}
