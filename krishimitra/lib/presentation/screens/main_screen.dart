import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:krishimitra/presentation/providers/app_providers.dart';
import 'package:krishimitra/presentation/screens/dashboard_screen.dart';
import 'package:krishimitra/presentation/screens/placeholder_screens.dart';
import 'package:krishimitra/utils/app_strings.dart';
import 'package:krishimitra/utils/app_theme.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _selectedIndex = 0;
  final bool _isListening = false;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const MonitorScreen(),
    const ScanScreen(),
    const ProfileScreen(),
  ];

  Future<void> _handleVoiceCommand() async {
    _showMessage('Voice feature coming soon! Use navigation tabs below.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(fontSize: 13)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        duration: const Duration(seconds: 2),
        backgroundColor: AppTheme.darkGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch language provider to rebuild when language changes
    ref.watch(languageProvider);

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _selectedIndex, children: _screens),
      floatingActionButton: FloatingActionButton(
        onPressed: _isListening ? null : _handleVoiceCommand,
        tooltip: AppStrings.voiceCommand,
        backgroundColor: AppTheme.primaryGreen,
        elevation: 4,
        child:
            _isListening
                ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
                : const Icon(Icons.mic_rounded, size: 26),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.7),
                  Colors.white.withOpacity(0.5),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.8),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _NavItem(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home_rounded,
                      label: AppStrings.navHome,
                      isActive: _selectedIndex == 0,
                      onTap: () => setState(() => _selectedIndex = 0),
                    ),
                    _NavItem(
                      icon: Icons.cloud_outlined,
                      activeIcon: Icons.cloud_rounded,
                      label: AppStrings.navMonitor,
                      isActive: _selectedIndex == 1,
                      onTap: () => setState(() => _selectedIndex = 1),
                    ),
                    _NavItem(
                      icon: Icons.document_scanner_outlined,
                      activeIcon: Icons.document_scanner_rounded,
                      label: AppStrings.navScan,
                      isActive: _selectedIndex == 2,
                      onTap: () => setState(() => _selectedIndex = 2),
                    ),
                    _NavItem(
                      icon: Icons.person_outline_rounded,
                      activeIcon: Icons.person_rounded,
                      label: AppStrings.navProfile,
                      isActive: _selectedIndex == 3,
                      onTap: () => setState(() => _selectedIndex = 3),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: isActive ? 0 : 8,
                  sigmaY: isActive ? 0 : 8,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient:
                        isActive
                            ? LinearGradient(
                              colors: [
                                AppTheme.primaryGreen,
                                AppTheme.mediumGreen,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                            : null,
                    color:
                        isActive
                            ? null
                            : AppTheme.veryPaleGreen.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color:
                          isActive
                              ? Colors.white.withOpacity(0.3)
                              : AppTheme.primaryGreen.withOpacity(0.2),
                      width: 1,
                    ),
                    boxShadow:
                        isActive
                            ? [
                              BoxShadow(
                                color: AppTheme.primaryGreen.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                            : null,
                  ),
                  child: Icon(
                    isActive ? activeIcon : icon,
                    color: isActive ? Colors.white : AppTheme.darkGreen,
                    size: 28,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? AppTheme.darkGreen : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
