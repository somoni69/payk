import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'strings.dart';

const _key = 'payk.locale';

class LocaleController extends Notifier<String> {
  @override
  String build() {
    unawaited(_restore());
    return 'ru';
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (!ref.mounted || saved == null || !locales.contains(saved)) return;
    state = saved;
  }

  Future<void> set(String code) async {
    if (!locales.contains(code) || code == state) return;
    state = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, code);
  }
}

final localeProvider = NotifierProvider<LocaleController, String>(LocaleController.new);

String t(WidgetRef ref, String key, [Map<String, String> vars = const {}]) {
  return tr(ref.watch(localeProvider), key, vars);
}
