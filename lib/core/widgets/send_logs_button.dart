import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:path/path.dart' as path;
import '../config.dart';
import '../utils/log_manager.dart';

class SendLogsButton extends StatefulWidget {
  final String buttonText;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final EdgeInsetsGeometry? padding;

  const SendLogsButton({
    Key? key,
    this.buttonText = 'Отправить логи',
    this.icon = Icons.send,
    this.backgroundColor,
    this.textColor,
    this.padding,
  }) : super(key: key);

  @override
  State<SendLogsButton> createState() => _SendLogsButtonState();
}

class _SendLogsButtonState extends State<SendLogsButton> {
  bool _isLoading = false;

  Future<void> _sendLogs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final logContent = await LogManager.getAllLogsContent();

      if (logContent.isEmpty) {
        _showMessage('Нет логов для отправки', isError: false);
        return;
      }

      // Пытаемся отправить через SMTP
      bool smtpSent = await _sendViaSMTP(logContent);

      if (!smtpSent) {
        // Если SMTP не сработал, показываем диалог с альтернативными вариантами
        await _showFallbackOptions(logContent);
      }
    } catch (e) {
      LogManager.error('EMAIL', 'Ошибка отправки логов: $e');
      _showMessage('Ошибка отправки логов: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _sendViaSMTP(String logContent) async {
    try {
      // Настройка SMTP сервера
      final smtpServer = SmtpServer(
        AppConfig.smtpHost,
        port: AppConfig.smtpPort,
        ssl: false, // TLS будет использован автоматически
        allowInsecure: false,
        username: AppConfig.senderEmail,
        password: AppConfig.senderPassword,
      );

      final message = Message()
        ..from = Address(AppConfig.senderEmail, AppConfig.senderName)
        ..recipients.add(AppConfig.supportEmail)
        ..subject = '${AppConfig.logEmailSubject} - ${DateTime.now().toLocal()}'
        ..text = '${AppConfig.logEmailBodyPrefix}$logContent';

      await send(message, smtpServer);

      LogManager.info('EMAIL', 'Логи успешно отправлены через SMTP');
      _showMessage('Логи отправлены!', isError: false);
      Navigator.of(context).pop();

      return true;
    } catch (e) {
      LogManager.warning('EMAIL', 'Не удалось отправить через SMTP: $e');

      if (e.toString().contains('authentication') ||
          e.toString().contains('Authentication')) {
        _showMessage('Ошибка аутентификации SMTP. Проверьте настройки email.',
            isError: true);
      } else if (e.toString().contains('network') ||
          e.toString().contains('timeout')) {
        _showMessage('Нет подключения к интернету. Попробуйте позже.',
            isError: true);
      } else {
        _showMessage('Ошибка SMTP сервера. Попробуйте альтернативные способы.',
            isError: true);
      }

      return false;
    }
  }

  Future<void> _sendViaMailto(String logContent) async {
    try {
      String truncatedContent = logContent;
      if (logContent.length > AppConfig.maxMailtoContentLength) {
        truncatedContent =
            logContent.substring(0, AppConfig.maxMailtoContentLength) +
                AppConfig.mailtoTruncationMessage;
      }

      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: AppConfig.supportEmail,
        query: _encodeQueryParameters({
          'subject':
              '${AppConfig.logEmailSubject} - ${DateTime.now().toLocal()}',
          'body': '${AppConfig.logEmailBodyPrefix}$truncatedContent',
        }),
      );

      // Удаляем проверку canLaunchUrl и пытаемся сразу запустить
      try {
        Process.run('cmd', ['/c', 'start', emailUri.toString()]);
        LogManager.info('EMAIL', 'Открыт mailto для отправки логов');
        _showMessage('Открыто приложение почты', isError: false);
      } catch (e) {
        throw Exception('Не удалось открыть почтовое приложение');
      }
    } catch (e) {
      LogManager.error('EMAIL', 'Ошибка при открытии mailto: $e');
      throw Exception('Не удалось открыть почтовое приложение: $e');
    }
  }

  String _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((MapEntry<String, String> e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  void _showMessage(String message, {required bool isError}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: isError ? 4 : 2),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _sendLogs,
      icon: _isLoading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  widget.textColor ?? Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            )
          : Icon(
              widget.icon,
              color:
                  widget.textColor ?? Theme.of(context).colorScheme.onPrimary,
            ),
      label: Text(
        _isLoading ? 'Отправка...' : widget.buttonText,
        style: TextStyle(
          color: widget.textColor ?? Theme.of(context).colorScheme.onPrimary,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor:
            widget.backgroundColor ?? Theme.of(context).colorScheme.primary,
        padding: widget.padding ??
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Future<void> _showFallbackOptions(String logContent) async {
    if (!mounted) return;

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Не удалось отправить через SMTP'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SMTP сервер недоступен. Выберите альтернативный способ:',
              ),
              SizedBox(height: 8),
              Text(
                '• Скопировать логи в буфер обмена\n'
                '• Сохранить логи в файл\n'
                '• Попробовать отправить через браузер',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _copyToClipboard(logContent);
              },
              child: const Text('Копировать'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _saveToFile(logContent);
              },
              child: const Text('Сохранить'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _sendViaMailto(logContent);
              },
              child: const Text('Браузер'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _copyToClipboard(String logContent) async {
    try {
      await Clipboard.setData(ClipboardData(text: logContent));
      LogManager.info('EMAIL', 'Логи скопированы в буфер обмена');
      _showMessage('Логи скопированы в буфер обмена', isError: false);
    } catch (e) {
      LogManager.error('EMAIL', 'Ошибка копирования в буфер: $e');
      _showMessage('Ошибка копирования: $e', isError: true);
    }
  }

  Future<void> _saveToFile(String logContent) async {
    try {
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = 'logs_$timestamp.txt';
      final downloadsPath = '/storage/emulated/0/Download';
      final filePath = path.join(downloadsPath, fileName);

      final file = File(filePath);
      await file.writeAsString(logContent);

      LogManager.info('EMAIL', 'Логи сохранены в файл: $filePath');
      _showMessage('Логи сохранены в: $fileName', isError: false);
    } catch (e) {
      LogManager.error('EMAIL', 'Ошибка сохранения файла: $e');
      _showMessage('Ошибка сохранения: $e', isError: true);
    }
  }
}
