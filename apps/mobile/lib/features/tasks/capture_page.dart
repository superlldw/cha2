import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'task_models.dart';
import 'task_service.dart';

class CapturePage extends StatefulWidget {
  const CapturePage({
    super.key,
    required this.taskService,
    required this.taskId,
  });

  final TaskService taskService;
  final String taskId;

  @override
  State<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends State<CapturePage> {
  static const Map<String, String> _quickStatus = {
    'normal': '正常',
    'abnormal': '异常',
    'undecided': '未判',
  };

  final ImagePicker _picker = ImagePicker();
  final TextEditingController _speechController = TextEditingController();
  final TextEditingController _rawNoteController = TextEditingController();

  List<StructureInstanceItem> _instances = const [];
  String? _selectedInstanceId;
  List<StructurePartTemplateItem> _parts = const [];
  String? _selectedPartCode;

  String _status = 'undecided';
  XFile? _photo;
  bool _loadingMeta = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadMeta();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pickPhoto(ImageSource.camera);
    });
  }

  @override
  void dispose() {
    _speechController.dispose();
    _rawNoteController.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    setState(() => _loadingMeta = true);
    try {
      final task = await widget.taskService.fetchTaskDetail(widget.taskId);
      final instances =
          await widget.taskService.fetchProjectStructureInstances(task.projectId);
      if (!mounted) return;
      setState(() {
        _instances = instances.where((e) => e.enabledForCapture).toList();
        _loadingMeta = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMeta = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('加载对象实例失败: $e')));
    }
  }

  Future<void> _onSelectInstance(String? instanceId) async {
    if (instanceId == null) return;
    setState(() {
      _selectedInstanceId = instanceId;
      _selectedPartCode = null;
      _parts = const [];
    });
    final instance = _instances.where((e) => e.instanceId == instanceId).firstOrNull;
    if (instance == null) return;
    try {
      final parts = await widget.taskService
          .fetchStructurePartTemplates(objectType: instance.templateSourceType);
      if (!mounted) return;
      setState(() {
        _parts = parts;
        if (parts.isNotEmpty) {
          _selectedPartCode = parts.first.partCode;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('加载粗部位失败: $e')));
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    setState(() => _photo = picked);
  }

  Future<void> _mockSpeechInput() async {
    final controller = TextEditingController(text: _speechController.text);
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
      setState(() => _speechController.text = controller.text.trim());
    }
  }

  String _compatQuickPartTag(String partCode) {
    if (partCode.contains('crest')) return 'crest';
    if (partCode.contains('upstream')) return 'upstream_face';
    if (partCode.contains('downstream')) return 'downstream_face';
    if (partCode.contains('inlet') || partCode.contains('chute')) return 'spillway';
    if (partCode.contains('tunnel') || partCode.contains('outlet')) return 'outlet_structure';
    if (partCode.contains('building') || partCode.contains('equipment')) {
      return 'management_facility';
    }
    if (partCode.contains('bank') || partCode.contains('river') || partCode.contains('slope')) {
      return 'surroundings';
    }
    return 'other';
  }

  Future<void> _save() async {
    if (_selectedInstanceId == null || _selectedInstanceId!.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先选择对象实例')));
      return;
    }
    if (_selectedPartCode == null || _selectedPartCode!.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先选择粗部位')));
      return;
    }
    if (_photo == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先拍照或选择照片')));
      return;
    }

    final speech = _speechController.text.trim();
    final raw = _rawNoteController.text.trim();
    if (speech.isEmpty && raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('speech_text 或 raw_note 至少填写一项')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final captureId = await widget.taskService.createCapture(
        taskId: widget.taskId,
        structureInstanceId: _selectedInstanceId!,
        partCode: _selectedPartCode!,
        quickPartTag: _compatQuickPartTag(_selectedPartCode!),
        quickStatus: _status,
        speechText: speech.isEmpty ? null : speech,
        rawNote: raw.isEmpty ? null : raw,
        createdBy: 'mobile_user',
      );

      await widget.taskService.uploadCaptureMedia(
        captureId: captureId,
        filePath: _photo!.path,
        mediaType: 'photo',
      );

      if (speech.isNotEmpty) {
        await widget.taskService.updateCaptureSpeechText(
          captureId: captureId,
          speechText: speech,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('现场采集已保存')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存失败: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('现场采集')),
      body: _loadingMeta
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              children: [
                if (_photo != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_photo!.path),
                      height: 180,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _pickPhoto(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera),
                      label: const Text('拍照'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _pickPhoto(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('选图'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedInstanceId,
                  decoration: const InputDecoration(labelText: '对象实例（必选）'),
                  items: _instances
                      .map((e) => DropdownMenuItem(
                            value: e.instanceId,
                            child: Text(e.instanceName),
                          ))
                      .toList(),
                  onChanged: _onSelectInstance,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedPartCode,
                  decoration: const InputDecoration(labelText: '粗部位（必选）'),
                  items: _parts
                      .map((e) => DropdownMenuItem(
                            value: e.partCode,
                            child: Text(e.partName),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedPartCode = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: '快速状态'),
                  items: _quickStatus.entries
                      .map((e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) => setState(() => _status = v ?? 'undecided'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _mockSpeechInput,
                  icon: const Icon(Icons.mic),
                  label: const Text('录音/语音录入（MVP）'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _speechController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'speech_text',
                    hintText: '语音转文字（第一阶段可手工补录/Mock）',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _rawNoteController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'raw_note',
                    hintText: '现场补充说明（可选）',
                  ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(12),
        child: FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? '保存中...' : '保存采集记录'),
        ),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
