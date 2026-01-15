import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:path/path.dart';
import '../models/transaction.dart';
import '../models/case.dart';
import '../models/pdf_import.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'mis_cuentas.db');
    return await openDatabase(
      path,
      version: 4, // Force upgrade
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        descriptionRaw TEXT,
        merchantNorm TEXT,
        amount REAL,
        currency TEXT,
        pdfName TEXT,
        pageNumber INTEGER,
        period TEXT
      )
    ''');
    // ... existing cases table ...
    await db.execute('''
      CREATE TABLE cases(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transactionId INTEGER,
        type INTEGER,
        explanation TEXT,
        status INTEGER,
        FOREIGN KEY(transactionId) REFERENCES transactions(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE imports(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fileName TEXT,
        importDate TEXT,
        path TEXT,
        statementDate TEXT 
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migration for Statement Date
      await db.execute('ALTER TABLE imports ADD COLUMN statementDate TEXT');
    }
    if (oldVersion < 3) {
      // Migration for Period
      await db.execute('ALTER TABLE transactions ADD COLUMN period TEXT');
    }
    if (oldVersion < 4) {
      // Re-run Period migration just in case it failed or user was on weird state
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN period TEXT');
      } catch (e) {
        print("Migration: Column 'period' likely already exists. Error: $e");
      }
    }
  }

  // Transactions
  Future<int> insertTransaction(Transaction transaction) async {
    Database db = await database;
    return await db.insert('transactions', transaction.toMap());
  }

  Future<List<Transaction>> getTransactions() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      orderBy: "date DESC",
    );
    return List.generate(maps.length, (i) => Transaction.fromMap(maps[i]));
  }

  Future<void> deleteAllTransactions() async {
    Database db = await database;
    await db.delete('transactions');
  }

  // Cases
  Future<int> insertCase(Case caseModel) async {
    Database db = await database;
    return await db.insert('cases', caseModel.toMap());
  }

  Future<List<Case>> getCases() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('cases');
    return List.generate(maps.length, (i) => Case.fromMap(maps[i]));
  }

  Future<void> updateCaseStatus(int id, CaseStatus status) async {
    Database db = await database;
    await db.update(
      'cases',
      {'status': status.index},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteAllCases() async {
    Database db = await database;
    await db.delete('cases');
  }

  // Imports
  Future<int> insertImport(PdfImport pdfImport) async {
    Database db = await database;
    return await db.insert('imports', pdfImport.toMap());
  }

  Future<List<PdfImport>> getImports() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'imports',
      orderBy: "importDate DESC",
    );
    return List.generate(maps.length, (i) => PdfImport.fromMap(maps[i]));
  }

  // Periods
  Future<List<String?>> getPeriods() async {
    Database db = await database;
    // Get distinct periods, including NULL
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      'SELECT DISTINCT period FROM transactions ORDER BY period DESC',
    );
    return List.generate(maps.length, (i) => maps[i]['period'] as String?);
  }

  Future<void> clearAllData() async {
    Database db = await database;
    await db.delete('transactions');
    await db.delete('cases');
    await db.delete('imports');
  }
}
