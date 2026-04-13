import 'package:flutter/material.dart';

import 'project_structure_config_page.dart';
import 'task_service.dart';

class NewTaskPage extends StatefulWidget {
  const NewTaskPage({super.key, required this.taskService});

  final TaskService taskService;

  @override
  State<NewTaskPage> createState() => _NewTaskPageState();
}

class _NewTaskPageState extends State<NewTaskPage> {
  final _formKey = GlobalKey<FormState>();
  final _reservoirNameController = TextEditingController();

  String _damType = 'earthfill';
  String _weather = '晴天';
  DateTime _inspectionDate = DateTime.now();
  bool _submitting = false;

  @override
  void dispose() {
    _reservoirNameController.dispose();
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
      final taskId = await widget.taskService.createTaskQuick(
        reservoirName: _reservoirNameController.text.trim(),
        damType: _damType,
        inspectionDate: _inspectionDate,
        weather: _weather,
      );
      if (!mounted) return;

      final task = await widget.taskService.fetchTaskDetail(taskId);
      if (!mounted) return;
      final configured = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ProjectStructureConfigPage(
            taskService: widget.taskService,
            projectId: task.projectId,
          ),
        ),
      );
      if (!mounted) return;
      if (configured == true) {
        Navigator.pop(context, taskId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先完成对象管理配置后再继续')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('创建失败: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateText = _inspectionDate.toIso8601String().split('T').first;
    return Scaffold(
      appBar: AppBar(title: const Text('新建任务')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          children: [
            TextFormField(
              controller: _reservoirNameController,
              decoration: const InputDecoration(labelText: '水库名称'),
              validator: (v) => (v == null || v.trim().isEmpty) ? '请输入水库名称' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _damType,
              decoration: const InputDecoration(labelText: '坝型'),
              items: const ['earthfill', 'concrete']
                  .map((e) => DropdownMenuItem(value: e, child: Text(_damTypeLabel(e))))
                  .toList(),
              onChanged: (v) => setState(() => _damType = v ?? 'earthfill'),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('检查日期'),
              subtitle: Text(dateText),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _weather,
              decoration: const InputDecoration(labelText: '天气'),
              items: const ['晴天', '阴天', '大雨', '小雨', '雪']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _weather = v ?? '晴天'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(12),
        child: FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? '创建中...' : '创建任务并配置对象'),
        ),
      ),
    );
  }

  static String _damTypeLabel(String value) {
    switch (value) {
      case 'earthfill':
        return '土石坝';
      case 'rockfill':
        return '堆石坝';
      case 'concrete':
        return '混凝土坝';
      case 'masonry':
        return '浆砌石坝';
      default:
        return value;
    }
  }
}
