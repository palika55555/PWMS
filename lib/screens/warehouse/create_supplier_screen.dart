import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import '../../providers/database_provider.dart';
import '../../models/supplier.dart';
import '../../config/api_config.dart';

class CreateSupplierScreen extends StatefulWidget {
  final Supplier? supplier;

  const CreateSupplierScreen({super.key, this.supplier});

  @override
  State<CreateSupplierScreen> createState() => _CreateSupplierScreenState();
}

class _CreateSupplierScreenState extends State<CreateSupplierScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _companyIdController = TextEditingController();
  final _taxIdController = TextEditingController();
  final _vatIdController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _countryController = TextEditingController(text: 'Slovensko');
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _paymentTermsController = TextEditingController();
  final _notesController = TextEditingController();
  bool _loading = false;
  bool _loadingIco = false;
  List<Map<String, dynamic>> _addressSuggestions = [];
  bool _showAddressSuggestions = false;
  Timer? _addressDebounceTimer;
  Timer? _icoDebounceTimer;
  bool _loadingAddresses = false;
  
  // Google Places API Key from config
  String get _googlePlacesApiKey => ApiConfig.googlePlacesApiKey;

  @override
  void initState() {
    super.initState();
    _companyIdController.addListener(() => _onIcoChanged());
    _addressController.addListener(() => _onAddressChanged());
    if (widget.supplier != null) {
      _nameController.text = widget.supplier!.name;
      _companyIdController.text = widget.supplier!.companyId ?? '';
      _taxIdController.text = widget.supplier!.taxId ?? '';
      _vatIdController.text = widget.supplier!.vatId ?? '';
      _addressController.text = widget.supplier!.address ?? '';
      _cityController.text = widget.supplier!.city ?? '';
      _zipCodeController.text = widget.supplier!.zipCode ?? '';
      _countryController.text = widget.supplier!.country ?? 'Slovensko';
      _phoneController.text = widget.supplier!.phone ?? '';
      _emailController.text = widget.supplier!.email ?? '';
      _websiteController.text = widget.supplier!.website ?? '';
      _contactPersonController.text = widget.supplier!.contactPerson ?? '';
      _paymentTermsController.text = widget.supplier!.paymentTerms ?? '';
      _notesController.text = widget.supplier!.notes ?? '';
    }
  }

  @override
  void dispose() {
    _addressDebounceTimer?.cancel();
    _icoDebounceTimer?.cancel();
    _nameController.dispose();
    _companyIdController.dispose();
    _taxIdController.dispose();
    _vatIdController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _zipCodeController.dispose();
    _countryController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _contactPersonController.dispose();
    _paymentTermsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onIcoChanged() {
    _icoDebounceTimer?.cancel();
    _icoDebounceTimer = Timer(const Duration(milliseconds: 800), () {
      final ico = _companyIdController.text.trim();
      if (ico.length >= 8 && ico.length <= 10) {
        _fetchCompanyData(ico);
      }
    });
  }

  Future<Map<String, String>?> _fetchFromFinstat(String ico) async {
    try {
      // Finstat.sk - skúsime rôzne endpointy a prístupy
      
      // Možnosť 1: Finstat detail stránka podľa IČO
      final detailUrl = Uri.parse('https://www.finstat.sk/$ico');
      
      print('Fetching from Finstat.sk detail page for ICO: $ico');
      
      final response = await http.get(
        detailUrl,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'sk-SK,sk;q=0.9,en-US;q=0.8,en;q=0.7',
          'Referer': 'https://www.finstat.sk/',
        },
      ).timeout(
        const Duration(seconds: 10),
      );
      
      print('Finstat detail page response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final html = response.body;
        
        // Skúsime nájsť JSON dáta v HTML (Finstat používa embedded JSON)
        final jsonPatterns = [
          RegExp(r'window\.__INITIAL_STATE__\s*=\s*({.+?});', dotAll: true),
          RegExp(r'window\.__APOLLO_STATE__\s*=\s*({.+?});', dotAll: true),
          RegExp(r'data-company\s*=\s*"([^"]+)"', dotAll: true),
        ];
        
        for (final pattern in jsonPatterns) {
          final match = pattern.firstMatch(html);
          if (match != null) {
            try {
              final jsonStr = match.group(1)!.replaceAll('&quot;', '"').replaceAll('&amp;', '&');
              final data = json.decode(jsonStr);
              
              Map<String, String>? result = _parseFinstatData(data);
              if (result != null && result['name']?.isNotEmpty == true) {
                print('Finstat detail page success: $result');
                return result;
              }
            } catch (e) {
              print('Error parsing JSON from HTML: $e');
            }
          }
        }
        
        // Alternatívne: Parsovanie HTML pomocí regex
        Map<String, String>? result = _parseFinstatHtml(html, ico);
        if (result != null && result['name']?.isNotEmpty == true) {
          print('Finstat HTML parsing success: $result');
          return result;
        }
      }
      
      // Možnosť 2: Finstat API endpoint (ak existuje)
      final apiUrls = [
        'https://www.finstat.sk/api/company/$ico',
        'https://www.finstat.sk/api/v1/company/$ico',
        'https://api.finstat.sk/company/$ico',
      ];
      
      for (final apiUrlStr in apiUrls) {
        try {
          final apiUrl = Uri.parse(apiUrlStr);
          print('Trying Finstat API: $apiUrl');
          
          final apiResponse = await http.get(
            apiUrl,
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              'Accept': 'application/json, */*',
              'Accept-Language': 'sk-SK,sk;q=0.9,en-US;q=0.8,en;q=0.7',
              'Referer': 'https://www.finstat.sk/',
            },
          ).timeout(
            const Duration(seconds: 8),
          );
          
          if (apiResponse.statusCode == 200) {
            final data = json.decode(apiResponse.body);
            Map<String, String>? result = _parseFinstatData(data);
            if (result != null && result['name']?.isNotEmpty == true) {
              print('Finstat API success: $result');
              return result;
            }
          }
        } catch (e) {
          print('Error with API endpoint $apiUrlStr: $e');
        }
      }
      
      return null;
    } catch (e) {
      print('Error fetching from Finstat: $e');
      return null;
    }
  }

  Map<String, String>? _parseFinstatData(dynamic data) {
    try {
      Map<String, String> result = {};
      
      // Rekurzívne hľadanie dát v rôznych štruktúrach
      dynamic findValue(dynamic obj, List<String> keys) {
        if (obj is Map) {
          for (final key in keys) {
            if (obj.containsKey(key)) {
              return obj[key];
            }
            // Skúsime case-insensitive vyhľadávanie
            for (final k in obj.keys) {
              if (k.toString().toLowerCase() == key.toLowerCase()) {
                return obj[k];
              }
            }
          }
          // Rekurzívne prehľadávanie
          for (final value in obj.values) {
            if (value is Map || value is List) {
              final found = findValue(value, keys);
              if (found != null) return found;
            }
          }
        } else if (obj is List) {
          for (final item in obj) {
            if (item is Map || item is List) {
              final found = findValue(item, keys);
              if (found != null) return found;
            }
          }
        }
        return null;
      }
      
      // Názov firmy
      final name = findValue(data, ['name', 'nazov', 'companyName', 'nazovUJ', 'title']);
      if (name != null) result['name'] = name.toString();
      
      // DIČ
      final taxId = findValue(data, ['dic', 'taxId', 'DIC', 'tax_id']);
      if (taxId != null) result['taxId'] = taxId.toString();
      
      // IČ DPH
      final vatId = findValue(data, ['icDph', 'vatId', 'IC_DPH', 'vat_id', 'ic_dph']);
      if (vatId != null) {
        result['vatId'] = vatId.toString();
      } else if (taxId != null) {
        result['vatId'] = taxId.toString();
      }
      
      // Adresa
      final street = findValue(data, ['ulica', 'street', 'address', 'adresa']);
      final streetNumber = findValue(data, ['cisloDomu', 'cisloOrientacne', 'streetNumber', 'houseNumber']);
      if (street != null) {
        result['address'] = streetNumber != null && streetNumber.toString().isNotEmpty
            ? '${street.toString()} ${streetNumber.toString()}'
            : street.toString();
      }
      
      // Mesto
      final city = findValue(data, ['mesto', 'city', 'obec']);
      if (city != null) result['city'] = city.toString();
      
      // PSČ
      final zipCode = findValue(data, ['psc', 'zipCode', 'PSC', 'zip', 'postalCode']);
      if (zipCode != null) result['zipCode'] = zipCode.toString();
      
      // Krajina
      final country = findValue(data, ['stat', 'country', 'krajina']);
      if (country != null) {
        result['country'] = country.toString();
      } else {
        result['country'] = 'Slovensko';
      }
      
      return result.isNotEmpty ? result : null;
    } catch (e) {
      print('Error parsing Finstat data: $e');
      return null;
    }
  }

  String _decodeHtmlEntities(String text) {
    // Dekódovanie základných HTML entít
    return text
        .replaceAll('&#253;', 'ý')
        .replaceAll('&#225;', 'á')
        .replaceAll('&#237;', 'í')
        .replaceAll('&#233;', 'é')
        .replaceAll('&#243;', 'ó')
        .replaceAll('&#250;', 'ú')
        .replaceAll('&#269;', 'č')
        .replaceAll('&#271;', 'ď')
        .replaceAll('&#328;', 'ň')
        .replaceAll('&#353;', 'š')
        .replaceAll('&#357;', 'ť')
        .replaceAll('&#382;', 'ž')
        .replaceAll('&#193;', 'Á')
        .replaceAll('&#201;', 'É')
        .replaceAll('&#205;', 'Í')
        .replaceAll('&#211;', 'Ó')
        .replaceAll('&#218;', 'Ú')
        .replaceAll('&#221;', 'Ý')
        .replaceAll('&#268;', 'Č')
        .replaceAll('&#272;', 'Ď')
        .replaceAll('&#327;', 'Ň')
        .replaceAll('&#352;', 'Š')
        .replaceAll('&#356;', 'Ť')
        .replaceAll('&#381;', 'Ž')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&nbsp;', ' ');
  }

  String _cleanHtmlText(String text) {
    // Odstránenie HTML komentárov a conditional comments
    String cleaned = text;
    
    // Odstránenie HTML komentárov <!-- -->
    cleaned = cleaned.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
    
    // Odstránenie conditional comments pre IE
    cleaned = cleaned.replaceAll(RegExp(r'<!\[if[^\]]*\].*?<!\[endif\]>', dotAll: true, caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'<!--\[if[^\]]*\].*?<!\[endif\]-->', dotAll: true, caseSensitive: false), '');
    
    // Odstránenie HTML tagov
    cleaned = cleaned.replaceAll(RegExp(r'<[^>]+>', dotAll: true), ' ');
    
    // Odstránenie viacerých medzier
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return cleaned;
  }

  bool _isValidAddress(String address) {
    // Validácia adresy - musí obsahovať písmená a nie byť technický text
    final invalidPatterns = [
      RegExp(r'^if\s+(lt|gte|gt|lte)\s+IE', caseSensitive: false),
      RegExp(r'^<!--', caseSensitive: false),
      RegExp(r'^<!\[', caseSensitive: false),
      RegExp(r'^script', caseSensitive: false),
      RegExp(r'^style', caseSensitive: false),
      RegExp(r'^noscript', caseSensitive: false),
      RegExp(r'^meta', caseSensitive: false),
      RegExp(r'^link', caseSensitive: false),
    ];
    
    final cleanAddr = address.trim().toLowerCase();
    
    // Musí obsahovať aspoň jedno písmeno
    if (!RegExp(r'[a-záéíóúýčďĺňšťž]').hasMatch(cleanAddr)) {
      return false;
    }
    
    // Nesmie obsahovať technické HTML elementy
    for (final pattern in invalidPatterns) {
      if (pattern.hasMatch(cleanAddr)) {
        return false;
      }
    }
    
    // Filtrovanie neplatných textov - texty obsahujúce štatistiky, dane, rebríčky, atď.
    final invalidKeywords = [
      'dane', 'príjmu', 'príjm', 'platcov', 'rebrič', 'rebrick', 'štatist', 'statist',
      'najväčší', 'najväčších', 'najlepšie', 'analýz', 'analyz', 'prehľad', 'prehlad',
      'online', 'ročn', 'rocn', 'spoločnost', 'spolocnost', 'register', 'databáza', 'databaza',
      'kategóri', 'kategori', 'zamestnanc', 'zamestnan', 'zápis', 'zapis', 'oršr', 'orsr',
      'základné', 'zakladne', 'imanie', 'nace', 'sk nace', 'podľa', 'podla',
      'financ', 'údaj', 'udaj', 'premenn', 'variabil', 'vyrob', 'beton', 'stavebn',
      'prešovský', 'presovsky', 'kraj', 'oddiel', 'vložka', 'vlozka',
    ];
    
    for (final keyword in invalidKeywords) {
      if (cleanAddr.contains(keyword)) {
        return false;
      }
    }
    
    // Musí mať aspoň 3 znaky a maximálne 100 znakov (adresy sú zvyčajne kratšie)
    if (cleanAddr.length < 3 || cleanAddr.length > 100) {
      return false;
    }
    
    // Nesmie byť len čísla alebo len PSČ
    if (RegExp(r'^\d{3,}$').hasMatch(cleanAddr)) {
      return false;
    }
    
    // Musí obsahovať aspoň jedno slovo s písmenami (nie len samotné číslo)
    if (!RegExp(r'[a-záéíóúýčďĺňšťž]{2,}').hasMatch(cleanAddr)) {
      return false;
    }
    
    // Adresa by mala obsahovať číslo domu alebo názov ulice/mesta
    // Skontrolujeme, či obsahuje aspoň jedno slovo začínajúce veľkým písmenom (názov ulice/mesta)
    // alebo kombináciu písmen a čísla (ulica + číslo)
    final hasStreetOrCityName = RegExp(r'[A-ZÁÉÍÓÚÝČĎĹŇŠŤŽ][a-záéíóúýčďĺňšťž]+').hasMatch(address);
    final hasStreetNumber = RegExp(r'\d+[a-z]?').hasMatch(cleanAddr);
    
    if (!hasStreetOrCityName && !hasStreetNumber) {
      return false;
    }
    
    return true;
  }

  Map<String, String>? _parseFinstatHtml(String html, String ico) {
    try {
      Map<String, String> result = {};
      
      // Parsovanie názvu firmy
      final namePatterns = [
        RegExp(r'<h1[^>]*>([^<]+)</h1>', caseSensitive: false),
        RegExp(r'<title>([^<]+)</title>', caseSensitive: false),
        RegExp(r'class="company-name"[^>]*>([^<]+)</', caseSensitive: false),
        RegExp(r"class='company-name'[^>]*>([^<]+)</", caseSensitive: false),
        RegExp(r'<span[^>]*class="[^"]*name[^"]*"[^>]*>([^<]+)</span>', caseSensitive: false),
      ];
      
      for (final pattern in namePatterns) {
        final match = pattern.firstMatch(html);
        if (match != null) {
          final name = _decodeHtmlEntities(match.group(1)!.trim());
          if (name.isNotEmpty && !name.toLowerCase().contains('finstat') && !name.toLowerCase().contains('vyroba')) {
            result['name'] = name;
            break;
          }
        }
      }
      
      // Parsovanie DIČ - Finstat má štruktúru: <strong>DIČ</strong><span>hodnota</span>
      final dicPatterns = [
        // HTML štruktúra Finstat: <li><strong>DIČ</strong><span>2122464333</span></li>
        RegExp(r'<strong[^>]*>DIČ</strong>\s*<span[^>]*>([^<]+)</span>', caseSensitive: false),
        // Alternatívne formáty
        RegExp(r'DIČ[:\s]*([A-Z]{2}\d{8,10})', caseSensitive: false),
        RegExp(r'<[^>]*>DIČ[:\s]*</[^>]*>([A-Z]{2}\d{8,10})', caseSensitive: false),
        RegExp(r'data-dic[^>]*>([A-Z]{2}\d{8,10})', caseSensitive: false),
        // Môže byť aj bez prefixu (len čísla)
        RegExp(r'<strong[^>]*>DIČ</strong>\s*<span[^>]*>(\d{8,12})</span>', caseSensitive: false),
      ];
      
      for (final pattern in dicPatterns) {
        final dicMatch = pattern.firstMatch(html);
        if (dicMatch != null) {
          String dicValue = dicMatch.group(1)!.trim();
          // Vyčistíme hodnotu
          dicValue = _cleanHtmlText(dicValue);
          dicValue = _decodeHtmlEntities(dicValue);
          
          if (dicValue.isNotEmpty) {
            result['taxId'] = dicValue;
            // IČ DPH môže byť rovnaké ako DIČ (ak nie je špecifické IČ DPH)
            if (!result.containsKey('vatId')) {
              result['vatId'] = dicValue;
            }
            break;
          }
        }
      }
      
      // Parsovanie IČ DPH - Finstat má štruktúru: <strong>IČ DPH</strong><span>hodnota</span>
      final icDphPatterns = [
        // HTML štruktúra Finstat: <li><strong>IČ DPH</strong><span>SK2122464333</span></li>
        // Prioritný pattern - zachytí celú hodnotu vrátane SK prefixu
        RegExp(r'<strong[^>]*>IČ\s+DPH</strong>\s*<span[^>]*>([^<]+)</span>', caseSensitive: false),
        RegExp(r'<strong[^>]*>IČ\s*DPH</strong>\s*<span[^>]*>([^<]+)</span>', caseSensitive: false),
        // Alternatívne formáty
        RegExp(r'IČ\s+DPH[:\s]*([A-Z]{2}\d{8,12})', caseSensitive: false),
        RegExp(r'IČ\s*DPH[:\s]*([A-Z]{2}\d{8,12})', caseSensitive: false),
        RegExp(r'<[^>]*>IČ\s+DPH[:\s]*</[^>]*>([A-Z]{2}\d{8,12})', caseSensitive: false),
      ];
      
      for (final pattern in icDphPatterns) {
        final icDphMatch = pattern.firstMatch(html);
        if (icDphMatch != null) {
          String icDphValue = icDphMatch.group(1)!.trim();
          
          // Vyčistíme hodnotu (ale zachováme SK prefix ak je tam)
          icDphValue = _cleanHtmlText(icDphValue);
          icDphValue = _decodeHtmlEntities(icDphValue);
          
          // Odstránime medzery medzi SK a číslami (napr. "SK 2122464333" -> "SK2122464333")
          icDphValue = icDphValue.replaceAll(RegExp(r'^(SK)\s+(\d+)', caseSensitive: false), r'$1$2');
          
          // Ak hodnota nezačína SK a je len číslo, pridáme SK prefix
          if (icDphValue.isNotEmpty && RegExp(r'^\d+$').hasMatch(icDphValue)) {
            icDphValue = 'SK$icDphValue';
          }
          
          if (icDphValue.isNotEmpty) {
            result['vatId'] = icDphValue;
            print('IČ DPH parsed: $icDphValue');
            break;
          }
        }
      }
      
      // Ak sme nenašli IČ DPH, použijeme DIČ ako fallback
      if (!result.containsKey('vatId') && result.containsKey('taxId')) {
        final dicValue = result['taxId']!;
        // Pridáme SK prefix k DIČ, ak ešte nemá prefix
        if (!dicValue.toUpperCase().startsWith('SK')) {
          result['vatId'] = 'SK$dicValue';
        } else {
          result['vatId'] = dicValue;
        }
      }
      
      // Parsovanie sídla - Finstat má štruktúru: "Sídlo" nasledované viacerými riadkami
      // Formát: <strong>Sídlo</strong><span>Názov firmy<br>Adresa PSČ Mesto</span>
      // alebo: <strong>Sídlo</strong><span>Názov firmy<br>Adresa<br>PSČ Mesto</span>
      // alebo: **Sídlo** Názov firmy\nAdresa\nPSČ Mesto
      final sidloPatterns = [
        // Pattern s HTML tagmi - <strong>Sídlo</strong><span>...</span>
        RegExp(r'<strong[^>]*>Sídlo</strong>\s*<span[^>]*>([^<]+(?:s\.\s*r\.\s*o\.|spol\.|a\.s\.)?)<br[^>]*>([^<]+)</span>', caseSensitive: false, dotAll: true),
        // Pattern s <br> tagmi v span
        RegExp(r'<strong[^>]*>Sídlo</strong>\s*<span[^>]*>([^<]+)<br[^>]*>([A-ZÁÉÍÓÚÝČĎĹŇŠŤŽ][^<]*?\d+[^<]*?)</span>', caseSensitive: false, dotAll: true),
        // Pattern bez HTML tagov - **Sídlo** alebo Sídlo:
        RegExp(r'\*\*Sídlo\*\*[^<]*?([^\n<]+(?:s\.\s*r\.\s*o\.|spol\.|a\.s\.)?)\s+([^\n<]+)\s+(\d{3}\s?\d{2})\s+([^\n<]+)', caseSensitive: false, dotAll: true),
        RegExp(r'Sídlo[:\s]*([^\n<]+(?:s\.\s*r\.\s*o\.|spol\.|a\.s\.)?)\s+([^\n<]+)\s+(\d{3}\s?\d{2})\s+([^\n<]+)', caseSensitive: false, dotAll: true),
        // Pattern bez názvu firmy - len adresa, PSČ, mesto
        RegExp(r'\*\*Sídlo\*\*[^<]*?([A-ZÁÉÍÓÚÝČĎĹŇŠŤŽ][^\n<]*?\d+[^\n<]*?)\s+(\d{3}\s?\d{2})\s+([A-ZÁÉÍÓÚÝČĎĹŇŠŤŽ][a-záéíóúýčďĺňšťž]+)', caseSensitive: false, dotAll: true),
        RegExp(r'Sídlo[:\s]*([A-ZÁÉÍÓÚÝČĎĹŇŠŤŽ][^\n<]*?\d+[^\n<]*?)\s+(\d{3}\s?\d{2})\s+([A-ZÁÉÍÓÚÝČĎĹŇŠŤŽ][a-záéíóúýčďĺňšťž]+)', caseSensitive: false, dotAll: true),
        // Pattern s HTML tagmi - starší formát
        RegExp(r'<[^>]*>Sídlo[:\s]*</[^>]*>\s*(?:<[^>]*>([^<]+)</[^>]*>\s*)?<[^>]*>([^<]+)</[^>]*>\s*<[^>]*>(\d{3}\s?\d{2})\s+([^<]+)</[^>]*>', caseSensitive: false, dotAll: true),
      ];
      
      bool sidloFound = false;
      for (final pattern in sidloPatterns) {
        final sidloMatch = pattern.firstMatch(html);
        if (sidloMatch != null) {
          String? addressLine;
          String? zipCodeLine;
          String? cityLine;
          
          // Pattern s 2 skupinami - názov firmy a adresa+PSČ+mesto v jednom
          if (sidloMatch.groupCount == 2) {
            // Druhý group obsahuje adresu, PSČ a mesto spolu (napr. "Lubina 1 040 12 Košice")
            final fullAddressLine = sidloMatch.group(2) ?? '';
            if (fullAddressLine.isNotEmpty) {
              // Rozdelíme podľa PSČ patternu
              final addressZipCityMatch = RegExp(r'([A-ZÁÉÍÓÚÝČĎĹŇŠŤŽ][^\d]*?\d+[^\d]*?)\s+(\d{3}\s?\d{2})\s+([A-ZÁÉÍÓÚÝČĎĹŇŠŤŽ][a-záéíóúýčďĺňšťž]+)').firstMatch(fullAddressLine);
              if (addressZipCityMatch != null) {
                addressLine = addressZipCityMatch.group(1);
                zipCodeLine = addressZipCityMatch.group(2);
                cityLine = addressZipCityMatch.group(3);
              } else {
                // Skúsime len adresu a mesto bez PSČ
                addressLine = fullAddressLine;
              }
            }
          } else if (sidloMatch.groupCount >= 3) {
            // Pattern s 3 skupinami: adresa, PSČ, mesto
            if (sidloMatch.groupCount == 3) {
              addressLine = sidloMatch.group(1);
              zipCodeLine = sidloMatch.group(2);
              cityLine = sidloMatch.group(3);
            } else if (sidloMatch.groupCount >= 4) {
              // Pattern s 4 skupinami: názov firmy, adresa, PSČ, mesto
              addressLine = sidloMatch.group(2);
              zipCodeLine = sidloMatch.group(3);
              cityLine = sidloMatch.group(4);
            }
          }
          
          // Adresa (riadok s ulicou a číslom - napr. "Lubina 1" alebo "Hudcovce 99")
          if (addressLine != null && addressLine.isNotEmpty) {
            String address = _cleanHtmlText(addressLine);
            address = _decodeHtmlEntities(address.trim());
            // Odstránime PSČ a mesto ak sú v adrese (napr. "Lubina 1 040 12 Košice")
            address = address.replaceAll(RegExp(r'\s+\d{3}\s?\d{2}\s+[A-ZÁÉÍÓÚÝČĎĹŇŠŤŽ][a-záéíóúýčďĺňšťž]+$'), '');
            // Odstránime názov firmy ak je tam
            address = address.replaceAll(RegExp(r'\b(s\.\s*r\.\s*o\.|spol\.|a\.s\.|s\.r\.o\.)', caseSensitive: false), '').trim();
            // Odstránime čiarky na začiatku
            address = address.replaceAll(RegExp(r'^,\s*'), '').trim();
            
            if (address.isNotEmpty && _isValidAddress(address) && !RegExp(r'^\d{3}\s?\d{2}$').hasMatch(address)) {
              result['address'] = address;
            }
          }
          
          // PSČ (riadok s PSČ - napr. "067 45" alebo "040 12")
          if (zipCodeLine != null && zipCodeLine.isNotEmpty) {
            final zipCode = zipCodeLine.trim().replaceAll(' ', '');
            if (RegExp(r'^\d{5}$').hasMatch(zipCode)) {
              result['zipCode'] = zipCode;
            }
          }
          
          // Mesto (riadok s mestom - napr. "Hudcovce" alebo "Košice")
          if (cityLine != null && cityLine.isNotEmpty) {
            String city = _cleanHtmlText(cityLine);
            city = _decodeHtmlEntities(city.trim());
            // Odstránime PSČ ak je tam
            city = city.replaceAll(RegExp(r'^\d{3}\s?\d{2}\s+'), '');
            if (city.isNotEmpty && 
                !city.toLowerCase().contains('vyroba') &&
                !city.toLowerCase().contains('beton') &&
                !city.toLowerCase().contains('stavebn') &&
                city.length < 50) {
              result['city'] = city;
            }
          }
          
          if (result.containsKey('address') || result.containsKey('city') || result.containsKey('zipCode')) {
            sidloFound = true;
            print('Sídlo parsed: address=${result['address']}, zipCode=${result['zipCode']}, city=${result['city']}');
            break;
          }
        }
      }
      
      // Ak sme nenašli cez "Sídlo", skúsime najprv nájsť adresu pomocou všeobecnejšieho patternu
      if (!sidloFound || !result.containsKey('address')) {
        // Hľadanie adresy - mesto + číslo domu (napr. "Hudcovce 99")
        final addressOnlyPatterns = [
          RegExp(r'([A-ZÁÉÍÓÚÝČĎĹŇŠŤŽ][a-záéíóúýčďĺňšťž]+(?:\s+[a-záéíóúýčďĺňšťž]+)*)\s+(\d+[a-z]?)\s*(?:\n|<|$)', caseSensitive: false),
        ];
        
        for (final pattern in addressOnlyPatterns) {
          final matches = pattern.allMatches(html);
          for (final match in matches) {
            if (match.groupCount >= 2) {
              String potentialAddress = '${match.group(1)!.trim()} ${match.group(2)!.trim()}';
              potentialAddress = _cleanHtmlText(potentialAddress);
              potentialAddress = _decodeHtmlEntities(potentialAddress.trim());
              
              // Skontrolujeme, že to nie je mesto ktoré už máme
              if (_isValidAddress(potentialAddress) && 
                  !result.containsKey('city') || !potentialAddress.toLowerCase().contains(result['city']?.toLowerCase() ?? '')) {
                result['address'] = potentialAddress;
                print('Address found via pattern: $potentialAddress');
                break;
              }
            }
          }
          if (result.containsKey('address')) break;
        }
      }
      
      // Ak sme nenašli cez "Sídlo", skúsime iné formáty
      if (!sidloFound) {
        // Parsovanie adresy - hľadáme rôzne formáty
        final addressPatterns = [
          RegExp(r'Adresa[:\s]*([^<\n]+)', caseSensitive: false),
          RegExp(r'<[^>]*>Adresa[:\s]*</[^>]*>([^<\n]+)', caseSensitive: false),
          RegExp(r'<div[^>]*class="[^"]*address[^"]*"[^>]*>([^<]+)</div>', caseSensitive: false),
          RegExp(r'<span[^>]*class="[^"]*address[^"]*"[^>]*>([^<]+)</span>', caseSensitive: false),
          // Hľadanie ulice s číslom domu (napr. "Hudcovce 99")
          RegExp(r'([A-ZÁÉÍÓÚÝČĎĹŇŠŤŽ][a-záéíóúýčďĺňšťž]+(?:\s+[a-záéíóúýčďĺňšťž]+)*)\s+(\d+[a-z]?)', caseSensitive: false),
        ];
        
        for (final pattern in addressPatterns) {
          final addressMatch = pattern.firstMatch(html);
          if (addressMatch != null) {
            String address = addressMatch.group(1)!.trim();
            // Ak máme aj číslo domu v druhej skupine
            if (addressMatch.groupCount > 1 && addressMatch.group(2) != null) {
              address = '${addressMatch.group(1)!.trim()} ${addressMatch.group(2)!.trim()}';
            }
            address = _cleanHtmlText(address);
            address = _decodeHtmlEntities(address.trim());
            // Skontrolujeme, že to nie je PSČ alebo mesto alebo technický text
            if (address.isNotEmpty && 
                _isValidAddress(address) &&
                !RegExp(r'^\d{5}$').hasMatch(address) && 
                !address.toLowerCase().contains('vyroba') &&
                address.length > 3) {
              result['address'] = address;
              break;
            }
          }
        }
        
        // Parsovanie PSČ a mesta - hľadáme rôzne formáty
        final cityZipPatterns = [
          // Formát: PSČ Mesto (napr. "067 45 Hudcovce" alebo "06745 Hudcovce")
          RegExp(r'(\d{3}\s?\d{2})\s+([A-ZÁÉÍÓÚÝČĎĹŇŠŤŽ][a-záéíóúýčďĺňšťž]+(?:\s+[A-ZÁÉÍÓÚÝČĎĹŇŠŤŽ][a-záéíóúýčďĺňšťž]+)*)', caseSensitive: false),
          // Formát: Mesto, PSČ
          RegExp(r'([A-ZÁÉÍÓÚÝČĎĹŇŠŤŽ][a-záéíóúýčďĺňšťž]+(?:\s+[A-ZÁÉÍÓÚÝČĎĹŇŠŤŽ][a-záéíóúýčďĺňšťž]+)*)[,\s]+(\d{3}\s?\d{2})', caseSensitive: false),
          // Hľadanie v HTML elementoch
          RegExp(r'<[^>]*>(\d{3}\s?\d{2})[^<]*</[^>]*>\s*<[^>]*>([^<]+)</[^>]*>', caseSensitive: false),
        ];
        
        for (final pattern in cityZipPatterns) {
          final cityZipMatch = pattern.firstMatch(html);
          if (cityZipMatch != null) {
            // Zistíme, ktorá skupina je PSČ a ktorá mesto
            String? zipCode;
            String? city;
            
            if (cityZipMatch.groupCount >= 2) {
              // Skúsime oba poradia
              final group1 = cityZipMatch.group(1) ?? '';
              final group2 = cityZipMatch.group(2) ?? '';
              
              if (RegExp(r'^\d{3}\s?\d{2}$').hasMatch(group1)) {
                zipCode = group1.trim().replaceAll(' ', '');
                city = group2;
              } else if (RegExp(r'^\d{3}\s?\d{2}$').hasMatch(group2)) {
                zipCode = group2.trim().replaceAll(' ', '');
                city = group1;
              }
            } else if (cityZipMatch.groupCount == 1) {
              final group = cityZipMatch.group(1) ?? '';
              if (RegExp(r'^\d{3}\s?\d{2}$').hasMatch(group)) {
                zipCode = group.trim().replaceAll(' ', '');
              }
            }
            
            if (zipCode != null && RegExp(r'^\d{5}$').hasMatch(zipCode)) {
              result['zipCode'] = zipCode;
            }
            
            if (city != null) {
              city = _decodeHtmlEntities(city.trim());
              // Skontrolujeme, že to nie je popis činnosti
              if (city.isNotEmpty && 
                  !city.toLowerCase().contains('vyroba') &&
                  !city.toLowerCase().contains('beton') &&
                  !city.toLowerCase().contains('stavebn') &&
                  city.length < 50) {
                result['city'] = city;
              }
            }
            
            if (zipCode != null || city != null) {
              break;
            }
          }
        }
      }
      
      result['country'] = 'Slovensko';
      
      return result.isNotEmpty ? result : null;
    } catch (e) {
      print('Error parsing Finstat HTML: $e');
      return null;
    }
  }

  Future<void> _fetchCompanyData(String ico) async {
    if (_loadingIco || !mounted) return;
    
    setState(() => _loadingIco = true);
    
    try {
      // Skúsime najprv Finstat.sk API/vyhľadávanie
      final finstatResult = await _fetchFromFinstat(ico);
      if (finstatResult != null && mounted) {
        setState(() {
          final name = finstatResult['name'];
          if (name != null && name.isNotEmpty && _nameController.text.isEmpty) {
            _nameController.text = name;
          }
          final taxId = finstatResult['taxId'];
          if (taxId != null && taxId.isNotEmpty && _taxIdController.text.isEmpty) {
            _taxIdController.text = taxId;
          }
          final vatId = finstatResult['vatId'];
          if (vatId != null && vatId.isNotEmpty && _vatIdController.text.isEmpty) {
            _vatIdController.text = vatId;
          }
          final address = finstatResult['address'];
          if (address != null && address.isNotEmpty && _addressController.text.isEmpty) {
            _addressController.text = address;
          }
          final city = finstatResult['city'];
          if (city != null && city.isNotEmpty && _cityController.text.isEmpty) {
            _cityController.text = city;
          }
          final zipCode = finstatResult['zipCode'];
          if (zipCode != null && zipCode.isNotEmpty && _zipCodeController.text.isEmpty) {
            _zipCodeController.text = zipCode;
          }
          final country = finstatResult['country'];
          if (country != null && country.isNotEmpty && _countryController.text.isEmpty) {
            _countryController.text = country;
          }
        });
        
        if (mounted) {
          setState(() => _loadingIco = false);
          final mediaQuery = MediaQuery.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Údaje boli načítané z Finstat.sk'),
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
        return;
      }
      
      // Fallback na Register UZ API pre slovenské IČO
      final url = Uri.parse('https://www.registeruz.sk/cruz-public/api/uctovne-jednotky?ico=$ico');
      
      print('Fetching company data for ICO: $ico');
      print('URL: $url');
      
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'application/json, text/plain, */*',
          'Accept-Language': 'sk-SK,sk;q=0.9,en-US;q=0.8,en;q=0.7',
          'Accept-Encoding': 'gzip, deflate, br',
          'Referer': 'https://www.registeruz.sk/',
          'Origin': 'https://www.registeruz.sk',
          'Connection': 'keep-alive',
          'Sec-Fetch-Dest': 'empty',
          'Sec-Fetch-Mode': 'cors',
          'Sec-Fetch-Site': 'same-origin',
        },
      ).timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          throw TimeoutException('Načítanie údajov z IČO trvalo príliš dlho');
        },
      );
      
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode == 403 && mounted) {
        // Register UZ API blokuje požiadavky - možno kvôli ochrannému systému
        setState(() => _loadingIco = false);
        final mediaQuery = MediaQuery.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Register UZ API momentálne blokuje prístup. Prosím, vyplňte údaje manuálne.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: mediaQuery.size.height - mediaQuery.padding.top - 100,
          ),
          ),
        );
        return;
      }
      
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        
        print('Parsed data type: ${data.runtimeType}');
        print('Parsed data: $data');
        
        // Register UZ API môže vracať rôzne formáty
        int? companyId;
        
        if (data is Map) {
          // Môže to byť objekt s priamym id alebo objekt s id vnútri
          if (data['id'] != null) {
            companyId = data['id'] is int ? data['id'] : int.tryParse(data['id'].toString());
          } else if (data['uctovnaJednotka'] != null && data['uctovnaJednotka'] is Map) {
            companyId = data['uctovnaJednotka']['id'] is int 
                ? data['uctovnaJednotka']['id'] 
                : int.tryParse(data['uctovnaJednotka']['id'].toString());
          }
        } else if (data is List && data.isNotEmpty) {
          // Ak je to pole, vezmeme prvý výsledok
          final firstItem = data[0];
          if (firstItem is Map) {
            companyId = firstItem['id'] is int 
                ? firstItem['id'] 
                : int.tryParse(firstItem['id'].toString());
          }
        }
        
        print('Company ID found: $companyId');
        
        if (companyId != null) {
          // Načítanie detailov
          final detailUrl = Uri.parse('https://www.registeruz.sk/cruz-public/api/uctovne-jednotky/$companyId');
          print('Fetching details from: $detailUrl');
          
          final detailResponse = await http.get(
            detailUrl,
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              'Accept': 'application/json, text/plain, */*',
              'Accept-Language': 'sk-SK,sk;q=0.9,en-US;q=0.8,en;q=0.7',
              'Accept-Encoding': 'gzip, deflate, br',
              'Referer': 'https://www.registeruz.sk/',
              'Origin': 'https://www.registeruz.sk',
              'Connection': 'keep-alive',
              'Sec-Fetch-Dest': 'empty',
              'Sec-Fetch-Mode': 'cors',
              'Sec-Fetch-Site': 'same-origin',
            },
          ).timeout(
            const Duration(seconds: 8),
            onTimeout: () {
              throw TimeoutException('Načítanie detailov z IČO trvalo príliš dlho');
            },
          );
          
          if (detailResponse.statusCode == 200 && mounted) {
            final detailData = json.decode(detailResponse.body);
            
            // Debug - zobrazíme čo sme dostali
            print('Register UZ data: $detailData');
            
            setState(() {
              // Názov firmy
              if (detailData['nazovUJ'] != null && _nameController.text.isEmpty) {
                _nameController.text = detailData['nazovUJ'];
              }
              
              // DIČ
              if (detailData['dic'] != null && _taxIdController.text.isEmpty) {
                _taxIdController.text = detailData['dic'];
              }
              
              // IČ DPH - môže byť rovnaké ako DIČ alebo samostatné
              if (detailData['icDph'] != null && _vatIdController.text.isEmpty) {
                _vatIdController.text = detailData['icDph'];
              } else if (detailData['dic'] != null && _vatIdController.text.isEmpty) {
                // Ak nie je špecifické IČ DPH, použijeme DIČ
                _vatIdController.text = detailData['dic'];
              }
              
              // Adresa - skladá sa z viacerých polí
              String? street = detailData['ulica'];
              String? streetNumber = detailData['cisloDomu'] ?? detailData['cisloOrientacne'];
              String? city = detailData['mesto'];
              
              if (_addressController.text.isEmpty) {
                String addressParts = '';
                if (street != null) {
                  addressParts = street;
                  if (streetNumber != null) {
                    addressParts += ' $streetNumber';
                  }
                }
                if (addressParts.isNotEmpty && city != null) {
                  _addressController.text = '$addressParts, $city';
                } else if (street != null) {
                  _addressController.text = street;
                }
              }
              
              // Mesto
              if (city != null && _cityController.text.isEmpty) {
                _cityController.text = city;
              }
              
              // PSČ
              if (detailData['psc'] != null && _zipCodeController.text.isEmpty) {
                _zipCodeController.text = detailData['psc'];
              }
              
              // Krajina (zvyčajne Slovensko)
              if (detailData['stat'] != null && _countryController.text.isEmpty) {
                String country = detailData['stat'];
                // Normalizácia názvu krajiny
                if (country.toLowerCase().contains('slovensko') || 
                    country.toLowerCase().contains('slovakia')) {
                  _countryController.text = 'Slovensko';
                } else {
                  _countryController.text = country;
                }
              } else if (_countryController.text.isEmpty) {
                _countryController.text = 'Slovensko';
              }
              
              // Email (ak je v API)
              if (detailData['email'] != null && _emailController.text.isEmpty) {
                _emailController.text = detailData['email'];
              }
              
              // Telefón (ak je v API)
              if (detailData['telefon'] != null && _phoneController.text.isEmpty) {
                _phoneController.text = detailData['telefon'];
              }
              
              // Web stránka (ak je v API)
              if (detailData['web'] != null && _websiteController.text.isEmpty) {
                _websiteController.text = detailData['web'];
              }
            });
            
            // Show success message
            if (mounted) {
              final mediaQuery = MediaQuery.of(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Údaje boli načítané z Register UZ'),
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
        }
      }
    } on TimeoutException {
      // Zobrazíme chybu pri timeout
      if (mounted) {
        final mediaQuery = MediaQuery.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Načítanie údajov z Register UZ trvalo príliš dlho'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: mediaQuery.size.height - mediaQuery.padding.top - 100,
          ),
          ),
        );
      }
    } catch (e) {
      // Zobrazíme chybu
      if (mounted) {
        print('Error fetching company data: $e');
        final mediaQuery = MediaQuery.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba pri načítaní údajov: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: mediaQuery.size.height - mediaQuery.padding.top - 100,
          ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingIco = false);
      }
    }
  }

  void _onAddressChanged() {
    _addressDebounceTimer?.cancel();
    final address = _addressController.text.trim();
    
    if (address.length < 2) {
      setState(() {
        _showAddressSuggestions = false;
        _addressSuggestions = [];
      });
      return;
    }
    
    _addressDebounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted && _addressController.text.trim() == address) {
        _searchAddresses(address);
      }
    });
  }

  Future<void> _searchAddresses(String query) async {
    if (!mounted) return;
    
    // Always try OpenStreetMap first (free, no API key needed)
    if (_googlePlacesApiKey.isEmpty || _googlePlacesApiKey == 'YOUR_GOOGLE_PLACES_API_KEY') {
      _searchAddressesOpenStreetMap(query);
      return;
    }
    
    if (_loadingAddresses) return;
    
    setState(() => _loadingAddresses = true);
    
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$encodedQuery&key=$_googlePlacesApiKey&components=country:sk&language=sk'
      );
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Vyhľadávanie adries trvalo príliš dlho');
        },
      );
      
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['predictions'] != null) {
          final predictions = data['predictions'] as List;
          setState(() {
            _addressSuggestions = predictions.map((prediction) {
              return {
                'description': prediction['description'] ?? '',
                'place_id': prediction['place_id'] ?? '',
                'structured_formatting': prediction['structured_formatting'] ?? {},
              };
            }).toList();
            _showAddressSuggestions = _addressSuggestions.isNotEmpty;
          });
        } else if (mounted) {
          setState(() {
            _showAddressSuggestions = false;
            _addressSuggestions = [];
          });
        }
      }
    } catch (e) {
      if (mounted) {
        _searchAddressesOpenStreetMap(query);
      }
    } finally {
      if (mounted) {
        setState(() => _loadingAddresses = false);
      }
    }
  }

  Future<void> _searchAddressesOpenStreetMap(String query) async {
    if (!mounted) return;
    
    setState(() => _loadingAddresses = true);
    
    try {
      // Fallback: Použijeme OpenStreetMap Nominatim API
      // Try searching with Slovakia first, then without if no results
      String encodedQuery = Uri.encodeComponent('$query, Slovakia');
      Uri url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$encodedQuery&format=json&limit=10&addressdetails=1&countrycodes=sk');
      
      http.Response response = await http.get(
        url,
        headers: {
          'User-Agent': 'ProBlockPWMS/1.0',
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          throw TimeoutException('Vyhľadávanie adries trvalo príliš dlho');
        },
      );
      
      List<dynamic> results = [];
      
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        if (data is List) {
          results = data;
        }
      }
      
      // If no results with Slovakia, try without country restriction
      if (results.isEmpty) {
        encodedQuery = Uri.encodeComponent(query);
        url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$encodedQuery&format=json&limit=10&addressdetails=1');
        
        response = await http.get(
          url,
          headers: {
            'User-Agent': 'ProBlockPWMS/1.0',
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 8));
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data is List) {
            results = data;
          }
        }
      }
      
      if (mounted && results.isNotEmpty) {
        setState(() {
          _addressSuggestions = results.map((item) {
            final address = item['address'] ?? {};
            final street = address['road'] ?? address['pedestrian'] ?? '';
            final houseNumber = address['house_number'] ?? '';
            final city = address['city'] ?? address['town'] ?? address['village'] ?? address['municipality'] ?? '';
            final zipCode = address['postcode'] ?? '';
            final displayName = item['display_name'] ?? '';
            
            String addressStr = '';
            
            // Build address string
            if (street.isNotEmpty || houseNumber.isNotEmpty) {
              if (street.isNotEmpty && houseNumber.isNotEmpty) {
                addressStr = '$street $houseNumber';
              } else if (street.isNotEmpty) {
                addressStr = street;
              } else if (houseNumber.isNotEmpty) {
                addressStr = houseNumber;
              }
              
              if (city.isNotEmpty) {
                addressStr += ', $city';
              }
              if (zipCode.isNotEmpty) {
                addressStr += ' $zipCode';
              }
            } else {
              // Use display_name as fallback
              addressStr = displayName;
              // Try to extract useful parts
              if (addressStr.contains(',')) {
                final parts = addressStr.split(',');
                if (parts.length > 1) {
                  addressStr = parts.take(3).join(', '); // Take first 3 parts
                }
              }
            }
            
            return {
              'description': addressStr,
              'place_id': null,
              'osm_data': item,
              'structured_formatting': {
                'main_text': street.isNotEmpty ? '$street${houseNumber.isNotEmpty ? ' $houseNumber' : ''}' : (displayName.split(',')[0] ?? ''),
                'secondary_text': city.isNotEmpty ? '$city${zipCode.isNotEmpty ? ' $zipCode' : ''}' : (displayName.split(',').skip(1).take(2).join(', ') ?? ''),
              },
            };
          }).toList();
          _showAddressSuggestions = _addressSuggestions.isNotEmpty;
        });
      } else if (mounted) {
        setState(() {
          _showAddressSuggestions = false;
          _addressSuggestions = [];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _showAddressSuggestions = false;
          _addressSuggestions = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loadingAddresses = false);
      }
    }
  }

  Future<void> _fetchAddressDetails(String? placeId) async {
    if (placeId == null || placeId.isEmpty || _googlePlacesApiKey.isEmpty || _googlePlacesApiKey == 'YOUR_GOOGLE_PLACES_API_KEY') {
      return;
    }
    
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$_googlePlacesApiKey&fields=address_components,formatted_address&language=sk'
      );
      
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['result'] != null) {
          final result = data['result'];
          final addressComponents = result['address_components'] as List? ?? [];
          
          String? streetNumber;
          String? route;
          String? city;
          String? postalCode;
          String? country;
          
          for (var component in addressComponents) {
            final types = component['types'] as List;
            if (types.contains('street_number')) {
              streetNumber = component['long_name'];
            } else if (types.contains('route')) {
              route = component['long_name'];
            } else if (types.contains('locality') || types.contains('administrative_area_level_2')) {
              city = component['long_name'];
            } else if (types.contains('postal_code')) {
              postalCode = component['long_name'];
            } else if (types.contains('country')) {
              country = component['long_name'];
            }
          }
          
          setState(() {
            if (route != null) {
              _addressController.text = streetNumber != null ? '$route $streetNumber' : route;
            }
            if (city != null && _cityController.text.isEmpty) {
              _cityController.text = city;
            }
            if (postalCode != null && _zipCodeController.text.isEmpty) {
              _zipCodeController.text = postalCode;
            }
            if (country != null && _countryController.text.isEmpty) {
              if (country == 'Slovakia' || country == 'Slovak Republic') {
                _countryController.text = 'Slovensko';
              } else {
                _countryController.text = country;
              }
            }
            _showAddressSuggestions = false;
          });
        }
      }
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _saveSupplier() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _loading = true);

    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      
      final supplier = Supplier(
        id: widget.supplier?.id,
        name: _nameController.text.trim(),
        companyId: _companyIdController.text.trim().isEmpty ? null : _companyIdController.text.trim(),
        taxId: _taxIdController.text.trim().isEmpty ? null : _taxIdController.text.trim(),
        vatId: _vatIdController.text.trim().isEmpty ? null : _vatIdController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
        zipCode: _zipCodeController.text.trim().isEmpty ? null : _zipCodeController.text.trim(),
        country: _countryController.text.trim().isEmpty ? null : _countryController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
        contactPerson: _contactPersonController.text.trim().isEmpty ? null : _contactPersonController.text.trim(),
        paymentTerms: _paymentTermsController.text.trim().isEmpty ? null : _paymentTermsController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: widget.supplier?.createdAt ?? DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );

      if (widget.supplier == null) {
        await dbProvider.insertSupplier(supplier);
      } else {
        await dbProvider.updateSupplier(supplier);
      }

      if (mounted) {
        final mediaQuery = MediaQuery.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.supplier == null 
                ? 'Dodávateľ bol úspešne vytvorený'
                : 'Dodávateľ bol úspešne aktualizovaný'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: mediaQuery.size.height - mediaQuery.padding.top - 100,
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
            left: 16,
            right: 16,
            bottom: mediaQuery.size.height - mediaQuery.padding.top - 100,
          ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
//-------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.supplier == null ? 'Nový dodávateľ' : 'Upraviť dodávateľa'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.blue.shade50,
                      Colors.blue.shade100,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.business,
                        color: Colors.blue,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.supplier == null 
                                ? 'Nový dodávateľ'
                                : 'Upraviť dodávateľa',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Vyplňte údaje o dodávateľovi',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Basic info
            _buildSectionTitle('Základné informácie'),
            _buildTextField(_nameController, 'Názov spoločnosti *', Icons.business, validator: (v) => v?.isEmpty ?? true ? 'Zadajte názov' : null),
            _buildTextFieldWithLoader(_companyIdController, 'IČO', Icons.badge, _loadingIco),
            _buildTextField(_taxIdController, 'DIČ', Icons.receipt),
            _buildTextField(_vatIdController, 'IČ DPH', Icons.confirmation_number),
            
            const SizedBox(height: 16),
            _buildSectionTitle('Kontaktné údaje'),
            _buildAddressField(),
            Row(
              children: [
                Expanded(flex: 2, child: _buildTextField(_cityController, 'Mesto', Icons.location_city)),
                const SizedBox(width: 8),
                Expanded(child: _buildTextField(_zipCodeController, 'PSČ', Icons.markunread_mailbox)),
              ],
            ),
            _buildTextField(_countryController, 'Krajina', Icons.public),
            _buildTextField(_phoneController, 'Telefón', Icons.phone, keyboardType: TextInputType.phone),
            _buildTextField(_emailController, 'Email', Icons.email, keyboardType: TextInputType.emailAddress),
            _buildTextField(_websiteController, 'Web stránka', Icons.language, keyboardType: TextInputType.url),
            _buildTextField(_contactPersonController, 'Kontaktná osoba', Icons.person),
            
            const SizedBox(height: 16),
            _buildSectionTitle('Ďalšie informácie'),
            _buildTextField(_paymentTermsController, 'Platobné podmienky', Icons.payment),
            _buildTextField(_notesController, 'Poznámky', Icons.note, maxLines: 3),
            
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _loading ? null : _saveSupplier,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle),
                        const SizedBox(width: 8),
                        Text(
                          widget.supplier == null ? 'Vytvoriť dodávateľa' : 'Uložiť zmeny',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildAddressField() {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'Adresa',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.location_on),
                suffixIcon: _loadingAddresses
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _showAddressSuggestions
                        ? IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _showAddressSuggestions = false;
                                _addressSuggestions = [];
                              });
                            },
                          )
                        : null,
                helperText: _googlePlacesApiKey.isEmpty || _googlePlacesApiKey == 'YOUR_GOOGLE_PLACES_API_KEY'
                    ? 'Poznámka: Konfigurujte GOOGLE_PLACES_API_KEY pre Google Maps'
                    : 'Zadajte adresu a vyberte z návrhov (Google Maps)',
              ),
            ),
            if (_showAddressSuggestions && _addressSuggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _addressSuggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = _addressSuggestions[index];
                    final description = suggestion['description'] ?? '';
                    final structuredFormatting = suggestion['structured_formatting'] ?? {};
                    final mainText = structuredFormatting['main_text'] ?? '';
                    final secondaryText = structuredFormatting['secondary_text'] ?? '';
                    
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.location_on, size: 20, color: Colors.blue),
                      title: Text(
                        mainText.isNotEmpty ? mainText : description,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      subtitle: secondaryText.isNotEmpty
                          ? Text(
                              secondaryText,
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            )
                          : null,
                      onTap: () async {
                        final placeId = suggestion['place_id'];
                        if (placeId != null) {
                          await _fetchAddressDetails(placeId);
                          setState(() {
                            _addressController.text = description;
                            _showAddressSuggestions = false;
                            _addressSuggestions = [];
                          });
                        } else {
                          // Extract data from OpenStreetMap
                          final osmData = suggestion['osm_data'];
                          if (osmData != null) {
                            final address = osmData['address'] ?? {};
                            final city = address['city'] ?? 
                                        address['town'] ?? 
                                        address['village'] ?? 
                                        address['municipality'] ?? '';
                            final zipCode = address['postcode'] ?? '';
                            
                            setState(() {
                              _addressController.text = description;
                              // Fill city if field is empty
                              if (city.isNotEmpty && _cityController.text.isEmpty) {
                                _cityController.text = city;
                              }
                              // Fill postal code if field is empty
                              if (zipCode.isNotEmpty && _zipCodeController.text.isEmpty) {
                                _zipCodeController.text = zipCode;
                              }
                              _showAddressSuggestions = false;
                              _addressSuggestions = [];
                            });
                          } else {
                            // Fallback if no OSM data
                            setState(() {
                              _addressController.text = description;
                              _showAddressSuggestions = false;
                              _addressSuggestions = [];
                            });
                          }
                        }
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
//--------------------------------
  Widget _buildTextFieldWithLoader(
  TextEditingController controller,
  String label,
  IconData icon,
  bool isLoading,
) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          icon,
          color: Colors.blueGrey.shade600,
        ),

        // 🔹 moderný "filled" vzhľad
        filled: true,
        fillColor: Colors.grey.shade100,

        // 🔹 jemné zaoblenie
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),

        // 🔹 focus border
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.blue.shade400,
            width: 1.5,
          ),
        ),

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),

        // 🔹 loader ako suffix
        suffixIcon: isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.blue.shade400,
                  ),
                ),
              )
            : null,
      ),
    ),
  );
}

//-----------------------------------
  Widget _buildTextField(
  TextEditingController controller,
  String label,
  IconData icon, {
  TextInputType? keyboardType,
  int maxLines = 1,
  String? Function(String?)? validator,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          icon,
          color: Colors.blueGrey.shade600,
        ),

        // 🔹 moderný "filled" vzhľad
        filled: true,
        fillColor: Colors.grey.shade100,

        // 🔹 jemné zaoblenie
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),

        // 🔹 focus border
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.blue.shade400,
            width: 1.5,
          ),
        ),

        // 🔹 error border
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Colors.redAccent,
          ),
        ),

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    ),
  );
}


}