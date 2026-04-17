import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/widgets/loading_error_view.dart';
import 'task_models.dart';
import 'task_service.dart';

class CaptureInboxDetailPage extends StatefulWidget {
  const CaptureInboxDetailPage({
    super.key,
    required this.taskService,
    required this.taskId,
    required this.captureId,
  });

  final TaskService taskService;
  final String taskId;
  final String captureId;

  @override
  State<CaptureInboxDetailPage> createState() => _CaptureInboxDetailPageState();
}

class _CaptureInboxDetailPageState extends State<CaptureInboxDetailPage> {
  static const _checkStatusOptions = [
    'unchecked',
    'normal',
    'basically_normal',
    'abnormal',
    'not_applicable',
  ];
  static const _severityOptions = ['minor', 'moderate', 'serious', 'critical'];

  bool _loading = true;
  bool _submitting = false;
  bool _deleting = false;
  String? _error;
  CaptureDetail? _capture;
  List<TemplateInspectionItem> _candidateItems = const [];

  String? _selectedItemCode;
  String _checkStatus = 'unchecked';
  bool _issueFlag = false;
  String _issueTypeText = '';
  String? _severityLevel;

  final TextEditingController _checkRecordController = TextEditingController();
  final TextEditingController _suggestionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _checkRecordController.dispose();
    _suggestionController.dispose();
    super.dispose();
  }

  String _checkStatusLabel(String value) {
    switch (value) {
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
        return value;
    }
  }

  String _severityLabel(String value) {
    switch (value) {
      case 'minor':
        return '一般';
      case 'moderate':
        return '较重';
      case 'serious':
        return '严重';
      case 'critical':
        return '特别严重';
      default:
        return value;
    }
  }

  List<String> _partHints(CaptureDetail capture) {
    switch (capture.partCode) {
      case 'dam_crest':
        return ['crest', '坝顶', '顶坝'];
      case 'upstream_face':
        return ['upstream', '上游'];
      case 'downstream_face':
        return ['downstream', '下游'];
      case 'dam_abutment':
        return ['abutment', '坝肩'];
      case 'dam_foundation':
        return ['foundation', '坝基', '基础'];
      case 'inlet':
        return ['inlet', '进口', '进水口'];
      case 'control':
        return ['control', '控制'];
      case 'chute':
        return ['chute', '泄槽'];
      case 'energy_dissipation':
        return ['energy', 'dissipation', '消能'];
      case 'tailwater':
        return ['tailwater', '尾水'];
      case 'tunnel_body':
        return ['tunnel', 'body', '洞身'];
      case 'outlet':
        return ['outlet', '出口'];
      case 'hoist':
        return ['hoist', '启闭'];
      case 'main_building':
        return ['building', '主体', '建筑'];
      case 'equipment':
        return ['equipment', '设备'];
      case 'power_lighting':
        return ['power', 'lighting', '电源', '照明'];
      case 'communication_monitor':
        return ['communication', 'monitor', '通信', '监测'];
      case 'surrounding_road':
        return ['road', '道路', '周边'];
      case 'bank':
        return ['bank', '库岸'];
      case 'river_channel':
        return ['river', 'channel', '河道'];
      case 'slope':
        return ['slope', '边坡', '岸坡'];
      case 'bridge_path':
        return ['bridge', 'path', '桥', '通道'];
      case 'hazard_zone':
        return ['hazard', 'zone', '隐患', '障碍'];
      default:
        return [
          capture.partCode,
          capture.partName,
        ].where((e) => e.trim().isNotEmpty).toList();
    }
  }

  List<TemplateInspectionItem> _filterCandidates(
    List<TemplateInspectionItem> items,
    CaptureDetail capture,
  ) {
    final hints = _partHints(capture)
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();

    int scoreOf(TemplateInspectionItem item) {
      final code = item.itemCode.toLowerCase();
      final name = item.itemName.toLowerCase();
      var score = 0;
      for (final hint in hints) {
        if (code.contains(hint)) score += 3;
        if (name.contains(hint)) score += 4;
      }
      if (code.startsWith('a1_')) score -= 10;
      return score;
    }

    final scored = items
        .map((item) => (item: item, score: scoreOf(item)))
        .where((entry) => entry.score > 0)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    if (scored.isNotEmpty) {
      return scored.map((entry) => entry.item).toList();
    }

    return items.where((item) => !item.itemCode.toLowerCase().startsWith('a1_')).toList();
  }

  String _mapQuickStatusToCheckStatus(String quickStatus) {
    switch (quickStatus) {
      case 'normal':
        return 'normal';
      case 'abnormal':
        return 'abnormal';
      case 'undecided':
      default:
        return 'unchecked';
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final capture = await widget.taskService.fetchCaptureDetail(widget.captureId);
      final chapters = await widget.taskService.fetchTemplateTree(widget.taskId);

      final allItems = <TemplateInspectionItem>[];
      for (final ch in chapters) {
        for (final sec in ch.children) {
          allItems.addAll(sec.children);
        }
      }

      final candidates = _filterCandidates(allItems, capture);
      final mappedStatus = _mapQuickStatusToCheckStatus(capture.quickStatus);
      final mappedIssueFlag = capture.quickStatus == 'abnormal';

      if (!mounted) return;
      setState(() {
        _capture = capture;
        _candidateItems = candidates;
        _selectedItemCode = candidates.isNotEmpty ? candidates.first.itemCode : null;
        _checkStatus = mappedStatus;
        _issueFlag = mappedIssueFlag;
        _severityLevel = null;
        _checkRecordController.text = (capture.speechText ?? capture.rawNote ?? '').trim();
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

  Future<void> _confirm() async {
    if (_selectedItemCode == null || _selectedItemCode!.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先选择归属检查项')));
      return;
    }

    setState(() => _submitting = true);
    try {
      final issueType = _issueTypeText
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      await widget.taskService.confirmCapture(
        captureId: widget.captureId,
        itemCode: _selectedItemCode!,
        checkStatus: _checkStatus,
        issueFlag: _issueFlag,
        issueType: _issueFlag ? issueType : const [],
        severityLevel: _issueFlag ? _severityLevel : null,
        checkRecord: _checkRecordController.text.trim(),
        suggestion: _suggestionController.text.trim(),
        checkedBy: 'reviewer_mobile',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已确认归档到 inspection_result')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('确认失败: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _deleteCapture() async {
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

    setState(() => _deleting = true);
    try {
      await widget.taskService.deleteCapture(widget.captureId);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('待整理记录已删除')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('删除失败: $e')));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Widget _buildPhoto(CaptureMediaItem media) {
    final localPath = (media.localPath ?? '').trim();
    if (!kIsWeb && localPath.isNotEmpty && File(localPath).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.file(
          File(localPath),
          width: 120,
          height: 80,
          fit: BoxFit.cover,
        ),
      );
    }

    final url = (media.serverUrl ?? '').trim();
    if (url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          url,
          width: 120,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 120,
            height: 80,
            color: Colors.grey.shade300,
            alignment: Alignment.center,
            child: const Text('图片加载失败'),
          ),
        ),
      );
    }

    return Container(
      width: 120,
      height: 80,
      color: Colors.grey.shade300,
      alignment: Alignment.center,
      child: const Text('无图片路径'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final capture = _capture;
    final canDelete = capture?.reviewStatus == 'pending';
    return Scaffold(
      appBar: AppBar(
        title: const Text('待整理详情'),
        actions: [
          if (canDelete)
            IconButton(
              onPressed: _deleting ? null : _deleteCapture,
              tooltip: '删除',
              icon: _deleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? LoadingErrorView(message: _error!, onRetry: _load)
              : capture == null
                  ? LoadingErrorView(message: '采集记录不存在', onRetry: _load)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                      children: [
                        Text('对象实例：${capture.structureInstanceName}'),
                        Text('粗部位：${capture.partName} (${capture.partCode})'),
                        const SizedBox(height: 8),
                        Text('语音文字：${capture.speechText ?? '-'}'),
                        const SizedBox(height: 8),
                        Text('补充备注：${capture.rawNote ?? '-'}'),
                        const SizedBox(height: 12),
                        if (capture.media.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: capture.media
                                .where((m) => m.mediaType == 'photo')
                                .map(_buildPhoto)
                                .toList(),
                          ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _selectedItemCode,
                          decoration: const InputDecoration(labelText: '建议检查项（可修改）'),
                          items: _candidateItems
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e.itemCode,
                                  child: Text(
                                    e.itemName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _selectedItemCode = v),
                        ),
                        if (_selectedItemCode != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '检查项编码：$_selectedItemCode',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _checkStatus,
                          decoration: const InputDecoration(labelText: '检查状态'),
                          items: _checkStatusOptions
                              .map((e) => DropdownMenuItem(
                                  value: e, child: Text(_checkStatusLabel(e))))
                              .toList(),
                          onChanged: (v) => setState(() => _checkStatus = v ?? 'unchecked'),
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('是否存在问题'),
                          value: _issueFlag,
                          onChanged: (v) => setState(() {
                            _issueFlag = v;
                            if (!v) _severityLevel = null;
                          }),
                        ),
                        if (_issueFlag) ...[
                          TextField(
                            decoration: const InputDecoration(labelText: '问题类型（逗号分隔）'),
                            onChanged: (v) => _issueTypeText = v,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _severityLevel,
                            hint: const Text('请选择严重程度'),
                            decoration: const InputDecoration(labelText: '严重程度'),
                            items: _severityOptions
                                .map((e) => DropdownMenuItem(
                                    value: e, child: Text(_severityLabel(e))))
                                .toList(),
                            onChanged: (v) => setState(() => _severityLevel = v),
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextField(
                          controller: _checkRecordController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(labelText: '检查记录'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _suggestionController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(labelText: '处理建议'),
                        ),
                      ],
                    ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(12),
        child: FilledButton(
          onPressed: _submitting ? null : _confirm,
          child: Text(_submitting ? '确认中...' : '确认归档'),
        ),
      ),
    );
  }
}
