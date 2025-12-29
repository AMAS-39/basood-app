import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class FileLogger {
  static File? _logFile;
  static const String _logFileName = 'basood_debug.log';
  static final List<String> _logBuffer = [];
  static const int _maxBufferSize = 1000; // Keep last 1000 logs in memory

  static Future<void> init() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      _logFile = File('${directory.path}/$_logFileName');

      // Clear old log on app start (optional - comment out if you want to keep history)
      // await _logFile!.writeAsString('');

      await log('📱 ========== APP STARTED - LOGGER INITIALIZED ==========');
    } catch (e) {
      print('Failed to initialize file logger: $e');
    }
  }

  static Future<void> log(String message) async {
    try {
      final timestamp = DateTime.now().toIso8601String();
      final logEntry = '[$timestamp] $message';

      // Add to buffer
      _logBuffer.add(logEntry);
      if (_logBuffer.length > _maxBufferSize) {
        _logBuffer.removeAt(0); // Remove oldest
      }

      // Write to file
      if (_logFile == null) await init();
      await _logFile!.writeAsString('$logEntry\n', mode: FileMode.append);

      // Also print to console
      print(logEntry);
    } catch (e) {
      print('Failed to write to log file: $e');
    }
  }

  static Future<String> getAllLogs() async {
    try {
      if (_logFile == null) await init();

      if (await _logFile!.exists()) {
        final content = await _logFile!.readAsString();
        if (content.isEmpty && _logBuffer.isNotEmpty) {
          // If file is empty but buffer has logs, return buffer
          return _logBuffer.join('\n');
        }
        return content;
      }

      // If file doesn't exist, return buffer
      return _logBuffer.join('\n');
    } catch (e) {
      return 'Error reading log file: $e\n\nBuffer logs:\n${_logBuffer.join('\n')}';
    }
  }

  static Future<String?> getLogFilePath() async {
    try {
      if (_logFile == null) await init();
      return _logFile?.path;
    } catch (e) {
      return null;
    }
  }

  static Future<void> shareLogFile() async {
    try {
      var logs = await getAllLogs();
      if (logs.isEmpty || logs.trim().isEmpty) {
        logs =
            'No logs available yet. Logging will start after app initialization.';
      }

      // Create a temporary file to share
      final directory = await getTemporaryDirectory();
      final tempFile = File(
        '${directory.path}/basood_debug_${DateTime.now().millisecondsSinceEpoch}.log',
      );
      await tempFile.writeAsString(logs);

      // Share the file
      await Share.shareXFiles(
        [XFile(tempFile.path)],
        text: 'Basood Debug Logs',
        subject: 'Basood App Debug Logs',
      );
    } catch (e) {
      print('Error sharing log file: $e');
      // Fallback: share as text
      try {
        var logs = await getAllLogs();
        if (logs.isEmpty || logs.trim().isEmpty) {
          logs = 'No logs available yet.';
        }
        await Share.shareXFiles(
          [XFile(_logFile!.path)],
          text: logs,
          subject: 'Basood App Debug Logs',
        );
      } catch (e2) {
        print('Error in fallback share: $e2');
      }
    }
  }
}
