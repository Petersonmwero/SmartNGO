import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'file_download.dart';

/// Web: hand the bytes to the browser as a Blob and click a temporary
/// anchor, which is the only way to start a download from Dart.
///
/// The object URL is revoked immediately after the click — the browser has
/// already taken its own reference to the blob by then, and leaving it would
/// pin the PDF in memory for the life of the tab.
Future<DownloadResult> saveFile(Uint8List bytes, String filename) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename
    ..style.display = 'none';
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
  return const DownloadResult.platform();
}
