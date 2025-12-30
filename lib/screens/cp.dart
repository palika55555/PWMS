import 'dart:typed_data';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:async';
import 'dart:convert';

class PriceOfferItem {
  String name;
  String description;
  double qty;
  double unitPrice;
  String unit;
  double? additionalFee;
  String? additionalFeeName;
  String itemType; // 'tovar', 'obalovy_material', 'paleta'

  PriceOfferItem({
    required this.name,
    required this.description,
    required this.qty,
    required this.unitPrice,
    this.unit = 'ks',
    this.additionalFee,
    this.additionalFeeName,
    this.itemType = 'tovar',
  });

  double get total => (qty * unitPrice) + (additionalFee ?? 0);
}

class CpScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  
  const CpScreen({super.key, this.initialData});

  @override
  State<CpScreen> createState() => _CpScreenState();
}

class _CpScreenState extends State<CpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dateFmt = DateFormat('dd.MM.yyyy');

  DateTime _issueDate = DateTime.now();
  String _offerNumber = _generateOfferNumber();

  final _issuerName = TextEditingController();
  final _issuerAddress = TextEditingController();
  final _issuerIco = TextEditingController();
  final _issuerDic = TextEditingController();
  final _issuerIcdph = TextEditingController();
  final _issuerContactPerson = TextEditingController();
  final _issuerPhone = TextEditingController();
  final _issuerEmail = TextEditingController();

  final _customerName = TextEditingController();
  final _customerAddress = TextEditingController();
  final _customerContactPerson = TextEditingController();
  final _customerIco = TextEditingController();
  final _customerDic = TextEditingController();
  final _customerIcdph = TextEditingController();
  final _customerPhone = TextEditingController();
  final _customerEmail = TextEditingController();

  final _validityDays = TextEditingController(text: '14');
  final _paymentMethod = TextEditingController(text: 'Bankový prevod');
  final _deliveryTerm = TextEditingController(text: 'Dohodou');

  final _vatPercent = TextEditingController(text: '20');
  bool _vatExempt = false;
  final _shipping = TextEditingController(text: '0');
  final _otherFees = TextEditingController(text: '0');
  final _deposit = TextEditingController(text: '0');

  final _notes = TextEditingController();

  Uint8List? _logoBytes;
  String? _logoName;

  bool _loadingIco = false;
  Timer? _icoDebounceTimer;
  String? _lastIcoFetched;

  bool _loadingCustomerIco = false;
  Timer? _customerIcoDebounceTimer;
  String? _lastCustomerIcoFetched;

  final List<PriceOfferItem> _items = [
    PriceOfferItem(name: '', description: '', qty: 1, unitPrice: 0, itemType: 'tovar'),
  ];

  static String _generateOfferNumber() {
    final now = DateTime.now();
    final y = now.year.toString();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    return 'CP-$y$m$d-$hh$mm';
  }

  @override
  void initState() {
    super.initState();
    _issuerIco.addListener(_onIssuerIcoChanged);
    _customerIco.addListener(_onCustomerIcoChanged);
    
    // Load initial data if provided
    if (widget.initialData != null) {
      _loadInitialData(widget.initialData!);
    }
  }

  void _loadInitialData(Map<String, dynamic> data) {
    setState(() {
      _offerNumber = data['offerNumber'] ?? _generateOfferNumber();
      _issueDate = DateTime.parse(data['issueDate'] ?? DateTime.now().toIso8601String());

      final issuer = data['issuer'] ?? {};
      _issuerName.text = issuer['name'] ?? '';
      _issuerAddress.text = issuer['address'] ?? '';
      _issuerIco.text = issuer['ico'] ?? '';
      _issuerDic.text = issuer['dic'] ?? '';
      _issuerIcdph.text = issuer['icdph'] ?? '';
      _issuerContactPerson.text = issuer['contactPerson'] ?? '';
      _issuerPhone.text = issuer['phone'] ?? '';
      _issuerEmail.text = issuer['email'] ?? '';

      final customer = data['customer'] ?? {};
      _customerName.text = customer['name'] ?? '';
      _customerAddress.text = customer['address'] ?? '';
      _customerContactPerson.text = customer['contactPerson'] ?? '';
      _customerIco.text = customer['ico'] ?? '';
      _customerDic.text = customer['dic'] ?? '';
      _customerIcdph.text = customer['icdph'] ?? '';
      _customerPhone.text = customer['phone'] ?? '';
      _customerEmail.text = customer['email'] ?? '';

      _validityDays.text = data['validityDays'] ?? '14';
      _paymentMethod.text = data['paymentMethod'] ?? 'Bankový prevod';
      _deliveryTerm.text = data['deliveryTerm'] ?? 'Dohodou';
      _vatPercent.text = data['vatPercent'] ?? '20';
      _vatExempt = data['vatExempt'] ?? false;
      _shipping.text = data['shipping'] ?? '0';
      _otherFees.text = data['otherFees'] ?? '0';
      _deposit.text = data['deposit'] ?? '0';
      _notes.text = data['notes'] ?? '';

      _logoName = data['logoName'];
      _logoBytes = data['logoBytes'] != null ? base64Decode(data['logoBytes']) : null;

      final itemsData = data['items'] as List? ?? [];
      _items.clear();
      for (final itemData in itemsData) {
        _items.add(PriceOfferItem(
          name: itemData['name'] ?? '',
          description: itemData['description'] ?? '',
          qty: (itemData['qty'] ?? 0).toDouble(),
          unitPrice: (itemData['unitPrice'] ?? 0).toDouble(),
          unit: itemData['unit'] ?? 'ks',
          additionalFee: itemData['additionalFee']?.toDouble(),
          additionalFeeName: itemData['additionalFeeName'],
          itemType: itemData['itemType'] ?? 'tovar',
        ));
      }

      if (_items.isEmpty) {
        _items.add(PriceOfferItem(name: '', description: '', qty: 1, unitPrice: 0, itemType: 'tovar'));
      }
    });
  }

  @override
  void dispose() {
    _icoDebounceTimer?.cancel();
    _customerIcoDebounceTimer?.cancel();
    _issuerName.dispose();
    _issuerAddress.dispose();
    _issuerIco.dispose();
    _issuerDic.dispose();
    _issuerIcdph.dispose();
    _issuerContactPerson.dispose();
    _issuerPhone.dispose();
    _issuerEmail.dispose();

    _customerName.dispose();
    _customerAddress.dispose();
    _customerContactPerson.dispose();
    _customerIco.dispose();
    _customerDic.dispose();
    _customerIcdph.dispose();
    _customerPhone.dispose();
    _customerEmail.dispose();

    _validityDays.dispose();
    _paymentMethod.dispose();
    _deliveryTerm.dispose();

    _vatPercent.dispose();
    _shipping.dispose();
    _otherFees.dispose();

    _notes.dispose();
    super.dispose();
  }

  void _onIssuerIcoChanged() {
    _icoDebounceTimer?.cancel();
    _icoDebounceTimer = Timer(const Duration(milliseconds: 800), () {
      final ico = _issuerIco.text.trim();
      if (ico.length >= 8 && ico.length <= 10) {
        if (_lastIcoFetched == ico) return;
        _fetchIssuerCompanyData(ico);
      }
    });
  }

  void _onCustomerIcoChanged() {
    _customerIcoDebounceTimer?.cancel();
    _customerIcoDebounceTimer = Timer(const Duration(milliseconds: 800), () {
      final ico = _customerIco.text.trim();
      if (ico.length >= 8 && ico.length <= 10) {
        if (_lastCustomerIcoFetched == ico) return;
        _fetchCustomerCompanyData(ico);
      }
    });
  }

  Future<void> _fetchIssuerCompanyData(String ico) async {
    if (_loadingIco || !mounted) return;

    setState(() => _loadingIco = true);
    try {
      final finstatResult = await _fetchFromFinstat(ico);
      if (finstatResult != null && mounted) {
        setState(() {
          _lastIcoFetched = ico;

          final name = finstatResult['name'];
          if (name != null && name.isNotEmpty && _issuerName.text.trim().isEmpty) {
            _issuerName.text = name;
          }

          final taxId = finstatResult['taxId'];
          if (taxId != null && taxId.isNotEmpty && _issuerDic.text.trim().isEmpty) {
            _issuerDic.text = taxId;
          }

          final vatId = finstatResult['vatId'];
          if (vatId != null && vatId.isNotEmpty && _issuerIcdph.text.trim().isEmpty) {
            _issuerIcdph.text = vatId;
          }

          final address = finstatResult['address'];
          final city = finstatResult['city'];
          final zip = finstatResult['zipCode'];
          final country = finstatResult['country'];

          if (_issuerAddress.text.trim().isEmpty) {
            final parts = <String>[];
            if (address != null && address.isNotEmpty) parts.add(address);
            final cityLine = [zip, city].where((v) => v != null && v.toString().trim().isNotEmpty).join(' ');
            if (cityLine.trim().isNotEmpty) parts.add(cityLine.trim());
            if (country != null && country.isNotEmpty) parts.add(country);
            if (parts.isNotEmpty) _issuerAddress.text = parts.join(', ');
          }
        });

        if (mounted) {
          final mediaQuery = MediaQuery.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Údaje boli načítané podľa IČO (Finstat.sk)'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: mediaQuery.size.height - mediaQuery.padding.top - 100,
              ),
            ),
          );
        }
      }
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loadingIco = false);
    }
  }

  Future<void> _fetchCustomerCompanyData(String ico) async {
    if (_loadingCustomerIco || !mounted) return;

    setState(() => _loadingCustomerIco = true);
    try {
      final finstatResult = await _fetchFromFinstat(ico);
      if (finstatResult != null && mounted) {
        setState(() {
          _lastCustomerIcoFetched = ico;

          final name = finstatResult['name'];
          if (name != null && name.isNotEmpty && _customerName.text.trim().isEmpty) {
            _customerName.text = name;
          }

          final taxId = finstatResult['taxId'];
          if (taxId != null && taxId.isNotEmpty && _customerDic.text.trim().isEmpty) {
            _customerDic.text = taxId;
          }

          final vatId = finstatResult['vatId'];
          if (vatId != null && vatId.isNotEmpty && _customerIcdph.text.trim().isEmpty) {
            _customerIcdph.text = vatId;
          }

          final address = finstatResult['address'];
          final city = finstatResult['city'];
          final zip = finstatResult['zipCode'];
          final country = finstatResult['country'];

          if (_customerAddress.text.trim().isEmpty) {
            final parts = <String>[];
            if (address != null && address.isNotEmpty) parts.add(address);
            final cityLine = [zip, city].where((v) => v != null && v.toString().trim().isNotEmpty).join(' ');
            if (cityLine.trim().isNotEmpty) parts.add(cityLine.trim());
            if (country != null && country.isNotEmpty) parts.add(country);
            if (parts.isNotEmpty) _customerAddress.text = parts.join(', ');
          }
        });

        if (mounted) {
          final mediaQuery = MediaQuery.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Údaje zákazníka boli načítané podľa IČO (Finstat.sk)'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: mediaQuery.size.height - mediaQuery.padding.top - 100,
              ),
            ),
          );
        }
      }
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loadingCustomerIco = false);
    }
  }

  Future<Map<String, String>?> _fetchFromFinstat(String ico) async {
    try {
      final detailUrl = Uri.parse('https://www.finstat.sk/$ico');
      final response = await http.get(
        detailUrl,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'sk-SK,sk;q=0.9,en-US;q=0.8,en;q=0.7',
          'Referer': 'https://www.finstat.sk/',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final html = response.body;

        // 1) Try embedded JSON
        final jsonPatterns = [
          RegExp(r'window\.__INITIAL_STATE__\s*=\s*({.+?});', dotAll: true),
          RegExp(r'window\.__APOLLO_STATE__\s*=\s*({.+?});', dotAll: true),
          RegExp(r'data-company\s*=\s*"([^"]+)"', dotAll: true),
        ];

        for (final pattern in jsonPatterns) {
          final match = pattern.firstMatch(html);
          if (match != null) {
            try {
              final jsonStr = match
                  .group(1)!
                  .replaceAll('&quot;', '"')
                  .replaceAll('&amp;', '&');
              final data = json.decode(jsonStr);
              final parsed = _parseFinstatData(data);
              if (parsed != null && parsed['name']?.isNotEmpty == true) return parsed;
            } catch (_) {
              // ignore
            }
          }
        }

        // 2) Fallback HTML parsing
        final parsedHtml = _parseFinstatHtml(html);
        if (parsedHtml != null && parsedHtml['name']?.isNotEmpty == true) return parsedHtml;
      }
    } catch (_) {
      // ignore
    }
    return null;
  }

  Map<String, String>? _parseFinstatData(dynamic data) {
    try {
      final result = <String, String>{};

      dynamic findValue(dynamic obj, List<String> keys) {
        if (obj is Map) {
          for (final key in keys) {
            if (obj.containsKey(key)) return obj[key];
            for (final k in obj.keys) {
              if (k.toString().toLowerCase() == key.toLowerCase()) return obj[k];
            }
          }
          for (final v in obj.values) {
            if (v is Map || v is List) {
              final found = findValue(v, keys);
              if (found != null) return found;
            }
          }
        } else if (obj is List) {
          for (final it in obj) {
            if (it is Map || it is List) {
              final found = findValue(it, keys);
              if (found != null) return found;
            }
          }
        }
        return null;
      }

      final name = findValue(data, ['name', 'nazov', 'companyName', 'nazovUJ', 'title']);
      if (name != null) result['name'] = name.toString();

      final taxId = findValue(data, ['dic', 'taxId', 'DIC', 'tax_id']);
      if (taxId != null) result['taxId'] = taxId.toString();

      final vatId = findValue(data, ['icDph', 'vatId', 'IC_DPH', 'vat_id', 'ic_dph']);
      if (vatId != null) {
        result['vatId'] = vatId.toString();
      } else if (taxId != null) {
        result['vatId'] = taxId.toString();
      }

      final street = findValue(data, ['ulica', 'street', 'address', 'adresa']);
      final streetNumber = findValue(data, ['cisloDomu', 'cisloOrientacne', 'streetNumber', 'houseNumber']);
      if (street != null) {
        result['address'] = (streetNumber != null && streetNumber.toString().isNotEmpty)
            ? '${street.toString()} ${streetNumber.toString()}'
            : street.toString();
      }

      final city = findValue(data, ['mesto', 'city', 'obec']);
      if (city != null) result['city'] = city.toString();

      final zipCode = findValue(data, ['psc', 'zipCode', 'PSC', 'zip', 'postalCode']);
      if (zipCode != null) result['zipCode'] = zipCode.toString().replaceAll(' ', '');

      final country = findValue(data, ['stat', 'country', 'krajina']);
      if (country != null) result['country'] = country.toString();

      return result.isEmpty ? null : result;
    } catch (_) {
      return null;
    }
  }

  Map<String, String>? _parseFinstatHtml(String html) {
    try {
      final result = <String, String>{};

      // name
      final namePatterns = [
        RegExp(r'<h1[^>]*>([^<]+)</h1>', caseSensitive: false),
        RegExp(r'<title>([^<]+)</title>', caseSensitive: false),
        RegExp(r'class="company-name"[^>]*>([^<]+)</', caseSensitive: false),
      ];
      for (final p in namePatterns) {
        final m = p.firstMatch(html);
        if (m != null) {
          final name = _decodeHtmlEntities(_cleanHtmlText(m.group(1)!.trim()));
          if (name.isNotEmpty && !name.toLowerCase().contains('finstat')) {
            result['name'] = name;
            break;
          }
        }
      }

      // DIČ
      final dicPatterns = [
        RegExp(r'<strong[^>]*>DIČ</strong>\s*<span[^>]*>([^<]+)</span>', caseSensitive: false),
        RegExp(r'DIČ[:\s]*([A-Z]{2}\d{8,12})', caseSensitive: false),
        RegExp(r'<strong[^>]*>DIČ</strong>\s*<span[^>]*>(\d{8,12})</span>', caseSensitive: false),
      ];
      for (final p in dicPatterns) {
        final m = p.firstMatch(html);
        if (m != null) {
          final v = _decodeHtmlEntities(_cleanHtmlText(m.group(1)!.trim()));
          if (v.isNotEmpty) {
            result['taxId'] = v;
            break;
          }
        }
      }

      // IČ DPH
      final icDphPatterns = [
        RegExp(r'<strong[^>]*>IČ\s*DPH</strong>\s*<span[^>]*>([^<]+)</span>', caseSensitive: false),
        RegExp(r'IČ\s*DPH[:\s]*([A-Z]{2}\d{8,12})', caseSensitive: false),
      ];
      for (final p in icDphPatterns) {
        final m = p.firstMatch(html);
        if (m != null) {
          var v = _decodeHtmlEntities(_cleanHtmlText(m.group(1)!.trim()));
          v = v.replaceAll(RegExp(r'^(SK)\s+(\d+)', caseSensitive: false), r'$1$2');
          if (v.isNotEmpty && RegExp(r'^\d+$').hasMatch(v)) v = 'SK$v';
          if (v.isNotEmpty) {
            result['vatId'] = v;
            break;
          }
        }
      }

      if (!result.containsKey('vatId') && result.containsKey('taxId')) {
        final dic = result['taxId']!;
        result['vatId'] = dic.toUpperCase().startsWith('SK') ? dic : 'SK$dic';
      }

      // Sídlo block
      final sidloBlock = RegExp(r'<strong[^>]*>Sídlo</strong>\s*<span[^>]*>(.*?)</span>',
              caseSensitive: false, dotAll: true)
          .firstMatch(html)
          ?.group(1);
      if (sidloBlock != null) {
        final normalized = sidloBlock
            .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
            .replaceAll(RegExp(r'<[^>]+>'), ' ');
        final lines = normalized
            .split('\n')
            .map((e) => _decodeHtmlEntities(_cleanHtmlText(e)).trim())
            .where((e) => e.isNotEmpty)
            .toList();

        // heuristics: address line usually contains digits, zip+city line contains 5 digits
        String? address;
        String? zip;
        String? city;

        for (final l in lines) {
          final zipMatch = RegExp(r'(\d{3})\s?(\d{2})').firstMatch(l);
          if (zipMatch != null && zip == null) {
            zip = '${zipMatch.group(1)}${zipMatch.group(2)}';
            final rest = l.replaceAll(zipMatch.group(0)!, '').trim();
            if (rest.isNotEmpty) city = rest;
            continue;
          }
          if (address == null && RegExp(r'\d').hasMatch(l)) {
            address = l;
          }
        }

        if (address != null) result['address'] = address;
        if (zip != null) result['zipCode'] = zip;
        if (city != null) result['city'] = city;
        result['country'] = result['country'] ?? 'Slovensko';
      }

      return result.isEmpty ? null : result;
    } catch (_) {
      return null;
    }
  }

  String _cleanHtmlText(String input) {
    return input
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\u00A0'), ' ')
        .trim();
  }

  String _decodeHtmlEntities(String input) {
    return input
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ');
  }

  double get _itemsSubtotal => _items.fold(0, (sum, i) => sum + i.total);

  double get _palletDepositTotal => _items
      .where((i) => i.itemType == 'paleta')
      .fold(0, (sum, i) => sum + (i.unitPrice * i.qty));

  double get _vatRate {
    if (_vatExempt) return 0.0;
    final p = double.tryParse(_vatPercent.text.trim().replaceAll(',', '.')) ?? 0;
    return (p.clamp(0, 100)) / 100.0;
  }

  double get _shippingValue => double.tryParse(_shipping.text.trim().replaceAll(',', '.')) ?? 0;

  double get _otherFeesValue => double.tryParse(_otherFees.text.trim().replaceAll(',', '.')) ?? 0;

  double get _depositValue => (double.tryParse(_deposit.text.trim().replaceAll(',', '.')) ?? 0) + _palletDepositTotal;

  double get _totalBase => _itemsSubtotal + _shippingValue + _otherFeesValue;

  double get _vatValue => _totalBase * _vatRate;

  double get _totalWithVat => _totalBase + _vatValue - _depositValue;

  String _money(double v) => NumberFormat.currency(locale: 'sk_SK', symbol: '€').format(v);

  String _getItemTypeDisplay(String itemType) {
    switch (itemType) {
      case 'tovar':
        return 'Tovar';
      case 'obalovy_material':
        return 'Obalový mat.';
      case 'paleta':
        return 'Paleta';
      default:
        return 'Tovar';
    }
  }

  Future<void> _pickLogo() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );

    final f = res?.files.single;
    if (f == null) return;

    setState(() {
      _logoBytes = f.bytes;
      _logoName = f.name;
    });
  }

  Future<void> _savePriceOffer() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    try {
      // Create directory if it doesn't exist
      final directory = Directory('vystavene_cp');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Create price offer data
      final offerData = {
        'offerNumber': _offerNumber,
        'issueDate': _issueDate.toIso8601String(),
        'issuer': {
          'name': _issuerName.text,
          'address': _issuerAddress.text,
          'ico': _issuerIco.text,
          'dic': _issuerDic.text,
          'icdph': _issuerIcdph.text,
          'contactPerson': _issuerContactPerson.text,
          'phone': _issuerPhone.text,
          'email': _issuerEmail.text,
        },
        'customer': {
          'name': _customerName.text,
          'address': _customerAddress.text,
          'contactPerson': _customerContactPerson.text,
          'ico': _customerIco.text,
          'dic': _customerDic.text,
          'icdph': _customerIcdph.text,
          'phone': _customerPhone.text,
          'email': _customerEmail.text,
        },
        'items': _items.map((i) => {
          'name': i.name,
          'description': i.description,
          'qty': i.qty,
          'unitPrice': i.unitPrice,
          'unit': i.unit,
          'additionalFee': i.additionalFee,
          'additionalFeeName': i.additionalFeeName,
          'itemType': i.itemType,
        }).toList(),
        'validityDays': _validityDays.text,
        'paymentMethod': _paymentMethod.text,
        'deliveryTerm': _deliveryTerm.text,
        'vatPercent': _vatPercent.text,
        'vatExempt': _vatExempt,
        'shipping': _shipping.text,
        'otherFees': _otherFees.text,
        'deposit': _deposit.text,
        'notes': _notes.text,
        'logoName': _logoName,
        'logoBytes': _logoBytes != null ? base64Encode(_logoBytes!) : null,
        'createdAt': DateTime.now().toIso8601String(),
      };

      // Save to JSON file
      final fileName = '$_offerNumber.json';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(jsonEncode(offerData));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cenová ponuka uložená ako $fileName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba pri ukladaní: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadPriceOffer() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        final data = jsonDecode(content);

        // Load all data
        setState(() {
          _offerNumber = data['offerNumber'] ?? _generateOfferNumber();
          _issueDate = DateTime.parse(data['issueDate'] ?? DateTime.now().toIso8601String());

          final issuer = data['issuer'] ?? {};
          _issuerName.text = issuer['name'] ?? '';
          _issuerAddress.text = issuer['address'] ?? '';
          _issuerIco.text = issuer['ico'] ?? '';
          _issuerDic.text = issuer['dic'] ?? '';
          _issuerIcdph.text = issuer['icdph'] ?? '';
          _issuerContactPerson.text = issuer['contactPerson'] ?? '';
          _issuerPhone.text = issuer['phone'] ?? '';
          _issuerEmail.text = issuer['email'] ?? '';

          final customer = data['customer'] ?? {};
          _customerName.text = customer['name'] ?? '';
          _customerAddress.text = customer['address'] ?? '';
          _customerContactPerson.text = customer['contactPerson'] ?? '';
          _customerIco.text = customer['ico'] ?? '';
          _customerDic.text = customer['dic'] ?? '';
          _customerIcdph.text = customer['icdph'] ?? '';
          _customerPhone.text = customer['phone'] ?? '';
          _customerEmail.text = customer['email'] ?? '';

          _validityDays.text = data['validityDays'] ?? '14';
          _paymentMethod.text = data['paymentMethod'] ?? 'Bankový prevod';
          _deliveryTerm.text = data['deliveryTerm'] ?? 'Dohodou';
          _vatPercent.text = data['vatPercent'] ?? '20';
          _vatExempt = data['vatExempt'] ?? false;
          _shipping.text = data['shipping'] ?? '0';
          _otherFees.text = data['otherFees'] ?? '0';
          _deposit.text = data['deposit'] ?? '0';
          _notes.text = data['notes'] ?? '';

          _logoName = data['logoName'];
          _logoBytes = data['logoBytes'] != null ? base64Decode(data['logoBytes']) : null;

          final itemsData = data['items'] as List? ?? [];
          _items.clear();
          for (final itemData in itemsData) {
            _items.add(PriceOfferItem(
              name: itemData['name'] ?? '',
              description: itemData['description'] ?? '',
              qty: (itemData['qty'] ?? 0).toDouble(),
              unitPrice: (itemData['unitPrice'] ?? 0).toDouble(),
              unit: itemData['unit'] ?? 'ks',
              additionalFee: itemData['additionalFee']?.toDouble(),
              additionalFeeName: itemData['additionalFeeName'],
            ));
          }

          if (_items.isEmpty) {
            _items.add(PriceOfferItem(name: '', description: '', qty: 1, unitPrice: 0));
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cenová ponuka načítaná'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba pri načítaní: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _printPdf() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    // Use built-in Helvetica font for PDF generation
    final unicodeFont = pw.Font.helvetica();
    final unicodeFontBold = pw.Font.helveticaBold();

    final doc = pw.Document();

    final logo = _logoBytes == null ? null : pw.MemoryImage(_logoBytes!);

    final items = _items.where((i) => i.name.trim().isNotEmpty).toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(20, 20, 20, 20),
        theme: pw.ThemeData.withFont(
          base: unicodeFont,
          bold: unicodeFontBold,
        ),
        build: (ctx) {
          return [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Cenová ponuka', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 8),
                    pw.Text('Dátum vystavenia: ${_dateFmt.format(_issueDate)}'),
                    pw.Text('Číslo ponuky: $_offerNumber'),
                  ],
                ),
                if (logo != null)
                  pw.Container(
                    width: 120,
                    height: 60,
                    alignment: pw.Alignment.topRight,
                    child: pw.Image(logo, fit: pw.BoxFit.contain),
                  ),
              ],
            ),
            pw.SizedBox(height: 18),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.grey400),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Vystavovateľ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                        pw.SizedBox(height: 3),
                        pw.Text(_issuerName.text.trim(), style: const pw.TextStyle(fontSize: 8)),
                        pw.Text(_issuerAddress.text.trim(), style: const pw.TextStyle(fontSize: 8)),
                        if (_issuerIco.text.trim().isNotEmpty) pw.Text('IČO: ${_issuerIco.text.trim()}', style: const pw.TextStyle(fontSize: 8)),
                        if (_issuerDic.text.trim().isNotEmpty) pw.Text('DIČ: ${_issuerDic.text.trim()}', style: const pw.TextStyle(fontSize: 8)),
                        if (_issuerIcdph.text.trim().isNotEmpty) pw.Text('IČ DPH: ${_issuerIcdph.text.trim()}', style: const pw.TextStyle(fontSize: 8)),
                        pw.SizedBox(height: 3),
                        if (_issuerContactPerson.text.trim().isNotEmpty) pw.Text('Kontakt: ${_issuerContactPerson.text.trim()}', style: const pw.TextStyle(fontSize: 8)),
                        if (_issuerPhone.text.trim().isNotEmpty) pw.Text('Tel: ${_issuerPhone.text.trim()}', style: const pw.TextStyle(fontSize: 8)),
                        if (_issuerEmail.text.trim().isNotEmpty) pw.Text('E-mail: ${_issuerEmail.text.trim()}', style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Zákazník', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                        pw.SizedBox(height: 3),
                        pw.Text(_customerName.text.trim(), style: const pw.TextStyle(fontSize: 8)),
                        pw.Text(_customerAddress.text.trim(), style: const pw.TextStyle(fontSize: 8)),
                        if (_customerIco.text.trim().isNotEmpty) pw.Text('IČO: ${_customerIco.text.trim()}', style: const pw.TextStyle(fontSize: 8)),
                        if (_customerDic.text.trim().isNotEmpty) pw.Text('DIČ: ${_customerDic.text.trim()}', style: const pw.TextStyle(fontSize: 8)),
                        if (_customerIcdph.text.trim().isNotEmpty) pw.Text('IČ DPH: ${_customerIcdph.text.trim()}', style: const pw.TextStyle(fontSize: 8)),
                        pw.SizedBox(height: 3),
                        if (_customerContactPerson.text.trim().isNotEmpty)
                          pw.Text('Kontakt: ${_customerContactPerson.text.trim()}', style: const pw.TextStyle(fontSize: 8)),
                        if (_customerPhone.text.trim().isNotEmpty) pw.Text('Tel: ${_customerPhone.text.trim()}', style: const pw.TextStyle(fontSize: 8)),
                        if (_customerEmail.text.trim().isNotEmpty) pw.Text('E-mail: ${_customerEmail.text.trim()}', style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text('Predmet ponuky', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.8),
                1: const pw.FlexColumnWidth(2.3),
                2: const pw.FlexColumnWidth(0.7),
                3: const pw.FlexColumnWidth(0.9),
                4: const pw.FlexColumnWidth(1.1),
                5: const pw.FlexColumnWidth(1.2),
                6: const pw.FlexColumnWidth(1.3),
                7: const pw.FlexColumnWidth(1.3),
              },
              defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Typ', style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Názov', style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Popis', style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Množ.', style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Jedn.', style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Jedn. cena', style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Príplatok', style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Celkom', style: const pw.TextStyle(fontSize: 8))),
                  ],
                ),
                ...items.map(
                  (i) => pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(_getItemTypeDisplay(i.itemType), style: const pw.TextStyle(fontSize: 7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(i.name, style: const pw.TextStyle(fontSize: 7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(i.description, style: const pw.TextStyle(fontSize: 7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(i.qty.toStringAsFixed(2).replaceAll(RegExp(r'\.?0*$'), ''), style: const pw.TextStyle(fontSize: 7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(i.unit, style: const pw.TextStyle(fontSize: 7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(_money(i.unitPrice), style: const pw.TextStyle(fontSize: 7)))),
                      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(i.additionalFeeName != null ? _money(i.additionalFee!) : '-', style: const pw.TextStyle(fontSize: 7)))),
                      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(_money(i.total), style: const pw.TextStyle(fontSize: 7)))),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  width: 220,
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(color: PdfColors.grey400),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      _pdfTotalRow('Súčet položiek', _money(_itemsSubtotal)),
                      _pdfTotalRow('Doprava', _money(_shippingValue)),
                      _pdfTotalRow('Iné poplatky', _money(_otherFeesValue)),
                      pw.Divider(),
                      _pdfTotalRow('Cena tovaru', _money(_totalWithVat), bold: true),
                      _pdfTotalRow('Vratná záloha', _money(_depositValue)),
                      if (!_vatExempt) _pdfTotalRow('DPH (${(_vatRate * 100).toStringAsFixed(0)}%)', _money(_vatValue)),
                      if (!_vatExempt) pw.Divider(),
                      
                      _pdfTotalRow('Celková cena na úhradu', _money(_totalBase), bold: true),
                      if (_vatExempt) pw.SizedBox(height: 4),
                      if (_vatExempt) pw.Text('Cenová ponuka uvedená bez DPH', 
                               style: pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic, fontFallback: [unicodeFont])),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Text('Podmienky', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Bullet(text: 'Ponuka platí ${_validityDays.text.trim()} dní od dátumu vystavenia.'),
            pw.Bullet(text: 'Spôsob platby: ${_paymentMethod.text.trim()}'),
            pw.Bullet(text: 'Termín dodania / realizácie: ${_deliveryTerm.text.trim()}'),
            pw.SizedBox(height: 14),
            pw.Text('Poznámky', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Text(_notes.text.trim().isEmpty ? '-' : _notes.text.trim()),
            pw.SizedBox(height: 20),
            pw.Spacer(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Container(width: 240, child: pw.Column(children: [pw.Divider(), pw.Text('Podpis a pečiatka')])),
                pw.Container(width: 240, child: pw.Column(children: [pw.Divider(), pw.Text('Za zákazníka')])),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      name: 'cenova_ponuka_$_offerNumber.pdf',
      onLayout: (_) async => doc.save(),
    );
  }

  pw.Widget _pdfTotalRow(String label, String value, {bool bold = false}) {
    final style = pw.TextStyle(
      fontSize: 8,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(value, style: style),
        ],
      ),
    );
  }

  Future<void> _pickIssueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _issueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _issueDate = picked);
  }

  void _addItem() {
    setState(() {
      _items.add(PriceOfferItem(name: '', description: '', qty: 1, unitPrice: 0, itemType: 'tovar'));
    });
  }

  void _removeItem(int index) {
    if (_items.length <= 1) return;
    setState(() {
      _items.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cenová ponuka'),
        actions: [
          IconButton(
            tooltip: 'Načítať ponuku',
            onPressed: _loadPriceOffer,
            icon: const Icon(Icons.folder_open_outlined),
          ),
          IconButton(
            tooltip: 'Uložiť ponuku',
            onPressed: _savePriceOffer,
            icon: const Icon(Icons.save_outlined),
          ),
          IconButton(
            tooltip: 'Pridať logo',
            onPressed: _pickLogo,
            icon: const Icon(Icons.image_outlined),
          ),
          IconButton(
            tooltip: 'Tlačiť PDF',
            onPressed: _printPdf,
            icon: const Icon(Icons.print),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _headerCard(context),
            const SizedBox(height: 12),
            _issuerCard(context),
            const SizedBox(height: 12),
            _customerCard(context),
            const SizedBox(height: 12),
            _itemsCard(context),
            const SizedBox(height: 12),
            _totalsCard(context),
            const SizedBox(height: 12),
            _termsCard(context),
            const SizedBox(height: 12),
            _footerCard(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title, {IconData? icon}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
        ],
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _headerCard(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Theme.of(context).dividerColor)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.request_quote, color: Theme.of(context).colorScheme.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cenová ponuka', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text('Dokument pripravený na tlač', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _offerNumber,
                    decoration: const InputDecoration(labelText: 'Číslo ponuky', border: OutlineInputBorder()),
                    onChanged: (v) => _offerNumber = v.trim(),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Vyplň číslo ponuky' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _pickIssueDate,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Dátum vystavenia', border: OutlineInputBorder()),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_dateFmt.format(_issueDate)),
                          const Icon(Icons.calendar_month, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_logoName != null)
              Text('Logo: $_logoName', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor)),
          ],
        ),
      ),
    );
  }

  Widget _issuerCard(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Theme.of(context).dividerColor)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context, 'Údaje o firme / osobe (vystavovateľ)', icon: Icons.business),
            const SizedBox(height: 12),
            TextFormField(
              controller: _issuerName,
              decoration: const InputDecoration(labelText: 'Názov firmy', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Vyplň názov firmy' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _issuerAddress,
              decoration: const InputDecoration(labelText: 'Adresa', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Vyplň adresu' : null,
              maxLines: 2,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _issuerIco,
                    decoration: InputDecoration(
                      labelText: 'IČO',
                      border: const OutlineInputBorder(),
                      helperText: 'Po zadaní IČO sa doplnia údaje automaticky',
                      suffixIcon: _loadingIco
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(controller: _issuerDic, decoration: const InputDecoration(labelText: 'DIČ', border: OutlineInputBorder()))),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(controller: _issuerIcdph, decoration: const InputDecoration(labelText: 'IČ DPH', border: OutlineInputBorder()))),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextFormField(controller: _issuerContactPerson, decoration: const InputDecoration(labelText: 'Kontaktná osoba', border: OutlineInputBorder()))),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(controller: _issuerPhone, decoration: const InputDecoration(labelText: 'Telefón', border: OutlineInputBorder()))),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(controller: _issuerEmail, decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder())),
          ],
        ),
      ),
    );
  }

  Widget _customerCard(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Theme.of(context).dividerColor)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context, 'Údaje o zákazníkovi / klientovi', icon: Icons.person),
            const SizedBox(height: 12),
            TextFormField(
              controller: _customerName,
              decoration: const InputDecoration(labelText: 'Názov firmy alebo meno', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Vyplň zákazníka' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _customerAddress,
              decoration: const InputDecoration(labelText: 'Adresa', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Vyplň adresu zákazníka' : null,
              maxLines: 2,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _customerIco,
                    decoration: InputDecoration(
                      labelText: 'IČO',
                      border: const OutlineInputBorder(),
                      helperText: 'Po zadaní IČO sa doplnia údaje automaticky',
                      suffixIcon: _loadingCustomerIco
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(controller: _customerDic, decoration: const InputDecoration(labelText: 'DIČ', border: OutlineInputBorder()))),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(controller: _customerIcdph, decoration: const InputDecoration(labelText: 'IČ DPH', border: OutlineInputBorder()))),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextFormField(controller: _customerContactPerson, decoration: const InputDecoration(labelText: 'Kontaktná osoba', border: OutlineInputBorder()))),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(controller: _customerPhone, decoration: const InputDecoration(labelText: 'Telefón', border: OutlineInputBorder()))),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(controller: _customerEmail, decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder())),
          ],
        ),
      ),
    );
  }

  Widget _itemsCard(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Theme.of(context).dividerColor)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionTitle(context, 'Položky ponuky', icon: Icons.list_alt),
                FilledButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add),
                  label: const Text('Pridať položku'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...List.generate(_items.length, (index) {
              final it = _items[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('Položka ${index + 1}', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        ),
                        IconButton(
                          tooltip: 'Odstrániť',
                          onPressed: () => _removeItem(index),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: it.name,
                      decoration: const InputDecoration(labelText: 'Názov tovaru/služby', border: OutlineInputBorder()),
                      onChanged: (v) {
                        it.name = v;
                        setState(() {});
                      },
                      validator: (v) {
                        if (_items.length == 1 && (v == null || v.trim().isEmpty)) return 'Vyplň aspoň jednu položku';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      initialValue: it.description,
                      decoration: const InputDecoration(labelText: 'Popis / špecifikácia', border: OutlineInputBorder()),
                      onChanged: (v) {
                        it.description = v;
                        setState(() {});
                      },
                      maxLines: 2,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: it.qty.toString(),
                            decoration: const InputDecoration(labelText: 'Množstvo', border: OutlineInputBorder()),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (v) {
                              it.qty = double.tryParse(v.trim().replaceAll(',', '.')) ?? 0;
                              setState(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            initialValue: it.unitPrice.toStringAsFixed(2),
                            decoration: const InputDecoration(labelText: 'Jednotková cena (€)', border: OutlineInputBorder()),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (v) {
                              it.unitPrice = double.tryParse(v.trim().replaceAll(',', '.')) ?? 0;
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: it.itemType,
                            decoration: const InputDecoration(labelText: 'Typ položky', border: OutlineInputBorder()),
                            items: const [
                              DropdownMenuItem(value: 'tovar', child: Text('Tovar')),
                              DropdownMenuItem(value: 'obalovy_material', child: Text('Obalový materiál')),
                              DropdownMenuItem(value: 'paleta', child: Text('Paleta (záloha)')),
                            ],
                            onChanged: (value) {
                              it.itemType = value ?? 'tovar';
                              setState(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: it.unit,
                            decoration: const InputDecoration(labelText: 'Jednotka', border: OutlineInputBorder()),
                            items: const [
                              DropdownMenuItem(value: 'ks', child: Text('ks')),
                              DropdownMenuItem(value: 'm', child: Text('m')),
                              DropdownMenuItem(value: 'm²', child: Text('m²')),
                              DropdownMenuItem(value: 'm³', child: Text('m³')),
                              DropdownMenuItem(value: 'l', child: Text('l')),
                              DropdownMenuItem(value: 'kg', child: Text('kg')),
                              DropdownMenuItem(value: 'g', child: Text('g')),
                              DropdownMenuItem(value: 't', child: Text('t')),
                              DropdownMenuItem(value: 'h', child: Text('h')),
                              DropdownMenuItem(value: 'hod', child: Text('hod')),
                              DropdownMenuItem(value: 'dn', child: Text('dn')),
                              DropdownMenuItem(value: 'mes', child: Text('mes')),
                              DropdownMenuItem(value: 'bal', child: Text('bal')),
                              DropdownMenuItem(value: 'paleta', child: Text('paleta')),
                              DropdownMenuItem(value: 'sada', child: Text('sada')),
                              DropdownMenuItem(value: 'kus', child: Text('kus')),
                            ],
                            onChanged: (value) {
                              it.unit = value ?? 'ks';
                              setState(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Celkom', border: OutlineInputBorder()),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text('${_money(it.total)} / ${it.unit}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: it.additionalFeeName,
                            decoration: const InputDecoration(labelText: 'Príplatok (typ)', border: OutlineInputBorder()),
                            items: const [
                              DropdownMenuItem(value: null, child: Text('Žiadny príplatok')),
                              DropdownMenuItem(value: 'Obalový materiál', child: Text('Obalový materiál')),
                              DropdownMenuItem(value: 'Preprava', child: Text('Preprava')),
                              DropdownMenuItem(value: 'Montáž', child: Text('Montáž')),
                              DropdownMenuItem(value: 'Servis', child: Text('Servis')),
                              DropdownMenuItem(value: 'Iné', child: Text('Iné')),
                            ],
                            onChanged: (value) {
                              it.additionalFeeName = value;
                              if (value == null) {
                                it.additionalFee = 0;
                              }
                              setState(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            initialValue: it.additionalFee?.toStringAsFixed(2) ?? '',
                            decoration: const InputDecoration(labelText: 'Príplatok (€)', border: OutlineInputBorder()),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            enabled: it.additionalFeeName != null,
                            onChanged: (v) {
                              it.additionalFee = double.tryParse(v.trim().replaceAll(',', '.')) ?? 0;
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _totalsCard(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Theme.of(context).dividerColor)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context, 'Celková cena', icon: Icons.calculate_outlined),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    title: const Text('Oslobodené od DPH'),
                    subtitle: const Text('Vystaviť bez DPH'),
                    value: _vatExempt,
                    onChanged: (value) {
                      setState(() {
                        _vatExempt = value ?? false;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!_vatExempt) ...[
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _vatPercent,
                      decoration: const InputDecoration(labelText: 'DPH (%)', border: OutlineInputBorder()),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _shipping,
                      decoration: const InputDecoration(labelText: 'Doprava (€)', border: OutlineInputBorder()),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _otherFees,
                      decoration: const InputDecoration(labelText: 'Iné poplatky (€)', border: OutlineInputBorder()),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _shipping,
                      decoration: const InputDecoration(labelText: 'Doprava (€)', border: OutlineInputBorder()),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _otherFees,
                      decoration: const InputDecoration(labelText: 'Iné poplatky (€)', border: OutlineInputBorder()),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const Expanded(child: SizedBox()), // Placeholder for alignment
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _deposit,
                      decoration: const InputDecoration(labelText: 'Vratná záloha (€)', border: OutlineInputBorder()),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const Expanded(child: SizedBox()), // Placeholder for alignment
                  const Expanded(child: SizedBox()), // Placeholder for alignment
                ],
              ),
            ],
            const SizedBox(height: 12),
            _totalLine(context, 'Súčet položiek', _money(_itemsSubtotal)),
            _totalLine(context, 'Doprava', _money(_shippingValue)),
            _totalLine(context, 'Iné poplatky', _money(_otherFeesValue)),
            const Divider(height: 20),
            _totalLine(context, 'Celková cena na úhradu', _money(_totalBase), bold: true),
            _totalLine(context, 'Vratná záloha', _money(_depositValue)),
            if (!_vatExempt) ...[
              _totalLine(context, 'DPH (${(_vatRate * 100).toStringAsFixed(0)}%)', _money(_vatValue)),
              const Divider(height: 20),
            ],
            _totalLine(context, 'Cena tovaru', _money(_totalWithVat), bold: true),
            if (_vatExempt)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Cenová ponuka uvedená bez DPH',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  Widget _totalLine(BuildContext context, String label, String value, {bool bold = false, bool big = false}) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          fontSize: big ? 18 : null,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }

  Widget _termsCard(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Theme.of(context).dividerColor)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context, 'Podmienky platnosti ponuky', icon: Icons.gavel_outlined),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _validityDays,
                    decoration: const InputDecoration(labelText: 'Lehota platnosti (dni)', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _paymentMethod,
                    decoration: const InputDecoration(labelText: 'Spôsob platby', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _deliveryTerm,
              decoration: const InputDecoration(labelText: 'Termín dodania / realizácie', border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footerCard(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Theme.of(context).dividerColor)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context, 'Záverečné informácie', icon: Icons.info_outline),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Poznámky / špeciálne podmienky', border: OutlineInputBorder()),
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: const Text('Podpis a pečiatka'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: const Text('Za zákazníka'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
