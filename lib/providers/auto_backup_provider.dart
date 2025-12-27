import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/db_backup_service.dart';
import 'app_settings_provider.dart';

class AutoBackupProvider extends ChangeNotifier {
  final DbBackupService _backupService = DbBackupService();

  Timer? _timer;
  AppSettingsProvider? _settings;

  bool _isRunning = false;
  bool _isBackingUp = false;
  String? _lastError;
  String? _lastBackupPath;

  bool get isRunning => _isRunning;
  bool get isBackingUp => _isBackingUp;
  String? get lastError => _lastError;
  String? get lastBackupPath => _lastBackupPath;

  void updateSettings(AppSettingsProvider settings) {
    // Avoid re-wiring listeners repeatedly.
    if (identical(_settings, settings)) return;

    _settings?.removeListener(_onSettingsChanged);
    _settings = settings;
    _settings!.addListener(_onSettingsChanged);

    _reconfigure();
  }

  void _onSettingsChanged() {
    _reconfigure();
  }

  void _reconfigure() {
    final s = _settings;
    if (s == null) return;

    final enabled = s.autoBackupEnabled;
    if (!enabled) {
      _stop();
      return;
    }

    _start();
  }

  void _start() {
    if (_timer != null) return;
    _isRunning = true;
    notifyListeners();

    // Tick frequently and decide based on interval (prevents timer drift).
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _tick());
    // Run an immediate check on enable/startup.
    _tick();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    if (_isRunning) {
      _isRunning = false;
      notifyListeners();
    }
  }

  Future<void> _tick() async {
    final s = _settings;
    if (s == null) return;
    if (!s.autoBackupEnabled) return;
    if (_isBackingUp) return;

    final dir = s.backupDir;
    if (dir == null || dir.isEmpty) return;

    final interval = Duration(minutes: s.autoBackupIntervalMinutes);
    final last = s.lastAutoBackupAt;
    final now = DateTime.now();

    if (last != null && now.difference(last) < interval) {
      return;
    }

    _isBackingUp = true;
    _lastError = null;
    notifyListeners();

    try {
      final path = await _backupService.backupNow(targetDir: dir);
      _lastBackupPath = path;
      await s.setLastAutoBackupAt(DateTime.now());
    } catch (e) {
      _lastError = e.toString();
    } finally {
      _isBackingUp = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _settings?.removeListener(_onSettingsChanged);
    super.dispose();
  }
}


