import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'task_models.dart';
import 'task_service.dart';

class ItemDetailPage extends StatefulWidget {
  const ItemDetailPage({
    super.key,
    required this.taskService,
    required this.taskId,
    required this.chapterCode,
    required this.item,
    required this.initialResult,
    this.compactMode = false,
    this.initialCompactEvidence = const [],
  });

  final TaskService taskService;
  final String taskId;
  final String chapterCode;
  final TemplateInspectionItem item;
  final TaskResultItem? initialResult;
  final bool compactMode;
  final List<EvidenceItem> initialCompactEvidence;

  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  static const _checkStatusOptions = [
    'unchecked',
    'normal',
    'basically_normal',
    'abnormal',
    'not_applicable',
  ];
  static const _severityOptions = ['minor', 'moderate', 'serious', 'critical'];

  late String _checkStatus;
  late bool _issueFlag;
  late TextEditingController _issueTypeController;
  String? _severityLevel;
  late TextEditingController _checkRecordController;
  late TextEditingController _suggestionController;

  final ImagePicker _picker = ImagePicker();
  List<EvidenceItem> _evidenceItems = const [];
  String? _resultId;
  String _resultSyncStatus = 'pending';

  bool _saving = false;
  bool _uploadingPhoto = false;
  bool _loadingEvidence = false;

  @override
  void initState() {
    super.initState();
    final result = widget.initialResult;
    _checkStatus = result?.checkStatus ?? 'unchecked';
    _issueFlag = result?.issueFlag ?? false;
    _issueTypeController =
        TextEditingController(text: (result?.issueType ?? []).join(','));
    _severityLevel = result?.severityLevel;
    _checkRecordController =
        TextEditingController(text: result?.checkRecord ?? '');
    _suggestionController = TextEditingController(text: result?.suggestion ?? '');
    _resultId =
        (result?.resultId.isNotEmpty ?? false) ? result!.resultId : null;
    _resultSyncStatus = result?.syncStatus ?? 'pending';
    _evidenceItems = List<EvidenceItem>.from(widget.initialCompactEvidence);
    if (_resultId != null) {
      _loadEvidence();
    }
  }

  @override
  void dispose() {
    _issueTypeController.dispose();
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

  String _syncStatusLabel(String value) {
    switch (value) {
      case 'local':
        return '已保存到本机';
      case 'pending':
        return '待同步';
      case 'synced':
        return '已同步';
      case 'failed':
        return '同步失败';
      default:
        return value;
    }
  }

  Future<String?> _persistResult({required bool popAfterSave}) async {
    setState(() => _saving = true);
    try {
      final issueType = _issueTypeController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final resultId = await widget.taskService.saveResult(
        taskId: widget.taskId,
        itemCode: widget.item.itemCode,
        checkStatus: _checkStatus,
        issueFlag: _issueFlag,
        issueType: issueType,
        severityLevel: _severityLevel,
        checkRecord: _checkRecordController.text.trim(),
        suggestion: _suggestionController.text.trim(),
      );
      _resultId = resultId;
      await _refreshResultSyncStatus();
      if (!mounted) return resultId;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('保存成功')));
      if (popAfterSave) {
        Navigator.pop(context);
      } else {
        await _loadEvidence();
      }
      return resultId;
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存失败: $e')));
      return null;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    await _persistResult(popAfterSave: true);
  }

  Future<String?> _ensureResultId() async {
    if (_resultId != null && _resultId!.isNotEmpty) {
      return _resultId;
    }
    final id = await _persistResult(popAfterSave: false);
    if (!mounted) return id;
    if (id != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已先保存检查项结果，再绑定照片')));
    }
    return id;
  }

  Future<void> _refreshResultSyncStatus() async {
    final status = await widget.taskService.getResultSyncStatus(
      taskId: widget.taskId,
      itemCode: widget.item.itemCode,
      resultId: _resultId,
    );
    if (!mounted) return;
    setState(() => _resultSyncStatus = status);
  }

  Future<void> _loadEvidence() async {
    final resultId = _resultId;
    if (resultId == null || resultId.isEmpty) {
      setState(() => _evidenceItems = const []);
      return;
    }
    setState(() => _loadingEvidence = true);
    try {
      await _refreshResultSyncStatus();
      final items = await widget.taskService.fetchResultEvidence(resultId);
      if (!mounted) return;
      final merged = <String, EvidenceItem>{
        for (final item in widget.initialCompactEvidence) item.evidenceId: item,
        for (final item in items) item.evidenceId: item,
      };
      setState(() => _evidenceItems = merged.values.toList());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('加载证据失败: $e')));
    } finally {
      if (mounted) setState(() => _loadingEvidence = false);
    }
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    if (!widget.item.supportsPhoto) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('当前检查项不支持图片证据')));
      return;
    }

    final resultId = await _ensureResultId();
    if (resultId == null || resultId.isEmpty || !mounted) {
      return;
    }

    final photo = await _picker.pickImage(source: source, imageQuality: 85);
    if (photo == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      await widget.taskService
          .uploadPhotoEvidence(
            resultId: resultId,
            filePath: photo.path,
            fileBytes: await photo.readAsBytes(),
            fileName: photo.name,
          );
      if (!mounted) return;
      await _loadEvidence();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('照片已挂到当前检查项')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('照片处理失败: $e')));
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _deleteEvidence(String evidenceId) async {
    try {
      await widget.taskService.deleteEvidence(evidenceId);
      if (!mounted) return;
      await _loadEvidence();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('证据已删除')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('删除证据失败: $e')));
    }
  }

  String _formatShotTime(DateTime? dt) {
    if (dt == null) return '-';
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  Future<void> _mockSpeechInput() async {
    final controller = TextEditingController(text: _checkRecordController.text);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('语音录入（第一阶段）'),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: '当前阶段先用手工补录/Mock 文本',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _checkRecordController.text = controller.text.trim());
    }
  }

  Future<void> _showImagePreview(EvidenceItem evidence) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('查看照片'),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: _buildEvidenceImage(
                evidence,
                fit: BoxFit.contain,
                errorWidget: const Text(
                  '??????',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEvidenceImage(
    EvidenceItem evidence, {
    BoxFit fit = BoxFit.cover,
    Widget? errorWidget,
    double? width,
    double? height,
  }) {
    final path = evidence.fileUrl.trim();
    if (!kIsWeb &&
        path.isNotEmpty &&
        (path.startsWith('/') || path.contains(r':\'))) {
      return Image.file(
        File(path),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) =>
            errorWidget ??
            Container(
              width: width,
              height: height,
              color: Colors.grey.shade300,
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image_outlined),
            ),
      );
    }
    return Image.network(
      path,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) =>
          errorWidget ??
          Container(
            width: width,
            height: height,
            color: Colors.grey.shade300,
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_outlined),
          ),
    );
  }

  Widget _buildCompactBody() {
    final photos = _evidenceItems.where((e) => e.evidenceType == 'photo').toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        Text(
          widget.item.itemName,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Text('图片 (${photos.length})'),
        const SizedBox(height: 8),
        if (_loadingEvidence)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          )
        else if (photos.isEmpty)
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            alignment: Alignment.center,
            child: const Text('暂无照片'),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: photos
                .map(
                  (evidence) => InkWell(
                    onTap: () => _showImagePreview(evidence),
                    borderRadius: BorderRadius.circular(12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          _buildEvidenceImage(
                            evidence,
                            width: 110,
                            height: 110,
                            fit: BoxFit.cover,
                          ),
                          Positioned(
                            right: 6,
                            bottom: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _formatShotTime(evidence.shotTime),
                                style: const TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _mockSpeechInput,
          icon: const Icon(Icons.mic),
          label: const Text('录音/语音录入（MVP）'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _checkRecordController,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: '检查记录',
            hintText: '可补充或修改记录内容',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _suggestionController,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: '处理建议',
            hintText: '填写建议处理方式',
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingEvidence =
        _evidenceItems.where((e) => e.syncStatus == 'pending').length;
    final failedEvidence =
        _evidenceItems.where((e) => e.syncStatus == 'failed').length;
    final syncedEvidence =
        _evidenceItems.where((e) => e.syncStatus == 'synced').length;

    return Scaffold(
      appBar: AppBar(title: Text(widget.item.itemName)),
      body: widget.compactMode
          ? _buildCompactBody()
          : ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          Text('检查项编码: ${widget.item.itemCode}'),
          const SizedBox(height: 4),
          Text('章节: ${widget.chapterCode}'),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _checkStatus,
            decoration: const InputDecoration(labelText: '检查状态'),
            items: _checkStatusOptions
                .map((e) => DropdownMenuItem(value: e, child: Text(_checkStatusLabel(e))))
                .toList(),
            onChanged: (v) => setState(() => _checkStatus = v ?? 'unchecked'),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('是否存在问题'),
            value: _issueFlag,
            onChanged: (v) => setState(() => _issueFlag = v),
          ),
          if (_issueFlag) ...[
            TextField(
              controller: _issueTypeController,
              decoration: const InputDecoration(
                labelText: '问题类型（逗号分隔）',
                hintText: '如: crack,seepage',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _severityLevel,
              decoration: const InputDecoration(labelText: '严重程度'),
              items: _severityOptions
                  .map((e) => DropdownMenuItem(value: e, child: Text(_severityLabel(e))))
                  .toList(),
              onChanged: (v) => setState(() => _severityLevel = v),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _checkRecordController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(labelText: '检查记录'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _suggestionController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: '处理建议'),
          ),
          const SizedBox(height: 16),
          Text('当前结果同步状态: ${_syncStatusLabel(_resultSyncStatus)}'),
          const SizedBox(height: 4),
          Text('当前证据状态: 待同步=$pendingEvidence, 失败=$failedEvidence, 已同步=$syncedEvidence'),
          const SizedBox(height: 8),
          Text('图片证据 (${_evidenceItems.length})'),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _uploadingPhoto
                    ? null
                    : () => _pickAndUploadPhoto(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('选择图片'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _uploadingPhoto
                    ? null
                    : () => _pickAndUploadPhoto(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('拍照'),
              ),
              const SizedBox(width: 8),
              Text(_uploadingPhoto ? '处理中...' : '仅支持 photo'),
            ],
          ),
          const SizedBox(height: 8),
          if (_loadingEvidence)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            ),
          if (!_loadingEvidence && _evidenceItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('暂无图片证据'),
            ),
          if (_evidenceItems.isNotEmpty)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _evidenceItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final evidence = _evidenceItems[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            evidence.fileUrl,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 80,
                              height: 80,
                              color: Colors.grey.shade300,
                              alignment: Alignment.center,
                              child: const Text('图片加载失败'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('证据ID: ${evidence.evidenceId}'),
                              const SizedBox(height: 4),
                              Text('拍摄时间: ${_formatShotTime(evidence.shotTime)}'),
                              Text('同步状态: ${_syncStatusLabel(evidence.syncStatus)}'),
                              if ((evidence.caption ?? '').isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text('说明: ${evidence.caption}'),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: '删除',
                          onPressed: () => _deleteEvidence(evidence.evidenceId),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(12),
        child: FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? '保存中...' : '保存'),
        ),
      ),
    );
  }
}
