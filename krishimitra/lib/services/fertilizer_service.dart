import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:krishimitra/domain/models/models.dart';
import 'dart:math' as math;

class FertilizerService {
  static const String fertilizersPath = 'assets/data/fertilizer_data.json';
  static List<Map<String, dynamic>> _fertilizerDatabase = [];
  static Future<void> loadDatabase() async {
    try {
      final jsonString = await rootBundle.loadString(fertilizersPath);
      _fertilizerDatabase = List<Map<String, dynamic>>.from(
        jsonDecode(jsonString) as List,
      );
    } catch (e) {
      print('Error loading fertilizer database: $e');
      _fertilizerDatabase = [];
    }
  }

  static double _euclideanDistance(
    double n1,
    double p1,
    double k1,
    double n2,
    double p2,
    double k2,
  ) {
    final nDiff = (n1 - n2);
    final pDiff = (p1 - p2);
    final kDiff = (k1 - k2);
    return math.sqrt((nDiff * nDiff) + (pDiff * pDiff) + (kDiff * kDiff));
  }

  static FertilizerRecommendation? findRecommendation(
    double nitrogen,
    double phosphorus,
    double potassium,
  ) {
    if (_fertilizerDatabase.isEmpty) {
      return null;
    }
    final List<Map<String, dynamic>> distances = [];

    for (final record in _fertilizerDatabase) {
      final distance = _euclideanDistance(
        nitrogen,
        phosphorus,
        potassium,
        (record['N'] as num).toDouble(),
        (record['P'] as num).toDouble(),
        (record['K'] as num).toDouble(),
      );

      distances.add({'record': record, 'distance': distance});
    }
    distances.sort((a, b) => (a['distance'] as num).compareTo(b['distance']));
    final closest = distances.first;
    final record = closest['record'] as Map<String, dynamic>;
    final distance = closest['distance'] as double;
    final maxDistance = 173.2;
    final similarity = 1.0 - (distance / maxDistance);

    return FertilizerRecommendation(
      name: record['recommendation'] as String? ?? 'Unknown',
      quantity: _suggestQuantity(record),
      type: record['type'] as String? ?? 'Chemical',
      similarity: math.max(0.0, similarity),
    );
  }

  static double _suggestQuantity(Map<String, dynamic> record) {
    final n = (record['N'] as num).toInt();
    final p = (record['P'] as num).toInt();
    final k = (record['K'] as num).toInt();
    double quantity = 10.0;
    final total = n + p + k;
    if (total > 100) {
      quantity = 12.0;
    } else if (total < 60) {
      quantity = 8.0;
    }

    return quantity;
  }
}
