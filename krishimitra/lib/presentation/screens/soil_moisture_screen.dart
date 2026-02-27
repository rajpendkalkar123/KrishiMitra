import 'package:flutter/material.dart';
import 'dart:async';
import 'package:krishimitra/services/soil_moisture_service.dart';
import 'package:krishimitra/services/farm_database_service.dart';
import 'package:krishimitra/domain/models/farm_models.dart';
import 'package:krishimitra/utils/app_theme.dart';
import 'package:krishimitra/utils/app_strings.dart';
import 'package:krishimitra/utils/set_default_sensor_ip.dart';
import 'package:krishimitra/presentation/widgets/configure_sensor_dialog.dart';

class SoilMoistureScreen extends StatefulWidget {
  const SoilMoistureScreen({super.key});

  @override
  State<SoilMoistureScreen> createState() => _SoilMoistureScreenState();
}

class _SoilMoistureScreenState extends State<SoilMoistureScreen> {
  SoilMoistureData? _moistureData;
  SensorHealthData? _healthData;
  SensorInfo? _sensorInfo;

  bool _isLoading = false;
  bool _isConnected = false;
  bool _autoRefresh = false;
  String? _errorMessage;

  Timer? _refreshTimer;

  List<Sector> _sectors = [];
  Sector? _selectedSector;
  bool _loadingSectors = true;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    // Set default IP for any sectors that don't have one
    await setDefaultSensorIPForAllSectors();
    // Load sectors
    await _loadSectors();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSectors() async {
    setState(() {
      _loadingSectors = true;
    });

    try {
      final sectors = await FarmDatabaseService.getAllSectors();
      setState(() {
        _sectors = sectors;
        _loadingSectors = false;
        // Auto-select first sector if available
        if (sectors.isNotEmpty) {
          _selectedSector = sectors.first;
          _testConnection();
        }
      });
    } catch (e) {
      setState(() {
        _loadingSectors = false;
        _errorMessage = 'Failed to load sectors: $e';
      });
    }
  }

  Future<void> _testConnection() async {
    if (_selectedSector?.sensorIP == null ||
        _selectedSector!.sensorIP!.isEmpty) {
      setState(() {
        _errorMessage = 'No sensor IP configured for this sector';
        _isConnected = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _moistureData = null;
      _healthData = null;
    });

    try {
      final ip = _selectedSector!.sensorIP!;

      if (!SoilMoistureSensorService.isValidIP(ip)) {
        throw Exception('Invalid IP address format');
      }

      // Test connection and fetch data in parallel for instant display
      final results = await Future.wait([
        SoilMoistureSensorService.testConnection(ip),
        SoilMoistureSensorService.getMoistureData(ip),
        SoilMoistureSensorService.getHealthStatus(ip),
      ]);

      final isConnected = results[0] as bool;
      final moisture = results[1] as SoilMoistureData;
      final health = results[2] as SensorHealthData;

      if (isConnected) {
        setState(() {
          _isConnected = true;
          _moistureData = moisture;
          _healthData = health;
          _isLoading = false;
        });

        // Auto-enable refresh for continuous monitoring
        if (!_autoRefresh) {
          _startAutoRefresh();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppStrings.isHindi
                    ? '✅ सेंसर से जुड़ा हुआ - लाइव डेटा'
                    : '✅ Connected - Live Data',
              ),
              backgroundColor: AppTheme.primaryGreen,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception('Cannot reach sensor at $ip');
      }
    } catch (e) {
      setState(() {
        _isConnected = false;
        _errorMessage = e.toString();
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _fetchAllData() async {
    if (_selectedSector?.sensorIP == null) return;

    final ip = _selectedSector!.sensorIP!;

    try {
      final moisture = await SoilMoistureSensorService.getMoistureData(ip);
      final health = await SoilMoistureSensorService.getHealthStatus(ip);

      setState(() {
        _moistureData = moisture;
        _healthData = health;
      });
    } catch (e) {
      print('Error fetching data: $e');
    }
  }

  Future<void> _fetchSensorInfo() async {
    if (_selectedSector?.sensorIP == null) return;

    final ip = _selectedSector!.sensorIP!;

    try {
      final info = await SoilMoistureSensorService.getSensorInfo(ip);
      setState(() {
        _sensorInfo = info;
      });
    } catch (e) {
      print('Error fetching sensor info: $e');
    }
  }

  void _startAutoRefresh() {
    setState(() {
      _autoRefresh = true;
    });

    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_isConnected) {
        _fetchAllData();
      }
    });
  }

  void _toggleAutoRefresh() {
    setState(() {
      _autoRefresh = !_autoRefresh;
    });

    if (_autoRefresh) {
      _refreshTimer?.cancel();
      _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        if (_isConnected) {
          _fetchAllData();
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.isHindi
                ? '🔄 ऑटो-रिफ्रेश सक्षम (हर 3 सेकंड)'
                : '🔄 Auto-refresh enabled (every 3 seconds)',
          ),
          backgroundColor: AppTheme.primaryGreen,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      _refreshTimer?.cancel();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.isHindi
                ? '⏸️ ऑटो-रिफ्रेश अक्षम'
                : '⏸️ Auto-refresh disabled',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppStrings.isHindi
              ? '💧 मिट्टी की नमी सेंसर'
              : '💧 Soil Moisture Sensor',
        ),
        backgroundColor: AppTheme.primaryGreen,
        actions: [
          if (_selectedSector != null)
            IconButton(
              onPressed: _configureSensorIP,
              icon: const Icon(Icons.settings_ethernet),
              tooltip: 'Configure Sensor IP',
            ),
          if (_isConnected)
            IconButton(
              onPressed: _toggleAutoRefresh,
              icon: Icon(_autoRefresh ? Icons.pause : Icons.refresh),
              tooltip:
                  _autoRefresh ? 'Pause auto-refresh' : 'Enable auto-refresh',
            ),
          if (_isConnected)
            IconButton(
              onPressed: () => _showSensorInfoDialog(),
              icon: const Icon(Icons.info_outline),
              tooltip: 'Sensor info',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Future<void> _configureSensorIP() async {
    if (_selectedSector == null) return;

    final result = await showConfigureSensorDialog(context, _selectedSector!);

    if (result == true) {
      // Reload sectors to get updated IP
      await _loadSectors();
      // Find the updated sector
      final updatedSector = _sectors.firstWhere(
        (s) => s.id == _selectedSector!.id,
        orElse: () => _selectedSector!,
      );
      setState(() {
        _selectedSector = updatedSector;
        _isConnected = false;
        _moistureData = null;
        _healthData = null;
      });
      // Test new connection
      await _testConnection();
    }
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Connection Card
          _buildConnectionCard(),

          // Error Message
          if (_errorMessage != null) _buildErrorCard(),

          // Loading Indicator
          if (_isLoading) _buildLoadingIndicator(),

          // Moisture Data Card
          if (_moistureData != null && _isConnected) _buildMoistureCard(),

          // Health Status Card
          if (_healthData != null && _isConnected) _buildHealthCard(),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildConnectionCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryGreen,
            AppTheme.primaryGreen.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            _isConnected ? Icons.sensors : Icons.sensor_occupied,
            size: 48,
            color: Colors.white,
          ),
          const SizedBox(height: 16),
          Text(
            AppStrings.isHindi
                ? 'ESP8266 सेंसर कनेक्शन'
                : 'ESP8266 Sensor Connection',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // Sector Selection Dropdown
          if (_loadingSectors)
            const CircularProgressIndicator(color: Colors.white)
          else if (_sectors.isEmpty)
            Text(
              AppStrings.isHindi ? 'कोई सेक्टर नहीं मिला' : 'No sectors found',
              style: const TextStyle(color: Colors.white70),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Sector>(
                  value: _selectedSector,
                  isExpanded: true,
                  dropdownColor: AppTheme.primaryGreen.withOpacity(0.95),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                  hint: Text(
                    AppStrings.isHindi ? 'सेक्टर चुनें' : 'Select Sector',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  items:
                      _sectors.map((sector) {
                        return DropdownMenuItem<Sector>(
                          value: sector,
                          child: Row(
                            children: [
                              const Icon(
                                Icons.agriculture,
                                color: Colors.white70,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  sector.name,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              if (sector.sensorIP != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    '🌐',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                  onChanged: (Sector? newValue) {
                    setState(() {
                      _selectedSector = newValue;
                      _isConnected = false;
                      _moistureData = null;
                      _healthData = null;
                      _sensorInfo = null;
                      _refreshTimer?.cancel();
                      _autoRefresh = false;
                    });
                    if (newValue != null) {
                      _testConnection();
                    }
                  },
                ),
              ),
            ),

          if (_selectedSector?.sensorIP != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'IP: ${_selectedSector!.sensorIP}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _testConnection,
              icon: Icon(_isConnected ? Icons.refresh : Icons.link),
              label: Text(
                _isConnected
                    ? (AppStrings.isHindi ? 'दोबारा जोड़ें' : 'Reconnect')
                    : (AppStrings.isHindi ? 'जुड़ें' : 'Connect'),
                style: const TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primaryGreen,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (_isConnected)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    AppStrings.isHindi ? 'जुड़ा हुआ' : 'Connected',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  color: AppTheme.primaryGreen,
                  strokeWidth: 6,
                ),
              ),
              Icon(
                Icons.sensors,
                size: 40,
                color: AppTheme.primaryGreen.withOpacity(0.7),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            AppStrings.isHindi
                ? 'सेंसर से जुड़ रहा है...'
                : 'Connecting to sensor...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.isHindi ? 'डेटा लोड हो रहा है' : 'Loading moisture data',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildMoistureCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.lightGreen,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.water_drop, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppStrings.isHindi ? 'मिट्टी की नमी' : 'Soil Moisture',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Live indicator
                if (_autoRefresh)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          AppStrings.isHindi ? 'लाइव' : 'LIVE',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  '${_moistureData!.moisturePercent}%',
                  style: TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _moistureData!.statusEmoji,
                      style: const TextStyle(fontSize: 32),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _moistureData!.status,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _moistureData!.recommendation,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Divider(color: Colors.grey.shade300),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          AppStrings.isHindi ? 'कच्चा मान' : 'Raw Value',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_moistureData!.rawValue}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          AppStrings.isHindi ? 'सेंसर' : 'Sensor',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _moistureData!.sensor,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _healthData!.isHealthy ? Icons.check_circle : Icons.error,
                color: _healthData!.isHealthy ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 12),
              Text(
                AppStrings.isHindi ? 'सेंसर स्थिति' : 'Sensor Status',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            'Status',
            _healthData!.status.toUpperCase(),
            Icons.info,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            'Uptime',
            _healthData!.uptimeFormatted,
            Icons.access_time,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            'WiFi Signal',
            '${_healthData!.wifiQuality} (${_healthData!.wifiStrength} dBm)',
            Icons.wifi,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showSensorInfoDialog() async {
    if (_sensorInfo == null) {
      await _fetchSensorInfo();
    }

    if (!mounted || _sensorInfo == null) return;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.info, color: AppTheme.primaryGreen),
                const SizedBox(width: 12),
                const Text('Sensor Information'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDialogInfoRow('Device', _sensorInfo!.device),
                _buildDialogInfoRow('Sensor', _sensorInfo!.sensor),
                _buildDialogInfoRow('Firmware', _sensorInfo!.firmware),
                _buildDialogInfoRow('IP Address', _sensorInfo!.ip),
                _buildDialogInfoRow('MAC Address', _sensorInfo!.mac),
                _buildDialogInfoRow('RSSI', '${_sensorInfo!.rssi} dBm'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  Widget _buildDialogInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}
