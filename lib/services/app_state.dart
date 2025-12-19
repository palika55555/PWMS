import 'package:flutter/foundation.dart';

class AppState extends ChangeNotifier {
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  Map<String, dynamic>? _syncStatus;
  Map<String, dynamic>? get syncStatus => _syncStatus;

  void setOnline(bool value) {
    _isOnline = value;
    notifyListeners();
  }

  void setSyncStatus(Map<String, dynamic>? status) {
    _syncStatus = status;
    notifyListeners();
  }
}

