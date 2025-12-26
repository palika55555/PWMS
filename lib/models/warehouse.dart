class Warehouse {
  final int? id;
  final String name;
  final String? code; // Kód skladu
  final String? address;
  final String? city;
  final String? zipCode;
  final String? country;
  final String? phone;
  final String? email;
  final String? manager; // Správca skladu
  final String? notes;
  final bool isActive; // Aktívny/neaktívny sklad
  final int synced;
  final String createdAt;
  final String updatedAt;

  Warehouse({
    this.id,
    required this.name,
    this.code,
    this.address,
    this.city,
    this.zipCode,
    this.country,
    this.phone,
    this.email,
    this.manager,
    this.notes,
    this.isActive = true,
    this.synced = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'address': address,
      'city': city,
      'zip_code': zipCode,
      'country': country,
      'phone': phone,
      'email': email,
      'manager': manager,
      'notes': notes,
      'is_active': isActive ? 1 : 0,
      'synced': synced,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Warehouse.fromMap(Map<String, dynamic> map) {
    return Warehouse(
      id: map['id'] as int?,
      name: map['name'] as String,
      code: map['code'] as String?,
      address: map['address'] as String?,
      city: map['city'] as String?,
      zipCode: map['zip_code'] as String?,
      country: map['country'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      manager: map['manager'] as String?,
      notes: map['notes'] as String?,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      synced: map['synced'] as int? ?? 0,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  Warehouse copyWith({
    int? id,
    String? name,
    String? code,
    String? address,
    String? city,
    String? zipCode,
    String? country,
    String? phone,
    String? email,
    String? manager,
    String? notes,
    bool? isActive,
    int? synced,
    String? createdAt,
    String? updatedAt,
  }) {
    return Warehouse(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      address: address ?? this.address,
      city: city ?? this.city,
      zipCode: zipCode ?? this.zipCode,
      country: country ?? this.country,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      manager: manager ?? this.manager,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      synced: synced ?? this.synced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}


