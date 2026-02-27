import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:krishimitra/domain/models/marketplace_models.dart';
import 'dart:math';

/// Service for managing equipment rentals (peer-to-peer marketplace)
class EquipmentRentalService {
  static Database? _database;
  static const String _equipmentTable = 'equipment';
  static const String _bookingsTable = 'rental_bookings';

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'krishimitra_rentals.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Equipment table
        await db.execute('''
          CREATE TABLE $_equipmentTable (
            id TEXT PRIMARY KEY,
            ownerId TEXT NOT NULL,
            ownerName TEXT NOT NULL,
            ownerPhone TEXT NOT NULL,
            equipmentName TEXT NOT NULL,
            type TEXT NOT NULL,
            brand TEXT NOT NULL,
            model TEXT NOT NULL,
            yearOfManufacture INTEGER NOT NULL,
            pricePerDay REAL NOT NULL,
            pricePerHour REAL NOT NULL,
            description TEXT NOT NULL,
            imageUrls TEXT NOT NULL,
            location TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            isAvailable INTEGER NOT NULL DEFAULT 1,
            rating REAL NOT NULL DEFAULT 0.0,
            totalRentals INTEGER NOT NULL DEFAULT 0,
            createdAt TEXT NOT NULL,
            lastRentedDate TEXT,
            features TEXT
          )
        ''');

        // Bookings table
        await db.execute('''
          CREATE TABLE $_bookingsTable (
            id TEXT PRIMARY KEY,
            equipmentId TEXT NOT NULL,
            renterId TEXT NOT NULL,
            renterName TEXT NOT NULL,
            renterPhone TEXT NOT NULL,
            startDate TEXT NOT NULL,
            endDate TEXT NOT NULL,
            totalCost REAL NOT NULL,
            status TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            notes TEXT,
            FOREIGN KEY (equipmentId) REFERENCES $_equipmentTable (id)
          )
        ''');

        // Add sample equipment
        await _insertSampleEquipment(db);
      },
    );
  }

  static Future<void> _insertSampleEquipment(Database db) async {
    final samples = [
      {
        'id': 'eq_${DateTime.now().millisecondsSinceEpoch}_1',
        'ownerId': 'owner_1',
        'ownerName': 'Ramesh Kumar',
        'ownerPhone': '+91 98765 43210',
        'equipmentName': 'Mahindra 575 DI Tractor',
        'type': 'tractor',
        'brand': 'Mahindra',
        'model': '575 DI',
        'yearOfManufacture': 2020,
        'pricePerDay': 2500.0,
        'pricePerHour': 300.0,
        'description':
            'Well-maintained tractor, suitable for all farming operations',
        'imageUrls': 'https://example.com/tractor1.jpg',
        'location': 'Pune, Maharashtra',
        'latitude': 18.5204,
        'longitude': 73.8567,
        'isAvailable': 1,
        'rating': 4.5,
        'totalRentals': 45,
        'createdAt': DateTime.now().toIso8601String(),
        'features': 'Power steering,Front loader,Excellent condition',
      },
      {
        'id': 'eq_${DateTime.now().millisecondsSinceEpoch}_2',
        'ownerId': 'owner_2',
        'ownerName': 'Suresh Patil',
        'ownerPhone': '+91 98765 43211',
        'equipmentName': 'Combine Harvester',
        'type': 'harvester',
        'brand': 'John Deere',
        'model': 'W70',
        'yearOfManufacture': 2019,
        'pricePerDay': 8000.0,
        'pricePerHour': 1000.0,
        'description': 'Modern harvester for wheat, rice, and other crops',
        'imageUrls': 'https://example.com/harvester1.jpg',
        'location': 'Nashik, Maharashtra',
        'latitude': 20.0117,
        'longitude': 73.7903,
        'isAvailable': 1,
        'rating': 4.8,
        'totalRentals': 32,
        'createdAt': DateTime.now().toIso8601String(),
        'features': 'GPS tracking,Low fuel consumption,High efficiency',
      },
      {
        'id': 'eq_${DateTime.now().millisecondsSinceEpoch}_3',
        'ownerId': 'owner_3',
        'ownerName': 'Vijay Singh',
        'ownerPhone': '+91 98765 43212',
        'equipmentName': 'Agricultural Drone',
        'type': 'drone',
        'brand': 'DJI',
        'model': 'Agras T30',
        'yearOfManufacture': 2022,
        'pricePerDay': 5000.0,
        'pricePerHour': 700.0,
        'description': 'Advanced spraying drone for precision agriculture',
        'imageUrls': 'https://example.com/drone1.jpg',
        'location': 'Ludhiana, Punjab',
        'latitude': 30.9010,
        'longitude': 75.8573,
        'isAvailable': 1,
        'rating': 4.9,
        'totalRentals': 28,
        'createdAt': DateTime.now().toIso8601String(),
        'features': 'Auto pilot,Smart spraying,Weather resistant',
      },
    ];

    for (final sample in samples) {
      await db.insert(_equipmentTable, sample);
    }
  }

  /// Add new equipment listing
  static Future<void> addEquipment(Equipment equipment) async {
    final db = await database;
    await db.insert(
      _equipmentTable,
      equipment.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all available equipment
  static Future<List<Equipment>> getAvailableEquipment() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _equipmentTable,
      where: 'isAvailable = ?',
      whereArgs: [1],
      orderBy: 'rating DESC, totalRentals DESC',
    );
    return List.generate(maps.length, (i) => Equipment.fromMap(maps[i]));
  }

  /// Get equipment by type
  static Future<List<Equipment>> getEquipmentByType(EquipmentType type) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _equipmentTable,
      where: 'type = ? AND isAvailable = ?',
      whereArgs: [type.name, 1],
      orderBy: 'rating DESC',
    );
    return List.generate(maps.length, (i) => Equipment.fromMap(maps[i]));
  }

  /// Get nearby equipment based on location
  static Future<List<Equipment>> getNearbyEquipment(
    double userLat,
    double userLon, {
    double radiusKm = 50,
  }) async {
    final allEquipment = await getAvailableEquipment();

    // Filter by distance
    final nearby =
        allEquipment.where((eq) {
          final distance = _calculateDistance(
            userLat,
            userLon,
            eq.latitude,
            eq.longitude,
          );
          return distance <= radiusKm;
        }).toList();

    // Sort by distance
    nearby.sort((a, b) {
      final distA = _calculateDistance(
        userLat,
        userLon,
        a.latitude,
        a.longitude,
      );
      final distB = _calculateDistance(
        userLat,
        userLon,
        b.latitude,
        b.longitude,
      );
      return distA.compareTo(distB);
    });

    return nearby;
  }

  /// Calculate distance between two points (Haversine formula)
  static double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371; // Earth's radius in km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _toRadians(double degree) {
    return degree * pi / 180;
  }

  /// Search equipment
  static Future<List<Equipment>> searchEquipment(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _equipmentTable,
      where: '''
        (equipmentName LIKE ? OR 
         brand LIKE ? OR 
         description LIKE ? OR
         location LIKE ?) AND 
        isAvailable = ?
      ''',
      whereArgs: ['%$query%', '%$query%', '%$query%', '%$query%', 1],
      orderBy: 'rating DESC',
    );
    return List.generate(maps.length, (i) => Equipment.fromMap(maps[i]));
  }

  /// Get equipment by ID
  static Future<Equipment?> getEquipmentById(String equipmentId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _equipmentTable,
      where: 'id = ?',
      whereArgs: [equipmentId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Equipment.fromMap(maps[0]);
  }

  /// Create a rental booking
  static Future<String> createBooking(RentalBooking booking) async {
    final db = await database;
    await db.insert(
      _bookingsTable,
      booking.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Update equipment availability if booking is confirmed
    if (booking.status == BookingStatus.confirmed) {
      await db.update(
        _equipmentTable,
        {'isAvailable': 0},
        where: 'id = ?',
        whereArgs: [booking.equipmentId],
      );
    }

    return booking.id;
  }

  /// Get bookings for a renter
  static Future<List<RentalBooking>> getRenterBookings(String renterId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _bookingsTable,
      where: 'renterId = ?',
      whereArgs: [renterId],
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) => RentalBooking.fromMap(maps[i]));
  }

  /// Get bookings for equipment
  static Future<List<RentalBooking>> getEquipmentBookings(
    String equipmentId,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _bookingsTable,
      where: 'equipmentId = ?',
      whereArgs: [equipmentId],
      orderBy: 'startDate DESC',
    );
    return List.generate(maps.length, (i) => RentalBooking.fromMap(maps[i]));
  }

  /// Update booking status
  static Future<void> updateBookingStatus(
    String bookingId,
    BookingStatus status,
  ) async {
    final db = await database;

    // Get the booking
    final bookingMaps = await db.query(
      _bookingsTable,
      where: 'id = ?',
      whereArgs: [bookingId],
      limit: 1,
    );

    if (bookingMaps.isEmpty) return;
    final booking = RentalBooking.fromMap(bookingMaps[0]);

    // Update booking
    await db.update(
      _bookingsTable,
      {'status': status.name},
      where: 'id = ?',
      whereArgs: [bookingId],
    );

    // Update equipment availability
    if (status == BookingStatus.completed ||
        status == BookingStatus.cancelled) {
      await db.update(
        _equipmentTable,
        {
          'isAvailable': 1,
          'totalRentals':
              '(SELECT totalRentals FROM $_equipmentTable WHERE id = ?) + 1',
        },
        where: 'id = ?',
        whereArgs: [booking.equipmentId, booking.equipmentId],
      );
    }
  }

  /// Update equipment rating
  static Future<void> updateEquipmentRating(
    String equipmentId,
    double newRating,
  ) async {
    final db = await database;
    final equipment = await getEquipmentById(equipmentId);
    if (equipment == null) return;

    // Calculate new average rating
    final totalRatings = equipment.totalRentals;
    final currentTotal = equipment.rating * totalRatings;
    final newAverage = (currentTotal + newRating) / (totalRatings + 1);

    await db.update(
      _equipmentTable,
      {'rating': newAverage},
      where: 'id = ?',
      whereArgs: [equipmentId],
    );
  }

  /// Get marketplace statistics
  static Future<Map<String, dynamic>> getMarketplaceStats() async {
    final db = await database;

    final totalEquipment = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $_equipmentTable'),
    );

    final availableEquipment = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM $_equipmentTable WHERE isAvailable = 1',
      ),
    );

    final totalBookings = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $_bookingsTable'),
    );

    final activeBookings = Sqflite.firstIntValue(
      await db.rawQuery(
        "SELECT COUNT(*) FROM $_bookingsTable WHERE status = 'ongoing'",
      ),
    );

    return {
      'totalEquipment': totalEquipment ?? 0,
      'availableEquipment': availableEquipment ?? 0,
      'totalBookings': totalBookings ?? 0,
      'activeBookings': activeBookings ?? 0,
    };
  }
}
