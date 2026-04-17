import 'package:flutter/material.dart';

import '../../core/widgets/loading_error_view.dart';
import 'capture_inbox_detail_page.dart';
import 'task_models.dart';
import 'task_service.dart';

class CaptureInboxPage extends StatefulWidget {
  const CaptureInboxPage({
    super.key,
    required this.taskService,
    required this.taskId,
  });

  final TaskService taskService;
  final String taskId;

  @override
  State<CaptureInboxPage> createState() => _CaptureInboxPageState();
}

class _CaptureInboxPageState extends State<CaptureInboxPage> {
  bool _loading = true;
  String? _error;
  List<CaptureListItem> _items = const [];
  final Set<String> _deletingIds = <String>{};

  static const Map<String, String> _statusLabels = {
    'normal': '正常',
    'abnormal': '异常',
    'undecided': '未判',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.taskService.fetchTaskCaptures(widget.taskId);
      if (!mounted) return;
      setState(() {
        _items = items;
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

  String _preview(CaptureListItem item) {
    final speech = (item.speechText ?? '').trim();
    if (speech.isNotEmpty) return speech;
    final raw = (item.rawNote ?? '').trim();
    if (raw.isNotEmpty) return raw;
    return '无文字描述';
  }

  Future<void> _deleteCapture(CaptureListItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除待整理记录'),
        content: const Text('删除后不可恢复，确定要删除这条待整理记录吗？'),
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

    setState(() => _deletingIds.add(item.captureId));
    try {
      await widget.taskService.deleteCapture(item.captureId);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('待整理记录已删除')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('删除失败: $e')));
    } finally {
      if (mounted) {
        setState(() => _deletingIds.remove(item.captureId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('待整理箱'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? LoadingErrorView(message: _error!, onRetry: _load)
              : _items.isEmpty
                  ? const Center(child: Text('暂无待整理采集记录'))
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        final subtitle =
                            '${item.structureInstanceName} · ${item.partName} · ${_statusLabels[item.quickStatus] ?? item.quickStatus}';
                        return Dismissible(
                          key: ValueKey(item.captureId),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (_) async {
                            await _deleteCapture(item);
                            return false;
                          },
                          background: Container(
                            color: Colors.red.shade400,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: const Icon(Icons.delete_outline, color: Colors.white),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text('${item.photoCount}'),
                            ),
                            title: Text(
                              _preview(item),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(subtitle),
                            trailing: _deletingIds.contains(item.captureId)
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.chevron_right),
                            onTap: _deletingIds.contains(item.captureId)
                                ? null
                                : () async {
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
                                  },
                          ),
                        );
                      },
                    ),
    );
  }
}
