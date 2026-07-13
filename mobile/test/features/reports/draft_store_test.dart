import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:smartngo/features/reports/draft_store.dart';
import 'package:smartngo/features/reports/models/report_draft.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

ReportDraft _draft({
  int? id,
  String title = 'Borehole inspection',
  DateTime? updatedAt,
}) {
  return ReportDraft(
    id: id,
    projectId: 3,
    projectName: 'WASH',
    title: title,
    description: 'Checked pump pressure.',
    reportType: 'weekly',
    latitude: -0.4547,
    longitude: 35.2698,
    photoPaths: const ['/tmp/a.jpg', '/tmp/b.jpg'],
    updatedAt: updatedAt ?? DateTime(2026, 7, 13, 10, 30),
  );
}

void main() {
  sqfliteFfiInit();

  late SqfliteDraftStore store;
  late Directory tmpDir;

  setUp(() async {
    // A fresh database file per test — the ffi factory returns the same
    // singleton for a repeated path (including :memory:), so a shared path
    // would leak rows between tests.
    tmpDir = await Directory.systemTemp.createTemp('smartngo_drafts_test');
    store = SqfliteDraftStore(
      factory: databaseFactoryFfi,
      dbPath: p.join(tmpDir.path, 'drafts.db'),
    );
  });

  tearDown(() async {
    await tmpDir.delete(recursive: true);
  });

  test('save assigns an id and list round-trips every field', () async {
    final saved = await store.save(_draft());

    expect(saved.id, isNotNull);
    final drafts = await store.list();
    expect(drafts, hasLength(1));
    final d = drafts.single;
    expect(d.id, saved.id);
    expect(d.projectId, 3);
    expect(d.projectName, 'WASH');
    expect(d.title, 'Borehole inspection');
    expect(d.description, 'Checked pump pressure.');
    expect(d.reportType, 'weekly');
    expect(d.latitude, closeTo(-0.4547, 1e-9));
    expect(d.longitude, closeTo(35.2698, 1e-9));
    expect(d.photoPaths, ['/tmp/a.jpg', '/tmp/b.jpg']);
    expect(d.updatedAt, DateTime(2026, 7, 13, 10, 30));
  });

  test('saving with an existing id updates the row in place', () async {
    final saved = await store.save(_draft());

    await store.save(_draft(id: saved.id, title: 'Updated title'));

    final drafts = await store.list();
    expect(drafts, hasLength(1));
    expect(drafts.single.title, 'Updated title');
  });

  test('list returns drafts newest first', () async {
    await store.save(_draft(title: 'Older', updatedAt: DateTime(2026, 7, 1)));
    await store.save(_draft(title: 'Newer', updatedAt: DateTime(2026, 7, 12)));

    final drafts = await store.list();
    expect(drafts.map((d) => d.title), ['Newer', 'Older']);
  });

  test('delete removes the draft', () async {
    final saved = await store.save(_draft());

    await store.delete(saved.id!);

    expect(await store.list(), isEmpty);
  });
}
