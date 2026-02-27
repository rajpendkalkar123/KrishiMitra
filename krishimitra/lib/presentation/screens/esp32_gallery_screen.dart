import 'dart:io';
import 'package:flutter/material.dart';
import 'package:krishimitra/services/esp32_camera_service.dart';
import 'package:krishimitra/utils/app_strings.dart';
import 'package:krishimitra/utils/app_theme.dart';

/// Full-screen gallery for ESP32 captured images.
/// Persists images on device until explicitly deleted by the user.
/// Supports single-delete, multi-select batch-delete, and full-screen preview.
class ESP32GalleryScreen extends StatefulWidget {
  /// If true, tapping an image returns it to the caller (for analyze flow).
  final bool pickMode;

  const ESP32GalleryScreen({super.key, this.pickMode = false});

  @override
  State<ESP32GalleryScreen> createState() => _ESP32GalleryScreenState();
}

class _ESP32GalleryScreenState extends State<ESP32GalleryScreen> {
  List<Map<String, dynamic>> _images = [];
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    setState(() => _loading = true);
    final imgs = await ESP32CameraService.getAllImages();
    if (mounted) {
      setState(() {
        _images = imgs;
        _loading = false;
        // Clear selection for images that no longer exist
        _selectedIds.removeWhere((id) => !imgs.any((img) => img['id'] == id));
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      });
    }
  }

  // ── Single Delete ──────────────────────────────────────────────────────────
  Future<void> _deleteSingle(String imageId) async {
    final confirm = await _showConfirmDialog(
      title: AppStrings.isHindi ? 'छवि हटाएं?' : 'Delete Image?',
      message:
          AppStrings.isHindi
              ? 'क्या आप इस छवि को स्थायी रूप से हटाना चाहते हैं?'
              : 'Permanently delete this image?',
    );
    if (confirm != true) return;

    await ESP32CameraService.deleteImage(imageId);
    _selectedIds.remove(imageId);
    await _loadImages();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.isHindi ? 'छवि हटा दी गई' : 'Image deleted'),
          backgroundColor: AppTheme.primaryGreen,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ── Batch Delete ───────────────────────────────────────────────────────────
  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final count = _selectedIds.length;
    final confirm = await _showConfirmDialog(
      title:
          AppStrings.isHindi ? '$count छवियां हटाएं?' : 'Delete $count images?',
      message:
          AppStrings.isHindi
              ? 'चयनित छवियां स्थायी रूप से हटा दी जाएंगी।'
              : 'Selected images will be permanently deleted.',
    );
    if (confirm != true) return;

    await ESP32CameraService.deleteMultipleImages(_selectedIds.toList());
    _selectedIds.clear();
    _isSelectionMode = false;
    await _loadImages();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.isHindi
                ? '$count छवियां हटा दी गईं'
                : '$count images deleted',
          ),
          backgroundColor: AppTheme.primaryGreen,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ── Delete All ─────────────────────────────────────────────────────────────
  Future<void> _deleteAll() async {
    final confirm = await _showConfirmDialog(
      title: AppStrings.isHindi ? 'सभी हटाएं?' : 'Delete All?',
      message:
          AppStrings.isHindi
              ? 'सभी ${_images.length} कैप्चर की गई छवियों को स्थायी रूप से हटा दिया जाएगा।'
              : 'All ${_images.length} captured images will be permanently deleted.',
    );
    if (confirm != true) return;

    await ESP32CameraService.deleteAllImages();
    _selectedIds.clear();
    _isSelectionMode = false;
    await _loadImages();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.isHindi ? 'सभी छवियां हटा दी गईं' : 'All images deleted',
          ),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(AppStrings.isHindi ? 'रद्द करें' : 'Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text(
                  AppStrings.isHindi ? 'हटाएं' : 'Delete',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  // ── Selection helpers ──────────────────────────────────────────────────────
  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIds.length == _images.length) {
        _selectedIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedIds
          ..clear()
          ..addAll(_images.map((i) => i['id'] as String));
      }
    });
  }

  void _enterSelectionMode(String firstId) {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.add(firstId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  // ── Full-screen preview ────────────────────────────────────────────────────
  void _openFullScreen(Map<String, dynamic> image) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => _FullScreenImageView(
              image: image,
              onDelete: () async {
                await _deleteSingle(image['id'] as String);
                if (mounted) Navigator.pop(context);
              },
              onAnalyze:
                  widget.pickMode ? () => Navigator.pop(context, image) : null,
            ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitSelectionMode();
      },
      child: Scaffold(
        appBar: _buildAppBar(),
        body:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : _images.isEmpty
                ? _buildEmpty()
                : _buildGrid(),
        bottomNavigationBar: _isSelectionMode ? _buildSelectionBar() : null,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    if (_isSelectionMode) {
      return AppBar(
        backgroundColor: AppTheme.earthBrown,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: _exitSelectionMode,
        ),
        title: Text(
          '${_selectedIds.length} ${AppStrings.isHindi ? 'चयनित' : 'selected'}',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _selectedIds.length == _images.length
                  ? Icons.deselect
                  : Icons.select_all,
              color: Colors.white,
            ),
            tooltip: AppStrings.isHindi ? 'सभी चुनें' : 'Select All',
            onPressed: _selectAll,
          ),
        ],
      );
    }

    return AppBar(
      backgroundColor: AppTheme.primaryGreen,
      title: Text(
        AppStrings.isHindi ? 'ESP32 कैप्चर गैलरी' : 'ESP32 Capture Gallery',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        if (_images.isNotEmpty)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (val) {
              if (val == 'select') {
                setState(() => _isSelectionMode = true);
              } else if (val == 'deleteAll') {
                _deleteAll();
              }
            },
            itemBuilder:
                (_) => [
                  PopupMenuItem(
                    value: 'select',
                    child: Row(
                      children: [
                        const Icon(Icons.check_box_outlined, size: 20),
                        const SizedBox(width: 8),
                        Text(AppStrings.isHindi ? 'चुनें' : 'Select'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'deleteAll',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.delete_forever,
                          size: 20,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppStrings.isHindi ? 'सभी हटाएं' : 'Delete All',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
          ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_camera_back, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            AppStrings.isHindi
                ? 'कोई कैप्चर की गई छवियां नहीं'
                : 'No captured images yet',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.isHindi
                ? 'ESP32 कैमरे से छवियां कैप्चर करें'
                : 'Capture images from the ESP32 camera',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return RefreshIndicator(
      onRefresh: _loadImages,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.72,
        ),
        itemCount: _images.length,
        itemBuilder: (context, index) {
          final image = _images[index];
          final id = image['id'] as String;
          final filePath = image['filePath'] as String;
          final capturedAt = image['capturedAt'] as DateTime;
          final analyzed = image['analyzed'] as bool;
          final isSelected = _selectedIds.contains(id);

          return GestureDetector(
            onTap: () {
              if (_isSelectionMode) {
                _toggleSelection(id);
              } else if (widget.pickMode) {
                Navigator.pop(context, image);
              } else {
                _openFullScreen(image);
              }
            },
            onLongPress: () {
              if (!_isSelectionMode) {
                _enterSelectionMode(id);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color:
                      isSelected
                          ? AppTheme.alertRed
                          : analyzed
                          ? AppTheme.primaryGreen
                          : Colors.grey.shade300,
                  width: isSelected ? 3 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isSelected ? AppTheme.alertRed : Colors.black)
                        .withOpacity(isSelected ? 0.18 : 0.08),
                    blurRadius: isSelected ? 8 : 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // ── Image + Info ──
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          child:
                              File(filePath).existsSync()
                                  ? Image.file(
                                    File(filePath),
                                    fit: BoxFit.cover,
                                  )
                                  : Container(
                                    color: Colors.grey.shade200,
                                    child: const Icon(
                                      Icons.image_not_supported,
                                      color: Colors.grey,
                                      size: 40,
                                    ),
                                  ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Status + Time row
                            Row(
                              children: [
                                Icon(
                                  analyzed
                                      ? Icons.check_circle
                                      : Icons.circle_outlined,
                                  size: 14,
                                  color:
                                      analyzed
                                          ? AppTheme.primaryGreen
                                          : Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  analyzed
                                      ? (AppStrings.isHindi
                                          ? 'विश्लेषित'
                                          : 'Analyzed')
                                      : (AppStrings.isHindi ? 'नया' : 'New'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color:
                                        analyzed
                                            ? AppTheme.primaryGreen
                                            : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _formatDate(capturedAt),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatTime(capturedAt),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            // Single delete button (not in selection mode)
                            if (!_isSelectionMode) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 30,
                                      child: OutlinedButton.icon(
                                        onPressed: () => _deleteSingle(id),
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 14,
                                        ),
                                        label: Text(
                                          AppStrings.isHindi
                                              ? 'हटाएं'
                                              : 'Delete',
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          side: const BorderSide(
                                            color: Colors.red,
                                            width: 1,
                                          ),
                                          padding: EdgeInsets.zero,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  // ── Selection checkbox overlay ──
                  if (_isSelectionMode)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        decoration: BoxDecoration(
                          color:
                              isSelected
                                  ? AppTheme.alertRed
                                  : Colors.white.withOpacity(0.85),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                isSelected
                                    ? AppTheme.alertRed
                                    : Colors.grey.shade400,
                            width: 2,
                          ),
                        ),
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          isSelected ? Icons.check : null,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  // ── Analyzed badge ──
                  if (analyzed && !_isSelectionMode)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.science,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              AppStrings.isHindi ? 'जांचा' : 'Scanned',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectionBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _selectedIds.isEmpty
                    ? (AppStrings.isHindi ? 'छवियां चुनें' : 'Select images')
                    : '${_selectedIds.length} ${AppStrings.isHindi ? 'चयनित' : 'selected'}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
              icon: const Icon(Icons.delete, size: 18),
              label: Text(
                AppStrings.isHindi
                    ? 'हटाएं (${_selectedIds.length})'
                    : 'Delete (${_selectedIds.length})',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Full-screen image preview with delete & pinch-zoom
// ═══════════════════════════════════════════════════════════════════════════════
class _FullScreenImageView extends StatelessWidget {
  final Map<String, dynamic> image;
  final VoidCallback onDelete;
  final VoidCallback? onAnalyze;

  const _FullScreenImageView({
    required this.image,
    required this.onDelete,
    this.onAnalyze,
  });

  @override
  Widget build(BuildContext context) {
    final filePath = image['filePath'] as String;
    final capturedAt = image['capturedAt'] as DateTime;
    final analyzed = image['analyzed'] as bool;
    final result = image['result'] as Map<String, dynamic>?;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${capturedAt.day}/${capturedAt.month}/${capturedAt.year}  '
          '${capturedAt.hour.toString().padLeft(2, '0')}:'
          '${capturedAt.minute.toString().padLeft(2, '0')}',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          if (onAnalyze != null)
            IconButton(
              onPressed: onAnalyze,
              icon: const Icon(Icons.science, color: Colors.greenAccent),
              tooltip: AppStrings.isHindi ? 'विश्लेषण करें' : 'Analyze',
            ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            tooltip: AppStrings.isHindi ? 'हटाएं' : 'Delete',
          ),
        ],
      ),
      body: Column(
        children: [
          // Image
          Expanded(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child:
                    File(filePath).existsSync()
                        ? Image.file(File(filePath), fit: BoxFit.contain)
                        : const Icon(
                          Icons.image_not_supported,
                          color: Colors.white38,
                          size: 80,
                        ),
              ),
            ),
          ),
          // Analysis result strip
          if (analyzed && result != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              color: Colors.grey.shade900,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.greenAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppStrings.isHindi
                            ? 'विश्लेषण परिणाम'
                            : 'Analysis Result',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (result['plant'] != null)
                    _infoRow(
                      AppStrings.isHindi ? 'पौधा' : 'Plant',
                      result['plant'].toString(),
                    ),
                  if (result['disease'] != null)
                    _infoRow(
                      AppStrings.isHindi ? 'बीमारी' : 'Disease',
                      result['disease'].toString(),
                    ),
                  if (result['confidence'] != null)
                    _infoRow(
                      AppStrings.isHindi ? 'विश्वास' : 'Confidence',
                      '${(result['confidence'] * 100).toStringAsFixed(1)}%',
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
