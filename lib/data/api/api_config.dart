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

  /// Веб-адрес приложения лояльности для запасной сборки ссылки-приглашения `/r/<код>`.
  static const loyaltyWebUrl = String.fromEnvironment(
    'LOYALTY_APP_URL',
    defaultValue: 'https://payk-loyalty.vercel.app',
  );

  /// Веб OAuth Client ID сервера PAYK (`GOOGLE_OAUTH_CLIENT_ID`) для нативного Google Sign-In.
  /// Можно переопределить через `--dart-define=GOOGLE_SERVER_CLIENT_ID=...` (пустое значение скроет кнопку).
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '504084251664-teedidul1839hu2i1cq17ka0v2dm2fvk.apps.googleusercontent.com',
  );

  /// Ссылка-приглашение участника: адрес с сервера (`member.referral_link` / `friends.link`),
  /// либо запасной адрес веб-приложения `/r/<КОД>`.
  static String referralLink({required String code, String? serverLink}) {
    final trimmed = serverLink?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
    final base = loyaltyWebUrl.replaceAll(RegExp(r'/+$'), '');
    final normalized = code.trim().toUpperCase();
    return '$base/r/${Uri.encodeComponent(normalized)}';
  }

  /// Разбиение ссылки для отображения без `https://` с переносом только перед `/r/...`.
  static ({String host, String path}) inviteLinkParts(String link) {
    final bare = link.trim().replaceFirst(RegExp(r'^https?://', caseSensitive: false), '');
    final slash = bare.indexOf('/');
    if (slash < 0) return (host: bare, path: '');
    return (host: bare.substring(0, slash), path: bare.substring(slash));
  }

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
