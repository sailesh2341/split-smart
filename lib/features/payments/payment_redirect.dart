import 'package:url_launcher/url_launcher.dart';

class PaymentRedirect {
  static Future<bool> openUpi({
    required String upiId,
    required double amount,
    String payeeName = 'SplitSmart',
    String note = 'SplitSmart bill payment',
  }) async {
    final uri = Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': upiId,
        'pn': payeeName,
        'am': amount.toStringAsFixed(2),
        'cu': 'INR',
        'tn': note,
      },
    );

    if (!await canLaunchUrl(uri)) {
      return false;
    }

    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
