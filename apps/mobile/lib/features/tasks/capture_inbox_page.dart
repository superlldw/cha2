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
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text('${item.photoCount}'),
                          ),
                          title: Text(
                            _preview(item),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(subtitle),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
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
                        );
                      },
                    ),
    );
  }
}
