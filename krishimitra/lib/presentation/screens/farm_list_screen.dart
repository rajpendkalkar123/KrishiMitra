import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:krishimitra/domain/models/farm_models.dart';
import 'package:krishimitra/services/farm_database_service.dart';
import 'package:krishimitra/utils/app_theme.dart';
import 'package:krishimitra/utils/app_strings.dart';
import 'package:krishimitra/presentation/screens/farm_sector_map_screen.dart';
class FarmListScreen extends ConsumerStatefulWidget {
  const FarmListScreen({super.key});

  @override
  ConsumerState<FarmListScreen> createState() => _FarmListScreenState();
}

class _FarmListScreenState extends ConsumerState<FarmListScreen> {
  List<Farm> _farms = [];
  bool _isLoading = true;
  String _searchQuery = '';

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
        _farms = farms;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading farms: $e')),
        );
      }
    }
  }

  Future<void> _deleteFarm(Farm farm) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.isHindi ? 'खेत हटाएं' : 'Delete Farm'),
        content: Text(
          AppStrings.isHindi
              ? 'क्या आप वाकई इस खेत को हटाना चाहते हैं? यह पूर्ववत नहीं किया जा सकता।'
              : 'Are you sure you want to delete this farm? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.isHindi ? 'रद्द करें' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(AppStrings.isHindi ? 'हटाएं' : 'Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FarmDatabaseService.deleteFarm(farm.id);
      _loadFarms();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppStrings.isHindi
                  ? 'खेत सफलतापूर्वक हटाया गया'
                  : 'Farm deleted successfully',
            ),
          ),
        );
      }
    }
  }

  List<Farm> get _filteredFarms {
    if (_searchQuery.isEmpty) return _farms;
    return _farms.where((farm) {
      return farm.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppStrings.isHindi ? 'मेरे खेत' : 'My Farms',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFarms,
            tooltip: AppStrings.isHindi ? 'रीफ्रेश करें' : 'Refresh',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: AppStrings.isHindi ? 'खेत खोजें...' : 'Search farms...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredFarms.isEmpty
              ? _buildEmptyState()
              : _buildFarmGrid(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const FarmSectorMapScreen(),
            ),
          ).then((_) => _loadFarms());
        },
        icon: const Icon(Icons.add_location_alt),
        label: Text(AppStrings.isHindi ? 'नया खेत जोड़ें' : 'Add New Farm'),
        backgroundColor: AppTheme.primaryGreen,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.agriculture_outlined,
            size: 100,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          Text(
            AppStrings.isHindi ? 'अभी तक कोई खेत नहीं' : 'No Farms Yet',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            AppStrings.isHindi
                ? 'अपना पहला खेत जोड़ने के लिए नीचे दिए गए बटन पर टैप करें'
                : 'Tap the button below to add your first farm',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFarmGrid() {
    return RefreshIndicator(
      onRefresh: _loadFarms,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.85,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _filteredFarms.length,
        itemBuilder: (context, index) {
          final farm = _filteredFarms[index];
          return _buildFarmCard(farm);
        },
      ),
    );
  }

  Widget _buildFarmCard(Farm farm) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FarmSectorMapScreen(existingFarm: farm),
            ),
          ).then((_) => _loadFarms());
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryGreen, AppTheme.primaryGreen.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Stack(
                children: [
                  const Center(
                    child: Icon(Icons.landscape, size: 50, color: Colors.white70),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: PopupMenuButton(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          child: ListTile(
                            leading: const Icon(Icons.delete, color: Colors.red),
                            title: Text(AppStrings.isHindi ? 'हटाएं' : 'Delete'),
                            contentPadding: EdgeInsets.zero,
                          ),
                          onTap: () => Future.delayed(
                            Duration.zero,
                            () => _deleteFarm(farm),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      farm.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.straighten, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${farm.area.toStringAsFixed(2)} ${AppStrings.isHindi ? 'एकड़' : 'acres'}',
                          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.grid_on, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${farm.sectors.length} ${AppStrings.isHindi ? 'सेक्टर' : 'sectors'}',
                          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      DateFormat('dd MMM yyyy').format(farm.createdAt),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
