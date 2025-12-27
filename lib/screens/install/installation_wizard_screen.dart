import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../database/local_database.dart';
import '../../providers/app_settings_provider.dart';

class InstallationWizardScreen extends StatefulWidget {
  const InstallationWizardScreen({super.key});

  @override
  State<InstallationWizardScreen> createState() => _InstallationWizardScreenState();
}

class _InstallationWizardScreenState extends State<InstallationWizardScreen> {
  int _step = 0;
  bool _busy = false;

  // DB step
  String? _dbDir;
  final _dbNameCtrl = TextEditingController(text: 'problock.db');

  // Backup step
  String? _backupDir;
  bool _autoBackupEnabled = true;
  int _autoBackupIntervalMinutes = 24 * 60;

  // API step
  final _apiCtrl = TextEditingController(text: 'http://localhost:3000');
  String? _apiTestResult;

  // Locale/theme step
  String _localeCode = 'sk';
  ThemeMode _themeMode = ThemeMode.light;
  Color _seedColor = Colors.blue;

  @override
  void dispose() {
    _dbNameCtrl.dispose();
    _apiCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Seed defaults from settings once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<AppSettingsProvider>();
      setState(() {
        _apiCtrl.text = settings.apiBaseUrl;
        _localeCode = settings.locale.languageCode;
        _themeMode = settings.themeMode;
        _seedColor = settings.seedColor;
        _backupDir = settings.backupDir;
        _autoBackupEnabled = settings.autoBackupEnabled;
        _autoBackupIntervalMinutes = settings.autoBackupIntervalMinutes;
      });
    });
  }

  String? _dbFullPath() {
    if (_dbDir == null || _dbDir!.trim().isEmpty) return null;
    final name = _dbNameCtrl.text.trim();
    if (name.isEmpty) return null;
    final fileName = name.toLowerCase().endsWith('.db') ? name : '$name.db';
    return '${_dbDir!}${Platform.pathSeparator}$fileName';
  }

  Future<void> _pickDbDirectory() async {
    final dir = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Vyber priečinok pre databázu');
    if (dir == null) return;
    setState(() => _dbDir = dir);
  }

  Future<void> _pickBackupDirectory() async {
    final dir = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Vyber priečinok pre zálohy');
    if (dir == null) return;
    setState(() => _backupDir = dir);
  }

  Future<void> _testApi() async {
    final url = _apiCtrl.text.trim();
    if (url.isEmpty) {
      setState(() => _apiTestResult = 'Zadaj URL');
      return;
    }

    setState(() {
      _busy = true;
      _apiTestResult = null;
    });
    try {
      final dio2 = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          validateStatus: (_) => true,
        ),
      );
      final resp = await dio2.get('$url/health');
      if (resp.statusCode == 200) {
        setState(() => _apiTestResult = 'OK');
      } else {
        setState(() => _apiTestResult = 'ERROR (HTTP ${resp.statusCode})');
      }
    } catch (e) {
      setState(() => _apiTestResult = 'ERROR');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _saveAndFinish() async {
    final settings = context.read<AppSettingsProvider>();

    final dbPath = _dbFullPath();
    if (dbPath == null) {
      _snack('Najprv vyber priečinok a názov DB.');
      return;
    }
    if (_backupDir == null || _backupDir!.trim().isEmpty) {
      _snack('Najprv nastav priečinok záloh.');
      return;
    }

    setState(() => _busy = true);
    try {
      // Persist settings
      await settings.setDatabaseFilePath(dbPath);
      await settings.setApiBaseUrl(_apiCtrl.text.trim().isEmpty ? 'http://localhost:3000' : _apiCtrl.text.trim());
      await settings.setLocaleCode(_localeCode);
      await settings.setBackupDir(_backupDir);
      await settings.setAutoBackupEnabled(_autoBackupEnabled);
      await settings.setAutoBackupIntervalMinutes(_autoBackupIntervalMinutes);
      await settings.setThemeMode(_themeMode);
      await settings.setSeedColor(_seedColor);

      // Create/open the DB at the selected location (creates schema if missing).
      await LocalDatabase.instance.closeDatabase();
      await LocalDatabase.instance.database;

      await settings.setInstallCompleted(true);

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _snack('Chyba pri inicializácii: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  bool _canContinue() {
    if (_busy) return false;
    if (_step == 1) return _dbFullPath() != null;
    if (_step == 2) return _backupDir != null && _backupDir!.trim().isNotEmpty;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inštalácia / nastavenie')),
      body: Stepper(
        currentStep: _step,
        onStepContinue: _canContinue()
            ? () async {
                if (_step < 5) {
                  setState(() => _step++);
                } else {
                  await _saveAndFinish();
                }
              }
            : null,
        onStepCancel: _busy
            ? null
            : () {
                if (_step == 0) {
                  Navigator.of(context).pop(false);
                } else {
                  setState(() => _step--);
                }
              },
        controlsBuilder: (context, details) {
          final isLast = _step == 4;
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                FilledButton(
                  onPressed: details.onStepContinue,
                  child: Text(isLast ? 'Dokončiť' : 'Ďalej'),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: details.onStepCancel,
                  child: Text(_step == 0 ? 'Zrušiť' : 'Späť'),
                ),
                if (_busy) ...[
                  const SizedBox(width: 12),
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('Vitajte'),
            isActive: _step >= 0,
            content: const Text(
              'Tento sprievodca nastaví databázu, zálohy, synchronizáciu a vzhľad.\n\n'
              'Poznámka: automatická záloha a sync fungujú, keď je aplikácia spustená.',
            ),
          ),
          Step(
            title: const Text('Databáza'),
            isActive: _step >= 1,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.folder),
                  title: const Text('Priečinok DB'),
                  subtitle: Text(_dbDir ?? 'Nie je vybraný'),
                  trailing: OutlinedButton(onPressed: _busy ? null : _pickDbDirectory, child: const Text('Vybrať')),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _dbNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Názov DB súboru',
                    hintText: 'napr. moja_firma.db',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Cesta: ${_dbFullPath() ?? '—'}'),
              ],
            ),
          ),
          Step(
            title: const Text('Zálohy'),
            isActive: _step >= 2,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.folder),
                  title: const Text('Priečinok záloh'),
                  subtitle: Text(_backupDir ?? 'Nie je vybraný'),
                  trailing: OutlinedButton(onPressed: _busy ? null : _pickBackupDirectory, child: const Text('Vybrať')),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _autoBackupEnabled,
                  onChanged: _busy ? null : (v) => setState(() => _autoBackupEnabled = v),
                  title: const Text('Automatická záloha'),
                  subtitle: const Text('Funguje, keď je aplikácia spustená'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: _autoBackupIntervalMinutes,
                  decoration: const InputDecoration(
                    labelText: 'Interval auto-zálohy',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 60, child: Text('Každú hodinu')),
                    DropdownMenuItem(value: 6 * 60, child: Text('Každých 6 hodín')),
                    DropdownMenuItem(value: 12 * 60, child: Text('Každých 12 hodín')),
                    DropdownMenuItem(value: 24 * 60, child: Text('Denne')),
                    DropdownMenuItem(value: 7 * 24 * 60, child: Text('Týždenne')),
                  ],
                  onChanged: _busy ? null : (v) => setState(() => _autoBackupIntervalMinutes = v ?? 24 * 60),
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Server & Sync'),
            isActive: _step >= 3,
            content: Column(
              children: [
                TextField(
                  controller: _apiCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Server URL (API)',
                    hintText: 'http://localhost:3000 alebo https://xxx.railway.app',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _testApi,
                        icon: const Icon(Icons.health_and_safety),
                        label: const Text('Otestovať /health'),
                      ),
                    ),
                  ],
                ),
                if (_apiTestResult != null) ...[
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerLeft, child: Text(_apiTestResult!)),
                ],
                const SizedBox(height: 8),
                const Text('Detailné sync prepínače vieš doladiť v Nastaveniach po dokončení.'),
              ],
            ),
          ),
          Step(
            title: const Text('Vzhľad & jazyk'),
            isActive: _step >= 4,
            content: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _localeCode,
                  decoration: const InputDecoration(
                    labelText: 'Jazyk',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'sk', child: Text('Slovenčina')),
                    DropdownMenuItem(value: 'cs', child: Text('Čeština')),
                    DropdownMenuItem(value: 'en', child: Text('English')),
                  ],
                  onChanged: _busy ? null : (v) => setState(() => _localeCode = v ?? 'sk'),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Téma'),
                  trailing: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                      ButtonSegment(value: ThemeMode.system, label: Text('System')),
                    ],
                    selected: {_themeMode},
                    onSelectionChanged: _busy ? null : (s) => setState(() => _themeMode = s.first),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in const [
                        Colors.blue,
                        Colors.teal,
                        Colors.green,
                        Colors.orange,
                        Colors.purple,
                        Colors.red,
                        Colors.blueGrey,
                      ])
                        InkWell(
                          onTap: _busy ? null : () => setState(() => _seedColor = c),
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _seedColor.value == c.value ? Colors.black : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Dokončenie'),
            isActive: _step >= 5,
            content: const Text(
              'Klikni „Dokončiť“ – aplikácia vytvorí/otvorí DB v zvolenom umiestnení a spustí sa.\n\n'
              'Admin PIN: admin',
            ),
          ),
        ],
      ),
    );
  }
}


