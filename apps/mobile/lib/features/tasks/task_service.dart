import 'dart:convert';

import '../../core/api/api_client.dart';
import '../../core/offline/local_db.dart';
import 'task_models.dart';

class TaskService {
  TaskService(this._api, {LocalDb? localDb})
      : _localDb = localDb ?? LocalDb.instance;

  final ApiClient _api;
  final LocalDb _localDb;
  bool _isLocalOnlyTask(String taskId) => taskId.startsWith('lt_');

  Future<SyncStatusSummary> getSyncStatusSummary() async {
    final map = await _localDb.getSyncStatusSummary();
    return SyncStatusSummary(
      pending: map['pending'] ?? 0,
      failed: map['failed'] ?? 0,
      synced: map['synced'] ?? 0,
    );
  }

  Future<List<TaskListItem>> fetchTasks() async {
    try {
      final data = await _api.get('/tasks') as Map<String, dynamic>;
      final items =
          (data['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      await _localDb.upsertTasks(items);
      return items.map(TaskListItem.fromJson).toList();
    } catch (_) {
      final cached = await _localDb.listTasks();
      return cached
          .map(
            (e) => TaskListItem.fromJson({
              ...e,
              'enabled_chapters':
                  jsonDecode(e['enabled_chapters_json'] as String? ?? '[]'),
            }),
          )
          .toList();
    }
  }

  Future<String> createDebugTask({required String reservoirName}) async {
    final project = await _api.post('/projects', body: {
      'reservoir_name': reservoirName,
      'dam_type': 'earthfill',
    }) as Map<String, dynamic>;
    final projectId = project['project_id'] as String;
    final now = DateTime.now().toIso8601String().split('T').first;
    final data = await _api.post('/tasks', body: {
      'project_id': projectId,
      'reservoir_name': reservoirName,
      'dam_type': 'earthfill',
      'inspection_type': 'routine',
      'inspection_date': now,
      'weather': '晴',
      'inspectors': ['mobile_user'],
      'water_level': 120.0,
      'storage': 5000000,
      'hub_main_structures': '主坝、溢洪道',
      'flood_protect_obj': '下游村庄',
      'main_problem_desc': '',
      'enabled_chapters': ['A1', 'A2', 'A4', 'A7', 'A8'],
    }) as Map<String, dynamic>;
    return data['task_id'] as String;
  }

  Future<String> createTask({
    required String projectId,
    required String reservoirName,
    required String damType,
    required String inspectionType,
    required DateTime inspectionDate,
    required String weather,
    List<String>? inspectors,
    double? waterLevel,
  }) async {
    final date = inspectionDate.toIso8601String().split('T').first;
    const enabledChapters = ['A1', 'A2', 'A3', 'A4', 'A5', 'A6', 'A7', 'A8'];
    final normalizedInspectors = (inspectors ?? const [])
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    try {
      final data = await _api.post('/tasks', body: {
        'project_id': projectId,
        'reservoir_name': reservoirName,
        'dam_type': damType,
        'inspection_type': inspectionType,
        'inspection_date': date,
        'weather': weather,
        'inspectors': normalizedInspectors,
        'water_level': waterLevel,
        'enabled_chapters': enabledChapters,
      }) as Map<String, dynamic>;
      final taskId = data['task_id'] as String;
      await fetchTasks();
      return taskId;
    } catch (e) {
      throw Exception('创建任务失败，请检查网络或项目配置: $e');
    }
  }

  Future<String> createTaskQuick({
    required String reservoirName,
    required String damType,
    required DateTime inspectionDate,
    required String weather,
  }) async {
    try {
      final projectId = await createProject(
        reservoirName: reservoirName,
        damType: damType,
      );
      return createTask(
        projectId: projectId,
        reservoirName: reservoirName,
        damType: damType,
        inspectionType: 'routine',
        inspectionDate: inspectionDate,
        weather: weather,
        inspectors: const [],
        waterLevel: null,
      );
    } catch (_) {
      final date = inspectionDate.toIso8601String().split('T').first;
      return _localDb.createLocalTask(
        reservoirName: reservoirName,
        damType: damType,
        inspectionType: 'routine',
        inspectionDate: date,
        weather: weather,
        enabledChapters: const ['A1', 'A2', 'A3', 'A4', 'A5', 'A6', 'A7', 'A8'],
      );
    }
  }

  Future<void> deleteTask(String taskId) async {
    await _api.delete('/tasks/$taskId');
  }

  Future<List<ProjectListItem>> fetchProjects(
      {bool includeArchived = false}) async {
    final data = await _api.get(
      '/projects',
      query: includeArchived ? {'include_archived': true} : null,
    ) as Map<String, dynamic>;
    final items =
        (data['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    return items.map(ProjectListItem.fromJson).toList();
  }

  Future<String> createProject({
    required String reservoirName,
    required String damType,
    String? description,
  }) async {
    final data = await _api.post('/projects', body: {
      'reservoir_name': reservoirName,
      'dam_type': damType,
      'description': description,
    }) as Map<String, dynamic>;
    return data['project_id'] as String;
  }

  Future<ProjectDetailItem> fetchProjectDetail(String projectId) async {
    final data = await _api.get('/projects/$projectId') as Map<String, dynamic>;
    return ProjectDetailItem.fromJson(data);
  }

  Future<ProjectDetailItem> updateProject({
    required String projectId,
    required String reservoirName,
    required String damType,
    String? description,
  }) async {
    final data = await _api.patch('/projects/$projectId', body: {
      'reservoir_name': reservoirName,
      'dam_type': damType,
      'description': description,
    }) as Map<String, dynamic>;
    return ProjectDetailItem.fromJson(data);
  }

  Future<void> deleteProject(String projectId, {bool force = false}) async {
    final suffix = force ? '?force=true' : '';
    await _api.delete('/projects/$projectId$suffix');
  }

  Future<void> archiveProject(String projectId) async {
    await _api.patch('/projects/$projectId/archive', body: {});
  }

  Future<List<StructureInstanceItem>> fetchProjectStructureInstances(
      String projectId) async {
    final data = await _api.get('/projects/$projectId/structure-instances')
        as Map<String, dynamic>;
    final items =
        (data['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    return items.map(StructureInstanceItem.fromJson).toList();
  }

  Future<List<StructureInstanceItem>> batchInitStructureInstances({
    required String projectId,
    required List<Map<String, dynamic>> presets,
    List<Map<String, dynamic>> customInstances = const [],
  }) async {
    final data = await _api.post(
      '/projects/$projectId/structure-instances/batch-init',
      body: {
        'presets': presets,
        'custom_instances': customInstances,
      },
    ) as Map<String, dynamic>;
    final items =
        (data['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    return items.map(StructureInstanceItem.fromJson).toList();
  }

  Future<StructureInstanceItem> createStructureInstance({
    required String projectId,
    required String objectType,
    required String instanceName,
    String? categoryCode,
    String? templateSourceType,
  }) async {
    final data =
        await _api.post('/projects/$projectId/structure-instances', body: {
      'object_type': objectType,
      'instance_name': instanceName,
      if (categoryCode != null) 'category_code': categoryCode,
      if (templateSourceType != null)
        'template_source_type': templateSourceType,
    }) as Map<String, dynamic>;
    return StructureInstanceItem.fromJson(data);
  }

  Future<StructureInstanceItem> patchStructureInstance({
    required String projectId,
    required String instanceId,
    String? instanceName,
    bool? enabledForCapture,
    bool? enabledForReport,
    int? sortOrder,
  }) async {
    final data = await _api.patch(
      '/projects/$projectId/structure-instances/$instanceId',
      body: {
        if (instanceName != null) 'instance_name': instanceName,
        if (enabledForCapture != null) 'enabled_for_capture': enabledForCapture,
        if (enabledForReport != null) 'enabled_for_report': enabledForReport,
        if (sortOrder != null) 'sort_order': sortOrder,
      },
    ) as Map<String, dynamic>;
    return StructureInstanceItem.fromJson(data);
  }

  Future<List<StructurePartTemplateItem>> fetchStructurePartTemplates({
    String? objectType,
  }) async {
    final query = objectType == null ? null : {'object_type': objectType};
    final data = await _api.get('/structure-part-templates', query: query)
        as Map<String, dynamic>;
    final items =
        (data['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    return items.map(StructurePartTemplateItem.fromJson).toList();
  }

  Future<TaskDetail> fetchTaskDetail(String taskId) async {
    if (_isLocalOnlyTask(taskId)) {
      final cached = await _localDb.getTask(taskId);
      if (cached == null) {
        throw Exception('task not found');
      }
      return TaskDetail.fromJson(cached);
    }
    try {
      final data = await _api.get('/tasks/$taskId') as Map<String, dynamic>;
      await _localDb.upsertTasks([data]);
      return TaskDetail.fromJson(data);
    } catch (_) {
      final cached = await _localDb.getTask(taskId);
      if (cached == null) {
        rethrow;
      }
      return TaskDetail.fromJson(cached);
    }
  }

  Future<List<TemplateChapter>> fetchTemplateTree(String taskId) async {
    if (_isLocalOnlyTask(taskId)) {
      final tree = await _localDb.getTemplateTree(taskId);
      return tree
          .map((e) => TemplateChapter.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    try {
      final data =
          await _api.get('/tasks/$taskId/template-tree') as List<dynamic>;
      await _localDb.upsertTemplateTree(taskId, data);
      return data
          .map((e) => TemplateChapter.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      final tree = await _localDb.getTemplateTree(taskId);
      return tree
          .map((e) => TemplateChapter.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }

  Future<List<TaskResultItem>> fetchTaskResults(
    String taskId, {
    String? chapterCode,
    bool? issueFlag,
    String? checkStatus,
  }) async {
    if (_isLocalOnlyTask(taskId)) {
      final rows = await _localDb.listResultsByTask(taskId);
      final allEvidence = <String, int>{};
      for (final row in rows) {
        final localId = row['local_result_id']?.toString() ?? '';
        if (localId.isEmpty) continue;
        final ev = await _localDb.listEvidenceByResultLocalId(localId);
        allEvidence[localId] = ev.length;
      }

      final filtered = rows.where((row) {
        if (chapterCode != null &&
            chapterCode.isNotEmpty &&
            row['chapter_code'] != chapterCode) {
          return false;
        }
        if (issueFlag != null && ((row['issue_flag'] == 1) != issueFlag)) {
          return false;
        }
        if (checkStatus != null &&
            checkStatus.isNotEmpty &&
            row['check_status'] != checkStatus) {
          return false;
        }
        return true;
      });

      return filtered.map((row) {
        final localId = row['local_result_id']?.toString() ?? '';
        return TaskResultItem.fromJson({
          'result_id': row['server_result_id'] ?? localId,
          'item_code': row['item_code'] ?? '',
          'item_name': row['item_name'] ?? '',
          'chapter_code': row['chapter_code'] ?? '',
          'check_status': row['check_status'] ?? 'unchecked',
          'issue_flag': row['issue_flag'] == 1,
          'issue_type': jsonDecode(row['issue_type_json'] as String? ?? '[]'),
          'severity_level': row['severity_level'],
          'check_record': row['check_record'] ?? '',
          'suggestion': row['suggestion'] ?? '',
          'evidence_count': allEvidence[localId] ?? 0,
          'sync_status': row['sync_status'] ?? 'pending',
        });
      }).toList();
    }
    try {
      final query = <String, dynamic>{};
      if (chapterCode != null && chapterCode.isNotEmpty) {
        query['chapter_code'] = chapterCode;
      }
      if (issueFlag != null) {
        query['issue_flag'] = issueFlag;
      }
      if (checkStatus != null && checkStatus.isNotEmpty) {
        query['check_status'] = checkStatus;
      }
      final data = await _api.get('/tasks/$taskId/results', query: query)
          as Map<String, dynamic>;
      final items =
          (data['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      await _localDb.replaceResultsFromServer(taskId, items);
      return items
          .map((e) => TaskResultItem.fromJson({...e, 'sync_status': 'synced'}))
          .toList();
    } catch (_) {
      final rows = await _localDb.listResultsByTask(taskId);
      final allEvidence = <String, int>{};
      for (final row in rows) {
        final localId = row['local_result_id']?.toString() ?? '';
        if (localId.isEmpty) continue;
        final ev = await _localDb.listEvidenceByResultLocalId(localId);
        allEvidence[localId] = ev.length;
      }

      final filtered = rows.where((row) {
        if (chapterCode != null &&
            chapterCode.isNotEmpty &&
            row['chapter_code'] != chapterCode) {
          return false;
        }
        if (issueFlag != null && ((row['issue_flag'] == 1) != issueFlag)) {
          return false;
        }
        if (checkStatus != null &&
            checkStatus.isNotEmpty &&
            row['check_status'] != checkStatus) {
          return false;
        }
        return true;
      });

      return filtered.map((row) {
        final localId = row['local_result_id']?.toString() ?? '';
        return TaskResultItem.fromJson({
          'result_id': row['server_result_id'] ?? localId,
          'item_code': row['item_code'] ?? '',
          'item_name': row['item_name'] ?? '',
          'chapter_code': row['chapter_code'] ?? '',
          'check_status': row['check_status'] ?? 'unchecked',
          'issue_flag': row['issue_flag'] == 1,
          'issue_type': jsonDecode(row['issue_type_json'] as String? ?? '[]'),
          'severity_level': row['severity_level'],
          'check_record': row['check_record'] ?? '',
          'suggestion': row['suggestion'] ?? '',
          'evidence_count': allEvidence[localId] ?? 0,
          'sync_status': row['sync_status'] ?? 'pending',
        });
      }).toList();
    }
  }

  Future<TaskProgress> fetchTaskProgress(String taskId) async {
    if (_isLocalOnlyTask(taskId)) {
      final tree = await _localDb.getTemplateTree(taskId);
      final rows = await _localDb.listResultsByTask(taskId);
      final total = tree.cast<Map<String, dynamic>>().fold<int>(
          0,
          (s, ch) =>
              s +
              (ch['children'] as List<dynamic>? ?? [])
                  .cast<Map<String, dynamic>>()
                  .fold<int>(
                      0,
                      (ss, sec) =>
                          ss +
                          ((sec['children'] as List<dynamic>? ?? []).length)));

      final completed = rows
          .where((r) =>
              (r['check_status']?.toString() ?? 'unchecked') != 'unchecked')
          .length;
      final percent = total == 0 ? 0.0 : ((completed / total) * 100);
      return TaskProgress(
          completed: completed,
          total: total,
          percent: double.parse(percent.toStringAsFixed(1)));
    }
    try {
      final data =
          await _api.get('/tasks/$taskId/progress') as Map<String, dynamic>;
      return TaskProgress.fromJson(data);
    } catch (_) {
      final tree = await _localDb.getTemplateTree(taskId);
      final rows = await _localDb.listResultsByTask(taskId);
      final total = tree.cast<Map<String, dynamic>>().fold<int>(
          0,
          (s, ch) =>
              s +
              (ch['children'] as List<dynamic>? ?? [])
                  .cast<Map<String, dynamic>>()
                  .fold<int>(
                      0,
                      (ss, sec) =>
                          ss +
                          ((sec['children'] as List<dynamic>? ?? []).length)));

      final completed = rows
          .where((r) =>
              (r['check_status']?.toString() ?? 'unchecked') != 'unchecked')
          .length;
      final percent = total == 0 ? 0.0 : ((completed / total) * 100);
      return TaskProgress(
          completed: completed,
          total: total,
          percent: double.parse(percent.toStringAsFixed(1)));
    }
  }

  Future<String> saveResult({
    required String taskId,
    required String itemCode,
    required String checkStatus,
    required bool issueFlag,
    required List<String> issueType,
    required String? severityLevel,
    required String checkRecord,
    required String suggestion,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final payload = {
      'task_id': taskId,
      'item_code': itemCode,
      'check_status': checkStatus,
      'issue_flag': issueFlag,
      'issue_type': issueFlag ? issueType : <String>[],
      'severity_level': issueFlag ? severityLevel : null,
      'check_record': checkRecord,
      'suggestion': suggestion,
      'location_desc': '',
      'gps_lat': null,
      'gps_lng': null,
      'checked_at': now,
      'checked_by': 'mobile_user',
    };

    try {
      final data =
          await _api.post('/results', body: payload) as Map<String, dynamic>;
      final serverId = data['result_id'] as String;
      final row = await _localDb.upsertResultFromPayload(
        taskId: taskId,
        itemCode: itemCode,
        payload: payload,
        serverResultId: serverId,
        syncStatus: 'synced',
      );
      await _localDb.markQueue(
          'result', row['local_result_id'] as String, 'upsert', 'synced');
      return serverId;
    } catch (e) {
      final row = await _localDb.upsertResultFromPayload(
        taskId: taskId,
        itemCode: itemCode,
        payload: payload,
        syncStatus: 'pending',
        lastError: e.toString(),
      );
      final localResultId = row['local_result_id'] as String;
      await _localDb.enqueue(
          entityType: 'result', entityId: localResultId, operation: 'upsert');
      return localResultId;
    }
  }

  Future<String> getResultSyncStatus({
    required String taskId,
    required String itemCode,
    String? resultId,
  }) async {
    Map<String, dynamic>? row;
    if (resultId != null && resultId.isNotEmpty) {
      row = await _localDb.findResultByAnyId(resultId);
    }
    row ??= await _localDb.findResultByTaskItem(taskId, itemCode);
    return row?['sync_status']?.toString() ?? 'pending';
  }

  Future<List<EvidenceItem>> fetchResultEvidence(String resultId) async {
    final resultRow = await _localDb.findResultByAnyId(resultId);
    final localResultId = resultRow?['local_result_id']?.toString() ?? resultId;
    final serverResultId = resultRow?['server_result_id']?.toString();

    if (serverResultId != null && serverResultId.isNotEmpty) {
      try {
        final data = await _api.get('/results/$serverResultId/evidence')
            as Map<String, dynamic>;
        final items = (data['items'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        for (final item in items) {
          await _localDb.upsertEvidenceFromServer(
              resultLocalId: localResultId, item: item);
        }
      } catch (_) {
        // fallback to local cache below
      }
    }

    final localItems =
        await _localDb.listEvidenceByResultLocalId(localResultId);
    return localItems
        .map(
          (row) => EvidenceItem.fromJson({
            'evidence_id':
                row['server_evidence_id'] ?? row['local_evidence_id'],
            'evidence_type': row['evidence_type'] ?? 'photo',
            'file_url': row['file_url'] ?? row['local_file_path'] ?? '',
            'caption': row['caption'],
            'gps_lat': row['gps_lat'],
            'gps_lng': row['gps_lng'],
            'shot_time': row['shot_time'],
            'sync_status': row['sync_status'] ?? 'pending',
          }),
        )
        .map(
          (e) => EvidenceItem(
            evidenceId: e.evidenceId,
            evidenceType: e.evidenceType,
            fileUrl: e.fileUrl.startsWith('http')
                ? e.fileUrl
                : _api.resolveUrl(e.fileUrl),
            caption: e.caption,
            gpsLat: e.gpsLat,
            gpsLng: e.gpsLng,
            shotTime: e.shotTime,
            syncStatus: e.syncStatus,
          ),
        )
        .toList();
  }

  Future<String> uploadPhotoEvidence({
    required String resultId,
    required String filePath,
    String? caption,
  }) async {
    final resultRow = await _localDb.findResultByAnyId(resultId);
    final localResultId = resultRow?['local_result_id']?.toString() ?? resultId;
    final serverResultId = resultRow?['server_result_id']?.toString();

    if (serverResultId != null && serverResultId.isNotEmpty) {
      try {
        final data = await _api.postMultipart(
          '/evidence/upload',
          fileField: 'file',
          filePath: filePath,
          fields: {
            'result_id': serverResultId,
            'evidence_type': 'photo',
            if (caption != null && caption.trim().isNotEmpty)
              'caption': caption.trim(),
            'shot_time': DateTime.now().toUtc().toIso8601String(),
          },
        ) as Map<String, dynamic>;

        final serverEvidenceId = data['evidence_id']?.toString() ?? '';
        final fileUrl = data['file_url']?.toString();
        final saved = await _localDb.upsertEvidenceMetadata(
          resultLocalId: localResultId,
          evidenceType: 'photo',
          localFilePath: filePath,
          fileUrl: fileUrl,
          serverEvidenceId: serverEvidenceId,
          caption: caption,
          syncStatus: 'synced',
        );
        await _localDb.markQueue('evidence',
            saved['local_evidence_id'] as String, 'upsert', 'synced');
        return serverEvidenceId.isNotEmpty
            ? serverEvidenceId
            : (saved['local_evidence_id'] as String);
      } catch (e) {
        final saved = await _localDb.upsertEvidenceMetadata(
          resultLocalId: localResultId,
          evidenceType: 'photo',
          localFilePath: filePath,
          caption: caption,
          syncStatus: 'pending',
          lastError: e.toString(),
        );
        final localEvidenceId = saved['local_evidence_id'] as String;
        await _localDb.enqueue(
            entityType: 'evidence',
            entityId: localEvidenceId,
            operation: 'upsert');
        return localEvidenceId;
      }
    }

    final saved = await _localDb.upsertEvidenceMetadata(
      resultLocalId: localResultId,
      evidenceType: 'photo',
      localFilePath: filePath,
      caption: caption,
      syncStatus: 'pending',
      lastError: 'result not synced yet',
    );
    final localEvidenceId = saved['local_evidence_id'] as String;
    await _localDb.enqueue(
        entityType: 'evidence', entityId: localEvidenceId, operation: 'upsert');
    return localEvidenceId;
  }

  Future<void> deleteEvidence(String evidenceId) async {
    final row = await _localDb.findEvidenceByAnyId(evidenceId);
    if (row == null) {
      try {
        await _api.delete('/evidence/$evidenceId');
      } catch (_) {
        rethrow;
      }
      return;
    }

    final localEvidenceId = row['local_evidence_id'] as String;
    final serverEvidenceId = row['server_evidence_id']?.toString();

    if (serverEvidenceId != null && serverEvidenceId.isNotEmpty) {
      try {
        await _api.delete('/evidence/$serverEvidenceId');
        await _localDb.markEvidenceDeleted(localEvidenceId, pending: false);
        await _localDb.markQueue(
            'evidence', localEvidenceId, 'delete', 'synced');
      } catch (e) {
        await _localDb.markEvidenceDeleted(localEvidenceId, pending: true);
        await _localDb.enqueue(
            entityType: 'evidence',
            entityId: localEvidenceId,
            operation: 'delete');
        await _localDb.markEvidenceFailed(localEvidenceId, e.toString());
      }
      return;
    }

    await _localDb.markEvidenceDeleted(localEvidenceId, pending: false);
  }

  Future<SyncSummary> manualSync({bool onlyFailed = false}) async {
    int syncedResults = 0;
    int failedResults = 0;
    int syncedEvidence = 0;
    int failedEvidence = 0;

    final pendingResults = onlyFailed
        ? await _localDb.listFailedResults()
        : await _localDb.listPendingResults();
    for (final row in pendingResults) {
      final payload = {
        'task_id': row['task_id'],
        'item_code': row['item_code'],
        'check_status': row['check_status'] ?? 'unchecked',
        'issue_flag': row['issue_flag'] == 1,
        'issue_type': jsonDecode(row['issue_type_json'] as String? ?? '[]'),
        'severity_level': row['severity_level'],
        'check_record': row['check_record'] ?? '',
        'suggestion': row['suggestion'] ?? '',
        'location_desc': '',
        'gps_lat': null,
        'gps_lng': null,
        'checked_at': DateTime.now().toUtc().toIso8601String(),
        'checked_by': 'mobile_user',
      };
      final localId = row['local_result_id'] as String;
      try {
        final data =
            await _api.post('/results', body: payload) as Map<String, dynamic>;
        final serverId = data['result_id'] as String;
        await _localDb.markResultSynced(localId, serverId);
        await _localDb.markQueue('result', localId, 'upsert', 'synced');
        syncedResults += 1;
      } catch (e) {
        await _localDb.markResultFailed(localId, e.toString());
        await _localDb.markQueue('result', localId, 'upsert', 'failed',
            lastError: e.toString());
        failedResults += 1;
      }
    }

    final pendingEvidence = onlyFailed
        ? await _localDb.listFailedEvidenceUpserts()
        : await _localDb.listPendingEvidenceUpserts();
    for (final row in pendingEvidence) {
      final localEvidenceId = row['local_evidence_id'] as String;
      final resultLocalId = row['result_local_id'] as String;
      final resultRow = await _localDb.findResultByAnyId(resultLocalId);
      final serverResultId = resultRow?['server_result_id']?.toString();
      final localPath = row['local_file_path']?.toString();

      if (serverResultId == null ||
          serverResultId.isEmpty ||
          localPath == null ||
          localPath.isEmpty) {
        await _localDb.markEvidenceFailed(
            localEvidenceId, 'missing server_result_id or local_file_path');
        await _localDb.markQueue(
            'evidence', localEvidenceId, 'upsert', 'failed',
            lastError: 'missing server_result_id or local_file_path');
        failedEvidence += 1;
        continue;
      }

      try {
        final data = await _api.postMultipart(
          '/evidence/upload',
          fileField: 'file',
          filePath: localPath,
          fields: {
            'result_id': serverResultId,
            'evidence_type': 'photo',
            if ((row['caption']?.toString() ?? '').isNotEmpty)
              'caption': row['caption'].toString(),
            'shot_time': row['shot_time']?.toString() ??
                DateTime.now().toUtc().toIso8601String(),
          },
        ) as Map<String, dynamic>;
        await _localDb.markEvidenceSynced(
          localEvidenceId,
          serverEvidenceId: data['evidence_id']?.toString(),
          fileUrl: data['file_url']?.toString(),
        );
        await _localDb.markQueue(
            'evidence', localEvidenceId, 'upsert', 'synced');
        syncedEvidence += 1;
      } catch (e) {
        await _localDb.markEvidenceFailed(localEvidenceId, e.toString());
        await _localDb.markQueue(
            'evidence', localEvidenceId, 'upsert', 'failed',
            lastError: e.toString());
        failedEvidence += 1;
      }
    }

    final pendingDeletes = onlyFailed
        ? await _localDb.listFailedEvidenceDeletes()
        : await _localDb.listPendingEvidenceDeletes();
    for (final row in pendingDeletes) {
      final localEvidenceId = row['local_evidence_id'] as String;
      final serverEvidenceId = row['server_evidence_id'] as String;
      try {
        await _api.delete('/evidence/$serverEvidenceId');
        await _localDb.markEvidenceSynced(localEvidenceId,
            serverEvidenceId: serverEvidenceId);
        await _localDb.markQueue(
            'evidence', localEvidenceId, 'delete', 'synced');
      } catch (e) {
        await _localDb.markEvidenceFailed(localEvidenceId, e.toString());
        await _localDb.markQueue(
            'evidence', localEvidenceId, 'delete', 'failed',
            lastError: e.toString());
      }
    }

    return SyncSummary(
      syncedResults: syncedResults,
      failedResults: failedResults,
      syncedEvidence: syncedEvidence,
      failedEvidence: failedEvidence,
    );
  }

  Future<SyncSummary> retryFailedSync() => manualSync(onlyFailed: true);

  Future<String> exportIssueList(String taskId) async {
    final data = await _api.get('/tasks/$taskId/exports/issues-list')
        as Map<String, dynamic>;
    final url = data['file_url'] as String? ?? '';
    if (url.isEmpty) {
      throw Exception('empty export url');
    }
    return _api.resolveUrl(url);
  }

  Future<String> exportPhotoSheet(String taskId) async {
    final data = await _api.get('/tasks/$taskId/exports/photo-sheet')
        as Map<String, dynamic>;
    final url = data['file_url'] as String? ?? '';
    if (url.isEmpty) {
      throw Exception('empty export url');
    }
    return _api.resolveUrl(url);
  }

  Future<String> createCapture({
    required String taskId,
    required String structureInstanceId,
    required String partCode,
    required String quickPartTag,
    required String quickStatus,
    String? rawNote,
    String? speechText,
    String? createdBy,
    double? gpsLat,
    double? gpsLng,
    String? locationDesc,
  }) async {
    final data = await _api.post('/captures', body: {
      'task_id': taskId,
      'structure_instance_id': structureInstanceId,
      'part_code': partCode,
      'quick_part_tag': quickPartTag,
      'quick_status': quickStatus,
      'raw_note': rawNote,
      'speech_text': speechText,
      'created_by': createdBy,
      'gps_lat': gpsLat,
      'gps_lng': gpsLng,
      'location_desc': locationDesc,
    }) as Map<String, dynamic>;
    return data['capture_id'] as String;
  }

  Future<void> uploadCaptureMedia({
    required String captureId,
    required String filePath,
    String mediaType = 'photo',
  }) async {
    await _api.postMultipart(
      '/captures/$captureId/media',
      fileField: 'file',
      filePath: filePath,
      fields: {'media_type': mediaType},
    );
  }

  Future<void> updateCaptureSpeechText({
    required String captureId,
    required String speechText,
  }) async {
    await _api.post(
      '/captures/$captureId/speech-transcribe',
      body: {'speech_text': speechText},
    );
  }

  Future<List<CaptureListItem>> fetchTaskCaptures(
    String taskId, {
    String reviewStatus = 'pending',
  }) async {
    final data = await _api.get(
      '/tasks/$taskId/captures',
      query: {'review_status': reviewStatus},
    ) as Map<String, dynamic>;
    final items =
        (data['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    return items.map(CaptureListItem.fromJson).toList();
  }

  Future<CaptureDetail> fetchCaptureDetail(String captureId) async {
    final data = await _api.get('/captures/$captureId') as Map<String, dynamic>;
    final raw = CaptureDetail.fromJson(data);
    final mappedMedia = raw.media
        .map(
          (m) => CaptureMediaItem(
            mediaId: m.mediaId,
            mediaType: m.mediaType,
            localPath: m.localPath,
            serverUrl: (m.serverUrl == null || m.serverUrl!.isEmpty)
                ? null
                : (m.serverUrl!.startsWith('http')
                    ? m.serverUrl
                    : _api.resolveUrl(m.serverUrl!)),
            shotTime: m.shotTime,
          ),
        )
        .toList();
    return CaptureDetail(
      captureId: raw.captureId,
      taskId: raw.taskId,
      createdAt: raw.createdAt,
      createdBy: raw.createdBy,
      structureInstanceId: raw.structureInstanceId,
      structureInstanceName: raw.structureInstanceName,
      partCode: raw.partCode,
      partName: raw.partName,
      quickPartTag: raw.quickPartTag,
      quickStatus: raw.quickStatus,
      rawNote: raw.rawNote,
      speechText: raw.speechText,
      reviewStatus: raw.reviewStatus,
      linkedResultId: raw.linkedResultId,
      media: mappedMedia,
    );
  }

  Future<String> confirmCapture({
    required String captureId,
    required String itemCode,
    required String checkStatus,
    required bool issueFlag,
    required List<String> issueType,
    String? severityLevel,
    String? checkRecord,
    String? suggestion,
    String? checkedBy,
  }) async {
    final data = await _api.post('/captures/$captureId/confirm', body: {
      'item_code': itemCode,
      'check_status': checkStatus,
      'issue_flag': issueFlag,
      'issue_type': issueType,
      'severity_level': severityLevel,
      'check_record': checkRecord,
      'suggestion': suggestion,
      'checked_by': checkedBy,
    }) as Map<String, dynamic>;
    return data['result_id'] as String;
  }
}
