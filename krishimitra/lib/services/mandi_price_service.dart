import 'package:krishimitra/domain/models/marketplace_models.dart';

/// Service for fetching real-time Mandi prices
/// Uses Government of India's Agmarknet API (data.gov.in)
class MandiPriceService {
  // For demonstration, we'll use mock data
  // In production, integrate with: https://api.data.gov.in/resource/9ef84268-d588-465a-a308-a864a43d0070

  /// Fetch prices for a specific commodity
  static Future<List<MandiPrice>> getPricesForCommodity(
    String commodity, {
    String? state,
    String? district,
    int limit = 10,
  }) async {
    try {
      // In production, use actual API
      // For now, return mock data
      return _getMockPrices(commodity, state: state, district: district);

      /* Production code:
      final queryParams = {
        'api-key': _apiKey,
        'format': 'json',
        'limit': limit.toString(),
        'filters[commodity]': commodity,
        if (state != null) 'filters[state]': state,
        if (district != null) 'filters[district]': district,
      };

      final uri = Uri.parse(_apiUrl).replace(queryParameters: queryParams);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final records = data['records'] as List;
        return records.map((r) => MandiPrice.fromJson(r)).toList();
      } else {
        throw Exception('Failed to load mandi prices: ${response.statusCode}');
      }
      */
    } catch (e) {
      print('Error fetching mandi prices: $e');
      return _getMockPrices(commodity, state: state, district: district);
    }
  }

  /// Get prices for multiple commodities
  static Future<Map<String, List<MandiPrice>>> getPricesForCommodities(
    List<String> commodities, {
    String? state,
  }) async {
    final result = <String, List<MandiPrice>>{};

    for (final commodity in commodities) {
      result[commodity] = await getPricesForCommodity(commodity, state: state);
    }

    return result;
  }

  /// Get nearby market prices based on user location
  static Future<List<MandiPrice>> getNearbyMarketPrices(
    String commodity,
    double latitude,
    double longitude, {
    int radiusKm = 100,
  }) async {
    // In production, filter by distance
    // For now, return mock data
    return _getMockPrices(commodity);
  }

  /// Get price trend for a commodity (last 30 days)
  static Future<List<Map<String, dynamic>>> getPriceTrend(
    String commodity,
    String market,
  ) async {
    // Mock trend data
    final now = DateTime.now();
    final trend = <Map<String, dynamic>>[];

    for (int i = 30; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final basePrice = _getBasePriceForCommodity(commodity);
      final variation = (i % 7) * 50.0; // Simulate weekly variation

      trend.add({
        'date': date.toIso8601String(),
        'price': basePrice + variation,
      });
    }

    return trend;
  }

  /// Get best markets for selling a commodity
  static Future<List<MandiPrice>> getBestMarketsForSelling(
    String commodity, {
    String? preferredState,
  }) async {
    final prices = await getPricesForCommodity(
      commodity,
      state: preferredState,
      limit: 20,
    );

    // Sort by modal price (highest first)
    prices.sort((a, b) => b.modalPrice.compareTo(a.modalPrice));
    return prices.take(5).toList();
  }

  static List<MandiPrice> _getMockPrices(
    String commodity, {
    String? state,
    String? district,
  }) {
    final mockData = <MandiPrice>[];
    final now = DateTime.now();
    final basePrice = _getBasePriceForCommodity(commodity);

    final markets = [
      {'state': 'Maharashtra', 'district': 'Pune', 'market': 'Pune APMC'},
      {'state': 'Maharashtra', 'district': 'Nashik', 'market': 'Nashik APMC'},
      {'state': 'Punjab', 'district': 'Ludhiana', 'market': 'Ludhiana Mandi'},
      {'state': 'Uttar Pradesh', 'district': 'Agra', 'market': 'Agra Mandi'},
      {'state': 'Haryana', 'district': 'Karnal', 'market': 'Karnal Mandi'},
      {'state': 'Rajasthan', 'district': 'Jaipur', 'market': 'Jaipur Mandi'},
      {
        'state': 'Madhya Pradesh',
        'district': 'Indore',
        'market': 'Indore APMC',
      },
    ];

    for (final market in markets) {
      if (state != null && market['state'] != state) continue;
      if (district != null && market['district'] != district) continue;

      final variation = (markets.indexOf(market) * 100.0);
      mockData.add(
        MandiPrice(
          commodity: commodity,
          commodityHindi: _getCommodityHindi(commodity),
          state: market['state']!,
          district: market['district']!,
          market: market['market']!,
          minPrice: basePrice - 200 + variation,
          maxPrice: basePrice + 300 + variation,
          modalPrice: basePrice + variation,
          priceUnit: 'Rs/Quintal',
          arrivalDate: now.subtract(Duration(hours: markets.indexOf(market))),
          variety: 'Local',
        ),
      );
    }

    return mockData;
  }

  static double _getBasePriceForCommodity(String commodity) {
    final prices = {
      'Wheat': 2500.0,
      'Rice': 3200.0,
      'Sugarcane': 350.0,
      'Cotton': 6500.0,
      'Corn': 1800.0,
      'Soybean': 4500.0,
      'Potato': 1200.0,
      'Onion': 2000.0,
      'Tomato': 1500.0,
    };
    return prices[commodity] ?? 2000.0;
  }

  static String _getCommodityHindi(String commodity) {
    final names = {
      'Wheat': 'गेहूं',
      'Rice': 'चावल',
      'Sugarcane': 'गन्ना',
      'Cotton': 'कपास',
      'Corn': 'मक्का',
      'Soybean': 'सोयाबीन',
      'Potato': 'आलू',
      'Onion': 'प्याज',
      'Tomato': 'टमाटर',
    };
    return names[commodity] ?? commodity;
  }

  /// Popular commodities for quick access
  static List<String> getPopularCommodities() {
    return [
      'Wheat',
      'Rice',
      'Cotton',
      'Sugarcane',
      'Corn',
      'Soybean',
      'Potato',
      'Onion',
      'Tomato',
    ];
  }
}
