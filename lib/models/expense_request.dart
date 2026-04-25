class ExpenseRequest {
  final String expenseId;
  final String type;
  final Map<String, dynamic> payload;

  ExpenseRequest({
    required this.expenseId,
    required this.type,
    required this.payload,
  });
}
