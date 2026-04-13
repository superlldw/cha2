import 'package:flutter/material.dart';

import 'task_models.dart';
import 'task_service.dart';

class StartInspectionPage extends StatefulWidget {
  const StartInspectionPage({
    super.key,
    required this.taskService,
    required this.project,
  });

  final TaskService taskService;
  final ProjectListItem project;

  @override
  State<StartInspectionPage> createState() => _StartInspectionPageState();
}

class _StartInspectionPageState extends State<StartInspectionPage> {
  final _formKey = GlobalKey<FormState>();
  final _inspectorsController = TextEditingController();
  final _waterLevelController = TextEditingController();

  DateTime _inspectionDate = DateTime.now();
  String _weather = '晴天';
  bool _submitting = false;

  @override
  void dispose() {
    _inspectorsController.dispose();
    _waterLevelController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _inspectionDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked != null) {
      setState(() => _inspectionDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final inspectors = _inspectorsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final waterLevel = double.tryParse(_waterLevelController.text.trim());
      final taskId = await widget.taskService.createTask(
        projectId: widget.project.projectId,
        reservoirName: widget.project.reservoirName,
        damType: widget.project.damType,
        inspectionType: 'routine',
        inspectionDate: _inspectionDate,
        weather: _weather,
        inspectors: inspectors,
        waterLevel: waterLevel,
      );
      if (!mounted) return;
      Navigator.pop(context, taskId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('开始检查失败: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateText = _inspectionDate.toIso8601String().split('T').first;
    return Scaffold(
      appBar: AppBar(title: const Text('开始检查')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(widget.project.reservoirName),
              subtitle: Text('坝型：${_damTypeLabel(widget.project.damType)}'),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('检查日期'),
              subtitle: Text(dateText),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _weather,
              decoration: const InputDecoration(labelText: '检查天气'),
              items: const ['晴天', '阴天', '大雨', '小雨', '雪']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _weather = v ?? '晴天'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _waterLevelController,
              decoration: const InputDecoration(labelText: '当日库水位（可不填）'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                final text = (v ?? '').trim();
                if (text.isEmpty) return null;
                return double.tryParse(text) == null ? '请输入数字' : null;
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _inspectorsController,
              decoration: const InputDecoration(
                labelText: '检查人员（可不填）',
                hintText: '多人请用英文逗号分隔',
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(12),
        child: FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? '创建中...' : '开始检查'),
        ),
      ),
    );
  }

  static String _damTypeLabel(String value) {
    switch (value) {
      case 'earthfill':
        return '土石坝';
      case 'concrete':
        return '混凝土坝';
      default:
        return value;
    }
  }
}
