import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ZoomProvider with ChangeNotifier {
  double _zoomLevel = 1.0;
  static const String _zoomKey = 'app_zoom_level';

  double get zoomLevel => _zoomLevel;

  ZoomProvider() {
    _loadZoomLevel();
  }

  Future<void> _loadZoomLevel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _zoomLevel = prefs.getDouble(_zoomKey) ?? 1.0;
      notifyListeners();
    } catch (e) {
      _zoomLevel = 1.0;
    }
  }

  Future<void> setZoomLevel(double level) async {
    if (level < 0.5 || level > 2.0) return; // Limit zoom between 50% and 200%
    
    _zoomLevel = level;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_zoomKey, level);
    } catch (e) {
      // Ignore save errors
    }
  }

  Future<void> resetZoom() async {
    await setZoomLevel(1.0);
  }

  void zoomIn() {
    final newLevel = (_zoomLevel + 0.1).clamp(0.5, 2.0);
    setZoomLevel(newLevel);
  }

  void zoomOut() {
    final newLevel = (_zoomLevel - 0.1).clamp(0.5, 2.0);
    setZoomLevel(newLevel);
  }
}


