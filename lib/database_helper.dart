
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDB('image_to_pdf.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(
    Database db,
    int version,
  ) async {
    await db.execute('''
      CREATE TABLE pdf_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_name TEXT NOT NULL,
        file_path TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<int> insertPdf(Map<String, dynamic> pdf) async {
    final db = await database;

    return await db.insert(
      'pdf_history',
      pdf,
    );
  }

  Future<List<Map<String, dynamic>>> getAllPdfs() async {
    final db = await database;

    return await db.query(
      'pdf_history',
      orderBy: 'id DESC',
    );
  }

  Future<int> deletePdf(int id) async {
    final db = await database;

    return await db.delete(
      'pdf_history',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
