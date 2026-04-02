import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/design/app_colors.dart';
import '../../core/navigation/route_names.dart';

class RejectedAccountScreen extends StatelessWidget {
  final String? reason;

  const RejectedAccountScreen({
    super.key,
    this.reason,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.beige,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.cancel_outlined,
                  color: Colors.red,
                  size: 88,
                ),
                const SizedBox(height: 20),
                Text(
                  'تم رفض الطلب',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  reason?.trim().isNotEmpty == true
                      ? reason!.trim()
                      : 'برجاء مراجعة البيانات وإعادة التسجيل مرة أخرى.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 15,
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => context.go(RouteNames.register),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.purple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'إعادة التسجيل',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => context.go(RouteNames.login),
                  child: Text(
                    'الرجوع لتسجيل الدخول',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w700,
                      color: AppColors.purple,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
