/// Model pre stálych odberateľov (zákazníkov)
class Customer {
  final int? id;
  final String name;
  final String? companyId; // IČO
  final String? taxId; // DIČ
  final String? vatId; // IČ DPH
  final String? address;
  final String? city;
  final String? zipCode;
  final String? country;
  final String? phone;
  final String? email;
  final String? website;
  final String? contactPerson;
  final String? paymentTerms; // Platobné podmienky
  final double? creditLimit; // Kreditný limit
  final String? priceList; // Názov cenníka pre zákazníka
  final String? notes;
  final bool isActive;
  final int synced;
  final String createdAt;
  final String updatedAt;

  Customer({
    this.id,
    required this.name,
    this.companyId,
    this.taxId,
    this.vatId,
    this.address,
    this.city,
    this.zipCode,
    this.country,
    this.phone,
    this.email,
    this.website,
    this.contactPerson,
    this.paymentTerms,
    this.creditLimit,
    this.priceList,
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
      'company_id': companyId,
      'tax_id': taxId,
      'vat_id': vatId,
      'address': address,
      'city': city,
      'zip_code': zipCode,
      'country': country,
      'phone': phone,
      'email': email,
      'website': website,
      'contact_person': contactPerson,
      'payment_terms': paymentTerms,
      'credit_limit': creditLimit,
      'price_list': priceList,
      'notes': notes,
      'is_active': isActive ? 1 : 0,
      'synced': synced,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as int?,
      name: map['name'] as String,
      companyId: map['company_id'] as String?,
      taxId: map['tax_id'] as String?,
      vatId: map['vat_id'] as String?,
      address: map['address'] as String?,
      city: map['city'] as String?,
      zipCode: map['zip_code'] as String?,
      country: map['country'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      website: map['website'] as String?,
      contactPerson: map['contact_person'] as String?,
      paymentTerms: map['payment_terms'] as String?,
      creditLimit: (map['credit_limit'] as num?)?.toDouble(),
      priceList: map['price_list'] as String?,
      notes: map['notes'] as String?,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      synced: map['synced'] as int? ?? 0,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  Customer copyWith({
    int? id,
    String? name,
    String? companyId,
    String? taxId,
    String? vatId,
    String? address,
    String? city,
    String? zipCode,
    String? country,
    String? phone,
    String? email,
    String? website,
    String? contactPerson,
    String? paymentTerms,
    double? creditLimit,
    String? priceList,
    String? notes,
    bool? isActive,
    int? synced,
    String? createdAt,
    String? updatedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      companyId: companyId ?? this.companyId,
      taxId: taxId ?? this.taxId,
      vatId: vatId ?? this.vatId,
      address: address ?? this.address,
      city: city ?? this.city,
      zipCode: zipCode ?? this.zipCode,
      country: country ?? this.country,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      contactPerson: contactPerson ?? this.contactPerson,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      creditLimit: creditLimit ?? this.creditLimit,
      priceList: priceList ?? this.priceList,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      synced: synced ?? this.synced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

