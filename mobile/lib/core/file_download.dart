import 'dart:typed_data';

import 'file_download_io.dart'
    if (dart.library.js_interop) 'file_download_web.dart' as impl;

/// Where a downloaded file ended up, for the confirmation message.
class DownloadResult {
  /// True when the platform handled the file itself (the browser's download
  /// bar), so there is no path worth showing.
  final bool handledByPlatform;

  /// Filesystem location on platforms that saved it themselves.
  final String? path;

  const DownloadResult.platform()
      : handledByPlatform = true,
        path = null;

  const DownloadResult.saved(this.path) : handledByPlatform = false;

  /// Message to show the user once the download completes.
  String get message => handledByPlatform
      ? 'Download started.'
      : 'Saved to ${path ?? 'your device'}';
}

/// Save [bytes] as [filename], using whatever the current platform offers.
///
/// Web triggers a browser download; everything else writes to the app's
/// documents directory and reports the path back. Split behind a conditional
/// import because the two need libraries that do not exist on the other
/// platform.
Future<DownloadResult> saveFile(Uint8List bytes, String filename) =>
    impl.saveFile(bytes, filename);
