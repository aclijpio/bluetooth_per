import 'package:flutter/material.dart';
import '../../core/config.dart';
import '../../core/widgets/send_logs_button.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Настройки",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppConfig.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Секция "Логирование"
          _buildSectionHeader('Логирование и диагностика'),
          const SizedBox(height: 8),
          _buildCard([
            _buildInfoTile(
              'Логи сохраняются',
              '/storage/emulated/0/Download/${AppConfig.logsDirName}/',
              Icons.folder,
            ),
            const Divider(height: 1),
            _buildInfoTile(
              'Размер файла лога',
              '${AppConfig.maxLogFileSize ~/ (1024 * 1024)} МБ',
              Icons.storage,
            ),
            const Divider(height: 1),
            _buildInfoTile(
              'Период хранения',
              '${AppConfig.maxLogAge.inDays} дня',
              Icons.schedule,
            ),
            const Divider(height: 1),
            _buildInfoTile(
              'Максимум файлов',
              '${AppConfig.maxLogFilesCount} файлов',
              Icons.inventory,
            ),
          ]),

          const SizedBox(height: 24),

          // Секция "Действия"
          _buildSectionHeader('Действия'),
          const SizedBox(height: 8),
          _buildCard([
            ListTile(
              leading: const Icon(Icons.email, color: AppConfig.primaryColor),
              title: const Text(
                'Отправить логи разработчикам',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: const Text(
                'Отправка файлов логов для диагностики проблем',
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              onTap: () => _showSendLogsDialog(),
            ),
          ]),

          const SizedBox(height: 24),

          // Секция "О приложении"
          _buildSectionHeader('О приложении'),
          const SizedBox(height: 8),
          _buildCard([
            _buildInfoTile(
              'Версия приложения',
              AppConfig.appVersion,
              Icons.info,
            ),
            const Divider(height: 1),
            _buildInfoTile(
              'Разработчик',
              AppConfig.appName,
              Icons.business,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppConfig.primaryColor,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildInfoTile(String title, String subtitle, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: AppConfig.primaryColor),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(subtitle),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
    );
  }

  void _showSendLogsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отправка логов'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Логи содержат информацию о работе приложения и могут помочь в диагностике проблем.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          const SendLogsButton(buttonText: 'Отправить'),
        ],
      ),
    );
  }
}
