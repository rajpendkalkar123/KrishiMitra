import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:krishimitra/domain/models/farm_models.dart';
import 'package:krishimitra/services/farm_database_service.dart';
import 'package:krishimitra/utils/app_theme.dart';
import 'package:krishimitra/presentation/widgets/configure_sensor_dialog.dart';

class FarmSectorMapScreen extends ConsumerStatefulWidget {
  final Farm? existingFarm;

  const FarmSectorMapScreen({super.key, this.existingFarm});

  @override
  ConsumerState<FarmSectorMapScreen> createState() =>
      _FarmSectorMapScreenState();
}

class _FarmSectorMapScreenState extends ConsumerState<FarmSectorMapScreen> {
  final MapController _mapController = MapController();
  final List<LatLng> _farmBoundaryPoints = [];
  final List<Sector> _sectors = [];
  final List<LatLng> _currentSectorPoints = [];

  bool _isDrawingFarmBoundary = false;
  bool _isDrawingSector = false;
  LatLng _centerPosition = LatLng(20.5937, 78.9629);

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    if (widget.existingFarm != null) {
      _loadExistingFarm();
    }
  }

  void _loadExistingFarm() {
    final farm = widget.existingFarm!;
    setState(() {
      _farmBoundaryPoints.addAll(farm.boundary);
      _sectors.addAll(farm.sectors);
      if (farm.boundary.isNotEmpty) {
        _centerPosition = farm.boundary.first;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_farmBoundaryPoints.isNotEmpty) {
        _mapController.move(_centerPosition, 15.0);
      }
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMessage('Location services are disabled. Using default location.');
        setState(() {
          _centerPosition = LatLng(20.5937, 78.9629);
        });
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showMessage('Location permission denied. Using default location.');
          setState(() {
            _centerPosition = LatLng(20.5937, 78.9629);
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showMessage('Location permission permanently denied.');
        setState(() {
          _centerPosition = LatLng(20.5937, 78.9629);
        });
        return;
      }
      _showMessage('Getting your location...');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _centerPosition = LatLng(position.latitude, position.longitude);
      });
      _mapController.move(_centerPosition, 17.0);
      _showMessage('Location found! You can start mapping.');
    } catch (e) {
      print('Error getting location: $e');
      _showMessage('Error getting location: $e');
      setState(() {
        _centerPosition = LatLng(20.5937, 78.9629);
      });
    }
  }

  void _startDrawingFarmBoundary() {
    setState(() {
      _farmBoundaryPoints.clear();
      _isDrawingFarmBoundary = true;
      _isDrawingSector = false;
    });
  }

  void _finishDrawingFarmBoundary() {
    if (_farmBoundaryPoints.length < 3) {
      _showMessage('Need at least 3 points to create a boundary');
      return;
    }
    setState(() {
      _isDrawingFarmBoundary = false;
    });
    _showMessage('Farm boundary created! Now create sectors.');
  }

  void _startDrawingSector() {
    if (_farmBoundaryPoints.isEmpty) {
      _showMessage('Please draw farm boundary first');
      return;
    }
    setState(() {
      _currentSectorPoints.clear();
      _isDrawingSector = true;
      _isDrawingFarmBoundary = false;
    });
  }

  void _finishDrawingSector() {
    if (_currentSectorPoints.length < 3) {
      _showMessage('Need at least 3 points to create a sector');
      return;
    }
    _showSectorDetailsDialog();
  }

  void _showSectorDetailsDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController cropController = TextEditingController();
    final TextEditingController ipController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Sector Details'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Sector Name',
                      hintText: 'e.g., Sector 1, North Field',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: cropController,
                    decoration: const InputDecoration(
                      labelText: 'Crop Type',
                      hintText: 'e.g., Sugarcane, Cotton, Wheat',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: ipController,
                    decoration: InputDecoration(
                      labelText: 'Soil Sensor IP (optional)',
                      hintText: '192.168.x.x',
                      prefixIcon: const Icon(Icons.sensors, size: 20),
                      helperText: 'ESP8266 sensor IP address',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _currentSectorPoints.clear();
                    _isDrawingSector = false;
                  });
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.isEmpty ||
                      cropController.text.isEmpty) {
                    return;
                  }
                  final area = _calculatePolygonArea(_currentSectorPoints);
                  final ip = ipController.text.trim();
                  final sector = Sector(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    farmId: 'farm_1', // TODO: Use actual farm ID
                    name: nameController.text,
                    boundary: List.from(_currentSectorPoints),
                    area: area,
                    cropType: cropController.text,
                    sensorIP: ip.isEmpty ? null : ip,
                  );

                  setState(() {
                    _sectors.add(sector);
                    _currentSectorPoints.clear();
                    _isDrawingSector = false;
                  });

                  Navigator.pop(context);
                  _showMessage('Sector "${sector.name}" created!');
                },
                child: const Text('Create'),
              ),
            ],
          ),
    );
  }

  void _editSectorSensorIP(int index) {
    final sector = _sectors[index];
    final ipController = TextEditingController(text: sector.sensorIP ?? '');

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.sensors, color: AppTheme.primaryGreen),
                const SizedBox(width: 8),
                const Text('Soil Sensor IP'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sector: ${sector.name}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ipController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'ESP8266 IP Address',
                    hintText: '192.168.x.x',
                    prefixIcon: const Icon(Icons.wifi),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 6),
                Text(
                  'Leave empty to remove sensor link.',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final ip = ipController.text.trim();
                  setState(() {
                    _sectors[index] = sector.copyWith(
                      sensorIP: ip.isEmpty ? null : ip,
                    );
                  });
                  Navigator.pop(context);
                  _showMessage(
                    ip.isEmpty
                        ? 'Sensor IP removed from "${sector.name}"'
                        : 'Sensor IP set for "${sector.name}"',
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    if (_isDrawingFarmBoundary) {
      setState(() {
        _farmBoundaryPoints.add(point);
      });
    } else if (_isDrawingSector) {
      if (_isPointInPolygon(point, _farmBoundaryPoints)) {
        setState(() {
          _currentSectorPoints.add(point);
        });
      } else {
        _showMessage('Point must be inside farm boundary');
      }
    }
  }

  void _deleteSector(String sectorId) {
    setState(() {
      _sectors.removeWhere((s) => s.id == sectorId);
    });
    _showMessage('Sector deleted');
  }

  void _clearAll() {
    setState(() {
      _farmBoundaryPoints.clear();
      _sectors.clear();
      _currentSectorPoints.clear();
      _isDrawingFarmBoundary = false;
      _isDrawingSector = false;
    });
    _showMessage('All cleared');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  double _calculatePolygonArea(List<LatLng> points) {
    if (points.length < 3) return 0;

    double area = 0;
    for (int i = 0; i < points.length; i++) {
      int j = (i + 1) % points.length;
      area += points[i].latitude * points[j].longitude;
      area -= points[j].latitude * points[i].longitude;
    }
    area = area.abs() / 2.0;
    final areaInMeters = area * 111000 * 111000;
    final areaInAcres = areaInMeters / 4047;

    return areaInAcres;
  }

  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) return false;

    bool inside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      if (((polygon[i].latitude > point.latitude) !=
              (polygon[j].latitude > point.latitude)) &&
          (point.longitude <
              (polygon[j].longitude - polygon[i].longitude) *
                      (point.latitude - polygon[i].latitude) /
                      (polygon[j].latitude - polygon[i].latitude) +
                  polygon[i].longitude)) {
        inside = !inside;
      }
    }
    return inside;
  }

  Color _getSectorColor(int index) {
    final colors = [
      Colors.green.withOpacity(0.4),
      Colors.blue.withOpacity(0.4),
      Colors.orange.withOpacity(0.4),
      Colors.purple.withOpacity(0.4),
      Colors.red.withOpacity(0.4),
      Colors.teal.withOpacity(0.4),
    ];
    return colors[index % colors.length];
  }

  Future<void> _saveFarm() async {
    if (_farmBoundaryPoints.isEmpty) {
      _showMessage('No farm boundary to save');
      return;
    }

    if (_sectors.isEmpty) {
      _showMessage('No sectors to save');
      return;
    }

    try {
      final farmName = await _showFarmNameDialog();
      if (farmName == null || farmName.isEmpty) {
        _showMessage('Farm name is required');
        return;
      }

      // Preserve the existing ID when editing so we overwrite rather than
      // create a duplicate entry in Hive.
      final farmId =
          widget.existingFarm?.id ??
          DateTime.now().millisecondsSinceEpoch.toString();

      // Delete old record first so stale sectors are cleaned up.
      if (widget.existingFarm != null) {
        await FarmDatabaseService.deleteFarm(widget.existingFarm!.id);
      }

      final totalArea = _calculatePolygonArea(_farmBoundaryPoints);

      // Patch every sector's farmId to match the real farm ID so that
      // getSectorsByFarmId() can find them later.
      final updatedSectors =
          _sectors.map((s) => s.copyWith(farmId: farmId)).toList();

      final farm = Farm(
        id: farmId,
        name: farmName,
        farmerId: 'default_user',
        boundary: _farmBoundaryPoints,
        area: totalArea,
        sectors: updatedSectors,
        createdAt: DateTime.now(),
      );
      await FarmDatabaseService.saveFarm(farm);

      _showMessage(
        'Farm "$farmName" saved successfully with ${_sectors.length} sectors!',
      );
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      _showMessage('Error saving farm: $e');
      print('Error saving farm: $e');
    }
  }

  Future<String?> _showFarmNameDialog() async {
    final TextEditingController nameController = TextEditingController();

    return showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Save Farm'),
            content: TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Farm Name',
                hintText: 'Enter farm name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, nameController.text);
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🗺️ Farm Sector Mapping'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
            tooltip: 'Center on my location',
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _clearAll,
            tooltip: 'Clear all',
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: _centerPosition,
              zoom: 15.0,
              onTap: _onMapTap,
              interactiveFlags: InteractiveFlag.all,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'krishimitra.agritech',
              ),
              if (_farmBoundaryPoints.isNotEmpty)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: _farmBoundaryPoints,
                      color: AppTheme.primaryGreen.withOpacity(0.2),
                      borderColor: AppTheme.primaryGreen,
                      borderStrokeWidth: 3,
                      isFilled: true,
                    ),
                  ],
                ),
              if (_sectors.isNotEmpty)
                PolygonLayer(
                  polygons:
                      _sectors.asMap().entries.map((entry) {
                        final index = entry.key;
                        final sector = entry.value;
                        return Polygon(
                          points: sector.boundary,
                          color: _getSectorColor(index),
                          borderColor: _getSectorColor(index).withOpacity(1),
                          borderStrokeWidth: 2,
                          isFilled: true,
                          label: sector.name,
                          labelStyle: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }).toList(),
                ),
              if (_currentSectorPoints.isNotEmpty)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: _currentSectorPoints,
                      color: Colors.yellow.withOpacity(0.3),
                      borderColor: Colors.yellow,
                      borderStrokeWidth: 2,
                      isDotted: true,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  ..._farmBoundaryPoints.asMap().entries.map((entry) {
                    return Marker(
                      point: entry.value,
                      width: 20,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            '${entry.key + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  ..._currentSectorPoints.asMap().entries.map((entry) {
                    return Marker(
                      point: entry.value,
                      width: 16,
                      height: 16,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.yellow,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 1),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          _isDrawingFarmBoundary
                              ? AppTheme.primaryGreen.withOpacity(0.1)
                              : _isDrawingSector
                              ? Colors.blue.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isDrawingFarmBoundary
                              ? Icons.edit_location
                              : _isDrawingSector
                              ? Icons.grid_on
                              : Icons.info_outline,
                          color:
                              _isDrawingFarmBoundary
                                  ? AppTheme.primaryGreen
                                  : _isDrawingSector
                                  ? Colors.blue
                                  : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _isDrawingFarmBoundary
                                ? 'Tap on map to add boundary points (${_farmBoundaryPoints.length} points)'
                                : _isDrawingSector
                                ? 'Tap inside farm to add sector points (${_currentSectorPoints.length} points)'
                                : _farmBoundaryPoints.isEmpty
                                ? 'Start by drawing farm boundary'
                                : '${_sectors.length} sector(s) created',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              _farmBoundaryPoints.isEmpty &&
                                      !_isDrawingFarmBoundary
                                  ? _startDrawingFarmBoundary
                                  : _isDrawingFarmBoundary
                                  ? _finishDrawingFarmBoundary
                                  : null,
                          icon: Icon(
                            _isDrawingFarmBoundary
                                ? Icons.check
                                : Icons.border_outer,
                          ),
                          label: Text(
                            _farmBoundaryPoints.isEmpty
                                ? 'Draw Farm'
                                : _isDrawingFarmBoundary
                                ? 'Finish'
                                : 'Farm OK',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _isDrawingFarmBoundary
                                    ? AppTheme.successGreen
                                    : AppTheme.primaryGreen,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              !_isDrawingSector &&
                                      _farmBoundaryPoints.isNotEmpty
                                  ? _startDrawingSector
                                  : _isDrawingSector
                                  ? _finishDrawingSector
                                  : null,
                          icon: Icon(
                            _isDrawingSector ? Icons.check : Icons.grid_on,
                          ),
                          label: Text(
                            _isDrawingSector ? 'Finish Sector' : 'Add Sector',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_sectors.isNotEmpty)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                width: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.grid_on, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Sectors',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _sectors.length,
                        itemBuilder: (context, index) {
                          final sector = _sectors[index];
                          return ListTile(
                            dense: true,
                            leading: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: _getSectorColor(index),
                                border: Border.all(color: Colors.black),
                              ),
                            ),
                            title: Text(
                              sector.name,
                              style: const TextStyle(fontSize: 12),
                            ),
                            subtitle: Text(
                              '${sector.cropType}\n${sector.area.toStringAsFixed(2)} acres',
                              style: const TextStyle(fontSize: 10),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Tooltip(
                                  message:
                                      sector.sensorIP != null
                                          ? 'Sensor: ${sector.sensorIP}'
                                          : 'Set sensor IP',
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.sensors,
                                      size: 18,
                                      color:
                                          sector.sensorIP != null
                                              ? AppTheme.primaryGreen
                                              : Colors.grey,
                                    ),
                                    onPressed: () => _editSectorSensorIP(index),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 18),
                                  onPressed: () => _deleteSector(sector.id),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton:
          _sectors.isNotEmpty
              ? FloatingActionButton.extended(
                onPressed: () => _saveFarm(),
                icon: const Icon(Icons.save),
                label: const Text('Save Farm'),
                backgroundColor: AppTheme.successGreen,
              )
              : null,
    );
  }
}
