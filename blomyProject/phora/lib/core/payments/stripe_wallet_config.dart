import 'package:flutter_stripe/flutter_stripe.dart' as stripe;

const stripeApplePayMerchantIdentifier = 'merchant.com.vyla.health';
const stripeMerchantCountryCode = 'GB';

const stripePaymentSheetApplePay = stripe.PaymentSheetApplePay(
  merchantCountryCode: stripeMerchantCountryCode,
);

const stripePaymentSheetGooglePay = stripe.PaymentSheetGooglePay(
  merchantCountryCode: stripeMerchantCountryCode,
  testEnv: false,
);
