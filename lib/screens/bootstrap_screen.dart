import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../database/local_database.dart';
import '../providers/app_settings_provider.dart';
import 'home_screen.dart';
import 'install/installation_wizard_screen.dart';

class BootstrapScreen extends StatefulWidget {
  const BootstrapScreen({super.key});

  @override
  State<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<BootstrapScreen> {
  bool _started = false;
  bool _loadingDb = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Avoid Navigator operations during build/layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    final settings = context.read<AppSettingsProvider>();
    // Ensure settings have loaded from SharedPreferences before decision.
    await settings.ready;
    if (!settings.installCompleted) {
      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const InstallationWizardScreen()),
      );
      if (ok != true) {
        setState(() => _error = 'Inštalácia nebola dokončená.');
        return;
      }
    }

    setState(() {
      _loadingDb = true;
      _error = null;
    });

    try {
      await LocalDatabase.instance.database;
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingDb = false);
    }
  }

  Future<void> _retry() async {
    setState(() {
      _error = null;
      _loadingDb = false;
    });
    await _bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 40),
                const SizedBox(height: 12),
                Text('Chyba štartu', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Skúsiť znova'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_loadingDb) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return const HomeScreen();
  }
}


