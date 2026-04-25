class ExpenseRequestItem {
  final String id;
  final String expenseId;
  final String expenseDescription;
  final double expenseAmount;
  final String requestedBy;
  final String requestedByName;
  final String type;
  final String status;
  final Map<String, dynamic> payload;

  ExpenseRequestItem({
    required this.id,
    required this.expenseId,
    required this.expenseDescription,
    required this.expenseAmount,
    required this.requestedBy,
    required this.requestedByName,
    required this.type,
    required this.status,
    required this.payload,
  });

  factory ExpenseRequestItem.fromJson(Map<String, dynamic> json) {
    final payloadJson = json['payload'];

    return ExpenseRequestItem(
      id: json['id'].toString(),
      expenseId: json['expense_id'].toString(),
      expenseDescription: json['expense_description']?.toString() ?? '',
      expenseAmount: double.tryParse(json['expense_amount'].toString()) ?? 0,
      requestedBy: json['requested_by'].toString(),
      requestedByName: json['requested_by_name']?.toString() ?? '',
      type: json['type'].toString(),
      status: json['status'].toString(),
      payload: payloadJson is Map<String, dynamic> ? payloadJson : {},
    );
  }
}
