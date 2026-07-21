import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'file_download.dart';

/// Mobile/desktop: write the file into the app's documents directory and
/// hand back the path so the UI can tell the user where it went.
Future<DownloadResult> saveFile(Uint8List bytes, String filename) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path, filename));
  await file.writeAsBytes(bytes, flush: true);
  return DownloadResult.saved(file.path);
}
