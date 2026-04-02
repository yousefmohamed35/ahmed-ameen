import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/design/app_colors.dart';
import '../../core/navigation/route_names.dart';
import '../../services/bundle_payments_service.dart';

class TermPaymentStatusScreen extends StatefulWidget {
  const TermPaymentStatusScreen({super.key});

  @override
  State<TermPaymentStatusScreen> createState() =>
      _TermPaymentStatusScreenState();
}

class _TermPaymentStatusScreenState extends State<TermPaymentStatusScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _bundles = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await BundlePaymentsService.instance.getMyBundles();
      if (!mounted) return;
      setState(() => _bundles = data);
    } catch (_) {
      if (!mounted) return;
      setState(() => _bundles = const []);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addPaymentDialog(String purchaseId) async {
    final amountController = TextEditingController();
    String paymentMethod = 'cash';
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('إضافة دفعة', style: GoogleFonts.cairo()),
        content: StatefulBuilder(
          builder: (ctx, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'المبلغ'),
              ),
              const SizedBox(height: 10),
              DropdownButton<String>(
                value: paymentMethod,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'wallet', child: Text('Wallet')),
                  DropdownMenuItem(value: 'card', child: Text('Card')),
                ],
                onChanged: (v) =>
                    setDialogState(() => paymentMethod = v ?? 'cash'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text.trim());
              if (amount == null || amount <= 0) return;
              Navigator.pop(ctx);
              try {
                await BundlePaymentsService.instance.addAdditionalPayment(
                  purchaseId: purchaseId,
                  amount: amount,
                  paymentMethod: paymentMethod,
                );
                await _load();
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
              }
            },
            child: Text('تأكيد', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.beige,
      appBar: AppBar(
        title: Text('حالة دفع الترم', style: GoogleFonts.cairo()),
        centerTitle: true,
        backgroundColor: AppColors.beige,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bundles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('لا توجد باقات مسجلة', style: GoogleFonts.cairo()),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () =>
                            context.go(RouteNames.termPaymentPlans),
                        child: Text('ابدأ خطة دفع', style: GoogleFonts.cairo()),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (_, i) {
                      final b = _bundles[i];
                      final id = b['id']?.toString() ?? '';
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('الحالة: ${b['status'] ?? '-'}',
                                style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text('المدفوع: ${b['amountPaid'] ?? '0'}',
                                style: GoogleFonts.cairo()),
                            Text('المتبقي: ${b['remainingDebt'] ?? '0'}',
                                style: GoogleFonts.cairo()),
                            Text(
                                'آخر موعد: ${b['paymentDeadline']?.toString() ?? '-'}',
                                style: GoogleFonts.cairo()),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                ElevatedButton(
                                  onPressed: id.isEmpty
                                      ? null
                                      : () => _addPaymentDialog(id),
                                  child: Text('إضافة دفعة',
                                      style: GoogleFonts.cairo(fontSize: 12)),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () async {
                                    final hasAccess =
                                        await BundlePaymentsService.instance
                                            .hasUnlockedAccess();
                                    if (!mounted) return;
                                    if (hasAccess) {
                                      context.go(RouteNames.home);
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'لا يمكن الدخول قبل إتمام شروط الدفع',
                                            style: GoogleFonts.cairo(),
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  },
                                  child: Text('دخول التطبيق',
                                      style: GoogleFonts.cairo(fontSize: 12)),
                                ),
                              ],
                            )
                          ],
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemCount: _bundles.length,
                  ),
                ),
    );
  }
}
