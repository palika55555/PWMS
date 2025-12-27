import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

import '../../providers/app_settings_provider.dart';
import '../../providers/auto_backup_provider.dart';
import '../../providers/sync_provider.dart';
import '../../services/db_backup_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final sync = context.watch<SyncProvider>();
    final autoBackup = context.watch<AutoBackupProvider>();
    final backupService = DbBackupService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nastavenia'),
        actions: [
          if (settings.adminUnlocked)
            TextButton.icon(
              onPressed: () => settings.lockAdmin(),
              icon: const Icon(Icons.lock_open),
              label: const Text('Admin'),
            )
          else
            TextButton.icon(
              onPressed: () => _showAdminUnlockDialog(context),
              icon: const Icon(Icons.lock),
              label: const Text('Admin'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: 'Synchronizácia',
            icon: Icons.sync,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.link),
                  title: const Text('Backend URL'),
                  subtitle: Text(settings.apiBaseUrl),
                  trailing: OutlinedButton(
                    onPressed: () => _showBackendUrlDialog(context),
                    child: const Text('Zmeniť'),
                  ),
                ),
                SwitchListTile(
                  value: settings.syncUploadEnabled,
                  onChanged: (v) => settings.setSyncUploadEnabled(v),
                  title: const Text('Upload (PC → server)'),
                  subtitle: const Text('Odošle lokálne zmeny, keď je internet'),
                ),
                SwitchListTile(
                  value: settings.syncDownloadEnabled,
                  onChanged: (v) => settings.setSyncDownloadEnabled(v),
                  title: const Text('Download overwrite (server → PC)'),
                  subtitle: const Text('Prepíše vybrané lokálne tabuľky podľa servera'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: sync.isSyncing
                            ? null
                            : () async {
                                // Push
                                if (settings.syncUploadEnabled) {
                                  await context.read<SyncProvider>().syncAll();
                                }

                                // Download overwrite
                                if (settings.syncDownloadEnabled) {
                                  if (!settings.adminUnlocked) {
                                    _snack(context, 'Download vyžaduje Admin PIN.');
                                    return;
                                  }
                                  final ok = await _confirmDestructive(
                                    context,
                                    title: 'Prepísať lokálne dáta?',
                                    message:
                                        'Týmto sa stiahne snapshot zo servera a prepíšu sa vybrané lokálne tabuľky.\n\nPokračovať?',
                                  );
                                  if (ok != true) return;
                                  await context.read<SyncProvider>().downloadOverwriteLocal();
                                }

                                final err = context.read<SyncProvider>().lastSyncError;
                                if (err == null) {
                                  _snack(context, 'Synchronizácia dokončená');
                                } else {
                                  _snack(context, 'Chyba sync: $err');
                                }
                              },
                        icon: const Icon(Icons.play_arrow),
                        label: Text(sync.isSyncing ? 'Prebieha…' : 'Spustiť teraz'),
                      ),
                    ),
                  ],
                ),
                if (sync.lastSyncError != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      sync.lastSyncError!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Zálohovanie databázy',
            icon: Icons.backup,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.folder),
                  title: const Text('Priečinok na zálohy'),
                  subtitle: Text(settings.backupDir ?? '—'),
                  trailing: OutlinedButton(
                    onPressed: () async {
                      final dir = await FilePicker.platform.getDirectoryPath(
                        dialogTitle: 'Vyber priečinok na zálohy',
                      );
                      if (dir != null) {
                        await settings.setBackupDir(dir);
                      }
                    },
                    child: const Text('Vybrať'),
                  ),
                ),
                SwitchListTile(
                  value: settings.autoBackupEnabled,
                  onChanged: (v) => settings.setAutoBackupEnabled(v),
                  title: const Text('Automatická záloha'),
                  subtitle: Text(
                    settings.autoBackupEnabled
                        ? 'Zapnuté • interval: ${_minutesLabel(settings.autoBackupIntervalMinutes)}'
                        : 'Vypnuté',
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child: settings.autoBackupEnabled
                      ? Padding(
                          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.schedule, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: DropdownButtonFormField<int>(
                                      value: _nearestIntervalValue(settings.autoBackupIntervalMinutes),
                                      decoration: const InputDecoration(
                                        labelText: 'Interval',
                                        border: OutlineInputBorder(),
                                      ),
                                      items: const [
                                        DropdownMenuItem(value: 60, child: Text('Každú hodinu')),
                                        DropdownMenuItem(value: 6 * 60, child: Text('Každých 6 hodín')),
                                        DropdownMenuItem(value: 12 * 60, child: Text('Každých 12 hodín')),
                                        DropdownMenuItem(value: 24 * 60, child: Text('Denne')),
                                        DropdownMenuItem(value: 7 * 24 * 60, child: Text('Týždenne')),
                                      ],
                                      onChanged: (v) {
                                        if (v != null) settings.setAutoBackupIntervalMinutes(v);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _autoBackupStatusText(settings, autoBackup),
                                  style: TextStyle(
                                    color: autoBackup.lastError == null
                                        ? Theme.of(context).colorScheme.onSurface.withOpacity(0.7)
                                        : Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          if (!settings.adminUnlocked) {
                            _snack(context, 'Záloha vyžaduje Admin PIN.');
                            return;
                          }
                          final dir = settings.backupDir;
                          if (dir == null || dir.isEmpty) {
                            _snack(context, 'Priečinok na zálohy nie je nastavený.');
                            return;
                          }
                          try {
                            final path = await backupService.backupNow(targetDir: dir);
                            _snack(context, 'Záloha uložená: $path');
                          } catch (e) {
                            _snack(context, 'Chyba zálohy: $e');
                          }
                        },
                        icon: const Icon(Icons.save),
                        label: const Text('Zálohovať teraz'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          if (!settings.adminUnlocked) {
                            _snack(context, 'Obnova vyžaduje Admin PIN.');
                            return;
                          }
                          final ok = await _confirmDestructive(
                            context,
                            title: 'Obnoviť databázu?',
                            message: 'Týmto prepíšeš lokálnu DB zo zálohy.\n\nPokračovať?',
                          );
                          if (ok != true) return;

                          final result = await FilePicker.platform.pickFiles(
                            dialogTitle: 'Vyber DB zálohu',
                            type: FileType.custom,
                            allowedExtensions: const ['db', 'sqlite', 'bak'],
                          );
                          final path = result?.files.single.path;
                          if (path == null) return;

                          try {
                            await backupService.restoreFromFile(sourcePath: path);
                            _snack(context, 'Databáza obnovená. Reštart obrazoviek môže byť potrebný.');
                          } catch (e) {
                            _snack(context, 'Chyba obnovy: $e');
                          }
                        },
                        icon: const Icon(Icons.restore),
                        label: const Text('Obnoviť'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Vzhľad',
            icon: Icons.palette,
            child: Column(
              children: [
                ListTile(
                  title: const Text('Téma'),
                  subtitle: Text(_themeLabel(settings.themeMode)),
                  trailing: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                      ButtonSegment(value: ThemeMode.system, label: Text('System')),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (s) => settings.setThemeMode(s.first),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  title: const Text('Farba (seed)'),
                  subtitle: Text('#${settings.seedColor.value.toRadixString(16).padLeft(8, '0')}'),
                  trailing: Wrap(
                    spacing: 8,
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
                          onTap: () => settings.setSeedColor(c),
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: settings.seedColor.value == c.value
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Colors.transparent,
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
        ],
      ),
    );
  }

  static String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.dark => 'Dark',
        ThemeMode.system => 'System',
        _ => 'Light',
      };

  static String _minutesLabel(int minutes) {
    if (minutes % (7 * 24 * 60) == 0) return '${minutes ~/ (7 * 24 * 60)} týž.';
    if (minutes % (24 * 60) == 0) return '${minutes ~/ (24 * 60)} deň';
    if (minutes % 60 == 0) return '${minutes ~/ 60} hod.';
    return '$minutes min';
  }

  static int _nearestIntervalValue(int minutes) {
    const options = [60, 6 * 60, 12 * 60, 24 * 60, 7 * 24 * 60];
    if (options.contains(minutes)) return minutes;
    // default to daily if custom
    return 24 * 60;
  }

  static String _autoBackupStatusText(AppSettingsProvider settings, AutoBackupProvider autoBackup) {
    if (autoBackup.isBackingUp) return 'Prebieha automatická záloha…';
    if (autoBackup.lastError != null) return 'Chyba auto-zálohy: ${autoBackup.lastError}';
    final last = settings.lastAutoBackupAt;
    if (last == null) return 'Posledná auto-záloha: ešte neprebehla';
    return 'Posledná auto-záloha: ${last.toLocal().toString()}';
  }

  static void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  static Future<bool?> _confirmDestructive(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Zrušiť')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Pokračovať'),
          ),
        ],
      ),
    );
  }

  static Future<void> _showAdminUnlockDialog(BuildContext context) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Admin prístup'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'PIN',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
          autofocus: true,
          onSubmitted: (_) => Navigator.pop(context, true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Zrušiť')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Odomknúť')),
        ],
      ),
    );

    if (ok == true) {
      final success = context.read<AppSettingsProvider>().unlockAdmin(controller.text.trim());
      if (!success) {
        _snack(context, 'Nesprávny PIN');
      } else {
        _snack(context, 'Admin režim odomknutý');
      }
    }
  }

  static Future<void> _showBackendUrlDialog(BuildContext context) async {
    final settings = context.read<AppSettingsProvider>();
    final controller = TextEditingController(text: settings.apiBaseUrl);
    String? testResult;
    bool busy = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          Future<void> test() async {
            final url = controller.text.trim().replaceAll(RegExp(r'/+$'), '');
            if (url.isEmpty) {
              setState(() => testResult = 'Zadaj URL');
              return;
            }

            setState(() {
              busy = true;
              testResult = null;
            });

            try {
              final dio = Dio(
                BaseOptions(
                  connectTimeout: const Duration(seconds: 5),
                  receiveTimeout: const Duration(seconds: 5),
                  validateStatus: (_) => true,
                ),
              );
              final resp = await dio.get('$url/health');
              if (resp.statusCode == 200) {
                setState(() => testResult = 'OK');
              } else {
                setState(() => testResult = 'ERROR (HTTP ${resp.statusCode})');
              }
            } catch (e) {
              setState(() => testResult = 'ERROR');
            } finally {
              setState(() => busy = false);
            }
          }

          Future<void> save() async {
            final url = controller.text.trim().replaceAll(RegExp(r'/+$'), '');
            if (url.isEmpty) return;
            await settings.setApiBaseUrl(url);
            if (ctx.mounted) Navigator.pop(ctx);
            _snack(context, 'Backend URL uložené');
          }

          return AlertDialog(
            title: const Text('Backend URL'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'URL',
                    hintText: 'https://pwms-production.up.railway.app',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                if (testResult != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(testResult!),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(ctx),
                child: const Text('Zrušiť'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : test,
                icon: const Icon(Icons.health_and_safety),
                label: Text(busy ? 'Testujem…' : 'Test /health'),
              ),
              FilledButton(
                onPressed: busy ? null : save,
                child: const Text('Uložiť'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}


