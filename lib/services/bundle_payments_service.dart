import 'package:flutter/foundation.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';

class BundlePaymentsService {
  BundlePaymentsService._();

  static final BundlePaymentsService instance = BundlePaymentsService._();

  Future<List<Map<String, dynamic>>> getMyBundles() async {
    final response = await ApiClient.instance.get(
      ApiEndpoints.myBundlePurchases,
      requireAuth: true,
    );
    final data = response['data'];
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return const [];
  }

  Future<Map<String, dynamic>> createBundlePurchase({
    required String subcategoryId,
    required double amount,
    String paymentMethod = 'cash',
    int minDownpaymentPercent = 30,
    int deadlineDays = 90,
    String? transactionReference,
  }) async {
    final response = await ApiClient.instance.post(
      ApiEndpoints.bundlePurchases,
      requireAuth: true,
      body: {
        'subcategory_id': subcategoryId,
        'amount': amount,
        'min_downpayment_percent': minDownpaymentPercent,
        'deadline_days': deadlineDays,
        'payment_method': paymentMethod,
        if (transactionReference != null &&
            transactionReference.trim().isNotEmpty)
          'transaction_reference': transactionReference.trim(),
      },
    );
    return Map<String, dynamic>.from(response['data'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> addAdditionalPayment({
    required String purchaseId,
    required double amount,
    String paymentMethod = 'cash',
    String? transactionReference,
  }) async {
    final response = await ApiClient.instance.post(
      ApiEndpoints.bundlePurchasePayments(purchaseId),
      requireAuth: true,
      body: {
        'amount': amount,
        'payment_method': paymentMethod,
        if (transactionReference != null &&
            transactionReference.trim().isNotEmpty)
          'transaction_reference': transactionReference.trim(),
      },
    );
    return Map<String, dynamic>.from(response['data'] as Map? ?? {});
  }

  Future<bool> hasUnlockedAccess() async {
    try {
      final bundles = await getMyBundles();
      if (bundles.isEmpty) return false;
      final now = DateTime.now();

      for (final bundle in bundles) {
        final status = (bundle['status'] ?? '').toString().toLowerCase();
        final amountPaid = _toDouble(bundle['amountPaid']);
        final remainingDebt = _toDouble(bundle['remainingDebt']);
        final deadlineRaw = bundle['paymentDeadline']?.toString();
        final deadline = deadlineRaw != null && deadlineRaw.isNotEmpty
            ? DateTime.tryParse(deadlineRaw)
            : null;

        final beforeDeadline = deadline == null || !now.isAfter(deadline);
        final isSettled = remainingDebt <= 0.0001;
        final statusAllows = status == 'active' || status == 'completed';

        if ((amountPaid > 0 && beforeDeadline) || isSettled || statusAllows) {
          return true;
        }
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Bundle access check error: $e');
      }
      return false;
    }
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
