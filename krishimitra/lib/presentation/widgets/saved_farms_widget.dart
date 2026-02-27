import 'package:flutter/material.dart';
import 'package:krishimitra/domain/models/farm_models.dart';
import 'package:krishimitra/services/farm_database_service.dart';
import 'package:krishimitra/presentation/screens/farm_sector_map_screen.dart';
import 'package:krishimitra/presentation/screens/farm_list_screen.dart';
import 'package:krishimitra/utils/app_strings.dart';
import 'package:krishimitra/utils/app_theme.dart';
class SavedFarmsWidget extends StatefulWidget {
  const SavedFarmsWidget({super.key});

  @override
  State<SavedFarmsWidget> createState() => _SavedFarmsWidgetState();
}

class _SavedFarmsWidgetState extends State<SavedFarmsWidget> {
  List<Farm> _farms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFarms();
  }

  Future<void> _loadFarms() async {
    setState(() => _isLoading = true);
    try {
      final farms = await FarmDatabaseService.getAllFarms();
      setState(() {
        _farms = farms.take(3).toList(); // Show only first 3
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        margin: EdgeInsets.all(16),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_farms.isEmpty) {
      return Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                Icons.agriculture_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 12),
              Text(
                AppStrings.isHindi ? 'कोई खेत नहीं मिला' : 'No Farms Found',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.isHindi
                    ? 'अपना पहला खेत बनाने के लिए मैप पर जाएं'
                    : 'Go to Map to create your first farm',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FarmSectorMapScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.add_location_alt),
                label: Text(AppStrings.isHindi ? 'खेत जोड़ें' : 'Add Farm'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.landscape,
                      color: AppTheme.primaryGreen,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      AppStrings.isHindi ? 'मेरे खेत' : 'My Farms',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FarmListScreen(),
                      ),
                    );
                  },
                  child: Text(
                    AppStrings.isHindi ? 'सभी देखें' : 'View All',
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _farms.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final farm = _farms[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.agriculture,
                    color: AppTheme.primaryGreen,
                    size: 28,
                  ),
                ),
                title: Text(
                  farm.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      '${farm.area.toStringAsFixed(2)} ${AppStrings.isHindi ? 'एकड़' : 'acres'} • ${farm.sectors.length} ${AppStrings.isHindi ? 'सेक्टर' : 'sectors'}',
                    ),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          FarmSectorMapScreen(existingFarm: farm),
                    ),
                  ).then((_) => _loadFarms());
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
