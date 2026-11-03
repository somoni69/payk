import 'package:flutter/material.dart';

import '../theme/payk_colors.dart';

void showPaykMessage(BuildContext context, String text) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        backgroundColor: PaykColors.ink,
      ),
    );
}
