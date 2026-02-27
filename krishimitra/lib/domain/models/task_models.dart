import 'package:flutter/material.dart';

/// Crop Task Model for task management and calendar
class CropTask {
  final String id;
  final String title;
  final String description;
  final String cropType;
  final TaskCategory category;
  final TaskPriority priority;
  final DateTime dueDate;
  final bool isCompleted;
  final DateTime? completedDate;
  final String? farmId;
  final String? sectorId;
  final String? notes;
  final bool notificationEnabled;

  CropTask({
    required this.id,
    required this.title,
    required this.description,
    required this.cropType,
    required this.category,
    required this.priority,
    required this.dueDate,
    this.isCompleted = false,
    this.completedDate,
    this.farmId,
    this.sectorId,
    this.notes,
    this.notificationEnabled = true,
  });

  factory CropTask.fromMap(Map<String, dynamic> map) {
    return CropTask(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      cropType: map['cropType'] as String,
      category: TaskCategory.values.firstWhere(
        (e) => e.name == map['category'],
        orElse: () => TaskCategory.general,
      ),
      priority: TaskPriority.values.firstWhere(
        (e) => e.name == map['priority'],
        orElse: () => TaskPriority.medium,
      ),
      dueDate: DateTime.parse(map['dueDate'] as String),
      isCompleted: (map['isCompleted'] as int) == 1,
      completedDate:
          map['completedDate'] != null
              ? DateTime.parse(map['completedDate'] as String)
              : null,
      farmId: map['farmId'] as String?,
      sectorId: map['sectorId'] as String?,
      notes: map['notes'] as String?,
      notificationEnabled: (map['notificationEnabled'] as int?) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'cropType': cropType,
      'category': category.name,
      'priority': priority.name,
      'dueDate': dueDate.toIso8601String(),
      'isCompleted': isCompleted ? 1 : 0,
      'completedDate': completedDate?.toIso8601String(),
      'farmId': farmId,
      'sectorId': sectorId,
      'notes': notes,
      'notificationEnabled': notificationEnabled ? 1 : 0,
    };
  }

  CropTask copyWith({
    String? title,
    String? description,
    String? cropType,
    TaskCategory? category,
    TaskPriority? priority,
    DateTime? dueDate,
    bool? isCompleted,
    DateTime? completedDate,
    String? notes,
    bool? notificationEnabled,
  }) {
    return CropTask(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      cropType: cropType ?? this.cropType,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      completedDate: completedDate ?? this.completedDate,
      farmId: farmId,
      sectorId: sectorId,
      notes: notes ?? this.notes,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
    );
  }

  bool get isOverdue => !isCompleted && dueDate.isBefore(DateTime.now());
  bool get isDueToday {
    final now = DateTime.now();
    return !isCompleted &&
        dueDate.year == now.year &&
        dueDate.month == now.month &&
        dueDate.day == now.day;
  }

  bool get isDueSoon {
    final daysDiff = dueDate.difference(DateTime.now()).inDays;
    return !isCompleted && daysDiff >= 0 && daysDiff <= 3;
  }
}

enum TaskCategory {
  sowing,
  irrigation,
  fertilization,
  pesticide,
  weeding,
  pruning,
  harvesting,
  soilTesting,
  general,
}

enum TaskPriority { low, medium, high, urgent }

extension TaskCategoryExtension on TaskCategory {
  String get displayName {
    switch (this) {
      case TaskCategory.sowing:
        return 'Sowing';
      case TaskCategory.irrigation:
        return 'Irrigation';
      case TaskCategory.fertilization:
        return 'Fertilization';
      case TaskCategory.pesticide:
        return 'Pesticide';
      case TaskCategory.weeding:
        return 'Weeding';
      case TaskCategory.pruning:
        return 'Pruning';
      case TaskCategory.harvesting:
        return 'Harvesting';
      case TaskCategory.soilTesting:
        return 'Soil Testing';
      case TaskCategory.general:
        return 'General';
    }
  }

  String get displayNameHindi {
    switch (this) {
      case TaskCategory.sowing:
        return 'बुवाई';
      case TaskCategory.irrigation:
        return 'सिंचाई';
      case TaskCategory.fertilization:
        return 'उर्वरक';
      case TaskCategory.pesticide:
        return 'कीटनाशक';
      case TaskCategory.weeding:
        return 'निराई';
      case TaskCategory.pruning:
        return 'छंटाई';
      case TaskCategory.harvesting:
        return 'कटाई';
      case TaskCategory.soilTesting:
        return 'मिट्टी परीक्षण';
      case TaskCategory.general:
        return 'सामान्य';
    }
  }

  IconData get icon {
    switch (this) {
      case TaskCategory.sowing:
        return Icons.grass;
      case TaskCategory.irrigation:
        return Icons.water_drop;
      case TaskCategory.fertilization:
        return Icons.science;
      case TaskCategory.pesticide:
        return Icons.bug_report;
      case TaskCategory.weeding:
        return Icons.cleaning_services;
      case TaskCategory.pruning:
        return Icons.content_cut;
      case TaskCategory.harvesting:
        return Icons.agriculture;
      case TaskCategory.soilTesting:
        return Icons.biotech;
      case TaskCategory.general:
        return Icons.task_alt;
    }
  }

  Color get color {
    switch (this) {
      case TaskCategory.sowing:
        return const Color(0xFF4CAF50);
      case TaskCategory.irrigation:
        return const Color(0xFF2196F3);
      case TaskCategory.fertilization:
        return const Color(0xFFFF9800);
      case TaskCategory.pesticide:
        return const Color(0xFFF44336);
      case TaskCategory.weeding:
        return const Color(0xFF9C27B0);
      case TaskCategory.pruning:
        return const Color(0xFF795548);
      case TaskCategory.harvesting:
        return const Color(0xFFFFEB3B);
      case TaskCategory.soilTesting:
        return const Color(0xFF607D8B);
      case TaskCategory.general:
        return const Color(0xFF9E9E9E);
    }
  }
}

extension TaskPriorityExtension on TaskPriority {
  String get displayName {
    switch (this) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
      case TaskPriority.urgent:
        return 'Urgent';
    }
  }

  String get displayNameHindi {
    switch (this) {
      case TaskPriority.low:
        return 'कम';
      case TaskPriority.medium:
        return 'मध्यम';
      case TaskPriority.high:
        return 'उच्च';
      case TaskPriority.urgent:
        return 'अत्यावश्यक';
    }
  }

  Color get color {
    switch (this) {
      case TaskPriority.low:
        return Colors.green;
      case TaskPriority.medium:
        return Colors.orange;
      case TaskPriority.high:
        return Colors.deepOrange;
      case TaskPriority.urgent:
        return Colors.red;
    }
  }
}
