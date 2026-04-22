import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class LocalDb {
  LocalDb._();

  static final LocalDb instance = LocalDb._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'reservoir_inspection.db');
    return openDatabase(
      path,
      version: 3,
      onCreate: (db, _) async {
        await db.execute('''
            CREATE TABLE projects (
              project_id TEXT PRIMARY KEY,
              project_name TEXT,
              reservoir_name TEXT,
              dam_type TEXT,
              description TEXT,
              archived_at TEXT,
              sync_status TEXT DEFAULT 'synced',
              updated_at TEXT
            )
          ''');

        await db.execute('''
            CREATE TABLE tasks (
              task_id TEXT PRIMARY KEY,
              project_id TEXT,
              reservoir_name TEXT,
              dam_type TEXT,
              inspection_date TEXT,
              status TEXT,
              issue_count INTEGER DEFAULT 0,
              weather TEXT,
              inspection_type TEXT,
              enabled_chapters_json TEXT,
              sync_status TEXT DEFAULT 'synced',
              updated_at TEXT
            )
          ''');

        await db.execute('''
            CREATE TABLE template_tree (
              task_id TEXT PRIMARY KEY,
              tree_json TEXT,
              updated_at TEXT
            )
          ''');

        await db.execute('''
            CREATE TABLE inspection_results (
              local_result_id TEXT PRIMARY KEY,
              server_result_id TEXT,
              task_id TEXT,
              item_code TEXT,
              item_name TEXT,
              chapter_code TEXT,
              check_status TEXT,
              issue_flag INTEGER,
              issue_type_json TEXT,
              severity_level TEXT,
              check_record TEXT,
              suggestion TEXT,
              sync_status TEXT,
              last_error TEXT,
              updated_at TEXT,
              UNIQUE(task_id, item_code)
            )
          ''');

        await db.execute('''
            CREATE TABLE evidence_metadata (
              local_evidence_id TEXT PRIMARY KEY,
              server_evidence_id TEXT,
              result_local_id TEXT,
              evidence_type TEXT,
              file_url TEXT,
              local_file_path TEXT,
              caption TEXT,
              gps_lat REAL,
              gps_lng REAL,
              shot_time TEXT,
              is_deleted INTEGER DEFAULT 0,
              sync_status TEXT,
              last_error TEXT,
              updated_at TEXT
            )
          ''');

        await db.execute('''
            CREATE TABLE sync_queue (
              queue_id INTEGER PRIMARY KEY AUTOINCREMENT,
              entity_type TEXT,
              entity_id TEXT,
              operation TEXT,
              sync_status TEXT,
              last_error TEXT,
              updated_at TEXT,
              UNIQUE(entity_type, entity_id, operation)
            )
          ''');

        await db.execute('''
            CREATE TABLE structure_instances (
              instance_id TEXT PRIMARY KEY,
              project_id TEXT,
              category_code TEXT,
              object_type TEXT,
              instance_name TEXT,
              template_source_type TEXT,
              enabled_for_capture INTEGER DEFAULT 1,
              enabled_for_report INTEGER DEFAULT 1,
              default_part_template_code TEXT,
              sort_order INTEGER DEFAULT 0,
              updated_at TEXT
            )
          ''');

        await db.execute('''
            CREATE TABLE capture_records (
              capture_id TEXT PRIMARY KEY,
              task_id TEXT,
              structure_instance_id TEXT,
              part_code TEXT,
              quick_part_tag TEXT,
              quick_status TEXT,
              raw_note TEXT,
              speech_text TEXT,
              review_status TEXT,
              linked_result_id TEXT,
              created_by TEXT,
              updated_at TEXT,
              created_at TEXT
            )
          ''');

        await db.execute('''
            CREATE TABLE capture_media (
              media_id TEXT PRIMARY KEY,
              capture_id TEXT,
              media_type TEXT,
              local_path TEXT,
              server_url TEXT,
              shot_time TEXT,
              updated_at TEXT
            )
          ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
              CREATE TABLE IF NOT EXISTS projects (
                project_id TEXT PRIMARY KEY,
                project_name TEXT,
                reservoir_name TEXT,
                dam_type TEXT,
                description TEXT,
                archived_at TEXT,
                sync_status TEXT DEFAULT 'synced',
                updated_at TEXT
              )
            ''');
          await _addColumnIfMissing(
            db,
            table: 'tasks',
            column: 'project_id',
            sql: 'ALTER TABLE tasks ADD COLUMN project_id TEXT',
          );
        }
        if (oldVersion < 3) {
          await db.execute('''
              CREATE TABLE IF NOT EXISTS structure_instances (
                instance_id TEXT PRIMARY KEY,
                project_id TEXT,
                category_code TEXT,
                object_type TEXT,
                instance_name TEXT,
                template_source_type TEXT,
                enabled_for_capture INTEGER DEFAULT 1,
                enabled_for_report INTEGER DEFAULT 1,
                default_part_template_code TEXT,
                sort_order INTEGER DEFAULT 0,
                updated_at TEXT
              )
            ''');
          await db.execute('''
              CREATE TABLE IF NOT EXISTS capture_records (
                capture_id TEXT PRIMARY KEY,
                task_id TEXT,
                structure_instance_id TEXT,
                part_code TEXT,
                quick_part_tag TEXT,
                quick_status TEXT,
                raw_note TEXT,
                speech_text TEXT,
                review_status TEXT,
                linked_result_id TEXT,
                created_by TEXT,
                updated_at TEXT,
                created_at TEXT
              )
            ''');
          await db.execute('''
              CREATE TABLE IF NOT EXISTS capture_media (
                media_id TEXT PRIMARY KEY,
                capture_id TEXT,
                media_type TEXT,
                local_path TEXT,
                server_url TEXT,
                shot_time TEXT,
                updated_at TEXT
              )
            ''');
        }
      },
    );
  }

  Future<void> _addColumnIfMissing(
    Database db, {
    required String table,
    required String column,
    required String sql,
  }) async {
    final rows = await db.rawQuery("PRAGMA table_info($table)");
    final hasColumn = rows.any((row) => row['name'] == column);
    if (!hasColumn) {
      await db.execute(sql);
    }
  }

  Future<void> upsertProjects(List<Map<String, dynamic>> items) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    for (final item in items) {
      batch.insert(
        'projects',
        {
          'project_id': item['project_id'],
          'project_name': item['project_name'] ?? item['reservoir_name'] ?? '',
          'reservoir_name': item['reservoir_name'] ?? '',
          'dam_type': item['dam_type'] ?? '',
          'description': item['description'],
          'archived_at': item['archived_at'],
          'sync_status': item['sync_status'] ?? 'synced',
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<String> createLocalProject({
    required String reservoirName,
    required String damType,
    String? description,
  }) async {
    final db = await database;
    final projectId = 'lp_${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now().toIso8601String();
    await db.insert(
      'projects',
      {
        'project_id': projectId,
        'project_name': reservoirName,
        'reservoir_name': reservoirName,
        'dam_type': damType,
        'description': description,
        'archived_at': null,
        'sync_status': 'pending',
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await enqueue(
      entityType: 'project',
      entityId: projectId,
      operation: 'upsert',
      syncStatus: 'pending',
      lastError: 'created offline',
    );
    return projectId;
  }

  Future<List<Map<String, dynamic>>> listProjects({
    bool includeArchived = false,
  }) async {
    final db = await database;
    return db.query(
      'projects',
      where: includeArchived ? null : 'archived_at IS NULL',
      orderBy: 'updated_at DESC',
    );
  }

  Future<Map<String, dynamic>?> getProject(String projectId) async {
    final db = await database;
    final rows = await db.query(
      'projects',
      where: 'project_id = ?',
      whereArgs: [projectId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  Future<Map<String, dynamic>?> updateLocalProject({
    required String projectId,
    required String reservoirName,
    required String damType,
    String? description,
  }) async {
    final db = await database;
    await db.update(
      'projects',
      {
        'project_name': reservoirName,
        'reservoir_name': reservoirName,
        'dam_type': damType,
        'description': description,
        'sync_status': 'pending',
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'project_id = ?',
      whereArgs: [projectId],
    );
    await enqueue(
      entityType: 'project',
      entityId: projectId,
      operation: 'upsert',
      syncStatus: 'pending',
    );
    return getProject(projectId);
  }

  Future<void> archiveLocalProject(String projectId) async {
    final db = await database;
    await db.update(
      'projects',
      {
        'archived_at': DateTime.now().toIso8601String(),
        'sync_status': 'pending',
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'project_id = ?',
      whereArgs: [projectId],
    );
    await enqueue(
      entityType: 'project',
      entityId: projectId,
      operation: 'archive',
      syncStatus: 'pending',
    );
  }

  Future<void> deleteLocalProject(String projectId) async {
    final db = await database;
    final tasks = await db.query(
      'tasks',
      columns: ['task_id'],
      where: 'project_id = ?',
      whereArgs: [projectId],
    );
    final batch = db.batch();
    for (final task in tasks) {
      final taskId = task['task_id'] as String;
      final captureRows = await db.query(
        'capture_records',
        columns: ['capture_id'],
        where: 'task_id = ?',
        whereArgs: [taskId],
      );
      for (final capture in captureRows) {
        batch.delete(
          'capture_media',
          where: 'capture_id = ?',
          whereArgs: [capture['capture_id']],
        );
      }
      batch.delete('capture_records', where: 'task_id = ?', whereArgs: [taskId]);
      batch.delete('template_tree', where: 'task_id = ?', whereArgs: [taskId]);
      batch.delete(
        'inspection_results',
        where: 'task_id = ?',
        whereArgs: [taskId],
      );
    }
    batch.delete('structure_instances', where: 'project_id = ?', whereArgs: [projectId]);
    batch.delete('tasks', where: 'project_id = ?', whereArgs: [projectId]);
    batch.delete('projects', where: 'project_id = ?', whereArgs: [projectId]);
    await batch.commit(noResult: true);
  }

  Future<void> deleteLocalTask(String taskId) async {
    final db = await database;
    final resultRows = await db.query(
      'inspection_results',
      columns: ['local_result_id'],
      where: 'task_id = ?',
      whereArgs: [taskId],
    );
    final batch = db.batch();
    for (final row in resultRows) {
      final localResultId = row['local_result_id'] as String;
      batch.delete(
        'evidence_metadata',
        where: 'result_local_id = ?',
        whereArgs: [localResultId],
      );
    }
    final captureRows = await db.query(
      'capture_records',
      columns: ['capture_id'],
      where: 'task_id = ?',
      whereArgs: [taskId],
    );
    for (final capture in captureRows) {
      batch.delete(
        'capture_media',
        where: 'capture_id = ?',
        whereArgs: [capture['capture_id']],
      );
    }
    batch.delete('capture_records', where: 'task_id = ?', whereArgs: [taskId]);
    batch.delete('inspection_results', where: 'task_id = ?', whereArgs: [taskId]);
    batch.delete('template_tree', where: 'task_id = ?', whereArgs: [taskId]);
    batch.delete('tasks', where: 'task_id = ?', whereArgs: [taskId]);
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> listStructureInstances(String projectId) async {
    final db = await database;
    return db.query(
      'structure_instances',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'sort_order ASC, updated_at ASC',
    );
  }

  Future<void> replaceStructureInstances({
    required String projectId,
    required List<Map<String, dynamic>> items,
  }) async {
    final db = await database;
    final batch = db.batch();
    batch.delete('structure_instances', where: 'project_id = ?', whereArgs: [projectId]);
    for (final item in items) {
      batch.insert(
        'structure_instances',
        {
          'instance_id': item['instance_id'],
          'project_id': item['project_id'],
          'category_code': item['category_code'],
          'object_type': item['object_type'],
          'instance_name': item['instance_name'],
          'template_source_type': item['template_source_type'],
          'enabled_for_capture': item['enabled_for_capture'] == true ? 1 : 0,
          'enabled_for_report': item['enabled_for_report'] == true ? 1 : 0,
          'default_part_template_code': item['default_part_template_code'],
          'sort_order': item['sort_order'] ?? 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<Map<String, dynamic>> createLocalStructureInstance({
    required String projectId,
    required String categoryCode,
    required String objectType,
    required String instanceName,
    required String templateSourceType,
    required String defaultPartTemplateCode,
    required int sortOrder,
  }) async {
    final db = await database;
    final instanceId = 'psi_${DateTime.now().microsecondsSinceEpoch}';
    final row = {
      'instance_id': instanceId,
      'project_id': projectId,
      'category_code': categoryCode,
      'object_type': objectType,
      'instance_name': instanceName,
      'template_source_type': templateSourceType,
      'enabled_for_capture': 1,
      'enabled_for_report': 1,
      'default_part_template_code': defaultPartTemplateCode,
      'sort_order': sortOrder,
      'updated_at': DateTime.now().toIso8601String(),
    };
    await db.insert('structure_instances', row, conflictAlgorithm: ConflictAlgorithm.replace);
    return row;
  }

  Future<Map<String, dynamic>?> patchLocalStructureInstance({
    required String instanceId,
    String? instanceName,
    bool? enabledForCapture,
    bool? enabledForReport,
    int? sortOrder,
  }) async {
    final db = await database;
    await db.update(
      'structure_instances',
      {
        if (instanceName != null) 'instance_name': instanceName,
        if (enabledForCapture != null)
          'enabled_for_capture': enabledForCapture ? 1 : 0,
        if (enabledForReport != null)
          'enabled_for_report': enabledForReport ? 1 : 0,
        if (sortOrder != null) 'sort_order': sortOrder,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'instance_id = ?',
      whereArgs: [instanceId],
    );
    final rows = await db.query(
      'structure_instances',
      where: 'instance_id = ?',
      whereArgs: [instanceId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  Future<String> createLocalCapture({
    required String taskId,
    required String structureInstanceId,
    required String partCode,
    required String quickPartTag,
    required String quickStatus,
    String? rawNote,
    String? speechText,
    String? createdBy,
  }) async {
    final db = await database;
    final captureId = 'cap_${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now().toIso8601String();
    await db.insert(
      'capture_records',
      {
        'capture_id': captureId,
        'task_id': taskId,
        'structure_instance_id': structureInstanceId,
        'part_code': partCode,
        'quick_part_tag': quickPartTag,
        'quick_status': quickStatus,
        'raw_note': rawNote,
        'speech_text': speechText,
        'review_status': 'pending',
        'linked_result_id': null,
        'created_by': createdBy,
        'updated_at': now,
        'created_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return captureId;
  }

  Future<void> addLocalCaptureMedia({
    required String captureId,
    required String mediaType,
    String? localPath,
    String? serverUrl,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.insert(
      'capture_media',
      {
        'media_id': 'cm_${DateTime.now().microsecondsSinceEpoch}',
        'capture_id': captureId,
        'media_type': mediaType,
        'local_path': localPath,
        'server_url': serverUrl,
        'shot_time': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateLocalCaptureSpeechText({
    required String captureId,
    required String speechText,
  }) async {
    final db = await database;
    await db.update(
      'capture_records',
      {
        'speech_text': speechText,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'capture_id = ?',
      whereArgs: [captureId],
    );
  }

  Future<List<Map<String, dynamic>>> listTaskCaptures(
    String taskId, {
    String? reviewStatus,
  }) async {
    final db = await database;
    return db.query(
      'capture_records',
      where: reviewStatus == null ? 'task_id = ?' : 'task_id = ? AND review_status = ?',
      whereArgs: reviewStatus == null ? [taskId] : [taskId, reviewStatus],
      orderBy: 'created_at DESC',
    );
  }

  Future<Map<String, dynamic>?> getCapture(String captureId) async {
    final db = await database;
    final rows = await db.query(
      'capture_records',
      where: 'capture_id = ?',
      whereArgs: [captureId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  Future<List<Map<String, dynamic>>> listCaptureMedia(String captureId) async {
    final db = await database;
    return db.query(
      'capture_media',
      where: 'capture_id = ?',
      whereArgs: [captureId],
      orderBy: 'shot_time ASC',
    );
  }

  Future<void> markCaptureConfirmed({
    required String captureId,
    required String linkedResultId,
  }) async {
    final db = await database;
    await db.update(
      'capture_records',
      {
        'review_status': 'confirmed',
        'linked_result_id': linkedResultId,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'capture_id = ?',
      whereArgs: [captureId],
    );
  }

  Future<void> deleteLocalCapture(String captureId) async {
    final db = await database;
    final batch = db.batch();
    batch.delete('capture_media', where: 'capture_id = ?', whereArgs: [captureId]);
    batch.delete('capture_records', where: 'capture_id = ?', whereArgs: [captureId]);
    await batch.commit(noResult: true);
  }

  Future<void> upsertTasks(List<Map<String, dynamic>> items) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    for (final item in items) {
      batch.insert(
        'tasks',
        {
          'task_id': item['task_id'],
          'project_id': item['project_id'],
          'reservoir_name': item['reservoir_name'] ?? '',
          'dam_type': item['dam_type'] ?? '',
          'inspection_date': item['inspection_date'] ?? '',
          'status': item['status'] ?? '',
          'issue_count': item['issue_count'] ?? 0,
          'weather': item['weather'],
          'inspection_type': item['inspection_type'],
          'enabled_chapters_json': jsonEncode(item['enabled_chapters'] ?? []),
          'sync_status': 'synced',
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<String> createLocalTask({
    required String projectId,
    required String reservoirName,
    required String damType,
    required String inspectionType,
    required String inspectionDate,
    required String weather,
    required List<String> enabledChapters,
    required List<dynamic> templateTree,
  }) async {
    final db = await database;
    final taskId = 'lt_${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now().toIso8601String();
    await db.insert(
      'tasks',
      {
        'task_id': taskId,
        'project_id': projectId,
        'reservoir_name': reservoirName,
        'dam_type': damType,
        'inspection_date': inspectionDate,
        'status': 'in_progress',
        'issue_count': 0,
        'weather': weather,
        'inspection_type': inspectionType,
        'enabled_chapters_json': jsonEncode(enabledChapters),
        'sync_status': 'pending',
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (templateTree.isNotEmpty) {
      await upsertTemplateTree(taskId, templateTree);
    }
    await enqueue(
      entityType: 'task',
      entityId: taskId,
      operation: 'upsert',
      syncStatus: 'pending',
      lastError: 'created offline',
    );
    return taskId;
  }

  Future<List<Map<String, dynamic>>> listTasks() async {
    final db = await database;
    return db.query('tasks', orderBy: 'inspection_date DESC, updated_at DESC');
  }

  Future<Map<String, dynamic>?> getTask(String taskId) async {
    final db = await database;
    final rows = await db.query('tasks',
        where: 'task_id = ?', whereArgs: [taskId], limit: 1);
    if (rows.isEmpty) return null;
    final row = Map<String, dynamic>.from(rows.first);
    row['project_id'] = row['project_id'] ?? '';
    row['enabled_chapters'] =
        jsonDecode(row['enabled_chapters_json'] as String? ?? '[]');
    return row;
  }

  Future<void> upsertTemplateTree(String taskId, List<dynamic> tree) async {
    final db = await database;
    await db.insert(
      'template_tree',
      {
        'task_id': taskId,
        'tree_json': jsonEncode(tree),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<dynamic>> getTemplateTree(String taskId) async {
    final db = await database;
    final rows = await db.query('template_tree',
        where: 'task_id = ?', whereArgs: [taskId], limit: 1);
    if (rows.isEmpty) return const [];
    return jsonDecode(rows.first['tree_json'] as String? ?? '[]')
        as List<dynamic>;
  }

  Future<List<dynamic>> getLatestTemplateTree() async {
    final db = await database;
    final rows = await db.query(
      'template_tree',
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return const [];
    return jsonDecode(rows.first['tree_json'] as String? ?? '[]')
        as List<dynamic>;
  }

  Future<Map<String, String>> _itemMetaFromTree(String taskId) async {
    final tree = await getTemplateTree(taskId);
    final map = <String, String>{};
    for (final chapter in tree.cast<Map<String, dynamic>>()) {
      final chapterCode = chapter['chapter_code']?.toString() ?? '';
      final sections = (chapter['children'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      for (final section in sections) {
        final items = (section['children'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        for (final item in items) {
          map['${item['item_code']}:chapter'] = chapterCode;
          map['${item['item_code']}:name'] =
              item['item_name']?.toString() ?? '';
        }
      }
    }
    return map;
  }

  Future<Map<String, dynamic>> upsertResultFromPayload({
    required String taskId,
    required String itemCode,
    required Map<String, dynamic> payload,
    String? serverResultId,
    required String syncStatus,
    String? lastError,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final exists = await db.query(
      'inspection_results',
      where: 'task_id = ? AND item_code = ?',
      whereArgs: [taskId, itemCode],
      limit: 1,
    );
    final meta = await _itemMetaFromTree(taskId);
    final chapterCode = meta['$itemCode:chapter'] ?? '';
    final itemName = meta['$itemCode:name'] ?? itemCode;

    String localId;
    if (exists.isNotEmpty) {
      localId = exists.first['local_result_id'] as String;
      await db.update(
        'inspection_results',
        {
          'server_result_id':
              serverResultId ?? exists.first['server_result_id'],
          'task_id': taskId,
          'item_code': itemCode,
          'item_name': itemName,
          'chapter_code': chapterCode,
          'check_status': payload['check_status'] ?? 'unchecked',
          'issue_flag': (payload['issue_flag'] == true) ? 1 : 0,
          'issue_type_json': jsonEncode(payload['issue_type'] ?? const []),
          'severity_level': payload['severity_level'],
          'check_record': payload['check_record'] ?? '',
          'suggestion': payload['suggestion'] ?? '',
          'sync_status': syncStatus,
          'last_error': lastError,
          'updated_at': now,
        },
        where: 'local_result_id = ?',
        whereArgs: [localId],
      );
    } else {
      localId = 'lr_${DateTime.now().microsecondsSinceEpoch}';
      await db.insert('inspection_results', {
        'local_result_id': localId,
        'server_result_id': serverResultId,
        'task_id': taskId,
        'item_code': itemCode,
        'item_name': itemName,
        'chapter_code': chapterCode,
        'check_status': payload['check_status'] ?? 'unchecked',
        'issue_flag': (payload['issue_flag'] == true) ? 1 : 0,
        'issue_type_json': jsonEncode(payload['issue_type'] ?? const []),
        'severity_level': payload['severity_level'],
        'check_record': payload['check_record'] ?? '',
        'suggestion': payload['suggestion'] ?? '',
        'sync_status': syncStatus,
        'last_error': lastError,
        'updated_at': now,
      });
    }

    return {
      'local_result_id': localId,
      'server_result_id': serverResultId,
      'task_id': taskId,
      'item_code': itemCode,
    };
  }

  Future<void> markResultSynced(
      String localResultId, String serverResultId) async {
    final db = await database;
    await db.update(
      'inspection_results',
      {
        'server_result_id': serverResultId,
        'sync_status': 'synced',
        'last_error': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'local_result_id = ?',
      whereArgs: [localResultId],
    );
  }

  Future<void> markResultFailed(String localResultId, String error) async {
    final db = await database;
    await db.update(
      'inspection_results',
      {
        'sync_status': 'failed',
        'last_error': error,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'local_result_id = ?',
      whereArgs: [localResultId],
    );
  }

  Future<List<Map<String, dynamic>>> listResultsByTask(String taskId) async {
    final db = await database;
    return db.query(
      'inspection_results',
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'updated_at DESC',
    );
  }

  Future<void> replaceResultsFromServer(
      String taskId, List<Map<String, dynamic>> items) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    for (final item in items) {
      final serverResultId = item['result_id']?.toString();
      final localRows = await db.query(
        'inspection_results',
        where: 'task_id = ? AND item_code = ?',
        whereArgs: [taskId, item['item_code']],
        limit: 1,
      );
      final localId = localRows.isNotEmpty
          ? localRows.first['local_result_id'] as String
          : 'srv_${serverResultId ?? DateTime.now().microsecondsSinceEpoch}';

      batch.insert(
        'inspection_results',
        {
          'local_result_id': localId,
          'server_result_id': serverResultId,
          'task_id': taskId,
          'item_code': item['item_code'],
          'item_name': item['item_name'] ?? '',
          'chapter_code': item['chapter_code'] ?? '',
          'check_status': item['check_status'] ?? 'unchecked',
          'issue_flag': (item['issue_flag'] == true) ? 1 : 0,
          'issue_type_json': jsonEncode(item['issue_type'] ?? const []),
          'severity_level': item['severity_level'],
          'check_record': item['check_record'] ?? '',
          'suggestion': item['suggestion'] ?? '',
          'sync_status': 'synced',
          'last_error': null,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> listPendingResults() async {
    final db = await database;
    return db.query(
      'inspection_results',
      where: "sync_status IN ('pending','failed')",
      orderBy: 'updated_at ASC',
    );
  }

  Future<List<Map<String, dynamic>>> listFailedResults() async {
    final db = await database;
    return db.query(
      'inspection_results',
      where: "sync_status = 'failed'",
      orderBy: 'updated_at ASC',
    );
  }

  Future<Map<String, dynamic>> upsertEvidenceMetadata({
    required String resultLocalId,
    required String evidenceType,
    String? localFilePath,
    String? fileUrl,
    String? serverEvidenceId,
    String? caption,
    String syncStatus = 'pending',
    bool isDeleted = false,
    String? lastError,
  }) async {
    final db = await database;
    final localEvidenceId = 'le_${DateTime.now().microsecondsSinceEpoch}';
    await db.insert('evidence_metadata', {
      'local_evidence_id': localEvidenceId,
      'server_evidence_id': serverEvidenceId,
      'result_local_id': resultLocalId,
      'evidence_type': evidenceType,
      'file_url': fileUrl,
      'local_file_path': localFilePath,
      'caption': caption,
      'shot_time': DateTime.now().toUtc().toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
      'sync_status': syncStatus,
      'last_error': lastError,
      'updated_at': DateTime.now().toIso8601String(),
    });
    return {'local_evidence_id': localEvidenceId};
  }

  Future<void> upsertEvidenceFromServer({
    required String resultLocalId,
    required Map<String, dynamic> item,
  }) async {
    final db = await database;
    final serverId = item['evidence_id']?.toString();
    if (serverId == null || serverId.isEmpty) return;
    final exist = await db.query(
      'evidence_metadata',
      where: 'server_evidence_id = ?',
      whereArgs: [serverId],
      limit: 1,
    );

    final data = {
      'local_evidence_id': exist.isNotEmpty
          ? exist.first['local_evidence_id'] as String
          : 'se_${DateTime.now().microsecondsSinceEpoch}',
      'server_evidence_id': serverId,
      'result_local_id': resultLocalId,
      'evidence_type': item['evidence_type'] ?? 'photo',
      'file_url': item['file_url'],
      'local_file_path':
          exist.isNotEmpty ? exist.first['local_file_path'] : null,
      'caption': item['caption'],
      'gps_lat': item['gps_lat'],
      'gps_lng': item['gps_lng'],
      'shot_time': item['shot_time'],
      'is_deleted': 0,
      'sync_status': 'synced',
      'last_error': null,
      'updated_at': DateTime.now().toIso8601String(),
    };

    await db.insert('evidence_metadata', data,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> listEvidenceByResultLocalId(
      String resultLocalId) async {
    final db = await database;
    return db.query(
      'evidence_metadata',
      where: 'result_local_id = ? AND is_deleted = 0',
      whereArgs: [resultLocalId],
      orderBy: 'updated_at DESC',
    );
  }

  Future<void> markEvidenceDeleted(String localEvidenceId,
      {bool pending = false}) async {
    final db = await database;
    await db.update(
      'evidence_metadata',
      {
        'is_deleted': 1,
        'sync_status': pending ? 'pending' : 'synced',
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'local_evidence_id = ?',
      whereArgs: [localEvidenceId],
    );
  }

  Future<List<Map<String, dynamic>>> listPendingEvidenceUpserts() async {
    final db = await database;
    return db.query(
      'evidence_metadata',
      where: "is_deleted = 0 AND sync_status IN ('pending','failed')",
      orderBy: 'updated_at ASC',
    );
  }

  Future<List<Map<String, dynamic>>> listFailedEvidenceUpserts() async {
    final db = await database;
    return db.query(
      'evidence_metadata',
      where: "is_deleted = 0 AND sync_status = 'failed'",
      orderBy: 'updated_at ASC',
    );
  }

  Future<List<Map<String, dynamic>>> listPendingEvidenceDeletes() async {
    final db = await database;
    return db.query(
      'evidence_metadata',
      where:
          "is_deleted = 1 AND sync_status IN ('pending','failed') AND server_evidence_id IS NOT NULL",
      orderBy: 'updated_at ASC',
    );
  }

  Future<List<Map<String, dynamic>>> listFailedEvidenceDeletes() async {
    final db = await database;
    return db.query(
      'evidence_metadata',
      where:
          "is_deleted = 1 AND sync_status = 'failed' AND server_evidence_id IS NOT NULL",
      orderBy: 'updated_at ASC',
    );
  }

  Future<void> markEvidenceSynced(String localEvidenceId,
      {String? serverEvidenceId, String? fileUrl}) async {
    final db = await database;
    await db.update(
      'evidence_metadata',
      {
        'server_evidence_id': serverEvidenceId,
        'file_url': fileUrl,
        'sync_status': 'synced',
        'last_error': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'local_evidence_id = ?',
      whereArgs: [localEvidenceId],
    );
  }

  Future<void> markEvidenceFailed(String localEvidenceId, String error) async {
    final db = await database;
    await db.update(
      'evidence_metadata',
      {
        'sync_status': 'failed',
        'last_error': error,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'local_evidence_id = ?',
      whereArgs: [localEvidenceId],
    );
  }

  Future<Map<String, dynamic>?> findResultByAnyId(String anyId) async {
    final db = await database;
    final rows = await db.query(
      'inspection_results',
      where: 'local_result_id = ? OR server_result_id = ?',
      whereArgs: [anyId, anyId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<Map<String, dynamic>?> findResultByTaskItem(
      String taskId, String itemCode) async {
    final db = await database;
    final rows = await db.query(
      'inspection_results',
      where: 'task_id = ? AND item_code = ?',
      whereArgs: [taskId, itemCode],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<Map<String, dynamic>?> findEvidenceByAnyId(String anyId) async {
    final db = await database;
    final rows = await db.query(
      'evidence_metadata',
      where: 'local_evidence_id = ? OR server_evidence_id = ?',
      whereArgs: [anyId, anyId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<void> enqueue({
    required String entityType,
    required String entityId,
    required String operation,
    String syncStatus = 'pending',
    String? lastError,
  }) async {
    final db = await database;
    await db.insert(
      'sync_queue',
      {
        'entity_type': entityType,
        'entity_id': entityId,
        'operation': operation,
        'sync_status': syncStatus,
        'last_error': lastError,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> markQueue(
    String entityType,
    String entityId,
    String operation,
    String status, {
    String? lastError,
  }) async {
    final db = await database;
    await db.update(
      'sync_queue',
      {
        'sync_status': status,
        'last_error': lastError,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'entity_type = ? AND entity_id = ? AND operation = ?',
      whereArgs: [entityType, entityId, operation],
    );
  }

  Future<Map<String, int>> getSyncStatusSummary() async {
    final db = await database;
    final summary = <String, int>{'pending': 0, 'failed': 0, 'synced': 0};

    final resultRows = await db.rawQuery('''
      SELECT sync_status, COUNT(*) AS cnt
      FROM inspection_results
      GROUP BY sync_status
    ''');
    for (final row in resultRows) {
      final key = row['sync_status']?.toString() ?? '';
      if (summary.containsKey(key)) {
        summary[key] = (summary[key] ?? 0) + (row['cnt'] as int? ?? 0);
      }
    }

    final evidenceRows = await db.rawQuery('''
      SELECT sync_status, COUNT(*) AS cnt
      FROM evidence_metadata
      WHERE is_deleted = 0
      GROUP BY sync_status
    ''');
    for (final row in evidenceRows) {
      final key = row['sync_status']?.toString() ?? '';
      if (summary.containsKey(key)) {
        summary[key] = (summary[key] ?? 0) + (row['cnt'] as int? ?? 0);
      }
    }
    return summary;
  }
}
