import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models/report_draft.dart';

/// Local persistence for offline report drafts.
///
/// The app provides [SqfliteDraftStore] on mobile and [InMemoryDraftStore]
/// on web, where the sqflite plugin is unavailable (web drafts therefore
/// last only for the browser session — acceptable for the dev/demo target).
abstract class DraftStore {
  /// All drafts on this device, newest first.
  Future<List<ReportDraft>> list();

  /// Insert (id == null) or update (id != null) a draft; returns it with id.
  Future<ReportDraft> save(ReportDraft draft);

  /// Remove a draft, e.g. after it has been submitted to the server.
  Future<void> delete(int id);
}

/// sqflite-backed [DraftStore]; the database file is created lazily on
/// first use. A custom [DatabaseFactory] and path can be injected so tests
/// can run against SQLite FFI with an in-memory database.
class SqfliteDraftStore implements DraftStore {
  static const _dbFile = 'smartngo_drafts.db';
  static const _table = 'report_drafts';
  static const _schemaVersion = 2;

  /// Columns added in schema v2 (structured donor reporting), as
  /// `name TYPE` fragments. Reused by both onCreate and onUpgrade so the two
  /// paths cannot drift.
  static const _structuredColumns = <String>[
    "activity_type TEXT NOT NULL DEFAULT ''",
    'linked_phase_id INTEGER',
    'linked_milestone_id INTEGER',
    "amount_spent TEXT NOT NULL DEFAULT ''",
    "expenditure_notes TEXT NOT NULL DEFAULT ''",
    'beneficiaries_reached INTEGER NOT NULL DEFAULT 0',
    'beneficiaries_male INTEGER NOT NULL DEFAULT 0',
    'beneficiaries_female INTEGER NOT NULL DEFAULT 0',
    'beneficiaries_youth INTEGER NOT NULL DEFAULT 0',
    "impact_description TEXT NOT NULL DEFAULT ''",
    "challenges_faced TEXT NOT NULL DEFAULT ''",
    "recommendations TEXT NOT NULL DEFAULT ''",
    "next_steps TEXT NOT NULL DEFAULT ''",
  ];

  final DatabaseFactory? _factory;
  final String? _dbPath;
  Database? _db;

  SqfliteDraftStore({this._factory, this._dbPath});

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final factory = _factory ?? databaseFactory;
    final path = _dbPath ?? p.join(await factory.getDatabasesPath(), _dbFile);
    _db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _schemaVersion,
        onCreate: (db, version) => db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            project_id INTEGER NOT NULL,
            project_name TEXT NOT NULL,
            title TEXT NOT NULL,
            description TEXT NOT NULL DEFAULT '',
            report_type TEXT NOT NULL DEFAULT 'daily',
            gps_latitude REAL,
            gps_longitude REAL,
            photo_paths TEXT NOT NULL DEFAULT '[]',
            updated_at INTEGER NOT NULL,
            ${_structuredColumns.join(',\n            ')}
          )
        '''),
        // Additive upgrade: a draft captured in the field before the app
        // updated must survive, so v1 rows are widened in place rather than
        // the table being recreated.
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            for (final column in _structuredColumns) {
              await db.execute('ALTER TABLE $_table ADD COLUMN $column');
            }
          }
        },
      ),
    );
    return _db!;
  }

  @override
  Future<List<ReportDraft>> list() async {
    final db = await _open();
    final rows = await db.query(_table, orderBy: 'updated_at DESC');
    return rows.map(ReportDraft.fromMap).toList();
  }

  @override
  Future<ReportDraft> save(ReportDraft draft) async {
    final db = await _open();
    if (draft.id == null) {
      final id = await db.insert(_table, draft.toMap());
      return draft.copyWith(id: id);
    }
    await db.update(
      _table,
      draft.toMap(),
      where: 'id = ?',
      whereArgs: [draft.id],
    );
    return draft;
  }

  @override
  Future<void> delete(int id) async {
    final db = await _open();
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}

/// Volatile [DraftStore] used on web (no sqflite) and in widget tests.
class InMemoryDraftStore implements DraftStore {
  final _drafts = <int, ReportDraft>{};
  int _nextId = 1;

  @override
  Future<List<ReportDraft>> list() async {
    final all = _drafts.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return all;
  }

  @override
  Future<ReportDraft> save(ReportDraft draft) async {
    final withId = draft.id == null ? draft.copyWith(id: _nextId++) : draft;
    _drafts[withId.id!] = withId;
    return withId;
  }

  @override
  Future<void> delete(int id) async {
    _drafts.remove(id);
  }
}
