import 'package:flutter/material.dart';

import 'core/api/api_client.dart';
import 'core/config/app_config.dart';
import 'features/tasks/task_list_page.dart';
import 'features/tasks/task_service.dart';

class ReservoirInspectionApp extends StatelessWidget {
  const ReservoirInspectionApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiClient = ApiClient(baseUrl: AppConfig.apiBaseUrl);
    final taskService = TaskService(apiClient);

    return MaterialApp(
      title: '水库现场安全检查',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E6A9E)),
        useMaterial3: true,
      ),
      home: TaskListPage(taskService: taskService),
    );
  }
}
