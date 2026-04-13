import 'package:flutter/material.dart';

import '../../core/widgets/loading_error_view.dart';
import 'project_create_page.dart';
import 'project_edit_page.dart';
import 'start_inspection_page.dart';
import 'task_detail_page.dart';
import 'task_models.dart';
import 'task_service.dart';

class TaskListPage extends StatefulWidget {
  const TaskListPage({super.key, required this.taskService});

  final TaskService taskService;

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  bool _loading = true;
  String? _error;
  List<ProjectListItem> _projects = const [];
  List<TaskListItem> _tasks = const [];
  final Set<String> _projectBusy = <String>{};

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
      final projects = await widget.taskService.fetchProjects();
      final tasks = await widget.taskService.fetchTasks();
      if (!mounted) return;
      setState(() {
        _projects = projects;
        _tasks = tasks;
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

  Future<void> _goCreateProject() async {
    final projectId = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectCreatePage(taskService: widget.taskService),
      ),
    );
    if (projectId == null || !mounted) return;
    await _load();
  }

  Future<void> _openArchivePage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArchivedProjectsPage(taskService: widget.taskService),
      ),
    );
    if (mounted) {
      await _load();
    }
  }

  Future<void> _openProjectEdit(ProjectListItem project) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectEditPage(
          taskService: widget.taskService,
          projectId: project.projectId,
        ),
      ),
    );
    if (changed == true && mounted) {
      await _load();
    }
  }

  Future<void> _startInspection(ProjectListItem project) async {
    final taskId = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => StartInspectionPage(
          taskService: widget.taskService,
          project: project,
        ),
      ),
    );
    if (taskId == null || !mounted) return;
    await _load();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskDetailPage(
          taskService: widget.taskService,
          taskId: taskId,
        ),
      ),
    );
    if (mounted) {
      await _load();
    }
  }

  Future<void> _openTask(TaskListItem task) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskDetailPage(
          taskService: widget.taskService,
          taskId: task.taskId,
        ),
      ),
    );
    if (mounted) {
      await _load();
    }
  }

  Future<void> _deleteTask(TaskListItem task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除检查记录'),
        content: Text('确认删除 ${task.inspectionDate} 这次检查吗？'),
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
    try {
      await widget.taskService.deleteTask(task.taskId);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('检查记录已删除')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('删除失败: $e')));
    }
  }

  Future<void> _deleteProject(ProjectListItem project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除项目'),
        content: Text('确认删除项目「${project.reservoirName}」吗？\n请先删除该项目下所有检查记录。'),
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
    try {
      if (_projectBusy.contains(project.projectId)) return;
      setState(() => _projectBusy.add(project.projectId));
      await widget.taskService.deleteProject(project.projectId, force: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('项目已删除')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('删除失败: $e')));
    } finally {
      if (mounted) {
        setState(() => _projectBusy.remove(project.projectId));
      }
    }
  }

  Future<void> _archiveProject(ProjectListItem project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('归档项目'),
        content: Text('确认归档项目「${project.reservoirName}」吗？归档后将不在首页显示。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('归档'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      if (_projectBusy.contains(project.projectId)) return;
      setState(() => _projectBusy.add(project.projectId));
      await widget.taskService.archiveProject(project.projectId);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('项目已归档')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('归档失败: $e')));
    } finally {
      if (mounted) {
        setState(() => _projectBusy.remove(project.projectId));
      }
    }
  }

  String _taskStatusLabel(String status) {
    switch (status) {
      case 'in_progress':
        return '进行中';
      case 'completed':
        return '已完成';
      case 'draft':
        return '草稿';
      default:
        return status;
    }
  }

  List<TaskListItem> _tasksOfProject(String projectId) {
    final rows = _tasks.where((t) => t.projectId == projectId).toList();
    rows.sort((a, b) => b.inspectionDate.compareTo(a.inspectionDate));
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('项目列表'),
        actions: [
          IconButton(
            onPressed: _openArchivePage,
            icon: const Icon(Icons.archive_outlined),
            tooltip: '归档项目',
          ),
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goCreateProject,
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('新建项目'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? LoadingErrorView(message: _error!, onRetry: _load)
              : _projects.isEmpty
                  ? const Center(child: Text('暂无项目，点击右下角新建项目'))
                  : ListView.separated(
                      itemCount: _projects.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final project = _projects[index];
                        final projectTasks = _tasksOfProject(project.projectId);
                        return ExpansionTile(
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(project.reservoirName),
                          subtitle:
                              Text('坝型：${_damTypeLabel(project.damType)}'),
                          trailing: _projectBusy.contains(project.projectId)
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      onPressed: () =>
                                          _openProjectEdit(project),
                                      tooltip: '项目属性',
                                      icon: const Icon(Icons.tune),
                                    ),
                                    IconButton(
                                      onPressed: () => _archiveProject(project),
                                      tooltip: '归档项目',
                                      icon: const Icon(Icons.archive_outlined),
                                    ),
                                    IconButton(
                                      onPressed: () => _deleteProject(project),
                                      tooltip: '删除项目',
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                          childrenPadding:
                              const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () => _startInspection(project),
                                    icon: const Icon(Icons.add_task),
                                    label: const Text('新增检查'),
                                  ),
                                ),
                              ],
                            ),
                            if (projectTasks.isEmpty)
                              const ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text('暂无检查记录'),
                              )
                            else
                              ...projectTasks.map(
                                (task) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text('检查日期：${task.inspectionDate}'),
                                  subtitle: Text(
                                      '状态：${_taskStatusLabel(task.status)}  异常：${task.issueCount}'),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'open') {
                                        _openTask(task);
                                      } else if (value == 'delete') {
                                        _deleteTask(task);
                                      }
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem<String>(
                                        value: 'open',
                                        child: Text('查看详情'),
                                      ),
                                      PopupMenuItem<String>(
                                        value: 'delete',
                                        child: Text('删除检查'),
                                      ),
                                    ],
                                  ),
                                  onTap: () => _openTask(task),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
    );
  }

  static String _damTypeLabel(String value) {
    switch (value) {
      case 'earthfill':
        return '土石坝';
      case 'concrete':
        return '混凝土坝';
      case 'rockfill':
        return '堆石坝';
      case 'masonry':
        return '浆砌石坝';
      default:
        return value;
    }
  }
}

class ArchivedProjectsPage extends StatefulWidget {
  const ArchivedProjectsPage({super.key, required this.taskService});

  final TaskService taskService;

  @override
  State<ArchivedProjectsPage> createState() => _ArchivedProjectsPageState();
}

class _ArchivedProjectsPageState extends State<ArchivedProjectsPage> {
  bool _loading = true;
  String? _error;
  List<ProjectListItem> _projects = const [];

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
      final projects =
          await widget.taskService.fetchProjects(includeArchived: true);
      if (!mounted) return;
      setState(() {
        _projects = projects.where((e) => e.archivedAt != null).toList();
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
      appBar: AppBar(title: const Text('归档项目')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? LoadingErrorView(message: _error!, onRetry: _load)
              : _projects.isEmpty
                  ? const Center(child: Text('暂无归档项目'))
                  : ListView.separated(
                      itemCount: _projects.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _projects[index];
                        return ListTile(
                          title: Text(item.reservoirName),
                          subtitle: Text('坝型：${_damTypeLabel(item.damType)}'),
                        );
                      },
                    ),
    );
  }

  static String _damTypeLabel(String value) {
    switch (value) {
      case 'earthfill':
        return '土石坝';
      case 'concrete':
        return '混凝土坝';
      case 'rockfill':
        return '堆石坝';
      case 'masonry':
        return '浆砌石坝';
      default:
        return value;
    }
  }
}
