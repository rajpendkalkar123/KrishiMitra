import 'package:flutter/material.dart';
import 'package:krishimitra/domain/models/farm_models.dart';
import 'package:krishimitra/services/farm_database_service.dart';
import 'package:krishimitra/utils/app_theme.dart';

/// Dialog to configure sensor IP for a sector
class ConfigureSensorDialog extends StatefulWidget {
  final Sector sector;

  const ConfigureSensorDialog({super.key, required this.sector});

  @override
  State<ConfigureSensorDialog> createState() => _ConfigureSensorDialogState();
}

class _ConfigureSensorDialogState extends State<ConfigureSensorDialog> {
  late TextEditingController _ipController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController(
      text: widget.sector.sensorIP ?? '192.168.1.1',
    );
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _saveSensorIP() async {
    final ip = _ipController.text.trim();

    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an IP address'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final updatedSector = widget.sector.copyWith(sensorIP: ip);
      await FarmDatabaseService.updateSector(updatedSector);

      if (mounted) {
        Navigator.of(context).pop(true); // Return true on success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Sensor IP updated for ${widget.sector.name}'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.settings_ethernet, color: AppTheme.primaryGreen),
          const SizedBox(width: 8),
          const Text('Configure Sensor'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sector: ${widget.sector.name}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ipController,
            decoration: InputDecoration(
              labelText: 'ESP8266 IP Address',
              hintText: '192.168.x.x',
              prefixIcon: const Icon(Icons.wifi),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the IP address of the soil moisture sensor for this sector.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveSensorIP,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryGreen,
            foregroundColor: Colors.white,
          ),
          child:
              _isSaving
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : const Text('Save'),
        ),
      ],
    );
  }
}

/// Helper function to show the configure sensor dialog
Future<bool?> showConfigureSensorDialog(BuildContext context, Sector sector) {
  return showDialog<bool>(
    context: context,
    builder: (context) => ConfigureSensorDialog(sector: sector),
  );
}
