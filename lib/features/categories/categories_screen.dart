import 'package:flutter/material.dart';
import '../history/history_screen.dart';

/// Экран категорий заменён на экран «Харидҳо / Покупки» (Purchases & Operations)
/// с 3D-плитками категорий операций в точном соответствии с UX Payk Ecosystem (loyalty-app).
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const HistoryScreen();
  }
}
