import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/design/app_colors.dart';
import '../../core/navigation/route_names.dart';
import '../../services/auth_service.dart';
import '../../services/bundle_payments_service.dart';
import '../../services/courses_service.dart';
import '../../services/student_academic_selection_service.dart';
import '../../l10n/app_localizations.dart';

/// Register Screen - Clean Design like Account Page
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _studentPhoneController = TextEditingController();
  final _parentPhoneController = TextEditingController();
  final _fatherJobController = TextEditingController();
  final _motherJobController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmationController = TextEditingController();
  File? _idFrontImageFile;
  File? _idBackImageFile;
  bool _showPassword = false;
  bool _showPasswordConfirmation = false;
  bool _isLoading = false;
  bool _acceptTerms = false;
  String? _studentType;
  bool _isLoadingCategories = false;
  bool _isLoadingSubcategories = false;
  List<Map<String, dynamic>> _categories = const [];
  List<Map<String, dynamic>> _subcategories = const [];
  String? _selectedCategoryId;
  String? _selectedSubcategoryId;

  Future<void> _navigateByAccountStatusAndRole({
    required String role,
    String? status,
    String? accountStatus,
    String? rejectionReason,
  }) async {
    final normalizedStatus = (status ?? '').toLowerCase();
    final normalizedAccountStatus = (accountStatus ?? '').toLowerCase();

    if (normalizedStatus == 'pending' || normalizedAccountStatus == 'pending') {
      context.go(RouteNames.pendingApproval);
      return;
    }
    if (normalizedStatus == 'rejected' ||
        normalizedAccountStatus == 'rejected') {
      context.go(
        RouteNames.rejectedAccount,
        extra: rejectionReason?.trim().isNotEmpty == true
            ? rejectionReason!.trim()
            : null,
      );
      return;
    }

    final roleLower = role.toLowerCase();
    if (roleLower == 'instructor' || roleLower == 'teacher') {
      context.go(RouteNames.instructorHome);
    } else {
      final hasAcademicSelection = await StudentAcademicSelectionService
          .instance
          .hasCompletedSelection();
      if (!hasAcademicSelection) {
        context.go(RouteNames.studentAcademicSelection);
        return;
      }
      final hasBundleAccess =
          await BundlePaymentsService.instance.hasUnlockedAccess();
      if (!hasBundleAccess) {
        context.go(RouteNames.termPaymentStatus);
        return;
      }
      context.go(RouteNames.home);
    }
  }

  String _extractErrorMessage(dynamic error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    final match = RegExp(r'\{.*\}', dotAll: true).firstMatch(raw);
    if (match != null) {
      try {
        final decoded = jsonDecode(match.group(0)!);
        if (decoded is Map<String, dynamic>) {
          final message = decoded['message']?.toString().trim();
          if (message != null && message.isNotEmpty) return message;
        }
      } catch (_) {}
    }
    return raw;
  }

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _handleRegister() async {
    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.pleaseAcceptTerms,
              style: GoogleFonts.cairo()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      // Validate password confirmation
      if (_passwordController.text != _passwordConfirmationController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.passwordMismatch,
                style: GoogleFonts.cairo()),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_studentType == null || _studentType!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.selectStudentType,
                style: GoogleFonts.cairo()),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_idFrontImageFile == null || _idBackImageFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('برجاء رفع صورة البطاقة (الوجه الأمامي والخلفي)',
                style: GoogleFonts.cairo()),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        final authResponse = await AuthService.instance.register(
          firstName: _firstNameController.text.trim(),
          middleName: _middleNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          email: _emailController.text.trim(),
          studentPhone: _studentPhoneController.text.trim(),
          parentPhone: _parentPhoneController.text.trim().isEmpty
              ? null
              : _parentPhoneController.text.trim(),
          fatherJob: _fatherJobController.text.trim(),
          motherJob: _motherJobController.text.trim(),
          password: _passwordController.text,
          studentType: _studentType!,
          selectedCategoryId: _selectedCategoryId,
          selectedSubcategoryId: _selectedSubcategoryId,
          idFrontImagePath: _idFrontImageFile!.path,
          idBackImagePath: _idBackImageFile!.path,
        );

        if (!mounted) return;

        // Save launch flag
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('hasLaunched', true);

        // Navigate by role: instructor → instructor flow, else → student flow
        if (mounted) {
          await _navigateByAccountStatusAndRole(
            role: authResponse.user.role,
            status: authResponse.user.status,
            accountStatus: authResponse.user.accountStatus,
            rejectionReason: authResponse.user.accountRejectionReason,
          );
        }
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _extractErrorMessage(e),
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _studentPhoneController.dispose();
    _parentPhoneController.dispose();
    _fatherJobController.dispose();
    _motherJobController.dispose();
    _passwordController.dispose();
    _passwordConfirmationController.dispose();
    super.dispose();
  }

  Future<void> _pickIdImage(bool isFront) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
      allowMultiple: false,
    );

    final path = result?.files.singleOrNull?.path;
    if (path == null || path.isEmpty) return;
    final file = File(path);

    setState(() {
      if (isFront) {
        _idFrontImageFile = file;
      } else {
        _idBackImageFile = file;
      }
    });
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);
    try {
      final categories =
          await CoursesService.instance.getCategories(requireAuth: false);
      if (!mounted) return;
      setState(() {
        _categories = categories;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تحميل الأقسام', style: GoogleFonts.cairo()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingCategories = false);
      }
    }
  }

  Future<void> _loadSubcategories(String categoryId) async {
    setState(() {
      _isLoadingSubcategories = true;
      _subcategories = const [];
      _selectedSubcategoryId = null;
    });

    try {
      final subs = await CoursesService.instance.getSubcategories(
        categoryId: categoryId,
        requireAuth: false,
      );
      if (!mounted) return;
      setState(() {
        _subcategories = subs;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('تعذر تحميل التصنيفات الفرعية', style: GoogleFonts.cairo()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingSubcategories = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.beige,
      body: Column(
        children: [
          // Purple Header (smaller for register)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF5A4544),
                  Color(0xFF5A4544),
                  Color(0xFF040825)
                ],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                child: Column(
                  children: [
                    // Back Button & Title
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.go(RouteNames.login),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          AppLocalizations.of(context)!.register,
                          style: GoogleFonts.cairo(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(width: 44),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.joinUsMessage,
                      style: GoogleFonts.cairo(
                        fontSize: 15,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Form Container
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -20),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.beige,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // First Name
                        _buildLabel('الاسم الأول'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _firstNameController,
                          hint: 'أدخل الاسم الأول',
                          icon: Icons.person_outline_rounded,
                        ),
                        const SizedBox(height: 16),

                        // Middle Name
                        _buildLabel('الاسم الأوسط'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _middleNameController,
                          hint: 'أدخل الاسم الأوسط',
                          icon: Icons.person_outline_rounded,
                        ),
                        const SizedBox(height: 16),

                        // Last Name
                        _buildLabel('اسم العائلة'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _lastNameController,
                          hint: 'أدخل اسم العائلة',
                          icon: Icons.person_outline_rounded,
                        ),
                        const SizedBox(height: 16),

                        // Email Field
                        _buildLabel(AppLocalizations.of(context)!.email),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _emailController,
                          hint: 'example@email.com',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),

                        // Student Phone Field
                        _buildLabel('رقم الطالب'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _studentPhoneController,
                          hint: AppLocalizations.of(context)!.phonePlaceholder,
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),

                        // Parent Phone Field
                        _buildLabel('رقم ولي الأمر (اختياري)'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _parentPhoneController,
                          hint: AppLocalizations.of(context)!.phonePlaceholder,
                          icon: Icons.family_restroom_outlined,
                          keyboardType: TextInputType.phone,
                          requiredField: false,
                        ),
                        const SizedBox(height: 16),

                        // Father Job
                        _buildLabel('وظيفة الأب'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _fatherJobController,
                          hint: 'أدخل وظيفة الأب',
                          icon: Icons.work_outline,
                        ),
                        const SizedBox(height: 16),

                        // Mother Job
                        _buildLabel('وظيفة الأم'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _motherJobController,
                          hint: 'أدخل وظيفة الأم',
                          icon: Icons.work_history_outlined,
                        ),
                        const SizedBox(height: 16),

                        // Student Type Selector
                        _buildLabel(AppLocalizations.of(context)!.studentType),
                        const SizedBox(height: 8),
                        _buildStudentTypeSelector(context),
                        const SizedBox(height: 16),

                        _buildLabel('القسم'),
                        const SizedBox(height: 8),
                        _buildCategoryDropdown(),
                        const SizedBox(height: 16),

                        _buildLabel('التصنيف الفرعي'),
                        const SizedBox(height: 8),
                        _buildSubcategoryDropdown(),
                        const SizedBox(height: 16),

                        _buildLabel('صورة البطاقة الشخصية'),
                        const SizedBox(height: 8),
                        _buildFilePickerTile(
                          label: 'الوجه الأمامي للبطاقة',
                          file: _idFrontImageFile,
                          onTap: () => _pickIdImage(true),
                        ),
                        const SizedBox(height: 10),
                        _buildFilePickerTile(
                          label: 'الوجه الخلفي للبطاقة',
                          file: _idBackImageFile,
                          onTap: () => _pickIdImage(false),
                        ),
                        const SizedBox(height: 16),

                        // Password Field
                        _buildLabel(AppLocalizations.of(context)!.password),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _passwordController,
                          hint: AppLocalizations.of(context)!.enterPassword,
                          icon: Icons.lock_outline_rounded,
                          isPassword: true,
                          passwordFieldType: 'password',
                        ),
                        const SizedBox(height: 16),

                        // Password Confirmation Field
                        _buildLabel(
                            AppLocalizations.of(context)!.confirmNewPassword),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _passwordConfirmationController,
                          hint:
                              AppLocalizations.of(context)!.enterPasswordAgain,
                          icon: Icons.lock_outline_rounded,
                          isPassword: true,
                          passwordFieldType: 'confirmation',
                        ),
                        const SizedBox(height: 16),

                        // Terms Checkbox
                        GestureDetector(
                          onTap: () =>
                              setState(() => _acceptTerms = !_acceptTerms),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: _acceptTerms
                                        ? AppColors.purple
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: _acceptTerms
                                          ? AppColors.purple
                                          : AppColors.mutedForeground,
                                      width: 2,
                                    ),
                                  ),
                                  child: _acceptTerms
                                      ? const Icon(Icons.check,
                                          size: 14, color: Colors.white)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(
                                      text:
                                          '${AppLocalizations.of(context)!.iAgreeTo} ',
                                      style: GoogleFonts.cairo(
                                          fontSize: 13,
                                          color: AppColors.mutedForeground),
                                      children: [
                                        TextSpan(
                                          text: AppLocalizations.of(context)!
                                              .termsAndConditions,
                                          style: GoogleFonts.cairo(
                                            fontSize: 13,
                                            color: AppColors.purple,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Register Button
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleRegister,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.purple,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2.5),
                                  )
                                : Text(
                                    AppLocalizations.of(context)!.createAccount,
                                    style: GoogleFonts.cairo(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Login Link
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                AppLocalizations.of(context)!
                                    .alreadyHaveAccount,
                                style: GoogleFonts.cairo(
                                    fontSize: 14,
                                    color: AppColors.mutedForeground),
                              ),
                              TextButton(
                                onPressed: () => context.go(RouteNames.login),
                                child: Text(
                                  AppLocalizations.of(context)!.login,
                                  style: GoogleFonts.cairo(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.purple,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.cairo(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.foreground),
    );
  }

  Widget _buildStudentTypeSelector(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final options = [
      (label: l10n.onlineStudent, value: 'online'),
      (label: l10n.inPersonStudent, value: 'offline'),
    ];

    return Row(
      children: [
        for (int i = 0; i < options.length; i++) ...[
          Expanded(
            child: _buildStudentTypeOption(
              label: options[i].label,
              value: options[i].value,
              isSelected: _studentType == options[i].value,
            ),
          ),
          if (i != options.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _buildStudentTypeOption({
    required String label,
    required String value,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => setState(() => _studentType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.purple.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.purple : AppColors.mutedForeground,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      isSelected ? AppColors.purple : AppColors.mutedForeground,
                  width: 2,
                ),
                color: isSelected ? AppColors.purple : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.cairo(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color:
                      isSelected ? AppColors.purple : AppColors.mutedForeground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
    String passwordFieldType = 'password',
    bool requiredField = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword &&
            (passwordFieldType == 'password'
                ? !_showPassword
                : !_showPasswordConfirmation),
        keyboardType: keyboardType,
        style: GoogleFonts.cairo(fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              GoogleFonts.cairo(color: AppColors.mutedForeground, fontSize: 14),
          prefixIcon: Icon(icon, color: AppColors.purple, size: 22),
          suffixIcon: isPassword
              ? IconButton(
                  onPressed: () => setState(() {
                    if (passwordFieldType == 'password') {
                      _showPassword = !_showPassword;
                    } else {
                      _showPasswordConfirmation = !_showPasswordConfirmation;
                    }
                  }),
                  icon: Icon(
                    (passwordFieldType == 'password'
                            ? _showPassword
                            : _showPasswordConfirmation)
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.mutedForeground,
                    size: 22,
                  ),
                )
              : null,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
        validator: (value) {
          final l10n = AppLocalizations.of(context)!;
          if (requiredField && (value == null || value.isEmpty)) {
            return l10n.fieldRequired;
          }
          final currentValue = value ?? '';
          if (keyboardType == TextInputType.emailAddress) {
            final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
            if (!emailRegex.hasMatch(currentValue)) {
              return l10n.invalidEmail;
            }
          }
          if (isPassword &&
              passwordFieldType == 'password' &&
              currentValue.length < 6) {
            return l10n.passwordMinLength;
          }
          if (isPassword && passwordFieldType == 'confirmation') {
            if (currentValue != _passwordController.text) {
              return l10n.passwordMismatch;
            }
          }
          if (keyboardType == TextInputType.phone) {
            if (currentValue.isEmpty) return null;
            final phoneRegex = RegExp(r'^01[0-2,5]{1}[0-9]{8}$');
            if (!phoneRegex.hasMatch(currentValue)) {
              return l10n.invalidPhone;
            }
          }
          return null;
        },
      ),
    );
  }

  Widget _buildFilePickerTile({
    required String label,
    required File? file,
    required VoidCallback onTap,
  }) {
    final fileName =
        file == null ? null : file.path.split(Platform.pathSeparator).last;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: file == null ? AppColors.muted : AppColors.purple,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.upload_file, color: AppColors.purple),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                fileName ?? label,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  color: fileName == null
                      ? AppColors.mutedForeground
                      : AppColors.foreground,
                  fontWeight:
                      fileName == null ? FontWeight.w500 : FontWeight.w700,
                ),
              ),
            ),
            Text(
              file == null ? 'اختيار' : 'تم',
              style: GoogleFonts.cairo(
                color: AppColors.purple,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.muted),
      ),
      child: _isLoadingCategories
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(
                  child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )),
            )
          : DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedCategoryId,
                hint: Text('اختر القسم', style: GoogleFonts.cairo()),
                items: _categories
                    .map(
                      (cat) => DropdownMenuItem<String>(
                        value: cat['id']?.toString(),
                        child: Text(
                          (cat['name_ar'] ?? cat['name'] ?? '').toString(),
                          style: GoogleFonts.cairo(),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedCategoryId = value);
                  _loadSubcategories(value);
                },
              ),
            ),
    );
  }

  Widget _buildSubcategoryDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.muted),
      ),
      child: _isLoadingSubcategories
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(
                  child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )),
            )
          : DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedSubcategoryId,
                hint: Text('اختر التصنيف الفرعي (اختياري)',
                    style: GoogleFonts.cairo()),
                items: _subcategories
                    .map(
                      (sub) => DropdownMenuItem<String>(
                        value: sub['id']?.toString(),
                        child: Text(
                          (sub['name_ar'] ?? sub['name'] ?? '').toString(),
                          style: GoogleFonts.cairo(),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _subcategories.isEmpty
                    ? null
                    : (value) {
                        setState(() => _selectedSubcategoryId = value);
                      },
              ),
            ),
    );
  }
}
