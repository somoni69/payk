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

  static const androidPackage = 'app.payk.payk';

  static const appStoreUrl = String.fromEnvironment(
    'IOS_APP_URL',
    defaultValue: 'https://apps.apple.com/us/app/payk/id6831621113',
  );

  /// Ссылка Google Play с меткой `referrer=payk_ref=<КОД>` для автопривязки через Install Referrer.
  static String googlePlayReferralLink(String code) {
    final normalized = code.trim().toUpperCase();
    return Uri.https('play.google.com', '/store/apps/details', {
      'id': androidPackage,
      'hl': 'ru',
      if (normalized.isNotEmpty) 'referrer': 'payk_ref=$normalized',
    }).toString();
  }

  /// Единый текст приглашения для кнопок «Поделиться» (Главная и экран «Друзья»):
  /// код приглашения и ссылки на Google Play и App Store.
  static String referralShareText({
    required String code,
    String store = '',
  }) {
    final trimmedCode = code.trim().toUpperCase();
    final where = store.trim().isEmpty ? '' : ' в ${store.trim()}';
    final playLink = googlePlayReferralLink(trimmedCode);
    return 'Присоединяйтесь к бонусной программе ПАЙК$where — кэшбэк с каждой покупки. '
        'Мой код приглашения: $trimmedCode\n\n'
        'Google Play: $playLink\n'
        'App Store: $appStoreUrl';
  }

  static String get base {
    final trimmed = root.replaceAll(RegExp(r'/+$'), '');
    return '$trimmed/loyalty-app';
  }

  /// Путь от корня API (`/loyalty-app/...`) или уже полный адрес — в URL картинки.
  static String url(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final trimmed = root.replaceAll(RegExp(r'/+$'), '');
    return path.startsWith('/') ? '$trimmed$path' : '$trimmed/$path';
  }
}
