/// Model pre skladové lokality (viacero skladov)
class WarehouseLocation {
  final int? id;
  final String name;
  final String? code; // Kód skladu
  final String? address;
  final String? city;
  final String? zipCode;
  final String? country;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final bool isActive;
  final bool isDefault; // Je toto predvolený sklad
  final String? notes;
  final int synced;
  final String createdAt;
  final String updatedAt;

  WarehouseLocation({
    this.id,
    required this.name,
    this.code,
    this.address,
    this.city,
    this.zipCode,
    this.country,
    this.contactPerson,
    this.phone,
    this.email,
    this.isActive = true,
    this.isDefault = false,
    this.notes,
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
      'contact_person': contactPerson,
      'phone': phone,
      'email': email,
      'is_active': isActive ? 1 : 0,
      'is_default': isDefault ? 1 : 0,
      'notes': notes,
      'synced': synced,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory WarehouseLocation.fromMap(Map<String, dynamic> map) {
    return WarehouseLocation(
      id: map['id'] as int?,
      name: map['name'] as String,
      code: map['code'] as String?,
      address: map['address'] as String?,
      city: map['city'] as String?,
      zipCode: map['zip_code'] as String?,
      country: map['country'] as String?,
      contactPerson: map['contact_person'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      isDefault: (map['is_default'] as int? ?? 0) == 1,
      notes: map['notes'] as String?,
      synced: map['synced'] as int? ?? 0,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }
}






