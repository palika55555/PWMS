import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class TransportScreen extends StatefulWidget {
  const TransportScreen({super.key});

  @override
  State<TransportScreen> createState() => _TransportScreenState();
}

class _TransportScreenState extends State<TransportScreen> {
  String? fromAddress;
  String? toAddress;
  
  double distanceKm = 0;
  double fuelConsumption = 6.5; // l/100km
  double fuelPrice = 1.70; // €/l
  double pricePerKm = 0.0; // €/km
  double transportPrice = 0;
  double fuelCost = 0; // Náklady na palivo
  double kmCost = 0; // Náklady za KM
  bool includeReturnTrip = false; // Zahrnúť späť cestu
  
  bool isLoading = false;
  String? errorMessage;
  
  final _fromAddressController = TextEditingController();
  final _toAddressController = TextEditingController();
  final _consumptionController = TextEditingController(text: '6.5');
  final _fuelPriceController = TextEditingController(text: '1.70');
  final _pricePerKmController = TextEditingController(text: '0.0');
  
  // Debouncing pre autocomplete
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _fromAddressController.dispose();
    _toAddressController.dispose();
    _consumptionController.dispose();
    _fuelPriceController.dispose();
    _pricePerKmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // HEADER - Hlava
          _buildHeader(context),
          
          // BODY - Telo
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).colorScheme.primaryContainer,
                    Theme.of(context).colorScheme.surface,
                  ],
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Formulár
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Výpočet dopravy',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 24),
                            
                            // Adresa odkiaľ s autocomplete
                            Autocomplete<String>(
                              optionsBuilder: (TextEditingValue textEditingValue) {
                                return _debouncedSearch(textEditingValue.text);
                              },
                              onSelected: (String selection) {
                                _fromAddressController.text = selection;
                                setState(() {
                                  fromAddress = selection;
                                });
                              },
                              fieldViewBuilder: (
                                BuildContext context,
                                TextEditingController fieldTextEditingController,
                                FocusNode fieldFocusNode,
                                VoidCallback onFieldSubmitted,
                              ) {
                                // Synchronizácia s hlavným controllerom
                                if (fieldTextEditingController.text != _fromAddressController.text) {
                                  fieldTextEditingController.text = _fromAddressController.text;
                                }
                                
                                return TextFormField(
                                  controller: fieldTextEditingController,
                                  focusNode: fieldFocusNode,
                                  decoration: InputDecoration(
                                    labelText: 'Adresa odkiaľ',
                                    hintText: 'Zadajte adresu odosielateľa',
                                    prefixIcon: const Icon(Icons.location_on),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  ),
                                  onChanged: (value) {
                                    _fromAddressController.text = value;
                                    setState(() {
                                      fromAddress = value.isEmpty ? null : value;
                                    });
                                  },
                                  onFieldSubmitted: (String value) {
                                    onFieldSubmitted();
                                  },
                                );
                              },
                              optionsViewBuilder: (
                                BuildContext context,
                                AutocompleteOnSelected<String> onSelected,
                                Iterable<String> options,
                              ) {
                                return Align(
                                  alignment: Alignment.topLeft,
                                  child: Material(
                                    elevation: 4.0,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      constraints: const BoxConstraints(maxHeight: 200),
                                      width: MediaQuery.of(context).size.width - 64,
                                      child: ListView.builder(
                                        padding: EdgeInsets.zero,
                                        shrinkWrap: true,
                                        itemCount: options.length,
                                        itemBuilder: (BuildContext context, int index) {
                                          final String option = options.elementAt(index);
                                          return InkWell(
                                            onTap: () {
                                              onSelected(option);
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(16.0),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.location_on,
                                                    size: 20,
                                                    color: Theme.of(context).colorScheme.primary,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      option,
                                                      style: Theme.of(context).textTheme.bodyMedium,
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            // Adresa kam s autocomplete
                            Autocomplete<String>(
                              optionsBuilder: (TextEditingValue textEditingValue) {
                                return _debouncedSearch(textEditingValue.text);
                              },
                              onSelected: (String selection) {
                                _toAddressController.text = selection;
                                setState(() {
                                  toAddress = selection;
                                });
                              },
                              fieldViewBuilder: (
                                BuildContext context,
                                TextEditingController fieldTextEditingController,
                                FocusNode fieldFocusNode,
                                VoidCallback onFieldSubmitted,
                              ) {
                                // Synchronizácia s hlavným controllerom
                                if (fieldTextEditingController.text != _toAddressController.text) {
                                  fieldTextEditingController.text = _toAddressController.text;
                                }
                                
                                return TextFormField(
                                  controller: fieldTextEditingController,
                                  focusNode: fieldFocusNode,
                                  decoration: InputDecoration(
                                    labelText: 'Adresa kam',
                                    hintText: 'Zadajte adresu príjemcu',
                                    prefixIcon: const Icon(Icons.location_on),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  ),
                                  onChanged: (value) {
                                    _toAddressController.text = value;
                                    setState(() {
                                      toAddress = value.isEmpty ? null : value;
                                    });
                                  },
                                  onFieldSubmitted: (String value) {
                                    onFieldSubmitted();
                                  },
                                );
                              },
                              optionsViewBuilder: (
                                BuildContext context,
                                AutocompleteOnSelected<String> onSelected,
                                Iterable<String> options,
                              ) {
                                return Align(
                                  alignment: Alignment.topLeft,
                                  child: Material(
                                    elevation: 4.0,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      constraints: const BoxConstraints(maxHeight: 200),
                                      width: MediaQuery.of(context).size.width - 64,
                                      child: ListView.builder(
                                        padding: EdgeInsets.zero,
                                        shrinkWrap: true,
                                        itemCount: options.length,
                                        itemBuilder: (BuildContext context, int index) {
                                          final String option = options.elementAt(index);
                                          return InkWell(
                                            onTap: () {
                                              onSelected(option);
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(16.0),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.location_on,
                                                    size: 20,
                                                    color: Theme.of(context).colorScheme.primary,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      option,
                                                      style: Theme.of(context).textTheme.bodyMedium,
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            // Spotreba paliva
                            TextFormField(
                              controller: _consumptionController,
                              decoration: InputDecoration(
                                labelText: 'Spotreba paliva (l/100 km)',
                                hintText: 'Napríklad: 6.5',
                                prefixIcon: const Icon(Icons.local_gas_station),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (value) {
                                setState(() {
                                  fuelConsumption = double.tryParse(value) ?? 6.5;
                                  if (distanceKm > 0) {
                                    _calculatePrice();
                                  }
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            // Cena paliva
                            TextFormField(
                              controller: _fuelPriceController,
                              decoration: InputDecoration(
                                labelText: 'Cena paliva (€/l)',
                                hintText: 'Napríklad: 1.70',
                                prefixIcon: const Icon(Icons.euro),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (value) {
                                setState(() {
                                  fuelPrice = double.tryParse(value) ?? 1.70;
                                  if (distanceKm > 0) {
                                    _calculatePrice();
                                  }
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            // Cena za KM
                            TextFormField(
                              controller: _pricePerKmController,
                              decoration: InputDecoration(
                                labelText: 'Cena za KM (€/km)',
                                hintText: 'Napríklad: 0.50 (voliteľné)',
                                prefixIcon: const Icon(Icons.attach_money),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (value) {
                                setState(() {
                                  pricePerKm = double.tryParse(value) ?? 0.0;
                                  if (distanceKm > 0) {
                                    _calculatePrice();
                                  }
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            // Checkbox pre späť cestu
                            Card(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              child: CheckboxListTile(
                                title: const Text('Zahrnúť späť cestu'),
                                subtitle: const Text('Vzdialenosť sa zdvojnásobí (tam aj späť)'),
                                value: includeReturnTrip,
                                onChanged: (value) {
                                  setState(() {
                                    includeReturnTrip = value ?? false;
                                    if (distanceKm > 0) {
                                      _calculatePrice();
                                    }
                                  });
                                },
                                controlAffinity: ListTileControlAffinity.leading,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // Tlačidlo na výpočet
                            ElevatedButton.icon(
                              onPressed: isLoading || fromAddress == null || toAddress == null
                                  ? null
                                  : _calculateDistance,
                              icon: isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.calculate),
                              label: Text(isLoading ? 'Počítam...' : 'Vypočítať dopravu'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            
                            // Chybová správa
                            if (errorMessage != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.error_outline, color: Colors.red.shade700),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        errorMessage!,
                                        style: TextStyle(color: Colors.red.shade700),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    
                    // Výsledky
                    if (distanceKm > 0) ...[
                      const SizedBox(height: 16),
                      Card(
                        elevation: 2,
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Výsledky',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Vzdialenosť
                              _buildResultRow(
                                context,
                                icon: Icons.route,
                                label: includeReturnTrip ? 'Vzdialenosť (tam aj späť)' : 'Vzdialenosť',
                                value: '${(distanceKm * (includeReturnTrip ? 2 : 1)).toStringAsFixed(2)} km',
                                color: Colors.blue,
                              ),
                              const SizedBox(height: 12),
                              
                              // Spotrebované palivo
                              _buildResultRow(
                                context,
                                icon: Icons.local_gas_station,
                                label: 'Spotrebované palivo',
                                value: '${((distanceKm * (includeReturnTrip ? 2 : 1)) * fuelConsumption / 100).toStringAsFixed(2)} l',
                                color: Colors.orange,
                              ),
                              const SizedBox(height: 12),
                              
                              // Náklady na palivo
                              if (fuelCost > 0)
                                _buildResultRow(
                                  context,
                                  icon: Icons.local_gas_station,
                                  label: 'Náklady na palivo',
                                  value: '${fuelCost.toStringAsFixed(2)} €',
                                  color: Colors.orange.shade700,
                                ),
                              if (fuelCost > 0) const SizedBox(height: 12),
                              
                              // Náklady za KM
                              if (kmCost > 0)
                                _buildResultRow(
                                  context,
                                  icon: Icons.route,
                                  label: 'Náklady za KM',
                                  value: '${kmCost.toStringAsFixed(2)} €',
                                  color: Colors.blue.shade700,
                                ),
                              if (kmCost > 0) const SizedBox(height: 12),
                              
                              // Cena dopravy
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.euro,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Celková cena dopravy',
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '${transportPrice.toStringAsFixed(2)} €',
                                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Tlačidlo na generovanie PDF štítku
                              ElevatedButton.icon(
                                onPressed: _generateTransportLabel,
                                icon: const Icon(Icons.print),
                                label: const Text('Vytvoriť PDF štítok'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: Theme.of(context).colorScheme.secondary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primaryContainer,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  Navigator.pop(context);
                },
                tooltip: 'Späť',
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_shipping,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Doprava',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      DateFormat('EEEE, d. MMMM yyyy', 'sk_SK').format(DateTime.now()),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Vyhľadávanie návrhov adries pomocou Nominatim
  Future<List<String>> _searchAddresses(String query) async {
    if (query.length < 3) {
      return [];
    }

    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?'
        'q=$encodedQuery&'
        'format=json&'
        'limit=5&'
        'addressdetails=1&'
        'countrycodes=sk,cz', // Obmedzenie na Slovensko a Česko
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'ProBlock PWMS App', // Nominatim vyžaduje User-Agent
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        return data.map((item) {
          // Zostavíme kompletnú adresu z komponentov
          final displayName = item['display_name'] as String? ?? '';
          return displayName;
        }).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Debounced search pre autocomplete
  Future<Iterable<String>> _debouncedSearch(String query) async {
    if (query.length < 3) {
      return const Iterable<String>.empty();
    }
    
    // Počkáme 300ms po poslednom stlačení klávesy
    final completer = Completer<Iterable<String>>();
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final results = await _searchAddresses(query);
      completer.complete(results);
    });
    
    return completer.future;
  }

  // Geokódovanie adresy pomocou Nominatim (OpenStreetMap)
  Future<Map<String, double>?> _geocodeAddress(String address) async {
    try {
      final encodedAddress = Uri.encodeComponent(address);
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?'
        'q=$encodedAddress&'
        'format=json&'
        'limit=1',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'ProBlock PWMS App', // Nominatim vyžaduje User-Agent
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        if (data.isNotEmpty) {
          final result = data[0];
          return {
            'lat': double.parse(result['lat'] as String),
            'lon': double.parse(result['lon'] as String),
          };
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Výpočet vzdialenosti pomocou OSRM
  Future<double?> _getDistanceKmOSRM(
    double fromLat,
    double fromLng,
    double toLat,
    double toLng,
  ) async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '$fromLng,$fromLat;$toLng,$toLat?overview=false',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 'Ok' && data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final meters = data['routes'][0]['distance'] as num;
          return meters / 1000;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _calculateDistance() async {
    if (fromAddress == null || toAddress == null) {
      setState(() {
        errorMessage = 'Prosím vyplňte obe adresy';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Krok 1: Geokódovanie adries (prevod na súradnice)
      final fromCoords = await _geocodeAddress(fromAddress!);
      if (fromCoords == null) {
        setState(() {
          errorMessage = 'Nepodarilo sa nájsť adresu "odkiaľ". Skontrolujte správnosť adresy.';
          isLoading = false;
        });
        return;
      }

      final toCoords = await _geocodeAddress(toAddress!);
      if (toCoords == null) {
        setState(() {
          errorMessage = 'Nepodarilo sa nájsť adresu "kam". Skontrolujte správnosť adresy.';
          isLoading = false;
        });
        return;
      }

      // Krok 2: Výpočet vzdialenosti pomocou OSRM
      final distance = await _getDistanceKmOSRM(
        fromCoords['lat']!,
        fromCoords['lon']!,
        toCoords['lat']!,
        toCoords['lon']!,
      );

      if (distance != null) {
        setState(() {
          distanceKm = distance;
          _calculatePrice();
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Nepodarilo sa vypočítať vzdialenosť. Skúste to znova.';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Chyba pri výpočte: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  void _calculatePrice() {
    // Vzdialenosť s prihliadnutím na späť cestu
    final totalDistance = distanceKm * (includeReturnTrip ? 2 : 1);
    
    final consumptionPerKm = fuelConsumption / 100;
    final fuelUsed = totalDistance * consumptionPerKm;
    
    // Náklady na palivo
    fuelCost = fuelUsed * fuelPrice;
    
    // Náklady za KM
    kmCost = totalDistance * pricePerKm;
    
    // Celková cena dopravy
    setState(() {
      transportPrice = fuelCost + kmCost;
    });
  }

  Future<void> _generateTransportLabel() async {
    if (fromAddress == null || toAddress == null || distanceKm == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Najprv vypočítajte dopravu'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final pdf = await _generateTransportPdf();
      
      // Otvorenie PDF priamo bez dialógu na tlač
      await Printing.sharePdf(
        bytes: pdf,
        filename: 'dopravny-stitok-${DateFormat('yyyy-MM-dd-HHmm', 'sk_SK').format(DateTime.now())}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba pri generovaní PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<Uint8List> _generateTransportPdf() async {
    // Načítanie fontov
    final fontData = await rootBundle.load('assets/fonts/OpenSans-Regular.ttf');
    final ttf = pw.Font.ttf(fontData);
    
    final fontBoldData = await rootBundle.load('assets/fonts/OpenSans-Bold.ttf');
    final ttfBold = pw.Font.ttf(fontBoldData);

    final pdf = pw.Document();
    final now = DateTime.now();
    final dateFormat = DateFormat('d. M. yyyy', 'sk_SK');
    final timeFormat = DateFormat('HH:mm', 'sk_SK');

    // Formátovanie údajov
    final totalDistance = distanceKm * (includeReturnTrip ? 2 : 1);
    final fuelUsed = totalDistance * fuelConsumption / 100;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Container(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Hlavička
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey300,
                    border: pw.Border.all(color: PdfColors.black, width: 2),
                  ),
                  child: pw.Text(
                    'DOPRAVNÝ ŠTÍTOK',
                    style: pw.TextStyle(
                      font: ttfBold,
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.SizedBox(height: 20),
                
                // Dátum a čas
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Dátum: ${dateFormat.format(now)}',
                      style: pw.TextStyle(font: ttf, fontSize: 12),
                    ),
                    pw.Text(
                      'Čas: ${timeFormat.format(now)}',
                      style: pw.TextStyle(font: ttf, fontSize: 12),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                
                // Odkiaľ
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black, width: 1.5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'ODKIAĽ:',
                        style: pw.TextStyle(
                          font: ttfBold,
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        fromAddress!,
                        style: pw.TextStyle(font: ttf, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),
                
                // Kam
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black, width: 1.5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'KAM:',
                        style: pw.TextStyle(
                          font: ttfBold,
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        toAddress!,
                        style: pw.TextStyle(font: ttf, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                
                // Vzdialenosť - veľký a zvýraznený
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue100,
                    border: pw.Border.all(color: PdfColors.blue700, width: 2),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            includeReturnTrip ? 'VZDIALENOSŤ (TAM AJ SPÄŤ):' : 'VZDIALENOSŤ:',
                            style: pw.TextStyle(
                              font: ttfBold,
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            '${(distanceKm * (includeReturnTrip ? 2 : 1)).toStringAsFixed(2)} km',
                            style: pw.TextStyle(
                              font: ttfBold,
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue900,
                            ),
                          ),
                        ],
                      ),
                      if (includeReturnTrip) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          '(Jednosmerná vzdialenosť: ${distanceKm.toStringAsFixed(2)} km)',
                          style: pw.TextStyle(
                            font: ttf,
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                
                // Detailné informácie
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Spotreba paliva:',
                            style: pw.TextStyle(font: ttf, fontSize: 12),
                          ),
                          pw.Text(
                            '${fuelUsed.toStringAsFixed(2)} l',
                            style: pw.TextStyle(font: ttf, fontSize: 12),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Cena paliva:',
                            style: pw.TextStyle(font: ttf, fontSize: 12),
                          ),
                          pw.Text(
                            '${fuelPrice.toStringAsFixed(2)} €/l',
                            style: pw.TextStyle(font: ttf, fontSize: 12),
                          ),
                        ],
                      ),
                      if (fuelCost > 0) ...[
                        pw.SizedBox(height: 8),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Náklady na palivo:',
                              style: pw.TextStyle(font: ttf, fontSize: 12),
                            ),
                            pw.Text(
                              '${fuelCost.toStringAsFixed(2)} €',
                              style: pw.TextStyle(font: ttf, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                      if (kmCost > 0) ...[
                        pw.SizedBox(height: 8),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Cena za KM (${pricePerKm.toStringAsFixed(2)} €/km):',
                              style: pw.TextStyle(font: ttf, fontSize: 12),
                            ),
                            pw.Text(
                              '${kmCost.toStringAsFixed(2)} €',
                              style: pw.TextStyle(font: ttf, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                
                // Celková cena dopravy - veľký a zvýraznený
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey800,
                    border: pw.Border.all(color: PdfColors.black, width: 2),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'CELKOVÁ CENA DOPRAVY:',
                        style: pw.TextStyle(
                          font: ttfBold,
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.Text(
                        '${transportPrice.toStringAsFixed(2)} €',
                        style: pw.TextStyle(
                          font: ttfBold,
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }
}
