import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import '../../providers/database_provider.dart';
import '../../models/customer.dart';
import '../../config/api_config.dart';

class AddCustomerDialog extends StatefulWidget {
  const AddCustomerDialog({super.key});

  @override
  State<AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<AddCustomerDialog> {
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
  final _creditLimitController = TextEditingController();
  final _priceListController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isActive = true;
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
    _zipCodeController.addListener(() => _onZipCodeChanged());
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
    _creditLimitController.dispose();
    _priceListController.dispose();
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

  void _onZipCodeChanged() {
    final zipCode = _zipCodeController.text.trim();
    if (zipCode.length == 5) {
      _fetchCityByZipCode(zipCode);
    }
  }

  Future<Map<String, String>?> _fetchFromFinstat(String ico) async {
    try {
      final detailUrl = Uri.parse('https://www.finstat.sk/$ico');
      
      final response = await http.get(
        detailUrl,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'sk-SK,sk;q=0.9,en-US;q=0.8,en;q=0.7',
          'Referer': 'https://www.finstat.sk/',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final html = response.body;
        
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
                return result;
              }
            } catch (e) {
              print('Error parsing JSON from HTML: $e');
            }
          }
        }
        
        Map<String, String>? result = _parseFinstatHtml(html, ico);
        if (result != null && result['name']?.isNotEmpty == true) {
          return result;
        }
      }
      
      final apiUrls = [
        'https://www.finstat.sk/api/company/$ico',
        'https://www.finstat.sk/api/v1/company/$ico',
        'https://api.finstat.sk/company/$ico',
      ];
      
      for (final apiUrlStr in apiUrls) {
        try {
          final apiUrl = Uri.parse(apiUrlStr);
          final apiResponse = await http.get(
            apiUrl,
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              'Accept': 'application/json, */*',
              'Accept-Language': 'sk-SK,sk;q=0.9,en-US;q=0.8,en;q=0.7',
              'Referer': 'https://www.finstat.sk/',
            },
          ).timeout(const Duration(seconds: 8));
          
          if (apiResponse.statusCode == 200) {
            final data = json.decode(apiResponse.body);
            Map<String, String>? result = _parseFinstatData(data);
            if (result != null && result['name']?.isNotEmpty == true) {
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
      
      dynamic findValue(dynamic obj, List<String> keys) {
        if (obj is Map) {
          for (final key in keys) {
            if (obj.containsKey(key)) {
              return obj[key];
            }
            for (final k in obj.keys) {
              if (k.toString().toLowerCase() == key.toLowerCase()) {
                return obj[k];
              }
            }
          }
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
        result['address'] = streetNumber != null && streetNumber.toString().isNotEmpty
            ? '${street.toString()} ${streetNumber.toString()}'
            : street.toString();
      }
      
      final city = findValue(data, ['mesto', 'city', 'obec']);
      if (city != null) result['city'] = city.toString();
      
      final zipCode = findValue(data, ['psc', 'zipCode', 'PSC', 'zip', 'postalCode']);
      if (zipCode != null) result['zipCode'] = zipCode.toString();
      
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
    return text
        .replaceAll('&#253;', 'ý').replaceAll('&#225;', 'á').replaceAll('&#237;', 'í')
        .replaceAll('&#233;', 'é').replaceAll('&#243;', 'ó').replaceAll('&#250;', 'ú')
        .replaceAll('&#269;', 'č').replaceAll('&#271;', 'ď').replaceAll('&#328;', 'ň')
        .replaceAll('&#353;', 'š').replaceAll('&#357;', 'ť').replaceAll('&#382;', 'ž')
        .replaceAll('&#193;', 'Á').replaceAll('&#201;', 'É').replaceAll('&#205;', 'Í')
        .replaceAll('&#211;', 'Ó').replaceAll('&#218;', 'Ú').replaceAll('&#221;', 'Ý')
        .replaceAll('&#268;', 'Č').replaceAll('&#272;', 'Ď').replaceAll('&#327;', 'Ň')
        .replaceAll('&#352;', 'Š').replaceAll('&#356;', 'Ť').replaceAll('&#381;', 'Ž')
        .replaceAll('&amp;', '&').replaceAll('&lt;', '<').replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"').replaceAll('&apos;', "'").replaceAll('&nbsp;', ' ');
  }

  String _cleanHtmlText(String text) {
    String cleaned = text;
    cleaned = cleaned.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'<!\[if[^\]]*\].*?<!\[endif\]>', dotAll: true, caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'<!--\[if[^\]]*\].*?<!\[endif\]-->', dotAll: true, caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'<[^>]+>', dotAll: true), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned;
  }

  bool _isValidAddress(String address) {
    final invalidPatterns = [
      RegExp(r'^if\s+(lt|gte|gt|lte)\s+IE', caseSensitive: false),
      RegExp(r'^<!--', caseSensitive: false),
      RegExp(r'^<!\[', caseSensitive: false),
      RegExp(r'^script', caseSensitive: false),
      RegExp(r'^style', caseSensitive: false),
    ];
    
    final cleanAddr = address.trim().toLowerCase();
    
    if (!RegExp(r'[a-záéíóúýčďĺňšťž]').hasMatch(cleanAddr)) {
      return false;
    }
    
    for (final pattern in invalidPatterns) {
      if (pattern.hasMatch(cleanAddr)) {
        return false;
      }
    }
    
    final invalidKeywords = [
      'dane', 'príjmu', 'príjm', 'platcov', 'rebrič', 'rebrick', 'štatist', 'statist',
      'najväčší', 'najväčších', 'najlepšie', 'analýz', 'analyz', 'prehľad', 'prehlad',
      'online', 'ročn', 'rocn', 'spoločnost', 'spolocnost', 'register', 'databáza', 'databaza',
    ];
    
    for (final keyword in invalidKeywords) {
      if (cleanAddr.contains(keyword)) {
        return false;
      }
    }
    
    if (cleanAddr.length < 3 || cleanAddr.length > 100) {
      return false;
    }
    
    if (RegExp(r'^\d{3,}$').hasMatch(cleanAddr)) {
      return false;
    }
    
    if (!RegExp(r'[a-záéíóúýčďĺňšťž]{2,}').hasMatch(cleanAddr)) {
      return false;
    }
    
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
      
      final namePatterns = [
        RegExp(r'<h1[^>]*>([^<]+)</h1>', caseSensitive: false),
        RegExp(r'<title>([^<]+)</title>', caseSensitive: false),
        RegExp(r'class="company-name"[^>]*>([^<]+)</', caseSensitive: false),
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
      
      final dicPatterns = [
        RegExp(r'<strong[^>]*>DIČ</strong>\s*<span[^>]*>([^<]+)</span>', caseSensitive: false),
        RegExp(r'DIČ[:\s]*([A-Z]{2}\d{8,10})', caseSensitive: false),
        RegExp(r'<strong[^>]*>DIČ</strong>\s*<span[^>]*>(\d{8,12})</span>', caseSensitive: false),
      ];
      
      for (final pattern in dicPatterns) {
        final dicMatch = pattern.firstMatch(html);
        if (dicMatch != null) {
          String dicValue = dicMatch.group(1)!.trim();
          dicValue = _cleanHtmlText(dicValue);
          dicValue = _decodeHtmlEntities(dicValue);
          
          if (dicValue.isNotEmpty) {
            result['taxId'] = dicValue;
            if (!result.containsKey('vatId')) {
              result['vatId'] = dicValue;
            }
            break;
          }
        }
      }
      
      final icDphPatterns = [
        RegExp(r'<strong[^>]*>IČ\s+DPH</strong>\s*<span[^>]*>([^<]+)</span>', caseSensitive: false),
        RegExp(r'<strong[^>]*>IČ\s*DPH</strong>\s*<span[^>]*>([^<]+)</span>', caseSensitive: false),
        RegExp(r'IČ\s+DPH[:\s]*([A-Z]{2}\d{8,12})', caseSensitive: false),
      ];
      
      for (final pattern in icDphPatterns) {
        final icDphMatch = pattern.firstMatch(html);
        if (icDphMatch != null) {
          String icDphValue = icDphMatch.group(1)!.trim();
          icDphValue = _cleanHtmlText(icDphValue);
          icDphValue = _decodeHtmlEntities(icDphValue);
          icDphValue = icDphValue.replaceAll(RegExp(r'^(SK)\s+(\d+)', caseSensitive: false), r'$1$2');
          
          if (icDphValue.isNotEmpty && RegExp(r'^\d+$').hasMatch(icDphValue)) {
            icDphValue = 'SK$icDphValue';
          }
          
          if (icDphValue.isNotEmpty) {
            result['vatId'] = icDphValue;
            break;
          }
        }
      }
      
      if (!result.containsKey('vatId') && result.containsKey('taxId')) {
        final dicValue = result['taxId']!;
        if (!dicValue.toUpperCase().startsWith('SK')) {
          result['vatId'] = 'SK$dicValue';
        } else {
          result['vatId'] = dicValue;
        }
      }
      
      final sidloPatterns = [
        RegExp(r'<strong[^>]*>Sídlo</strong>\s*<span[^>]*>([^<]+(?:s\.\s*r\.\s*o\.|spol\.|a\.s\.)?)<br[^>]*>([^<]+)</span>', caseSensitive: false, dotAll: true),
        RegExp(r'<strong[^>]*>Sídlo</strong>\s*<span[^>]*>([^<]+)<br[^>]*>([A-ZÁÉÍÓÚÝČĎĹŇŠŤŽ][^<]*?\d+[^<]*?)</span>', caseSensitive: false, dotAll: true),
      ];
      
      for (final pattern in sidloPatterns) {
        final sidloMatch = pattern.firstMatch(html);
        if (sidloMatch != null) {
          String? addressLine;
          String? zipCodeLine;
          String? cityLine;
          
          if (sidloMatch.groupCount == 2) {
            final fullAddressLine = sidloMatch.group(2) ?? '';
            if (fullAddressLine.isNotEmpty) {
              final addressZipCityMatch = RegExp(r'([A-ZÁÉÍÓÚÝČĎĹŇŠŤŽ][^\d]*?\d+[^\d]*?)\s+(\d{3}\s?\d{2})\s+([A-ZÁÉÍÓÚÝČĎĹŇŠŤŽ][a-záéíóúýčďĺňšťž]+)').firstMatch(fullAddressLine);
              if (addressZipCityMatch != null) {
                addressLine = addressZipCityMatch.group(1);
                zipCodeLine = addressZipCityMatch.group(2);
                cityLine = addressZipCityMatch.group(3);
              } else {
                addressLine = fullAddressLine;
              }
            }
          } else if (sidloMatch.groupCount >= 3) {
            if (sidloMatch.groupCount == 3) {
              addressLine = sidloMatch.group(1);
              zipCodeLine = sidloMatch.group(2);
              cityLine = sidloMatch.group(3);
            } else if (sidloMatch.groupCount >= 4) {
              addressLine = sidloMatch.group(2);
              zipCodeLine = sidloMatch.group(3);
              cityLine = sidloMatch.group(4);
            }
          }
          
          if (addressLine != null && addressLine.isNotEmpty) {
            String address = _cleanHtmlText(addressLine);
            address = _decodeHtmlEntities(address.trim());
            address = address.replaceAll(RegExp(r'\s+\d{3}\s?\d{2}\s+[A-ZÁÉÍÓÚÝČĎĹŇŠŤŽ][a-záéíóúýčďĺňšťž]+$'), '');
            address = address.replaceAll(RegExp(r'\b(s\.\s*r\.\s*o\.|spol\.|a\.s\.|s\.r\.o\.)', caseSensitive: false), '').trim();
            address = address.replaceAll(RegExp(r'^,\s*'), '').trim();
            
            if (address.isNotEmpty && _isValidAddress(address) && !RegExp(r'^\d{3}\s?\d{2}$').hasMatch(address)) {
              result['address'] = address;
            }
          }
          
          if (zipCodeLine != null && zipCodeLine.isNotEmpty) {
            final zipCode = zipCodeLine.trim().replaceAll(' ', '');
            if (RegExp(r'^\d{5}$').hasMatch(zipCode)) {
              result['zipCode'] = zipCode;
            }
          }
          
          if (cityLine != null && cityLine.isNotEmpty) {
            String city = _cleanHtmlText(cityLine);
            city = _decodeHtmlEntities(city.trim());
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
            break;
          }
        }
      }
      
      // Ak sme nenašli cez "Sídlo", skúsime nájsť adresu pomocou všeobecnejšieho patternu
      if (!result.containsKey('address')) {
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
                  (!result.containsKey('city') || !potentialAddress.toLowerCase().contains(result['city']?.toLowerCase() ?? ''))) {
                result['address'] = potentialAddress;
                break;
              }
            }
          }
          if (result.containsKey('address')) break;
        }
      }
      
      // Ak sme nenašli cez "Sídlo", skúsime iné formáty
      if (!result.containsKey('address')) {
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
            
            if (zipCode != null && RegExp(r'^\d{5}$').hasMatch(zipCode) && !result.containsKey('zipCode')) {
              result['zipCode'] = zipCode;
            }
            
            if (city != null && !result.containsKey('city')) {
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
      
      final url = Uri.parse('https://www.registeruz.sk/cruz-public/api/uctovne-jednotky?ico=$ico');
      
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'application/json, text/plain, */*',
          'Accept-Language': 'sk-SK,sk;q=0.9,en-US;q=0.8,en;q=0.7',
          'Referer': 'https://www.registeruz.sk/',
        },
      ).timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          throw TimeoutException('Načítanie údajov z IČO trvalo príliš dlho');
        },
      );
      
      if (response.statusCode == 403 && mounted) {
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
        
        int? companyId;
        
        if (data is Map) {
          if (data['id'] != null) {
            companyId = data['id'] is int ? data['id'] : int.tryParse(data['id'].toString());
          } else if (data['uctovnaJednotka'] != null && data['uctovnaJednotka'] is Map) {
            companyId = data['uctovnaJednotka']['id'] is int 
                ? data['uctovnaJednotka']['id'] 
                : int.tryParse(data['uctovnaJednotka']['id'].toString());
          }
        } else if (data is List && data.isNotEmpty) {
          final firstItem = data[0];
          if (firstItem is Map) {
            companyId = firstItem['id'] is int 
                ? firstItem['id'] 
                : int.tryParse(firstItem['id'].toString());
          }
        }
        
        if (companyId != null) {
          final detailUrl = Uri.parse('https://www.registeruz.sk/cruz-public/api/uctovne-jednotky/$companyId');
          
          final detailResponse = await http.get(
            detailUrl,
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              'Accept': 'application/json, text/plain, */*',
              'Accept-Language': 'sk-SK,sk;q=0.9,en-US;q=0.8,en;q=0.7',
              'Referer': 'https://www.registeruz.sk/',
            },
          ).timeout(
            const Duration(seconds: 8),
            onTimeout: () {
              throw TimeoutException('Načítanie detailov z IČO trvalo príliš dlho');
            },
          );
          
          if (detailResponse.statusCode == 200 && mounted) {
            final detailData = json.decode(detailResponse.body);
            
            setState(() {
              if (detailData['nazovUJ'] != null && _nameController.text.isEmpty) {
                _nameController.text = detailData['nazovUJ'];
              }
              
              if (detailData['dic'] != null && _taxIdController.text.isEmpty) {
                _taxIdController.text = detailData['dic'];
              }
              
              if (detailData['icDph'] != null && _vatIdController.text.isEmpty) {
                _vatIdController.text = detailData['icDph'];
              } else if (detailData['dic'] != null && _vatIdController.text.isEmpty) {
                _vatIdController.text = detailData['dic'];
              }
              
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
              
              if (city != null && _cityController.text.isEmpty) {
                _cityController.text = city;
              }
              
              if (detailData['psc'] != null && _zipCodeController.text.isEmpty) {
                _zipCodeController.text = detailData['psc'];
              }
              
              if (detailData['stat'] != null && _countryController.text.isEmpty) {
                String country = detailData['stat'];
                if (country.toLowerCase().contains('slovensko') || 
                    country.toLowerCase().contains('slovakia')) {
                  _countryController.text = 'Slovensko';
                } else {
                  _countryController.text = country;
                }
              } else if (_countryController.text.isEmpty) {
                _countryController.text = 'Slovensko';
              }
              
              if (detailData['email'] != null && _emailController.text.isEmpty) {
                _emailController.text = detailData['email'];
              }
              
              if (detailData['telefon'] != null && _phoneController.text.isEmpty) {
                _phoneController.text = detailData['telefon'];
              }
              
              if (detailData['web'] != null && _websiteController.text.isEmpty) {
                _websiteController.text = detailData['web'];
              }
            });
            
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

  Future<void> _searchAddresses(String query) async {
    if (!mounted) return;
    
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
    } on TimeoutException {
      if (mounted) {
        _searchAddressesOpenStreetMap(query);
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
              addressStr = displayName;
              if (addressStr.contains(',')) {
                final parts = addressStr.split(',');
                if (parts.length > 1) {
                  addressStr = parts.take(3).join(', ');
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
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 5),
      );
      
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

  Future<void> _fetchCityByZipCode(String zipCode) async {
    if (!mounted) return;
    
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?postalcode=$zipCode&country=sk&format=json&limit=1&addressdetails=1');
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'ProBlockPWMS/1.0',
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Načítanie mesta podľa PSČ trvalo príliš dlho');
        },
      );
      
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        if (data is List && data.isNotEmpty) {
          final item = data[0];
          final address = item['address'] ?? {};
          final city = address['city'] ?? address['town'] ?? address['village'] ?? '';
          
          if (city.isNotEmpty && _cityController.text.isEmpty && mounted) {
            setState(() {
              _cityController.text = city;
            });
          }
        }
      }
    } on TimeoutException {
      // Silently fail
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _loading = true);

    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      
      final customer = Customer(
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
        creditLimit: _creditLimitController.text.trim().isEmpty 
            ? null 
            : double.tryParse(_creditLimitController.text),
        priceList: _priceListController.text.trim().isEmpty ? null : _priceListController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        isActive: _isActive,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );

      await dbProvider.insertCustomer(customer);

      if (mounted) {
        final mediaQuery = MediaQuery.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Zákazník bol úspešne vytvorený'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: mediaQuery.size.height - mediaQuery.padding.top - 100,
          ),
          ),
        );
        Navigator.of(context).pop(true);
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.purple.shade400,
                    Colors.purple.shade600,
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.person_add,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nový zákazník',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Vyplňte údaje o zákazníkovi',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Form content
            Flexible(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Základné informácie
                      _buildSectionTitle('Základné informácie', Icons.info_outline),
                      const SizedBox(height: 8),
                      _buildTextField(
                        _nameController,
                        'Názov spoločnosti *',
                        Icons.business,
                        validator: (v) => v?.isEmpty ?? true ? 'Zadajte názov' : null,
                      ),
                      _buildTextFieldWithLoader(_companyIdController, 'IČO', Icons.badge, _loadingIco),
                      Row(
                        children: [
                          Expanded(child: _buildTextField(_taxIdController, 'DIČ', Icons.receipt)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildTextField(_vatIdController, 'IČ DPH', Icons.confirmation_number)),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      // Kontaktné údaje
                      _buildSectionTitle('Kontaktné údaje', Icons.contact_mail),
                      const SizedBox(height: 8),
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
                      // Obchodné informácie
                      _buildSectionTitle('Obchodné informácie', Icons.business_center),
                      const SizedBox(height: 8),
                      _buildTextField(_paymentTermsController, 'Platobné podmienky', Icons.payment),
                      _buildTextField(_creditLimitController, 'Kreditný limit (€)', Icons.account_balance_wallet, keyboardType: TextInputType.number),
                      _buildTextField(_priceListController, 'Cenník', Icons.list_alt),
                      
                      const SizedBox(height: 16),
                      // Ďalšie
                      _buildSectionTitle('Ďalšie', Icons.more_horiz),
                      const SizedBox(height: 8),
                      Card(
                        elevation: 0,
                        color: Colors.grey.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: SwitchListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          title: const Text('Aktívny', style: TextStyle(fontSize: 14)),
                          subtitle: const Text('Zákazník je aktívny a môže objednávať', style: TextStyle(fontSize: 12)),
                          value: _isActive,
                          onChanged: (value) {
                            setState(() {
                              _isActive = value;
                            });
                          },
                        ),
                      ),
                      _buildTextField(_notesController, 'Poznámky', Icons.note, maxLines: 2),
                    ],
                  ),
                ),
              ),
            ),
            // Footer s tlačidlami
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Zrušiť', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _saveCustomer,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.purple,
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
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle),
                                SizedBox(width: 8),
                                Text(
                                  'Uložiť',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.purple.shade700),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

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
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          suffixIcon: isLoading
              ? const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildAddressField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _addressController,
            decoration: InputDecoration(
              labelText: 'Adresa',
              prefixIcon: const Icon(Icons.location_on, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                            if (city.isNotEmpty && _cityController.text.isEmpty) {
                              _cityController.text = city;
                            }
                            if (zipCode.isNotEmpty && _zipCodeController.text.isEmpty) {
                              _zipCodeController.text = zipCode;
                            }
                            _showAddressSuggestions = false;
                            _addressSuggestions = [];
                          });
                        } else {
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
    );
  }

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
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
      ),
    );
  }
}

