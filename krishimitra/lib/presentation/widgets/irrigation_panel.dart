import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:krishimitra/presentation/providers/app_providers.dart';
import 'package:krishimitra/utils/app_strings.dart';
import 'package:krishimitra/utils/app_theme.dart';
class IrrigationPanel extends ConsumerWidget {
  const IrrigationPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moisture = ref.watch(soilMoistureProvider);
    final irrigationStatus = ref.watch(irrigationStatusProvider);

    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.irrigationPanel,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            Text(
              '${AppStrings.soilMoisture}: ${moisture.toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Slider(
              value: moisture,
              min: 0,
              max: 100,
              divisions: 100,
              label: '${moisture.toStringAsFixed(0)}%',
              onChanged: (value) {
                ref.read(soilMoistureProvider.notifier).state = value;
              },
            ),

            const SizedBox(height: 16),
            Container(
              decoration: AppTheme.alertCardDecoration(
                irrigationStatus.isAlert,
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    irrigationStatus.isAlert
                        ? Icons.warning_rounded
                        : Icons.check_circle_rounded,
                    color:
                        irrigationStatus.isAlert
                            ? AppTheme.alertRed
                            : AppTheme.successGreen,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          irrigationStatus.status,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                irrigationStatus.isAlert
                                    ? AppTheme.alertRed
                                    : AppTheme.successGreen,
                          ),
                        ),
                        Text(
                          irrigationStatus.message,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AppStrings.startPump),
                          backgroundColor: AppTheme.alertRed,
                        ),
                      );
                    },
                    icon: const Icon(Icons.power_settings_new),
                    label: Text(AppStrings.startPump),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.alertRed,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AppStrings.stopPump),
                          backgroundColor: AppTheme.successGreen,
                        ),
                      );
                    },
                    icon: const Icon(Icons.stop_circle),
                    label: Text(AppStrings.stopPump),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successGreen,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
