/// Боевой корень, как `NEXT_PUBLIC_API_URL` у loyalty-app в Payk-Ecosystem.
/// Локальный стенд: `--dart-define=API_URL=http://10.0.2.2:8011/api` (эмулятор Android).
class ApiConfig {
  static const root = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://payk-ecosystem-production.up.railway.app/api',
  );

  static const program = String.fromEnvironment(
    'LOYALTY_PROGRAM',
    defaultValue: 'almosi',
  );

  static const supportWhatsApp = String.fromEnvironment(
    'SUPPORT_WHATSAPP',
    defaultValue: '992555518220',
  );

  static String get base {
    final trimmed = root.replaceAll(RegExp(r'/+$'), '');
    return '$trimmed/loyalty-app';
  }
}
