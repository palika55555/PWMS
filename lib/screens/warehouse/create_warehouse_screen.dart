import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/database_provider.dart';
import '../../models/warehouse.dart';

class CreateWarehouseScreen extends StatefulWidget {
  final Warehouse? warehouse;

  const CreateWarehouseScreen({super.key, this.warehouse});

  @override
  State<CreateWarehouseScreen> createState() => _CreateWarehouseScreenState();
}

class _CreateWarehouseScreenState extends State<CreateWarehouseScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _countryController = TextEditingController(text: 'Slovensko');
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _managerController = TextEditingController();
  final _notesController = TextEditingController();

  bool _loading = false;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final w = widget.warehouse;
    if (w != null) {
      _nameController.text = w.name;
      _codeController.text = w.code ?? '';
      _addressController.text = w.address ?? '';
      _cityController.text = w.city ?? '';
      _zipCodeController.text = w.zipCode ?? '';
      _countryController.text = w.country ?? 'Slovensko';
      _phoneController.text = w.phone ?? '';
      _emailController.text = w.email ?? '';
      _managerController.text = w.manager ?? '';
      _notesController.text = w.notes ?? '';
      _isActive = w.isActive;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _zipCodeController.dispose();
    _countryController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _managerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveWarehouse() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      final warehouse = Warehouse(
        id: widget.warehouse?.id,
        name: _nameController.text.trim(),
        code: _codeController.text.trim().isEmpty ? null : _codeController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
        zipCode: _zipCodeController.text.trim().isEmpty ? null : _zipCodeController.text.trim(),
        country: _countryController.text.trim().isEmpty ? null : _countryController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        manager: _managerController.text.trim().isEmpty ? null : _managerController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        isActive: _isActive,
        createdAt: widget.warehouse?.createdAt ?? now,
        updatedAt: now,
      );

      if (widget.warehouse == null) {
        await dbProvider.insertWarehouse(warehouse);
      } else {
        await dbProvider.updateWarehouse(warehouse);
      }

      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    InputDecoration decoration(String label, IconData icon) =>
        InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        );

    Widget section(String title, List<Widget> children) => Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                ...children,
              ],
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.warehouse == null ? 'Nový sklad' : 'Upraviť sklad'),
        actions: [
          if (widget.warehouse != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Vymazať sklad'),
                    content: Text(
                        'Naozaj chcete vymazať sklad "${widget.warehouse!.name}"?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Zrušiť'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                            foregroundColor: Colors.red),
                        child: const Text('Vymazať'),
                      ),
                    ],
                  ),
                );

                if (confirm == true && mounted) {
                  final db = Provider.of<DatabaseProvider>(context, listen: false);
                  await db.deleteWarehouse(widget.warehouse!.id!);
                  Navigator.pop(context, true);
                }
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            section('Základné informácie', [
              TextFormField(
                controller: _nameController,
                decoration: decoration('Názov skladu *', Icons.warehouse),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Povinné pole' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _codeController,
                decoration: decoration('Kód skladu', Icons.qr_code),
              ),
            ]),
            section('Adresa', [
              TextFormField(
                controller: _addressController,
                decoration: decoration('Adresa', Icons.location_on),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cityController,
                      decoration: decoration('Mesto', Icons.location_city),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _zipCodeController,
                      decoration: decoration('PSČ', Icons.local_post_office),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _countryController,
                decoration: decoration('Krajina', Icons.public),
              ),
            ]),
            section('Kontakt', [
              TextFormField(
                controller: _phoneController,
                decoration: decoration('Telefón', Icons.phone),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: decoration('Email', Icons.email),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _managerController,
                decoration: decoration('Správca skladu', Icons.person),
              ),
            ]),
            section('Nastavenia', [
              SwitchListTile(
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                title: const Text('Aktívny sklad'),
                subtitle: const Text(
                    'Neaktívne sklady sa nezobrazujú v zozname'),
              ),
            ]),
            section('Poznámky', [
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: decoration('Interné poznámky', Icons.note),
              ),
            ]),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loading ? null : _saveWarehouse,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _loading
                  ? const CircularProgressIndicator()
                  : Text(widget.warehouse == null
                      ? 'Vytvoriť sklad'
                      : 'Uložiť zmeny'),
            ),
          ],
        ),
      ),
    );
  }
}
