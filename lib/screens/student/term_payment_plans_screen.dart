import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/design/app_colors.dart';
import '../../core/navigation/route_names.dart';
import '../../services/bundle_payments_service.dart';

class TermPaymentPlansScreen extends StatefulWidget {
  const TermPaymentPlansScreen({super.key});

  @override
  State<TermPaymentPlansScreen> createState() => _TermPaymentPlansScreenState();
}

class _TermPaymentPlansScreenState extends State<TermPaymentPlansScreen> {
  final _subcategoryIdController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isLoading = false;
  String _paymentMethod = 'cash';

  Future<void> _createPlan() async {
    final subcategoryId = _subcategoryIdController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());
    if (subcategoryId.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('اكتب التصنيف الفرعي والمبلغ بشكل صحيح',
              style: GoogleFonts.cairo()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await BundlePaymentsService.instance.createBundlePurchase(
        subcategoryId: subcategoryId,
        amount: amount,
        paymentMethod: _paymentMethod,
      );
      if (!mounted) return;
      context.go(RouteNames.termPaymentStatus);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _subcategoryIdController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.beige,
      appBar: AppBar(
        title: Text('خطط دفع الترم', style: GoogleFonts.cairo()),
        centerTitle: true,
        backgroundColor: AppColors.beige,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _field(_subcategoryIdController, 'Subcategory ID'),
            const SizedBox(height: 12),
            _field(_amountController, 'مبلغ الدفعة الأولى',
                keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _paymentMethod,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'wallet', child: Text('Wallet')),
                DropdownMenuItem(value: 'card', child: Text('Card')),
              ],
              onChanged: (v) => setState(() => _paymentMethod = v ?? 'cash'),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createPlan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.purple,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text('تأكيد الدفع', style: GoogleFonts.cairo()),
              ),
            ),
            TextButton(
              onPressed: () => context.go(RouteNames.termPaymentStatus),
              child: Text('عرض حالة الدفع', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String hint,
      {TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
