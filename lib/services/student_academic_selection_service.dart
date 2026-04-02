import 'package:shared_preferences/shared_preferences.dart';

class StudentAcademicSelectionService {
  StudentAcademicSelectionService._();

  static final StudentAcademicSelectionService instance =
      StudentAcademicSelectionService._();

  static const String _keyGrade = 'selected_grade';
  static const String _keyTerm = 'selected_term';

  Future<void> saveSelection({
    required String grade,
    required String term,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_keyGrade, grade),
      prefs.setString(_keyTerm, term),
    ]);
  }

  Future<String?> getSelectedGrade() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyGrade);
  }

  Future<String?> getSelectedTerm() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyTerm);
  }

  Future<bool> hasCompletedSelection() async {
    final prefs = await SharedPreferences.getInstance();
    final grade = prefs.getString(_keyGrade);
    final term = prefs.getString(_keyTerm);
    return grade != null && grade.isNotEmpty && term != null && term.isNotEmpty;
  }
}
