import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter/material.dart';

class PaymentService {
  late Razorpay _razorpay;
  final Function(PaymentSuccessResponse)? onSuccess;
  final Function(PaymentFailureResponse)? onFailure;
  final Function(ExternalWalletResponse)? onExternalWallet;

  PaymentService({
    this.onSuccess,
    this.onFailure,
    this.onExternalWallet,
  }) {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void dispose() {
    _razorpay.clear();
  }

  void openCheckout({
    required double amount,
    required String name,
    required String description,
    required String userEmail,
    required String userContact,
  }) {
    debugPrint("Bypassing Razorpay checkout: App is in Free-for-All mode.");
    // In a real "test" bypass, we could trigger onSuccess here if needed.
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    debugPrint("Payment Successful: ${response.paymentId}");
    onSuccess?.call(response);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint("Payment Error: ${response.code} - ${response.message}");
    onFailure?.call(response);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint("External Wallet selected: ${response.walletName}");
    onExternalWallet?.call(response);
  }
}
