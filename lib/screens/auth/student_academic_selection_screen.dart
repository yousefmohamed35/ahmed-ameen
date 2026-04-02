import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/design/app_colors.dart';
import '../../core/navigation/route_names.dart';
import '../../services/bundle_payments_service.dart';
import '../../services/student_academic_selection_service.dart';

class StudentAcademicSelectionScreen extends StatefulWidget {
  const StudentAcademicSelectionScreen({super.key});

  @override
  State<StudentAcademicSelectionScreen> createState() =>
      _StudentAcademicSelectionScreenState();
}

class _StudentAcademicSelectionScreenState
    extends State<StudentAcademicSelectionScreen> {
  bool _isSaving = false;
  String? _selectedGrade;
  String? _selectedTerm;

  static const List<Map<String, String>> _grades = [
    {'value': 'first', 'label': 'الفرقة الأولى'},
    {'value': 'second', 'label': 'الفرقة الثانية'},
    {'value': 'third', 'label': 'الفرقة الثالثة'},
    {'value': 'fourth', 'label': 'الفرقة الرابعة'},
  ];

  static const List<Map<String, String>> _terms = [
    {'value': 'term_1', 'label': 'الترم الأول'},
    {'value': 'term_2', 'label': 'الترم الثاني'},
  ];

  Future<void> _submit() async {
    if (_selectedGrade == null || _selectedTerm == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'من فضلك اختر الصف والترم',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await StudentAcademicSelectionService.instance.saveSelection(
        grade: _selectedGrade!,
        term: _selectedTerm!,
      );
      if (!mounted) return;
      final hasBundleAccess =
          await BundlePaymentsService.instance.hasUnlockedAccess();
      if (hasBundleAccess) {
        context.go(RouteNames.home);
      } else {
        context.go(RouteNames.termPaymentStatus);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.beige,
      appBar: AppBar(
        backgroundColor: AppColors.beige,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'اختيار المرحلة الدراسية',
          style: GoogleFonts.cairo(
            color: AppColors.foreground,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'اختر الصف',
              style: GoogleFonts.cairo(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 10),
            _buildDropdown(
              value: _selectedGrade,
              hint: 'اختر الصف',
              items: _grades,
              onChanged: (v) => setState(() => _selectedGrade = v),
            ),
            const SizedBox(height: 20),
            Text(
              'اختر الترم',
              style: GoogleFonts.cairo(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 10),
            _buildDropdown(
              value: _selectedTerm,
              hint: 'اختر الترم',
              items: _terms,
              onChanged: (v) => setState(() => _selectedTerm = v),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.4,
                        ),
                      )
                    : Text(
                        'متابعة',
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<Map<String, String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.muted),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(hint, style: GoogleFonts.cairo()),
          items: items
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item['value'],
                  child: Text(item['label'] ?? '', style: GoogleFonts.cairo()),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
