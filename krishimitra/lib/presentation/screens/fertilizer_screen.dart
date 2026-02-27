import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:krishimitra/presentation/providers/app_providers.dart';
import 'package:krishimitra/services/fertilizer_service.dart';
import 'package:krishimitra/utils/app_strings.dart';
import 'package:krishimitra/utils/app_theme.dart';

class FertilizerScreen extends ConsumerStatefulWidget {
  const FertilizerScreen({super.key});

  @override
  ConsumerState<FertilizerScreen> createState() => _FertilizerScreenState();
}

class _FertilizerScreenState extends ConsumerState<FertilizerScreen> {
  @override
  void initState() {
    super.initState();
    FertilizerService.loadDatabase();
  }

  @override
  Widget build(BuildContext context) {
    final n = ref.watch(nitrogenProvider);
    final p = ref.watch(phosphorusProvider);
    final k = ref.watch(potassiumProvider);
    final recommendation = FertilizerService.findRecommendation(n, p, k);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNutrientSlider(
              label: AppStrings.nitrogen,
              value: n,
              color: AppTheme.alertRed,
              onChanged: (value) {
                ref.read(nitrogenProvider.notifier).state = value;
              },
            ),
            const SizedBox(height: 20),

            _buildNutrientSlider(
              label: AppStrings.phosphorus,
              value: p,
              color: AppTheme.warningOrange,
              onChanged: (value) {
                ref.read(phosphorusProvider.notifier).state = value;
              },
            ),
            const SizedBox(height: 20),

            _buildNutrientSlider(
              label: AppStrings.potassium,
              value: k,
              color: AppTheme.lightGreen,
              onChanged: (value) {
                ref.read(potassiumProvider.notifier).state = value;
              },
            ),
            const SizedBox(height: 32),

            if (recommendation != null) ...[
              Text(
                AppStrings.recommendation,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.lightGreen.withOpacity(0.2),
                        AppTheme.primaryGreen.withOpacity(0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recommendation.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.grass, color: AppTheme.primaryGreen),
                          const SizedBox(width: 8),
                          Text(
                            recommendation.type,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.scale, color: AppTheme.primaryGreen),
                          const SizedBox(width: 8),
                          Text(
                            'Quantity: ${recommendation.quantity.toStringAsFixed(1)} kg',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.percent, color: AppTheme.primaryGreen),
                          const SizedBox(width: 8),
                          Text(
                            'Match: ${(recommendation.similarity * 100).toStringAsFixed(1)}%',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientSlider({
    required String label,
    required double value,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                value.toStringAsFixed(0),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            thumbColor: color,
            overlayColor: color.withOpacity(0.3),
            valueIndicatorColor: color,
          ),
          child: Slider(
            value: value,
            min: 0,
            max: 100,
            divisions: 100,
            label: value.toStringAsFixed(0),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
