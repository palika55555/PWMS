import 'package:flutter/material.dart';

extension SnackBarHelper on BuildContext {
  void showTopSnackBar(
    String message, {
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 3),
  }) {
    final mediaQuery = MediaQuery.of(this);
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(
          16,
          mediaQuery.padding.top + 16,
          16,
          0,
        ),
        duration: duration,
        dismissDirection: DismissDirection.horizontal,
      ),
    );
  }

  void showTopSnackBarWidget(
    Widget content, {
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 3),
  }) {
    final mediaQuery = MediaQuery.of(this);
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: content,
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(
          16,
          mediaQuery.padding.top + 16,
          16,
          0,
        ),
        duration: duration,
        dismissDirection: DismissDirection.horizontal,
      ),
    );
  }
}
