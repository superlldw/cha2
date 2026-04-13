import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/widgets/loading_error_view.dart';
import 'capture_page.dart';
import 'capture_inbox_page.dart';
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
  bool _exportingIssue = false;
  bool _exportingPhoto = false;
  String? _error;
  TaskDetail? _task;
  TaskProgress? _progress;

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
      final progress =
          await widget.taskService.fetchTaskProgress(widget.taskId);
      if (!mounted) return;
      setState(() {
        _task = detail;
        _progress = progress;
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

  Future<void> _openExportUrl(String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开导出链接: $url')),
      );
    }
  }

  Future<void> _exportIssueList() async {
    setState(() => _exportingIssue = true);
    try {
      final url = await widget.taskService.exportIssueList(widget.taskId);
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
      if (mounted) setState(() => _exportingIssue = false);
    }
  }

  Future<void> _exportPhotoSheet() async {
    setState(() => _exportingPhoto = true);
    try {
      final url = await widget.taskService.exportPhotoSheet(widget.taskId);
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
      if (mounted) setState(() => _exportingPhoto = false);
    }
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
                                        onPressed: _exportingIssue
                                            ? null
                                            : _exportIssueList,
                                        icon: const Icon(
                                            Icons.file_download_outlined),
                                        label: Text(_exportingIssue
                                            ? '导出中...'
                                            : '问题清单导出'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: _exportingPhoto
                                            ? null
                                            : _exportPhotoSheet,
                                        icon: const Icon(
                                            Icons.photo_library_outlined),
                                        label: Text(_exportingPhoto
                                            ? '导出中...'
                                            : '照片附表导出'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  const Text('当前为 CSV 最小导出，支持下载和查看'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}
