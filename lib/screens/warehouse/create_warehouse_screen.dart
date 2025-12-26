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
    if (widget.warehouse != null) {
      _nameController.text = widget.warehouse!.name;
      _codeController.text = widget.warehouse!.code ?? '';
      _addressController.text = widget.warehouse!.address ?? '';
      _cityController.text = widget.warehouse!.city ?? '';
      _zipCodeController.text = widget.warehouse!.zipCode ?? '';
      _countryController.text = widget.warehouse!.country ?? 'Slovensko';
      _phoneController.text = widget.warehouse!.phone ?? '';
      _emailController.text = widget.warehouse!.email ?? '';
      _managerController.text = widget.warehouse!.manager ?? '';
      _notesController.text = widget.warehouse!.notes ?? '';
      _isActive = widget.warehouse!.isActive;
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
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _loading = true;
    });

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

      if (mounted) {
        final mediaQuery = MediaQuery.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.warehouse == null 
                ? 'Sklad bol úspešne vytvorený'
                : 'Sklad bol úspešne upravený'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              bottom: mediaQuery.size.height - mediaQuery.padding.top - 60,
              left: 16,
              right: 16,
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        final mediaQuery = MediaQuery.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              bottom: mediaQuery.size.height - mediaQuery.padding.top - 60,
              left: 16,
              right: 16,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.warehouse == null ? 'Nový sklad' : 'Upraviť sklad'),
        actions: [
          if (widget.warehouse != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Vymazať sklad'),
                    content: Text('Naozaj chcete vymazať sklad "${widget.warehouse!.name}"?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Zrušiť'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Vymazať'),
                      ),
                    ],
                  ),
                );

                if (confirm == true && mounted) {
                  try {
                    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
                    await dbProvider.deleteWarehouse(widget.warehouse!.id!);
                    
                    final mediaQuery = MediaQuery.of(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Sklad bol úspešne vymazaný'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        margin: EdgeInsets.only(
                          bottom: mediaQuery.size.height - mediaQuery.padding.top - 60,
                          left: 16,
                          right: 16,
                        ),
                      ),
                    );
                    Navigator.pop(context, true);
                  } catch (e) {
                    final mediaQuery = MediaQuery.of(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Chyba pri vymazávaní: $e'),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        margin: EdgeInsets.only(
                          bottom: mediaQuery.size.height - mediaQuery.padding.top - 60,
                          left: 16,
                          right: 16,
                        ),
                      ),
                    );
                  }
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
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Názov skladu *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.warehouse),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Prosím zadajte názov skladu';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'Kód skladu',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.qr_code),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Adresa',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      labelText: 'Mesto',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_city),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _zipCodeController,
                    decoration: const InputDecoration(
                      labelText: 'PSČ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _countryController,
              decoration: const InputDecoration(
                labelText: 'Krajina',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.public),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Telefón',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  if (!value.contains('@')) {
                    return 'Prosím zadajte platnú emailovú adresu';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _managerController,
              decoration: const InputDecoration(
                labelText: 'Správca skladu',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Aktívny sklad'),
              subtitle: const Text('Neaktívne sklady sa nezobrazujú v zozname'),
              value: _isActive,
              onChanged: (value) {
                setState(() {
                  _isActive = value;
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Poznámky',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _loading ? null : _saveWarehouse,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.warehouse == null ? 'Vytvoriť sklad' : 'Uložiť zmeny'),
            ),
          ],
        ),
      ),
    );
  }
}

