class ProjectListItem {
  ProjectListItem({
    required this.projectId,
    required this.projectName,
    required this.reservoirName,
    required this.damType,
    required this.archivedAt,
  });

  factory ProjectListItem.fromJson(Map<String, dynamic> json) {
    return ProjectListItem(
      projectId: json['project_id'] as String? ?? '',
      projectName: json['project_name'] as String? ?? '',
      reservoirName: json['reservoir_name'] as String? ?? '',
      damType: json['dam_type'] as String? ?? '',
      archivedAt: DateTime.tryParse(json['archived_at'] as String? ?? ''),
    );
  }

  final String projectId;
  final String projectName;
  final String reservoirName;
  final String damType;
  final DateTime? archivedAt;

  String get displayName =>
      projectName.isNotEmpty ? projectName : reservoirName;
}

class ProjectDetailItem {
  ProjectDetailItem({
    required this.projectId,
    required this.projectName,
    required this.reservoirName,
    required this.damType,
    required this.description,
    required this.archivedAt,
  });

  factory ProjectDetailItem.fromJson(Map<String, dynamic> json) {
    return ProjectDetailItem(
      projectId: json['project_id'] as String? ?? '',
      projectName: json['project_name'] as String? ?? '',
      reservoirName: json['reservoir_name'] as String? ?? '',
      damType: json['dam_type'] as String? ?? '',
      description: json['description'] as String?,
      archivedAt: DateTime.tryParse(json['archived_at'] as String? ?? ''),
    );
  }

  final String projectId;
  final String projectName;
  final String reservoirName;
  final String damType;
  final String? description;
  final DateTime? archivedAt;
}

class StructureInstanceItem {
  StructureInstanceItem({
    required this.instanceId,
    required this.projectId,
    required this.categoryCode,
    required this.objectType,
    required this.instanceName,
    required this.templateSourceType,
    required this.enabledForCapture,
    required this.enabledForReport,
    required this.defaultPartTemplateCode,
    required this.sortOrder,
  });

  factory StructureInstanceItem.fromJson(Map<String, dynamic> json) {
    return StructureInstanceItem(
      instanceId: json['instance_id'] as String? ?? '',
      projectId: json['project_id'] as String? ?? '',
      categoryCode: json['category_code'] as String? ?? 'other',
      objectType: json['object_type'] as String? ?? 'custom',
      instanceName: json['instance_name'] as String? ?? '',
      templateSourceType: json['template_source_type'] as String? ?? 'main_dam',
      enabledForCapture: json['enabled_for_capture'] as bool? ?? true,
      enabledForReport: json['enabled_for_report'] as bool? ?? true,
      defaultPartTemplateCode:
          json['default_part_template_code'] as String? ?? 'main_dam',
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  final String instanceId;
  final String projectId;
  final String categoryCode;
  final String objectType;
  final String instanceName;
  final String templateSourceType;
  final bool enabledForCapture;
  final bool enabledForReport;
  final String defaultPartTemplateCode;
  final int sortOrder;
}

class StructurePartTemplateItem {
  StructurePartTemplateItem({
    required this.templateCode,
    required this.objectType,
    required this.partCode,
    required this.partName,
    required this.sortOrder,
  });

  factory StructurePartTemplateItem.fromJson(Map<String, dynamic> json) {
    return StructurePartTemplateItem(
      templateCode: json['template_code'] as String? ?? '',
      objectType: json['object_type'] as String? ?? '',
      partCode: json['part_code'] as String? ?? '',
      partName: json['part_name'] as String? ?? '',
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  final String templateCode;
  final String objectType;
  final String partCode;
  final String partName;
  final int sortOrder;
}

class TaskListItem {
  TaskListItem({
    required this.taskId,
    required this.projectId,
    required this.reservoirName,
    required this.damType,
    required this.inspectionDate,
    required this.status,
    required this.issueCount,
  });

  factory TaskListItem.fromJson(Map<String, dynamic> json) {
    return TaskListItem(
      taskId: json['task_id'] as String? ?? '',
      projectId: json['project_id'] as String? ?? '',
      reservoirName: json['reservoir_name'] as String? ?? '',
      damType: json['dam_type'] as String? ?? '',
      inspectionDate: json['inspection_date'] as String? ?? '',
      status: json['status'] as String? ?? '',
      issueCount: json['issue_count'] as int? ?? 0,
    );
  }

  final String taskId;
  final String projectId;
  final String reservoirName;
  final String damType;
  final String inspectionDate;
  final String status;
  final int issueCount;
}

class TaskDetail {
  TaskDetail({
    required this.taskId,
    required this.projectId,
    required this.reservoirName,
    required this.damType,
    required this.inspectionDate,
    required this.status,
    required this.enabledChapters,
    this.weather,
    this.inspectionType,
  });

  factory TaskDetail.fromJson(Map<String, dynamic> json) {
    return TaskDetail(
      taskId: json['task_id'] as String? ?? '',
      projectId: json['project_id'] as String? ?? '',
      reservoirName: json['reservoir_name'] as String? ?? '',
      damType: json['dam_type'] as String? ?? '',
      inspectionDate: json['inspection_date'] as String? ?? '',
      status: json['status'] as String? ?? '',
      enabledChapters: (json['enabled_chapters'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      weather: json['weather'] as String?,
      inspectionType: json['inspection_type'] as String?,
    );
  }

  final String taskId;
  final String projectId;
  final String reservoirName;
  final String damType;
  final String inspectionDate;
  final String status;
  final List<String> enabledChapters;
  final String? weather;
  final String? inspectionType;
}

class TemplateChapter {
  TemplateChapter({
    required this.chapterCode,
    required this.chapterName,
    required this.children,
  });

  factory TemplateChapter.fromJson(Map<String, dynamic> json) {
    return TemplateChapter(
      chapterCode: json['chapter_code'] as String? ?? '',
      chapterName: json['chapter_name'] as String? ?? '',
      children: (json['children'] as List<dynamic>? ?? [])
          .map((e) => TemplateSection.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final String chapterCode;
  final String chapterName;
  final List<TemplateSection> children;
}

class TemplateSection {
  TemplateSection({
    required this.itemCode,
    required this.itemName,
    required this.children,
  });

  factory TemplateSection.fromJson(Map<String, dynamic> json) {
    return TemplateSection(
      itemCode: json['item_code'] as String? ?? '',
      itemName: json['item_name'] as String? ?? '',
      children: (json['children'] as List<dynamic>? ?? [])
          .map(
              (e) => TemplateInspectionItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final String itemCode;
  final String itemName;
  final List<TemplateInspectionItem> children;
}

class TemplateInspectionItem {
  TemplateInspectionItem({
    required this.itemCode,
    required this.itemName,
    required this.supportsPhoto,
    required this.supportsAudio,
    required this.supportsLocation,
    required this.supportsAttachment,
  });

  factory TemplateInspectionItem.fromJson(Map<String, dynamic> json) {
    return TemplateInspectionItem(
      itemCode: json['item_code'] as String? ?? '',
      itemName: json['item_name'] as String? ?? '',
      supportsPhoto: json['supports_photo'] as bool? ?? false,
      supportsAudio: json['supports_audio'] as bool? ?? false,
      supportsLocation: json['supports_location'] as bool? ?? false,
      supportsAttachment: json['supports_attachment'] as bool? ?? false,
    );
  }

  final String itemCode;
  final String itemName;
  final bool supportsPhoto;
  final bool supportsAudio;
  final bool supportsLocation;
  final bool supportsAttachment;
}

class TaskResultItem {
  TaskResultItem({
    required this.resultId,
    required this.itemCode,
    required this.itemName,
    required this.chapterCode,
    required this.checkStatus,
    required this.issueFlag,
    required this.issueType,
    required this.severityLevel,
    required this.checkRecord,
    required this.suggestion,
    required this.evidenceCount,
    required this.syncStatus,
  });

  factory TaskResultItem.fromJson(Map<String, dynamic> json) {
    return TaskResultItem(
      resultId: json['result_id'] as String? ?? '',
      itemCode: json['item_code'] as String? ?? '',
      itemName: json['item_name'] as String? ?? '',
      chapterCode: json['chapter_code'] as String? ?? '',
      checkStatus: json['check_status'] as String? ?? 'unchecked',
      issueFlag: json['issue_flag'] as bool? ?? false,
      issueType: (json['issue_type'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      severityLevel: json['severity_level'] as String?,
      checkRecord: json['check_record'] as String? ?? '',
      suggestion: json['suggestion'] as String? ?? '',
      evidenceCount: json['evidence_count'] as int? ?? 0,
      syncStatus: json['sync_status'] as String? ?? 'synced',
    );
  }

  final String resultId;
  final String itemCode;
  final String itemName;
  final String chapterCode;
  final String checkStatus;
  final bool issueFlag;
  final List<String> issueType;
  final String? severityLevel;
  final String checkRecord;
  final String suggestion;
  final int evidenceCount;
  final String syncStatus;
}

class TaskProgress {
  TaskProgress({
    required this.completed,
    required this.total,
    required this.percent,
  });

  factory TaskProgress.fromJson(Map<String, dynamic> json) {
    final overall = json['overall'] as Map<String, dynamic>? ?? {};
    return TaskProgress(
      completed: overall['completed'] as int? ?? 0,
      total: overall['total'] as int? ?? 0,
      percent: (overall['percent'] as num? ?? 0).toDouble(),
    );
  }

  final int completed;
  final int total;
  final double percent;
}

class EvidenceItem {
  EvidenceItem({
    required this.evidenceId,
    required this.evidenceType,
    required this.fileUrl,
    required this.caption,
    required this.gpsLat,
    required this.gpsLng,
    required this.shotTime,
    required this.syncStatus,
  });

  factory EvidenceItem.fromJson(Map<String, dynamic> json) {
    return EvidenceItem(
      evidenceId: json['evidence_id'] as String? ?? '',
      evidenceType: json['evidence_type'] as String? ?? '',
      fileUrl: json['file_url'] as String? ?? '',
      caption: json['caption'] as String?,
      gpsLat: (json['gps_lat'] as num?)?.toDouble(),
      gpsLng: (json['gps_lng'] as num?)?.toDouble(),
      shotTime: DateTime.tryParse(json['shot_time'] as String? ?? ''),
      syncStatus: json['sync_status'] as String? ?? 'synced',
    );
  }

  final String evidenceId;
  final String evidenceType;
  final String fileUrl;
  final String? caption;
  final double? gpsLat;
  final double? gpsLng;
  final DateTime? shotTime;
  final String syncStatus;
}

class SyncSummary {
  SyncSummary({
    required this.syncedResults,
    required this.failedResults,
    required this.syncedEvidence,
    required this.failedEvidence,
  });

  final int syncedResults;
  final int failedResults;
  final int syncedEvidence;
  final int failedEvidence;
}

class SyncStatusSummary {
  SyncStatusSummary({
    required this.pending,
    required this.failed,
    required this.synced,
  });

  final int pending;
  final int failed;
  final int synced;
}

class CaptureListItem {
  CaptureListItem({
    required this.captureId,
    required this.taskId,
    required this.createdAt,
    required this.structureInstanceId,
    required this.structureInstanceName,
    required this.partCode,
    required this.partName,
    required this.quickPartTag,
    required this.quickStatus,
    required this.speechText,
    required this.rawNote,
    required this.reviewStatus,
    required this.linkedResultId,
    required this.photoCount,
  });

  factory CaptureListItem.fromJson(Map<String, dynamic> json) {
    return CaptureListItem(
      captureId: json['capture_id'] as String? ?? '',
      taskId: json['task_id'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      structureInstanceId: json['structure_instance_id'] as String? ?? '',
      structureInstanceName: json['structure_instance_name'] as String? ?? '',
      partCode: json['part_code'] as String? ?? '',
      partName: json['part_name'] as String? ?? '',
      quickPartTag: json['quick_part_tag'] as String? ?? 'other',
      quickStatus: json['quick_status'] as String? ?? 'undecided',
      speechText: json['speech_text'] as String?,
      rawNote: json['raw_note'] as String?,
      reviewStatus: json['review_status'] as String? ?? 'pending',
      linkedResultId: json['linked_result_id'] as String?,
      photoCount: json['photo_count'] as int? ?? 0,
    );
  }

  final String captureId;
  final String taskId;
  final DateTime createdAt;
  final String structureInstanceId;
  final String structureInstanceName;
  final String partCode;
  final String partName;
  final String quickPartTag;
  final String quickStatus;
  final String? speechText;
  final String? rawNote;
  final String reviewStatus;
  final String? linkedResultId;
  final int photoCount;
}

class CaptureMediaItem {
  CaptureMediaItem({
    required this.mediaId,
    required this.mediaType,
    required this.localPath,
    required this.serverUrl,
    required this.shotTime,
  });

  factory CaptureMediaItem.fromJson(Map<String, dynamic> json) {
    return CaptureMediaItem(
      mediaId: json['media_id'] as String? ?? '',
      mediaType: json['media_type'] as String? ?? 'photo',
      localPath: json['local_path'] as String?,
      serverUrl: json['server_url'] as String?,
      shotTime: DateTime.tryParse(json['shot_time'] as String? ?? ''),
    );
  }

  final String mediaId;
  final String mediaType;
  final String? localPath;
  final String? serverUrl;
  final DateTime? shotTime;
}

class CaptureDetail {
  CaptureDetail({
    required this.captureId,
    required this.taskId,
    required this.createdAt,
    required this.createdBy,
    required this.structureInstanceId,
    required this.structureInstanceName,
    required this.partCode,
    required this.partName,
    required this.quickPartTag,
    required this.quickStatus,
    required this.rawNote,
    required this.speechText,
    required this.reviewStatus,
    required this.linkedResultId,
    required this.media,
  });

  factory CaptureDetail.fromJson(Map<String, dynamic> json) {
    return CaptureDetail(
      captureId: json['capture_id'] as String? ?? '',
      taskId: json['task_id'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      createdBy: json['created_by'] as String?,
      structureInstanceId: json['structure_instance_id'] as String? ?? '',
      structureInstanceName: json['structure_instance_name'] as String? ?? '',
      partCode: json['part_code'] as String? ?? '',
      partName: json['part_name'] as String? ?? '',
      quickPartTag: json['quick_part_tag'] as String? ?? 'other',
      quickStatus: json['quick_status'] as String? ?? 'undecided',
      rawNote: json['raw_note'] as String?,
      speechText: json['speech_text'] as String?,
      reviewStatus: json['review_status'] as String? ?? 'pending',
      linkedResultId: json['linked_result_id'] as String?,
      media: (json['media'] as List<dynamic>? ?? [])
          .map((e) => CaptureMediaItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final String captureId;
  final String taskId;
  final DateTime createdAt;
  final String? createdBy;
  final String structureInstanceId;
  final String structureInstanceName;
  final String partCode;
  final String partName;
  final String quickPartTag;
  final String quickStatus;
  final String? rawNote;
  final String? speechText;
  final String reviewStatus;
  final String? linkedResultId;
  final List<CaptureMediaItem> media;
}
