import 'package:flutter/material.dart';

/// Mandi Price Model for real-time commodity prices
class MandiPrice {
  final String commodity;
  final String commodityHindi;
  final String state;
  final String district;
  final String market;
  final double minPrice;
  final double maxPrice;
  final double modalPrice;
  final String priceUnit;
  final DateTime arrivalDate;
  final String variety;

  MandiPrice({
    required this.commodity,
    required this.commodityHindi,
    required this.state,
    required this.district,
    required this.market,
    required this.minPrice,
    required this.maxPrice,
    required this.modalPrice,
    required this.priceUnit,
    required this.arrivalDate,
    required this.variety,
  });

  factory MandiPrice.fromJson(Map<String, dynamic> json) {
    return MandiPrice(
      commodity: json['commodity'] as String? ?? 'Unknown',
      commodityHindi: json['commodityHindi'] as String? ?? 'अज्ञात',
      state: json['state'] as String? ?? '',
      district: json['district'] as String? ?? '',
      market: json['market'] as String? ?? '',
      minPrice: _parsePrice(json['min_price']),
      maxPrice: _parsePrice(json['max_price']),
      modalPrice: _parsePrice(json['modal_price']),
      priceUnit: json['price_unit'] as String? ?? 'Rs/Quintal',
      arrivalDate: _parseDate(json['arrival_date']),
      variety: json['variety'] as String? ?? 'Local',
    );
  }

  static double _parsePrice(dynamic price) {
    if (price == null) return 0.0;
    if (price is num) return price.toDouble();
    if (price is String) {
      return double.tryParse(price.replaceAll(',', '')) ?? 0.0;
    }
    return 0.0;
  }

  static DateTime _parseDate(dynamic date) {
    if (date == null) return DateTime.now();
    if (date is String) {
      try {
        return DateTime.parse(date);
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  double get avgPrice => (minPrice + maxPrice) / 2;

  Map<String, dynamic> toMap() {
    return {
      'commodity': commodity,
      'commodityHindi': commodityHindi,
      'state': state,
      'district': district,
      'market': market,
      'minPrice': minPrice,
      'maxPrice': maxPrice,
      'modalPrice': modalPrice,
      'priceUnit': priceUnit,
      'arrivalDate': arrivalDate.toIso8601String(),
      'variety': variety,
    };
  }
}

/// Equipment Rental Model for peer-to-peer equipment sharing
class Equipment {
  final String id;
  final String ownerId;
  final String ownerName;
  final String ownerPhone;
  final String equipmentName;
  final EquipmentType type;
  final String brand;
  final String model;
  final int yearOfManufacture;
  final double pricePerDay;
  final double pricePerHour;
  final String description;
  final List<String> imageUrls;
  final String location;
  final double latitude;
  final double longitude;
  final bool isAvailable;
  final double rating;
  final int totalRentals;
  final DateTime createdAt;
  final DateTime? lastRentedDate;
  final List<String> features;

  Equipment({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.ownerPhone,
    required this.equipmentName,
    required this.type,
    required this.brand,
    required this.model,
    required this.yearOfManufacture,
    required this.pricePerDay,
    required this.pricePerHour,
    required this.description,
    required this.imageUrls,
    required this.location,
    required this.latitude,
    required this.longitude,
    this.isAvailable = true,
    this.rating = 0.0,
    this.totalRentals = 0,
    required this.createdAt,
    this.lastRentedDate,
    this.features = const [],
  });

  factory Equipment.fromMap(Map<String, dynamic> map) {
    return Equipment(
      id: map['id'] as String,
      ownerId: map['ownerId'] as String,
      ownerName: map['ownerName'] as String,
      ownerPhone: map['ownerPhone'] as String,
      equipmentName: map['equipmentName'] as String,
      type: EquipmentType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => EquipmentType.other,
      ),
      brand: map['brand'] as String,
      model: map['model'] as String,
      yearOfManufacture: map['yearOfManufacture'] as int,
      pricePerDay: (map['pricePerDay'] as num).toDouble(),
      pricePerHour: (map['pricePerHour'] as num).toDouble(),
      description: map['description'] as String,
      imageUrls: (map['imageUrls'] as String).split(','),
      location: map['location'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      isAvailable: (map['isAvailable'] as int) == 1,
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      totalRentals: map['totalRentals'] as int? ?? 0,
      createdAt: DateTime.parse(map['createdAt'] as String),
      lastRentedDate:
          map['lastRentedDate'] != null
              ? DateTime.parse(map['lastRentedDate'] as String)
              : null,
      features:
          map['features'] != null ? (map['features'] as String).split(',') : [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'ownerPhone': ownerPhone,
      'equipmentName': equipmentName,
      'type': type.name,
      'brand': brand,
      'model': model,
      'yearOfManufacture': yearOfManufacture,
      'pricePerDay': pricePerDay,
      'pricePerHour': pricePerHour,
      'description': description,
      'imageUrls': imageUrls.join(','),
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'isAvailable': isAvailable ? 1 : 0,
      'rating': rating,
      'totalRentals': totalRentals,
      'createdAt': createdAt.toIso8601String(),
      'lastRentedDate': lastRentedDate?.toIso8601String(),
      'features': features.join(','),
    };
  }

  int get equipmentAge => DateTime.now().year - yearOfManufacture;
}

enum EquipmentType {
  tractor,
  harvester,
  thresher,
  plough,
  seeder,
  sprayer,
  waterPump,
  drone,
  rotavator,
  cultivator,
  other,
}

extension EquipmentTypeExtension on EquipmentType {
  String get displayName {
    switch (this) {
      case EquipmentType.tractor:
        return 'Tractor';
      case EquipmentType.harvester:
        return 'Harvester';
      case EquipmentType.thresher:
        return 'Thresher';
      case EquipmentType.plough:
        return 'Plough';
      case EquipmentType.seeder:
        return 'Seeder';
      case EquipmentType.sprayer:
        return 'Sprayer';
      case EquipmentType.waterPump:
        return 'Water Pump';
      case EquipmentType.drone:
        return 'Drone';
      case EquipmentType.rotavator:
        return 'Rotavator';
      case EquipmentType.cultivator:
        return 'Cultivator';
      case EquipmentType.other:
        return 'Other';
    }
  }

  String get displayNameHindi {
    switch (this) {
      case EquipmentType.tractor:
        return 'ट्रैक्टर';
      case EquipmentType.harvester:
        return 'कटाई मशीन';
      case EquipmentType.thresher:
        return 'थ्रेशर';
      case EquipmentType.plough:
        return 'हल';
      case EquipmentType.seeder:
        return 'बीज बोने की मशीन';
      case EquipmentType.sprayer:
        return 'स्प्रेयर';
      case EquipmentType.waterPump:
        return 'पानी का पंप';
      case EquipmentType.drone:
        return 'ड्रोन';
      case EquipmentType.rotavator:
        return 'रोटावेटर';
      case EquipmentType.cultivator:
        return 'कल्टीवेटर';
      case EquipmentType.other:
        return 'अन्य';
    }
  }

  IconData get icon {
    switch (this) {
      case EquipmentType.tractor:
        return Icons.agriculture;
      case EquipmentType.harvester:
        return Icons.grass;
      case EquipmentType.thresher:
        return Icons.settings;
      case EquipmentType.plough:
        return Icons.landscape;
      case EquipmentType.seeder:
        return Icons.eco;
      case EquipmentType.sprayer:
        return Icons.water;
      case EquipmentType.waterPump:
        return Icons.water_drop;
      case EquipmentType.drone:
        return Icons.flight;
      case EquipmentType.rotavator:
        return Icons.build;
      case EquipmentType.cultivator:
        return Icons.construction;
      case EquipmentType.other:
        return Icons.handyman;
    }
  }

  Color get color {
    switch (this) {
      case EquipmentType.tractor:
        return const Color(0xFFFF9800);
      case EquipmentType.harvester:
        return const Color(0xFF4CAF50);
      case EquipmentType.thresher:
        return const Color(0xFF795548);
      case EquipmentType.plough:
        return const Color(0xFF8D6E63);
      case EquipmentType.seeder:
        return const Color(0xFF66BB6A);
      case EquipmentType.sprayer:
        return const Color(0xFF2196F3);
      case EquipmentType.waterPump:
        return const Color(0xFF00BCD4);
      case EquipmentType.drone:
        return const Color(0xFF9C27B0);
      case EquipmentType.rotavator:
        return const Color(0xFF607D8B);
      case EquipmentType.cultivator:
        return const Color(0xFF9E9E9E);
      case EquipmentType.other:
        return const Color(0xFF757575);
    }
  }
}

/// Rental Booking Model
class RentalBooking {
  final String id;
  final String equipmentId;
  final String renterId;
  final String renterName;
  final String renterPhone;
  final DateTime startDate;
  final DateTime endDate;
  final double totalCost;
  final BookingStatus status;
  final DateTime createdAt;
  final String? notes;

  RentalBooking({
    required this.id,
    required this.equipmentId,
    required this.renterId,
    required this.renterName,
    required this.renterPhone,
    required this.startDate,
    required this.endDate,
    required this.totalCost,
    required this.status,
    required this.createdAt,
    this.notes,
  });

  factory RentalBooking.fromMap(Map<String, dynamic> map) {
    return RentalBooking(
      id: map['id'] as String,
      equipmentId: map['equipmentId'] as String,
      renterId: map['renterId'] as String,
      renterName: map['renterName'] as String,
      renterPhone: map['renterPhone'] as String,
      startDate: DateTime.parse(map['startDate'] as String),
      endDate: DateTime.parse(map['endDate'] as String),
      totalCost: (map['totalCost'] as num).toDouble(),
      status: BookingStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => BookingStatus.pending,
      ),
      createdAt: DateTime.parse(map['createdAt'] as String),
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'equipmentId': equipmentId,
      'renterId': renterId,
      'renterName': renterName,
      'renterPhone': renterPhone,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'totalCost': totalCost,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'notes': notes,
    };
  }

  int get durationDays => endDate.difference(startDate).inDays + 1;
}

enum BookingStatus { pending, confirmed, ongoing, completed, cancelled }

extension BookingStatusExtension on BookingStatus {
  String get displayName {
    switch (this) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.ongoing:
        return 'Ongoing';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get displayNameHindi {
    switch (this) {
      case BookingStatus.pending:
        return 'लंबित';
      case BookingStatus.confirmed:
        return 'पुष्ट';
      case BookingStatus.ongoing:
        return 'चालू';
      case BookingStatus.completed:
        return 'पूर्ण';
      case BookingStatus.cancelled:
        return 'रद्द';
    }
  }

  Color get color {
    switch (this) {
      case BookingStatus.pending:
        return Colors.orange;
      case BookingStatus.confirmed:
        return Colors.blue;
      case BookingStatus.ongoing:
        return Colors.purple;
      case BookingStatus.completed:
        return Colors.green;
      case BookingStatus.cancelled:
        return Colors.red;
    }
  }
}
