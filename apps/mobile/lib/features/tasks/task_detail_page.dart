import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/widgets/loading_error_view.dart';
import 'capture_page.dart';
import 'capture_inbox_detail_page.dart';
import 'capture_inbox_page.dart';
import 'item_detail_page.dart';
import 'task_models.dart';
import 'task_service.dart';
import 'template_page.dart';

class TaskDetailPage extends StatefulWidget {
  const TaskDetailPage({
    super.key,
    required this.taskService,
    required this.taskId,
  });

  final TaskService taskService;
  final String taskId;

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  bool _loading = true;
  bool _exportingPhotoPackage = false;
  bool _exportingInspectionDoc = false;
  String? _error;
  TaskDetail? _task;
  TaskProgress? _progress;
  List<_CaptureGroupViewModel> _captureGroups = const [];
  final Set<String> _deletingCaptureIds = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _taskStatusLabel(String status) {
    switch (status) {
      case 'in_progress':
        return '进行中';
      case 'completed':
        return '已完成';
      case 'draft':
        return '草稿';
      default:
        return status;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await widget.taskService.fetchTaskDetail(widget.taskId);
      final progress = await widget.taskService.fetchTaskProgress(widget.taskId);
      final captureGroups =
          await _loadCaptureOverviewData(projectId: detail.projectId);
      if (!mounted) return;
      setState(() {
        _task = detail;
        _progress = progress;
        _captureGroups = captureGroups;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<List<_CaptureGroupViewModel>> _loadCaptureOverviewData({
    required String projectId,
  }) async {
    final structureInstances =
        await widget.taskService.fetchProjectStructureInstances(projectId);
    final captures = await widget.taskService.fetchAllTaskCaptures(widget.taskId);

    final detailsById = <String, CaptureDetail>{};
    final withPhotos = captures.where((item) => item.photoCount > 0).toList();
    if (withPhotos.isNotEmpty) {
      final detailList = await Future.wait(
        withPhotos.map((item) => widget.taskService.fetchCaptureDetail(item.captureId)),
      );
      for (final detail in detailList) {
        detailsById[detail.captureId] = detail;
      }
    }

    final orderByInstanceId = <String, int>{
      for (final item in structureInstances) item.instanceId: item.sortOrder,
    };
    final nameByInstanceId = <String, String>{
      for (final item in structureInstances) item.instanceId: item.instanceName,
    };

    final grouped = <String, List<_CaptureCardViewModel>>{};
    for (final item in captures) {
      final detail = detailsById[item.captureId];
      final photo = detail?.media.firstWhere(
        (media) =>
            media.mediaType == 'photo' &&
            ((media.serverUrl ?? '').trim().isNotEmpty ||
                (media.localPath ?? '').trim().isNotEmpty),
        orElse: () => CaptureMediaItem(
          mediaId: '',
          mediaType: 'photo',
          localPath: null,
          serverUrl: null,
          shotTime: null,
        ),
      );
      final note = (item.speechText ?? '').trim().isNotEmpty
          ? item.speechText!.trim()
          : (item.rawNote ?? '').trim();
      grouped.putIfAbsent(item.structureInstanceId, () => []).add(
            _CaptureCardViewModel(
              captureId: item.captureId,
              structureInstanceName:
                  nameByInstanceId[item.structureInstanceId] ??
                      item.structureInstanceName,
              partName: item.partName,
              note: note,
              quickStatus: item.quickStatus,
              reviewStatus: item.reviewStatus,
              linkedResultId: item.linkedResultId,
              createdAt: item.createdAt,
              photoCount: item.photoCount,
              photoUrl: (photo?.serverUrl ?? '').trim().isEmpty
                  ? null
                  : photo!.serverUrl,
              photoLocalPath: (photo?.localPath ?? '').trim().isEmpty
                  ? null
                  : photo!.localPath,
            ),
          );
    }

    final groups = grouped.entries
        .map(
          (entry) => _CaptureGroupViewModel(
            instanceId: entry.key,
            instanceName: nameByInstanceId[entry.key] ?? entry.value.first.structureInstanceName,
            sortOrder: orderByInstanceId[entry.key] ?? 9999,
            captures: (entry.value..sort((a, b) => b.createdAt.compareTo(a.createdAt))),
          ),
        )
        .toList()
      ..sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        if (byOrder != 0) return byOrder;
        return a.instanceName.compareTo(b.instanceName);
      });
    return groups;
  }

  Future<void> _openExportUrl(String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开导出链接: $url')),
      );
    }
  }

  // ignore: unused_element
  Future<void> _exportPhotoPackage() async {
    setState(() => _exportingPhotoPackage = true);
    try {
      final url = await widget.taskService.exportPhotoPackage(widget.taskId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('问题清单导出已生成，正在打开')),
      );
      await _openExportUrl(url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('问题清单导出失败: $e')),
      );
    } finally {
      if (mounted) setState(() => _exportingPhotoPackage = false);
    }
  }

  // ignore: unused_element
  Future<void> _exportInspectionDoc() async {
    setState(() => _exportingInspectionDoc = true);
    try {
      final url = await widget.taskService.exportInspectionDoc(widget.taskId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('照片附表导出已生成，正在打开')),
      );
      await _openExportUrl(url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('照片附表导出失败: $e')),
      );
    } finally {
      if (mounted) setState(() => _exportingInspectionDoc = false);
    }
  }

  Future<void> _exportPhotoPackageV2() async {
    setState(() => _exportingPhotoPackage = true);
    try {
      final url = await widget.taskService.exportPhotoPackage(widget.taskId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('照片打包已生成，正在打开')),
      );
      await _openExportUrl(url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('照片打包导出失败: $e')),
      );
    } finally {
      if (mounted) setState(() => _exportingPhotoPackage = false);
    }
  }

  Future<void> _exportInspectionDocV2() async {
    setState(() => _exportingInspectionDoc = true);
    try {
      final url = await widget.taskService.exportInspectionDoc(widget.taskId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('检查表格已生成，正在打开')),
      );
      await _openExportUrl(url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('检查表格导出失败: $e')),
      );
    } finally {
      if (mounted) setState(() => _exportingInspectionDoc = false);
    }
  }

  String _quickStatusLabel(String value) {
    switch (value) {
      case 'normal':
        return '正常';
      case 'abnormal':
        return '异常';
      case 'undecided':
        return '未判';
      default:
        return value;
    }
  }

  String _reviewStatusLabel(String value) {
    switch (value) {
      case 'confirmed':
        return '已归档';
      case 'pending':
        return '待整理';
      default:
        return value;
    }
  }

  Future<void> _showCapturePreview(_CaptureCardViewModel item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.structureInstanceName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (item.photoUrl != null || item.photoLocalPath != null)
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: double.infinity,
                        height: 220,
                        child: _buildCaptureImage(item, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                if (item.photoUrl != null || item.photoLocalPath != null)
                  const SizedBox(height: 12),
                Text('粗部位：${item.partName}'),
                const SizedBox(height: 4),
                Text('状态：${_quickStatusLabel(item.quickStatus)} / ${_reviewStatusLabel(item.reviewStatus)}'),
                const SizedBox(height: 4),
                Text('拍摄时间：${item.createdAt.toLocal()}'),
                const SizedBox(height: 8),
                Text('记录内容：${item.note.isEmpty ? '无文字说明' : item.note}'),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openCaptureEditor(_CaptureCardViewModel item) async {
    if (item.reviewStatus == 'pending') {
      final changed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => CaptureInboxDetailPage(
            taskService: widget.taskService,
            taskId: widget.taskId,
            captureId: item.captureId,
          ),
        ),
      );
      if (changed == true && mounted) {
        await _load();
      }
      return;
    }

    final linkedResultId = (item.linkedResultId ?? '').trim();
    if (linkedResultId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('这条已归档记录暂时找不到对应检查项，先显示预览')),
      );
      await _showCapturePreview(item);
      return;
    }

    try {
      final chapters = await widget.taskService.fetchTemplateTree(widget.taskId);
      final results = await widget.taskService.fetchTaskResults(widget.taskId);
      final captureDetail = await widget.taskService.fetchCaptureDetail(item.captureId);
      TaskResultItem? result;
      for (final itemResult in results) {
        if (itemResult.resultId == linkedResultId) {
          result = itemResult;
          break;
        }
      }
      if (result == null) {
        throw Exception('找不到对应的归档检查结果');
      }

      TemplateInspectionItem? matchedItem;
      String? chapterCode;
      for (final chapter in chapters) {
        for (final section in chapter.children) {
          for (final inspectionItem in section.children) {
            if (inspectionItem.itemCode == result.itemCode) {
              matchedItem = inspectionItem;
              chapterCode = chapter.chapterCode;
              break;
            }
          }
          if (matchedItem != null) break;
        }
        if (matchedItem != null) break;
      }

      if (matchedItem == null || chapterCode == null) {
        throw Exception('找不到对应的检查项模板');
      }

      if (!mounted) return;
      final inheritedEvidence = captureDetail.media
          .where((media) =>
              media.mediaType == 'photo' &&
              ((media.serverUrl ?? '').trim().isNotEmpty ||
                  (media.localPath ?? '').trim().isNotEmpty))
          .map(
            (media) => EvidenceItem(
              evidenceId: 'capture_${item.captureId}_${media.mediaId}',
              evidenceType: 'photo',
              fileUrl: (media.serverUrl ?? '').trim(),
              caption: '采集记录继承照片',
              gpsLat: null,
              gpsLng: null,
              shotTime: media.shotTime,
              syncStatus: 'synced',
            ),
          )
          .where((evidence) => evidence.fileUrl.isNotEmpty)
          .toList();
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ItemDetailPage(
            taskService: widget.taskService,
            taskId: widget.taskId,
            chapterCode: chapterCode!,
            item: matchedItem!,
            initialResult: result,
            compactMode: true,
            initialCompactEvidence: inheritedEvidence,
          ),
        ),
      );
      if (mounted) {
        await _load();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('打开编辑页失败，先显示预览: $e')),
      );
      await _showCapturePreview(item);
    }
  }

  Future<void> _deleteCaptureFromOverview(_CaptureCardViewModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除记录'),
        content: Text(
          item.reviewStatus == 'confirmed'
              ? '这条记录已经归档。删除时会一起删除归档结果和关联照片，且不可恢复，确定继续吗？'
              : '删除后不可恢复，确定要删除这条采集记录吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deletingCaptureIds.add(item.captureId));
    try {
      await widget.taskService.deleteCaptureCompletely(item.captureId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('记录已删除')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _deletingCaptureIds.remove(item.captureId));
      }
    }
  }

  Widget _buildCaptureImage(
    _CaptureCardViewModel item, {
    BoxFit fit = BoxFit.cover,
  }) {
    if ((item.photoUrl ?? '').trim().isNotEmpty) {
      return Image.network(
        item.photoUrl!,
        fit: fit,
        errorBuilder: (_, __, ___) => _buildImageFallback(),
      );
    }
    if (!kIsWeb && (item.photoLocalPath ?? '').trim().isNotEmpty) {
      return Image.file(
        File(item.photoLocalPath!),
        fit: fit,
        errorBuilder: (_, __, ___) => _buildImageFallback(),
      );
    }
    return _buildImageFallback();
  }

  Widget _buildImageFallback() {
    return Container(
      color: Colors.blueGrey.shade50,
      alignment: Alignment.center,
      child: const Icon(Icons.photo_outlined, size: 36, color: Colors.blueGrey),
    );
  }

  Widget _buildCaptureOverviewCard() {
    if (_captureGroups.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('还没有已归档照片记录。归档后的采集照片会按对象分组显示在这里。'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('采集记录总览'),
            const SizedBox(height: 4),
            Text(
              '按对象配置分组展示，仅显示已归档的照片记录。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            ..._captureGroups.map(
              (group) => ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: Text(group.instanceName),
                subtitle: Text('${group.captures.length} 条记录'),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: group.captures
                          .map(
                            (item) => InkWell(
                              onTap: _deletingCaptureIds.contains(item.captureId)
                                  ? null
                                  : () => _openCaptureEditor(item),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 150,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: SizedBox(
                                            width: double.infinity,
                                            height: 92,
                                            child: _buildCaptureImage(item),
                                          ),
                                        ),
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: Material(
                                            color: Colors.black45,
                                            borderRadius: BorderRadius.circular(999),
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(999),
                                              onTap: _deletingCaptureIds.contains(item.captureId)
                                                  ? null
                                                  : () => _deleteCaptureFromOverview(item),
                                              child: Padding(
                                                padding: const EdgeInsets.all(6),
                                                child: _deletingCaptureIds.contains(item.captureId)
                                                    ? const SizedBox(
                                                        width: 14,
                                                        height: 14,
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white,
                                                        ),
                                                      )
                                                    : const Icon(
                                                        Icons.delete_outline,
                                                        size: 16,
                                                        color: Colors.white,
                                                      ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      item.partName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context).textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.note.isEmpty ? '无文字说明' : item.note,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${_reviewStatusLabel(item.reviewStatus)} · ${item.photoCount} 张',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final task = _task;
    final progress = _progress;
    return Scaffold(
      appBar: AppBar(title: const Text('任务详情')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? LoadingErrorView(message: _error!, onRetry: _load)
              : task == null || progress == null
                  ? LoadingErrorView(message: '任务不存在', onRetry: _load)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    task.reservoirName,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text('检查日期: ${task.inspectionDate}'),
                                  Text('坝型: ${task.damType}'),
                                  Text('状态: ${_taskStatusLabel(task.status)}'),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () async {
                              final changed = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CapturePage(
                                    taskService: widget.taskService,
                                    taskId: widget.taskId,
                                  ),
                                ),
                              );
                              if (changed == true && mounted) {
                                await _load();
                              }
                            },
                            icon: const Icon(Icons.add_a_photo_outlined),
                            label: const Text('现场采集'),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final changed = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CaptureInboxPage(
                                    taskService: widget.taskService,
                                    taskId: widget.taskId,
                                  ),
                                ),
                              );
                              if (changed == true && mounted) {
                                await _load();
                              }
                            },
                            icon: const Icon(Icons.inventory_2_outlined),
                            label: const Text('待整理箱'),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TemplatePage(
                                    taskService: widget.taskService,
                                    taskId: widget.taskId,
                                  ),
                                ),
                              );
                              await _load();
                            },
                            icon: const Icon(Icons.list_alt),
                            label: const Text('进入章节/检查项'),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            child: ListTile(
                              title: const Text('检查进度'),
                              subtitle: Text(
                                  '${progress.completed}/${progress.total} (${progress.percent}%)'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('导出'),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: _exportingPhotoPackage
                                            ? null
                                            : _exportPhotoPackageV2,
                                        icon: const Icon(
                                            Icons.folder_zip_outlined),
                                        label: Text(_exportingPhotoPackage
                                            ? '导出中...'
                                            : '照片打包导出'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: _exportingInspectionDoc
                                            ? null
                                            : _exportInspectionDocV2,
                                        icon: const Icon(
                                            Icons.description_outlined),
                                        label: Text(_exportingInspectionDoc
                                            ? '导出中...'
                                            : '检查表格导出'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  const Text('导出为照片压缩包和 Word 检查表，按项目实际对象配置生成。'),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildCaptureOverviewCard(),
                        ],
                      ),
                    ),
    );
  }
}

class _CaptureGroupViewModel {
  const _CaptureGroupViewModel({
    required this.instanceId,
    required this.instanceName,
    required this.sortOrder,
    required this.captures,
  });

  final String instanceId;
  final String instanceName;
  final int sortOrder;
  final List<_CaptureCardViewModel> captures;
}

class _CaptureCardViewModel {
  const _CaptureCardViewModel({
    required this.captureId,
    required this.structureInstanceName,
    required this.partName,
    required this.note,
    required this.quickStatus,
    required this.reviewStatus,
    required this.linkedResultId,
    required this.createdAt,
    required this.photoCount,
    required this.photoUrl,
    required this.photoLocalPath,
  });

  final String captureId;
  final String structureInstanceName;
  final String partName;
  final String note;
  final String quickStatus;
  final String reviewStatus;
  final String? linkedResultId;
  final DateTime createdAt;
  final int photoCount;
  final String? photoUrl;
  final String? photoLocalPath;
}
