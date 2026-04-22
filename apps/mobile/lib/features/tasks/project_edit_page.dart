import 'package:flutter/material.dart';

import 'project_structure_config_page.dart';
import 'task_service.dart';

class ProjectEditPage extends StatefulWidget {
  const ProjectEditPage({
    super.key,
    required this.taskService,
    required this.projectId,
  });

  final TaskService taskService;
  final String projectId;

  @override
  State<ProjectEditPage> createState() => _ProjectEditPageState();
}

class _ProjectEditPageState extends State<ProjectEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String _damType = 'earthfill';
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail =
          await widget.taskService.fetchProjectDetail(widget.projectId);
      if (!mounted) return;
      _nameController.text = detail.reservoirName;
      _descController.text = detail.description ?? '';
      _damType = detail.damType;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.taskService.updateProject(
        projectId: widget.projectId,
        reservoirName: _nameController.text.trim(),
        damType: _damType,
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('项目属性已保存')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openStructureConfig() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectStructureConfigPage(
          taskService: widget.taskService,
          projectId: widget.projectId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('项目属性')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('加载失败: $_error'))
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: '水库名称'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? '请输入水库名称' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _damType,
                        decoration: const InputDecoration(labelText: '坝型'),
                        items: const [
                          DropdownMenuItem(
                              value: 'earthfill', child: Text('土石坝')),
                          DropdownMenuItem(
                              value: 'concrete', child: Text('混凝土坝')),
                        ],
                        onChanged: (v) =>
                            setState(() => _damType = v ?? 'earthfill'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _descController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(labelText: '备注（可选）'),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _openStructureConfig,
                        icon: const Icon(Icons.apartment_outlined),
                        label: const Text('对象配置'),
                      ),
                    ],
                  ),
                ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(12),
        child: FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? '保存中...' : '保存项目属性'),
        ),
      ),
    );
  }
}
