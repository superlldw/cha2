import 'package:flutter/material.dart';

import 'project_structure_config_page.dart';
import 'task_service.dart';

class ProjectCreatePage extends StatefulWidget {
  const ProjectCreatePage({super.key, required this.taskService});

  final TaskService taskService;

  @override
  State<ProjectCreatePage> createState() => _ProjectCreatePageState();
}

class _ProjectCreatePageState extends State<ProjectCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _reservoirNameController = TextEditingController();
  final _descController = TextEditingController();
  String _damType = 'earthfill';
  bool _submitting = false;

  @override
  void dispose() {
    _reservoirNameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final projectId = await widget.taskService.createProject(
        reservoirName: _reservoirNameController.text.trim(),
        damType: _damType,
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
      );
      if (!mounted) return;
      final configured = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ProjectStructureConfigPage(
            taskService: widget.taskService,
            projectId: projectId,
          ),
        ),
      );
      if (!mounted) return;
      if (configured == true) {
        Navigator.pop(context, projectId);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('新建项目失败: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新建项目')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          children: [
            TextFormField(
              controller: _reservoirNameController,
              decoration: const InputDecoration(
                labelText: '水库名称',
                helperText: '一个项目就是一个水库，项目名将自动与水库名一致',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '请输入水库名称' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _damType,
              decoration: const InputDecoration(labelText: '坝型'),
              items: const ['earthfill', 'concrete']
                  .map((e) =>
                      DropdownMenuItem(value: e, child: Text(_damTypeLabel(e))))
                  .toList(),
              onChanged: (v) => setState(() => _damType = v ?? 'earthfill'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: '备注（可选）'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(12),
        child: FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? '创建中...' : '下一步：配置项目对象'),
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
      default:
        return value;
    }
  }
}
