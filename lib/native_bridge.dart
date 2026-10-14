import 'package:flutter/services.dart';

/// PDFs handed to the app by another app ("Open with" / "Share").
class SharedFiles {
  /// Local copies, ready to import.
  final List<String> paths;

  /// Files that couldn't be read from the sending app.
  final List<String> failed;

  const SharedFiles(this.paths, this.failed);

  factory SharedFiles.fromChannel(Object? value) {
    final map = (value as Map?) ?? const {};
    return SharedFiles(List<String>.from(map['paths'] ?? const []),
        List<String>.from(map['failed'] ?? const []));
  }

  bool get isEmpty => paths.isEmpty && failed.isEmpty;
}

/// Talks to MainActivity.kt for things plugins don't cover: PDFs shared to the
/// app from other apps, and saving large files to a user-chosen location.
class NativeBridge {
  static const _channel = MethodChannel('sheet_music_viewer/files');

  /// [handler] receives PDFs shared to the app while it's running.
  static void setOnFilesShared(void Function(SharedFiles files) handler) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'filesShared') {
        handler(SharedFiles.fromChannel(call.arguments));
      }
    });
  }

  /// Any PDFs the app was launched with.
  static Future<SharedFiles> getInitialSharedFiles() async =>
      SharedFiles.fromChannel(await _channel.invokeMethod('getInitialSharedFiles'));

  /// The installed app's version, e.g. "2.0.0 (8)" (version name and build number).
  static Future<String> getAppVersion() async {
    final info = await _channel.invokeMethod<Map>('getAppVersion');
    return "${info?['name']} (${info?['code']})";
  }

  /// Lets the user pick where to save [sourcePath]. Returns false if cancelled or failed.
  static Future<bool> saveFileAs(String sourcePath, String fileName, String mimeType) async {
    final saved = await _channel.invokeMethod<bool>('saveFileAs', {
      'sourcePath': sourcePath,
      'fileName': fileName,
      'mimeType': mimeType,
    });
    return saved ?? false;
  }
}
