import 'package:flutter/material.dart';

import 'task_models.dart';
import 'task_service.dart';

class ProjectStructureConfigPage extends StatefulWidget {
  const ProjectStructureConfigPage({
    super.key,
    required this.taskService,
    required this.projectId,
  });

  final TaskService taskService;
  final String projectId;

  @override
  State<ProjectStructureConfigPage> createState() =>
      _ProjectStructureConfigPageState();
}

class _ProjectStructureConfigPageState extends State<ProjectStructureConfigPage> {
  static const List<_PresetMeta> _presets = [
    _PresetMeta('main_dam', '主坝', false),
    _PresetMeta('aux_dam', '副坝', true),
    _PresetMeta('spillway', '溢洪道', false),
    _PresetMeta('outlet_tunnel', '输水洞', true),
    _PresetMeta('spill_tunnel', '泄洪洞', true),
    _PresetMeta('power_tunnel', '发电洞', true),
    _PresetMeta('admin_facility', '管理设施', false),
    _PresetMeta('updownstream_env', '上下游环境对象', false),
  ];

  bool _loading = true;
  bool _savingBatch = false;
  bool _adding = false;
  String? _error;
  List<StructureInstanceItem> _items = const [];

  final Map<String, bool> _selected = {
    for (final p in _presets)
      p.objectType: p.objectType == 'main_dam' ||
          p.objectType == 'spillway' ||
          p.objectType == 'admin_facility' ||
          p.objectType == 'updownstream_env',
  };
  final Map<String, int> _counts = {
    for (final p in _presets) p.objectType: 1,
  };

  final _customNameController = TextEditingController();
  String _customCategory = 'other';
  String _customTemplateType = 'main_dam';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _customNameController.dispose();
    super.dispose();
  }

  bool get _isInitialized => _items.isNotEmpty;
  List<_PresetMeta> get _sortedPresets {
    final rows = List<_PresetMeta>.from(_presets);
    rows.sort((a, b) {
      final aSelected = _selected[a.objectType] == true;
      final bSelected = _selected[b.objectType] == true;
      if (aSelected == bSelected) {
        return _presets.indexOf(a).compareTo(_presets.indexOf(b));
      }
      return aSelected ? -1 : 1;
    });
    return rows;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.taskService
          .fetchProjectStructureInstances(widget.projectId);
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

  Future<void> _batchInit() async {
    final presets = <Map<String, dynamic>>[];
    for (final p in _presets) {
      if (_selected[p.objectType] == true) {
        presets.add({
          'object_type': p.objectType,
          'count': p.isMulti ? (_counts[p.objectType] ?? 1) : 1,
        });
      }
    }
    if (presets.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请至少选择一个对象类型')));
      return;
    }

    setState(() => _savingBatch = true);
    try {
      await widget.taskService.batchInitStructureInstances(
        projectId: widget.projectId,
        presets: presets,
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('项目对象初始化完成')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('初始化失败: $e')));
    } finally {
      if (mounted) setState(() => _savingBatch = false);
    }
  }

  Future<void> _saveRename(StructureInstanceItem item, String newName) async {
    if (newName.trim().isEmpty || newName.trim() == item.instanceName) return;
    try {
      await widget.taskService.patchStructureInstance(
        projectId: widget.projectId,
        instanceId: item.instanceId,
        instanceName: newName.trim(),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('改名失败: $e')));
    }
  }

  Future<void> _toggleEnabled(StructureInstanceItem item, bool enabled) async {
    try {
      await widget.taskService.patchStructureInstance(
        projectId: widget.projectId,
        instanceId: item.instanceId,
        enabledForCapture: enabled,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('更新失败: $e')));
    }
  }

  Future<void> _addCustom() async {
    final name = _customNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请输入自定义对象名称')));
      return;
    }
    setState(() => _adding = true);
    try {
      await widget.taskService.createStructureInstance(
        projectId: widget.projectId,
        objectType: 'custom',
        instanceName: name,
        categoryCode: _customCategory,
        templateSourceType: _customTemplateType,
      );
      _customNameController.clear();
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已追加自定义对象')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('追加失败: $e')));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _addPresetInstance(_PresetMeta preset) async {
    setState(() => _adding = true);
    try {
      await widget.taskService.createStructureInstance(
        projectId: widget.projectId,
        objectType: preset.objectType,
        instanceName: '${preset.label}${preset.isMulti ? _nextIndex(preset) : ''}',
      );
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('追加失败: $e')));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  int _nextIndex(_PresetMeta preset) {
    final count = _items.where((e) => e.objectType == preset.objectType).length;
    return count + 1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('项目对象配置'),
        actions: [
          TextButton(
            onPressed: _isInitialized ? () => Navigator.pop(context, true) : null,
            child: const Text('完成'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('加载失败: $_error'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  children: [
                    if (!_isInitialized) ...[
                      const Text('1) 首次初始化：选择预设对象与数量'),
                      const SizedBox(height: 8),
                      ..._sortedPresets.map((p) {
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: _selected[p.objectType] ?? false,
                                  onChanged: (v) =>
                                      setState(() => _selected[p.objectType] = v ?? false),
                                ),
                                Expanded(child: Text(p.label)),
                                if (p.isMulti)
                                  SizedBox(
                                    width: 90,
                                    child: TextFormField(
                                      initialValue:
                                          (_counts[p.objectType] ?? 1).toString(),
                                      decoration: const InputDecoration(labelText: '数量'),
                                      keyboardType: TextInputType.number,
                                      onChanged: (v) {
                                        final parsed = int.tryParse(v) ?? 1;
                                        _counts[p.objectType] = parsed < 1 ? 1 : parsed;
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: _savingBatch ? null : _batchInit,
                        child: Text(_savingBatch ? '初始化中...' : '保存初始化对象库'),
                      ),
                      const Divider(height: 32),
                    ],
                    Card(
                      margin: EdgeInsets.zero,
                      child: ExpansionTile(
                        initiallyExpanded: false,
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        title: const Text('2-4) 对象维护（展开后可改名/禁用/追加）'),
                        subtitle: Text(
                          _items.isEmpty
                              ? '暂无对象实例'
                              : '当前共 ${_items.length} 个对象实例',
                        ),
                        children: [
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text('2) 当前对象实例（可改名/禁用/追加）'),
                          ),
                          const SizedBox(height: 8),
                          if (_items.isEmpty)
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text('暂无对象实例，请先做首次初始化。'),
                            )
                          else
                            ..._items.map(
                              (item) => _InstanceTile(
                                item: item,
                                onRename: (newName) => _saveRename(item, newName),
                                onToggleEnabled: (enabled) =>
                                    _toggleEnabled(item, enabled),
                              ),
                            ),
                          const SizedBox(height: 16),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text('3) 追加预设对象'),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _presets
                                .map(
                                  (p) => OutlinedButton(
                                    onPressed:
                                        _adding ? null : () => _addPresetInstance(p),
                                    child: Text('+ ${p.label}'),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 16),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text('4) 追加自定义对象（必须选大类与模板来源）'),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _customNameController,
                            decoration:
                                const InputDecoration(labelText: '自定义对象名称'),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _customCategory,
                            decoration: const InputDecoration(labelText: '所属大类'),
                            items: const [
                              DropdownMenuItem(
                                  value: 'water_retaining', child: Text('挡水建筑物')),
                              DropdownMenuItem(
                                  value: 'water_releasing', child: Text('泄水建筑物')),
                              DropdownMenuItem(
                                  value: 'water_conveyance',
                                  child: Text('输（放）水建筑物')),
                              DropdownMenuItem(
                                  value: 'power_generation', child: Text('发电建筑物')),
                              DropdownMenuItem(
                                  value: 'management', child: Text('管理设施')),
                              DropdownMenuItem(
                                  value: 'environment', child: Text('上下游环境')),
                              DropdownMenuItem(value: 'other', child: Text('其他')),
                            ],
                            onChanged: (v) =>
                                setState(() => _customCategory = v ?? 'other'),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _customTemplateType,
                            decoration: const InputDecoration(labelText: '模板来源类型'),
                            items: const [
                              DropdownMenuItem(
                                  value: 'main_dam', child: Text('主坝模板')),
                              DropdownMenuItem(
                                  value: 'aux_dam', child: Text('副坝模板')),
                              DropdownMenuItem(
                                  value: 'spillway', child: Text('溢洪道模板')),
                              DropdownMenuItem(
                                  value: 'outlet_tunnel', child: Text('输水洞模板')),
                              DropdownMenuItem(
                                  value: 'spill_tunnel', child: Text('泄洪洞模板')),
                              DropdownMenuItem(
                                  value: 'power_tunnel', child: Text('发电洞模板')),
                              DropdownMenuItem(
                                  value: 'admin_facility',
                                  child: Text('管理设施模板')),
                              DropdownMenuItem(
                                  value: 'updownstream_env',
                                  child: Text('上下游环境模板')),
                            ],
                            onChanged: (v) => setState(
                              () => _customTemplateType = v ?? 'main_dam',
                            ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: _adding ? null : _addCustom,
                            child: Text(_adding ? '追加中...' : '追加自定义对象'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _InstanceTile extends StatefulWidget {
  const _InstanceTile({
    required this.item,
    required this.onRename,
    required this.onToggleEnabled,
  });

  final StructureInstanceItem item;
  final ValueChanged<String> onRename;
  final ValueChanged<bool> onToggleEnabled;

  @override
  State<_InstanceTile> createState() => _InstanceTileState();
}

class _InstanceTileState extends State<_InstanceTile> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item.instanceName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _controller,
                    decoration: InputDecoration(
                      labelText: '${item.objectType} (${item.instanceId})',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => widget.onRename(_controller.text.trim()),
                  icon: const Icon(Icons.save_outlined),
                  tooltip: '保存名称',
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('采集启用'),
              value: item.enabledForCapture,
              onChanged: widget.onToggleEnabled,
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetMeta {
  const _PresetMeta(this.objectType, this.label, this.isMulti);

  final String objectType;
  final String label;
  final bool isMulti;
}
