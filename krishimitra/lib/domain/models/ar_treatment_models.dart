/// Models for AR-based treatment guidance system
library;

import 'package:flutter/material.dart';

/// Represents a single treatment step in AR mode
class ARTreatmentStep {
  final int stepNumber;
  final String titleEn;
  final String titleHi;
  final String titleMr;
  final String descriptionEn;
  final String descriptionHi;
  final String descriptionMr;
  final TreatmentStepType type;
  final AROverlayConfig overlayConfig;
  final Duration estimatedDuration;
  final List<String> warnings;
  final String? animationAsset;

  ARTreatmentStep({
    required this.stepNumber,
    required this.titleEn,
    required this.titleHi,
    required this.titleMr,
    required this.descriptionEn,
    required this.descriptionHi,
    required this.descriptionMr,
    required this.type,
    required this.overlayConfig,
    this.estimatedDuration = const Duration(minutes: 2),
    this.warnings = const [],
    this.animationAsset,
  });

  String getTitle(String languageCode) {
    switch (languageCode) {
      case 'hi':
        return titleHi;
      case 'mr':
        return titleMr;
      default:
        return titleEn;
    }
  }

  String getDescription(String languageCode) {
    switch (languageCode) {
      case 'hi':
        return descriptionHi;
      case 'mr':
        return descriptionMr;
      default:
        return descriptionEn;
    }
  }
}

/// Types of treatment steps
enum TreatmentStepType {
  identifyArea,      // Locate infected area
  prepareTools,      // Prepare required tools
  prepareSolution,   // Mix pesticide/fungicide
  application,       // Apply treatment
  soilTreatment,     // Dig/prepare soil
  pruning,           // Cut infected parts
  watering,          // Specific watering instructions
  safety,            // Safety precautions
  monitoring,        // Post-treatment monitoring
  prevention,        // Preventive measures
}

/// Configuration for AR overlay elements
class AROverlayConfig {
  final Color highlightColor;
  final double highlightOpacity;
  final OverlayShape shape;
  final SprayDirection? sprayDirection;
  final double? safeDistance; // in meters
  final double? targetRadius; // in centimeters
  final List<ARArrow>? arrows;
  final ARAnimation? animation;

  AROverlayConfig({
    this.highlightColor = Colors.red,
    this.highlightOpacity = 0.4,
    this.shape = OverlayShape.circle,
    this.sprayDirection,
    this.safeDistance,
    this.targetRadius,
    this.arrows,
    this.animation,
  });
}

/// Shape of the overlay highlight
enum OverlayShape {
  circle,
  rectangle,
  freeform,
  arrow,
  grid,
}

/// Spray direction indicator
class SprayDirection {
  final double angle; // in degrees
  final double distance; // in centimeters
  final String pattern; // zigzag, circular, linear

  SprayDirection({
    required this.angle,
    required this.distance,
    this.pattern = 'linear',
  });
}

/// AR Arrow indicator
class ARArrow {
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  final Color color;
  final String label;

  ARArrow({
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    this.color = Colors.green,
    this.label = '',
  });
}

/// AR Animation configuration
class ARAnimation {
  final String type; // spray, dig, cut, water
  final Duration duration;
  final bool loop;

  ARAnimation({
    required this.type,
    this.duration = const Duration(seconds: 2),
    this.loop = true,
  });
}

/// Complete AR treatment plan for a disease
class ARTreatmentPlan {
  final String diseaseId;
  final String diseaseName;
  final String plantName;
  final String severityLevel; // mild, moderate, severe
  final List<ARTreatmentStep> steps;
  final List<RequiredTool> requiredTools;
  final List<RequiredChemical> requiredChemicals;
  final SafetyGuidelines safetyGuidelines;
  final NearbyStoreInfo? nearbyStore;

  ARTreatmentPlan({
    required this.diseaseId,
    required this.diseaseName,
    required this.plantName,
    required this.severityLevel,
    required this.steps,
    required this.requiredTools,
    required this.requiredChemicals,
    required this.safetyGuidelines,
    this.nearbyStore,
  });

  int get totalSteps => steps.length;

  Duration get totalEstimatedTime {
    return steps.fold(Duration.zero, (total, step) => total + step.estimatedDuration);
  }
}

/// Required tool for treatment
class RequiredTool {
  final String nameEn;
  final String nameHi;
  final String nameMr;
  final String icon;
  final bool isEssential;

  RequiredTool({
    required this.nameEn,
    required this.nameHi,
    required this.nameMr,
    this.icon = '🔧',
    this.isEssential = true,
  });

  String getName(String languageCode) {
    switch (languageCode) {
      case 'hi':
        return nameHi;
      case 'mr':
        return nameMr;
      default:
        return nameEn;
    }
  }
}

/// Required chemical/pesticide for treatment
class RequiredChemical {
  final String nameEn;
  final String nameHi;
  final String nameMr;
  final String type; // pesticide, fungicide, herbicide, fertilizer
  final String dosage;
  final String? brandSuggestion;
  final double? estimatedPrice;

  RequiredChemical({
    required this.nameEn,
    required this.nameHi,
    required this.nameMr,
    required this.type,
    required this.dosage,
    this.brandSuggestion,
    this.estimatedPrice,
  });

  String getName(String languageCode) {
    switch (languageCode) {
      case 'hi':
        return nameHi;
      case 'mr':
        return nameMr;
      default:
        return nameEn;
    }
  }
}

/// Safety guidelines for treatment
class SafetyGuidelines {
  final List<String> protectiveGearEn;
  final List<String> protectiveGearHi;
  final List<String> protectiveGearMr;
  final double safeDistanceMeters;
  final String applicationTimeEn;
  final String applicationTimeHi;
  final String applicationTimeMr;
  final List<String> doNotEn;
  final List<String> doNotHi;
  final List<String> doNotMr;
  final String emergencyContactEn;
  final String emergencyContactHi;
  final String emergencyContactMr;

  SafetyGuidelines({
    required this.protectiveGearEn,
    required this.protectiveGearHi,
    required this.protectiveGearMr,
    required this.safeDistanceMeters,
    required this.applicationTimeEn,
    required this.applicationTimeHi,
    required this.applicationTimeMr,
    required this.doNotEn,
    required this.doNotHi,
    required this.doNotMr,
    this.emergencyContactEn = 'Call local poison control or doctor immediately',
    this.emergencyContactHi = 'तुरंत स्थानीय विष नियंत्रण या डॉक्टर को कॉल करें',
    this.emergencyContactMr = 'तात्काळ स्थानिक विष नियंत्रण किंवा डॉक्टरांना कॉल करा',
  });

  List<String> getProtectiveGear(String languageCode) {
    switch (languageCode) {
      case 'hi':
        return protectiveGearHi;
      case 'mr':
        return protectiveGearMr;
      default:
        return protectiveGearEn;
    }
  }

  String getApplicationTime(String languageCode) {
    switch (languageCode) {
      case 'hi':
        return applicationTimeHi;
      case 'mr':
        return applicationTimeMr;
      default:
        return applicationTimeEn;
    }
  }

  List<String> getDoNots(String languageCode) {
    switch (languageCode) {
      case 'hi':
        return doNotHi;
      case 'mr':
        return doNotMr;
      default:
        return doNotEn;
    }
  }
}

/// Nearby agri-store information
class NearbyStoreInfo {
  final String name;
  final String address;
  final double distanceKm;
  final String? phoneNumber;
  final double latitude;
  final double longitude;
  final List<String> availableProducts;
  final String? openingHours;

  NearbyStoreInfo({
    required this.name,
    required this.address,
    required this.distanceKm,
    this.phoneNumber,
    required this.latitude,
    required this.longitude,
    this.availableProducts = const [],
    this.openingHours,
  });
}

/// AR Session state
class ARSessionState {
  final int currentStepIndex;
  final bool isPlaying;
  final bool isMuted;
  final bool showOverlay;
  final double cameraZoom;
  final ARTreatmentPlan? plan;

  ARSessionState({
    this.currentStepIndex = 0,
    this.isPlaying = false,
    this.isMuted = false,
    this.showOverlay = true,
    this.cameraZoom = 1.0,
    this.plan,
  });

  ARSessionState copyWith({
    int? currentStepIndex,
    bool? isPlaying,
    bool? isMuted,
    bool? showOverlay,
    double? cameraZoom,
    ARTreatmentPlan? plan,
  }) {
    return ARSessionState(
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      isMuted: isMuted ?? this.isMuted,
      showOverlay: showOverlay ?? this.showOverlay,
      cameraZoom: cameraZoom ?? this.cameraZoom,
      plan: plan ?? this.plan,
    );
  }

  bool get hasNextStep => plan != null && currentStepIndex < plan!.steps.length - 1;
  bool get hasPreviousStep => currentStepIndex > 0;
  
  ARTreatmentStep? get currentStep {
    if (plan == null || currentStepIndex >= plan!.steps.length) return null;
    return plan!.steps[currentStepIndex];
  }
}
