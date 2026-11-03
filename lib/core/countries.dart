const countryNames = <String, String>{
  'TJ': 'Таджикистан',
  'RU': 'Россия',
  'UZ': 'Узбекистан',
  'KZ': 'Казахстан',
  'KG': 'Кыргызстан',
  'AF': 'Афганистан',
  'TR': 'Турция',
  'AE': 'ОАЭ',
  'CN': 'Китай',
  'US': 'США',
  'OTHER': 'Другая',
};

String countryName(String? code) {
  if (code == null || code.isEmpty) return '—';
  return countryNames[code] ?? code;
}
