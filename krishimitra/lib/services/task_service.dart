import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:krishimitra/domain/models/task_models.dart';

/// Service for managing crop tasks and calendar
class TaskService {
  static Database? _database;
  static const String _tableName = 'crop_tasks';

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'krishimitra_tasks.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            description TEXT NOT NULL,
            cropType TEXT NOT NULL,
            category TEXT NOT NULL,
            priority TEXT NOT NULL,
            dueDate TEXT NOT NULL,
            isCompleted INTEGER NOT NULL DEFAULT 0,
            completedDate TEXT,
            farmId TEXT,
            sectorId TEXT,
            notes TEXT,
            notificationEnabled INTEGER NOT NULL DEFAULT 1
          )
        ''');
      },
    );
  }

  /// Add a new task
  static Future<void> addTask(CropTask task) async {
    final db = await database;
    await db.insert(
      _tableName,
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all tasks
  static Future<List<CropTask>> getAllTasks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      orderBy: 'dueDate ASC',
    );
    return List.generate(maps.length, (i) => CropTask.fromMap(maps[i]));
  }

  /// Get tasks for a specific date
  static Future<List<CropTask>> getTasksForDate(DateTime date) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'dueDate >= ? AND dueDate < ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'priority DESC, dueDate ASC',
    );
    return List.generate(maps.length, (i) => CropTask.fromMap(maps[i]));
  }

  /// Get upcoming tasks (next 7 days)
  static Future<List<CropTask>> getUpcomingTasks() async {
    final db = await database;
    final now = DateTime.now();
    final nextWeek = now.add(const Duration(days: 7));

    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'dueDate >= ? AND dueDate <= ? AND isCompleted = 0',
      whereArgs: [now.toIso8601String(), nextWeek.toIso8601String()],
      orderBy: 'dueDate ASC',
    );
    return List.generate(maps.length, (i) => CropTask.fromMap(maps[i]));
  }

  /// Get overdue tasks
  static Future<List<CropTask>> getOverdueTasks() async {
    final db = await database;
    final now = DateTime.now();

    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'dueDate < ? AND isCompleted = 0',
      whereArgs: [now.toIso8601String()],
      orderBy: 'dueDate ASC',
    );
    return List.generate(maps.length, (i) => CropTask.fromMap(maps[i]));
  }

  /// Get tasks by category
  static Future<List<CropTask>> getTasksByCategory(
    TaskCategory category,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'category = ?',
      whereArgs: [category.name],
      orderBy: 'dueDate ASC',
    );
    return List.generate(maps.length, (i) => CropTask.fromMap(maps[i]));
  }

  /// Get tasks by crop type
  static Future<List<CropTask>> getTasksByCrop(String cropType) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'cropType = ?',
      whereArgs: [cropType],
      orderBy: 'dueDate ASC',
    );
    return List.generate(maps.length, (i) => CropTask.fromMap(maps[i]));
  }

  /// Update task completion status
  static Future<void> toggleTaskCompletion(String taskId) async {
    final db = await database;
    final task = await getTaskById(taskId);
    if (task == null) return;

    await db.update(
      _tableName,
      {
        'isCompleted': task.isCompleted ? 0 : 1,
        'completedDate':
            task.isCompleted ? null : DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  /// Update a task
  static Future<void> updateTask(CropTask task) async {
    final db = await database;
    await db.update(
      _tableName,
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  /// Delete a task
  static Future<void> deleteTask(String taskId) async {
    final db = await database;
    await db.delete(_tableName, where: 'id = ?', whereArgs: [taskId]);
  }

  /// Get task by ID
  static Future<CropTask?> getTaskById(String taskId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [taskId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return CropTask.fromMap(maps[0]);
  }

  /// Get task statistics
  static Future<Map<String, int>> getTaskStats() async {
    final db = await database;
    final total = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $_tableName'),
    );
    final completed = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM $_tableName WHERE isCompleted = 1',
      ),
    );
    final overdue = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM $_tableName WHERE dueDate < ? AND isCompleted = 0',
        [DateTime.now().toIso8601String()],
      ),
    );
    final today = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM $_tableName WHERE DATE(dueDate) = DATE(?) AND isCompleted = 0',
        [DateTime.now().toIso8601String()],
      ),
    );

    return {
      'total': total ?? 0,
      'completed': completed ?? 0,
      'overdue': overdue ?? 0,
      'today': today ?? 0,
    };
  }

  /// Create default tasks for a crop
  static Future<void> createDefaultTasksForCrop(
    String cropType,
    DateTime plantingDate,
  ) async {
    final tasks = _getDefaultTasks(cropType, plantingDate);
    for (final task in tasks) {
      await addTask(task);
    }
  }

  static List<CropTask> _getDefaultTasks(
    String cropType,
    DateTime plantingDate,
  ) {
    final baseId = DateTime.now().millisecondsSinceEpoch;

    // Default tasks for wheat (adjust based on crop type)
    if (cropType.toLowerCase().contains('wheat') ||
        cropType.toLowerCase().contains('गेहूं')) {
      return [
        CropTask(
          id: '${baseId}_1',
          title: 'Pre-sowing Irrigation',
          description: 'Apply water 7-10 days before sowing',
          cropType: cropType,
          category: TaskCategory.irrigation,
          priority: TaskPriority.high,
          dueDate: plantingDate.subtract(const Duration(days: 7)),
        ),
        CropTask(
          id: '${baseId}_2',
          title: 'Sowing',
          description: 'Sow wheat seeds at recommended depth',
          cropType: cropType,
          category: TaskCategory.sowing,
          priority: TaskPriority.urgent,
          dueDate: plantingDate,
        ),
        CropTask(
          id: '${baseId}_3',
          title: 'First Irrigation',
          description: 'Crown root irrigation (20-25 days after sowing)',
          cropType: cropType,
          category: TaskCategory.irrigation,
          priority: TaskPriority.high,
          dueDate: plantingDate.add(const Duration(days: 21)),
        ),
        CropTask(
          id: '${baseId}_4',
          title: 'First Fertilizer Application',
          description: 'Apply nitrogen fertilizer',
          cropType: cropType,
          category: TaskCategory.fertilization,
          priority: TaskPriority.high,
          dueDate: plantingDate.add(const Duration(days: 21)),
        ),
        CropTask(
          id: '${baseId}_5',
          title: 'Weed Management',
          description: 'First weeding operation',
          cropType: cropType,
          category: TaskCategory.weeding,
          priority: TaskPriority.medium,
          dueDate: plantingDate.add(const Duration(days: 30)),
        ),
        CropTask(
          id: '${baseId}_6',
          title: 'Second Irrigation',
          description: 'Late tillering stage irrigation',
          cropType: cropType,
          category: TaskCategory.irrigation,
          priority: TaskPriority.high,
          dueDate: plantingDate.add(const Duration(days: 40)),
        ),
        CropTask(
          id: '${baseId}_7',
          title: 'Pest Monitoring',
          description: 'Check for aphids and other pests',
          cropType: cropType,
          category: TaskCategory.pesticide,
          priority: TaskPriority.medium,
          dueDate: plantingDate.add(const Duration(days: 50)),
        ),
        CropTask(
          id: '${baseId}_8',
          title: 'Harvesting',
          description: 'Harvest when grain moisture is 12-14%',
          cropType: cropType,
          category: TaskCategory.harvesting,
          priority: TaskPriority.urgent,
          dueDate: plantingDate.add(const Duration(days: 120)),
        ),
      ];
    }

    // Generic tasks for other crops
    return [
      CropTask(
        id: '${baseId}_1',
        title: 'Sowing',
        description: 'Plant seeds at recommended depth',
        cropType: cropType,
        category: TaskCategory.sowing,
        priority: TaskPriority.urgent,
        dueDate: plantingDate,
      ),
      CropTask(
        id: '${baseId}_2',
        title: 'First Irrigation',
        description: 'Water the crop adequately',
        cropType: cropType,
        category: TaskCategory.irrigation,
        priority: TaskPriority.high,
        dueDate: plantingDate.add(const Duration(days: 7)),
      ),
      CropTask(
        id: '${baseId}_3',
        title: 'Fertilizer Application',
        description: 'Apply recommended fertilizer',
        cropType: cropType,
        category: TaskCategory.fertilization,
        priority: TaskPriority.high,
        dueDate: plantingDate.add(const Duration(days: 21)),
      ),
    ];
  }
}
