import 'package:flutter/material.dart';

SnackBar createTopSnackBar({
  required Widget content,
  Color? backgroundColor,
  Duration duration = const Duration(seconds: 3),
  BuildContext? context,
}) {
  EdgeInsets margin = const EdgeInsets.only(top: 16, left: 16, right: 16);
  
  if (context != null) {
    final mediaQuery = MediaQuery.of(context);
    margin = EdgeInsets.only(
      bottom: mediaQuery.size.height - mediaQuery.padding.top - 60,
      left: 16,
      right: 16,
    );
  }

  return SnackBar(
    content: content,
    backgroundColor: backgroundColor,
    behavior: SnackBarBehavior.floating,
    margin: margin,
    duration: duration,
    dismissDirection: DismissDirection.horizontal,
  );
}

