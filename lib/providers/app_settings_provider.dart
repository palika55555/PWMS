import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class AppSettingsProvider extends ChangeNotifier {
  static const _kInstallCompleted = 'install.completed';
  static const _kDatabaseFilePath = 'settings.db.filePath';
  static const _kApiBaseUrl = 'settings.api.baseUrl';
  static const _kLocaleCode = 'settings.locale.code';

  static const _kThemeMode = 'settings.themeMode'; // system|light|dark
  static const _kSeedColor = 'settings.seedColor'; // int
  static const _kSyncUploadEnabled = 'settings.sync.uploadEnabled';
  static const _kSyncDownloadEnabled = 'settings.sync.downloadEnabled';
  static const _kBackupDir = 'settings.backup.dir';
  static const _kAutoBackupEnabled = 'settings.backup.autoEnabled';
  static const _kAutoBackupIntervalMinutes = 'settings.backup.autoIntervalMinutes';
  static const _kLastAutoBackupAt = 'settings.backup.lastAutoBackupAt';

  bool _installCompleted = false;
  String? _databaseFilePath;
  String _apiBaseUrl = 'http://localhost:3000';
  String _localeCode = 'sk';

  ThemeMode _themeMode = ThemeMode.light;
  Color _seedColor = Colors.blue;

  bool _syncUploadEnabled = true;
  bool _syncDownloadEnabled = false;

  String? _backupDir;
  bool _autoBackupEnabled = false;
  int _autoBackupIntervalMinutes = 24 * 60; // daily
  DateTime? _lastAutoBackupAt;

  bool _adminUnlocked = false; // session-only

  final Completer<void> _ready = Completer<void>();
  Future<void> get ready => _ready.future;
  bool get isLoaded => _ready.isCompleted;

  bool get installCompleted => _installCompleted;
  String? get databaseFilePath => _databaseFilePath;
  String get apiBaseUrl => _apiBaseUrl;
  Locale get locale => Locale(_localeCode);

  ThemeMode get themeMode => _themeMode;
  Color get seedColor => _seedColor;
  bool get syncUploadEnabled => _syncUploadEnabled;
  bool get syncDownloadEnabled => _syncDownloadEnabled;
  String? get backupDir => _backupDir;
  bool get autoBackupEnabled => _autoBackupEnabled;
  int get autoBackupIntervalMinutes => _autoBackupIntervalMinutes;
  DateTime? get lastAutoBackupAt => _lastAutoBackupAt;
  bool get adminUnlocked => _adminUnlocked;

  AppSettingsProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    _installCompleted = prefs.getBool(_kInstallCompleted) ?? false;
    _databaseFilePath = prefs.getString(_kDatabaseFilePath);
    _apiBaseUrl = prefs.getString(_kApiBaseUrl) ?? _apiBaseUrl;
    _localeCode = prefs.getString(_kLocaleCode) ?? _localeCode;

    final mode = prefs.getString(_kThemeMode) ?? 'light';
    _themeMode = switch (mode) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };

    final seed = prefs.getInt(_kSeedColor);
    if (seed != null) _seedColor = Color(seed);

    _syncUploadEnabled = prefs.getBool(_kSyncUploadEnabled) ?? true;
    _syncDownloadEnabled = prefs.getBool(_kSyncDownloadEnabled) ?? false;
    _autoBackupEnabled = prefs.getBool(_kAutoBackupEnabled) ?? false;
    _autoBackupIntervalMinutes = prefs.getInt(_kAutoBackupIntervalMinutes) ?? (24 * 60);
    final last = prefs.getString(_kLastAutoBackupAt);
    _lastAutoBackupAt = last == null ? null : DateTime.tryParse(last);

    _backupDir = prefs.getString(_kBackupDir);
    _backupDir ??= await _defaultBackupDir();

    if (!_ready.isCompleted) _ready.complete();
    notifyListeners();
  }

  Future<void> setInstallCompleted(bool v) async {
    _installCompleted = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kInstallCompleted, v);
  }

  Future<void> setDatabaseFilePath(String path) async {
    _databaseFilePath = path;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDatabaseFilePath, path);
  }

  Future<void> setApiBaseUrl(String url) async {
    _apiBaseUrl = url;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kApiBaseUrl, url);
  }

  Future<void> setLocaleCode(String code) async {
    _localeCode = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocaleCode, code);
  }

  Future<String> _defaultBackupDir() async {
    // Windows-only requirement, but keep sane fallback for other platforms.
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}ProBlockPWMS${Platform.pathSeparator}Backups');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kThemeMode,
      switch (mode) {
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
        _ => 'light',
      },
    );
  }

  Future<void> setSeedColor(Color color) async {
    _seedColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSeedColor, color.value);
  }

  Future<void> setSyncUploadEnabled(bool v) async {
    _syncUploadEnabled = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSyncUploadEnabled, v);
  }

  Future<void> setSyncDownloadEnabled(bool v) async {
    _syncDownloadEnabled = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSyncDownloadEnabled, v);
  }

  Future<void> setBackupDir(String? dir) async {
    _backupDir = (dir == null || dir.isEmpty) ? await _defaultBackupDir() : dir;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBackupDir, _backupDir!);
  }

  Future<void> setAutoBackupEnabled(bool v) async {
    _autoBackupEnabled = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoBackupEnabled, v);
  }

  Future<void> setAutoBackupIntervalMinutes(int minutes) async {
    if (minutes < 15) minutes = 15;
    _autoBackupIntervalMinutes = minutes;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAutoBackupIntervalMinutes, minutes);
  }

  Future<void> setLastAutoBackupAt(DateTime? dt) async {
    _lastAutoBackupAt = dt;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (dt == null) {
      await prefs.remove(_kLastAutoBackupAt);
    } else {
      await prefs.setString(_kLastAutoBackupAt, dt.toIso8601String());
    }
  }

  bool unlockAdmin(String pin) {
    if (pin == 'admin') {
      _adminUnlocked = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  void lockAdmin() {
    _adminUnlocked = false;
    notifyListeners();
  }
}


