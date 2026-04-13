import 'package:flutter/material.dart';

import '../../core/widgets/loading_error_view.dart';
import 'item_detail_page.dart';
import 'task_models.dart';
import 'task_service.dart';

class TemplatePage extends StatefulWidget {
  const TemplatePage({
    super.key,
    required this.taskService,
    required this.taskId,
  });

  final TaskService taskService;
  final String taskId;

  @override
  State<TemplatePage> createState() => _TemplatePageState();
}

class _TemplatePageState extends State<TemplatePage> {
  bool _loading = true;
  String? _error;
  List<TemplateChapter> _chapters = const [];
  Map<String, TaskResultItem> _resultByCode = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _checkStatusLabel(String status) {
    switch (status) {
      case 'unchecked':
        return '未检查';
      case 'normal':
        return '正常';
      case 'basically_normal':
        return '基本正常';
      case 'abnormal':
        return '异常';
      case 'not_applicable':
        return '不适用';
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
      final chapters = await widget.taskService.fetchTemplateTree(widget.taskId);
      final results = await widget.taskService.fetchTaskResults(widget.taskId);
      if (!mounted) return;
      setState(() {
        _chapters = chapters;
        _resultByCode = {for (final r in results) r.itemCode: r};
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('章节/检查项'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? LoadingErrorView(message: _error!, onRetry: _load)
              : _chapters.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.info_outline, size: 40),
                            const SizedBox(height: 12),
                            const Text('当前任务暂无检查模板数据'),
                            const SizedBox(height: 8),
                            const Text(
                              '请先在联网状态进入一次该任务的章节页以缓存模板，\n之后可离线查看和录入。',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton(
                              onPressed: _load,
                              child: const Text('重新加载'),
                            ),
                          ],
                        ),
                      ),
                    )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: _chapters.length,
                  itemBuilder: (context, index) {
                    final chapter = _chapters[index];
                    return ExpansionTile(
                      title: Text('${chapter.chapterCode} ${chapter.chapterName}'),
                      children: chapter.children
                          .map(
                            (section) => ExpansionTile(
                              title: Text(section.itemName),
                              children: section.children.map((item) {
                                final result = _resultByCode[item.itemCode];
                                final status = result?.checkStatus ?? 'unchecked';
                                return ListTile(
                                  title: Text(item.itemName),
                                  subtitle: Text('状态: ${_checkStatusLabel(status)}'),
                                  trailing: result != null && result.issueFlag
                                      ? const Icon(Icons.warning_amber, color: Colors.orange)
                                      : null,
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ItemDetailPage(
                                          taskService: widget.taskService,
                                          taskId: widget.taskId,
                                          chapterCode: chapter.chapterCode,
                                          item: item,
                                          initialResult: result,
                                        ),
                                      ),
                                    );
                                    await _load();
                                  },
                                );
                              }).toList(),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
    );
  }
}
