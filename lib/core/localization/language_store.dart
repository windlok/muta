import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _storageKey = 'app_language_v1';
const defaultLanguageCode = 'en';

Future<String> loadLanguageCode() async {
  final prefs = await SharedPreferences.getInstance();
  final code = prefs.getString(_storageKey);
  return code == 'tr' || code == 'en' ? code! : defaultLanguageCode;
}

Future<void> saveLanguageCode(String code) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_storageKey, code);
}

/// main() içinde cihazda kayıtlı dil ile override edilir.
final initialLanguageProvider = Provider<String>((ref) => defaultLanguageCode);

class AppLanguageController extends Notifier<String> {
  @override
  String build() => ref.read(initialLanguageProvider);

  Future<void> setLanguage(String code) async {
    if (code != 'en' && code != 'tr') return;
    if (state == code) return;
    state = code;
    await saveLanguageCode(code);
  }
}

final appLanguageProvider =
    NotifierProvider<AppLanguageController, String>(AppLanguageController.new);
