import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:csv/csv.dart';
import 'package:synchronized/synchronized.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  final _lock = Lock();

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'parking_data.db');
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE parking_records(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        receipt_id TEXT NOT NULL,
        vehicle_number TEXT NOT NULL,
        vehicle_type TEXT NOT NULL,
        checkin_time TEXT,
        checkout_time TEXT,
        checkedin_by TEXT,
        checkedout_by TEXT,
        amount REAL,
        duration TEXT,
        is_synced INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  Future<int> insertCheckInRecord(Map<String, dynamic> record) async {
    final db = await database;
    return await _lock.synchronized(() async {
      return await db.insert('parking_records', {
        'receipt_id': record['receipt_id'],
        'vehicle_number': record['vehicle_number'],
        'vehicle_type': record['vehicle_type'],
        'checkin_time': record['checkin_time'],
        'checkedin_by': record['checkedin_by'],
        'is_synced': 0,
      });
    });
  }

  Future<List<Map<String, dynamic>>> searchVehicleLocally(
    String vehicleNumber,
  ) async {
    final db = await database;
    return await db.query(
      'parking_records',
      where: 'vehicle_number = ?',
      whereArgs: [vehicleNumber],
    );
  }

  Future<int> updateCheckOutRecord(Map<String, dynamic> record) async {
    final db = await database;
    return await _lock.synchronized(() async {
      return await db.update(
        'parking_records',
        {
          'checkout_time': record['checkout_time'],
          'checkedout_by': record['checkedout_by'],
          'amount': record['amount'],
          'duration': record['duration'],
          'is_synced': 0,
        },
        where: 'receipt_id = ?',
        whereArgs: [record['receipt_id']],
      );
    });
  }

  Future<List<Map<String, dynamic>>> getUnsyncedRecords() async {
    final db = await database;
    return await db.query('parking_records', where: 'is_synced = 0');
  }

  Future<void> markRecordsAsSynced(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    await _lock.synchronized(() async {
      await db.rawUpdate(
        'UPDATE parking_records SET is_synced = 1 WHERE id IN (${List.filled(ids.length, '?').join(',')})',
        ids,
      );
    });
  }

  Future<String> exportToCsv() async {
    final db = await database;
    final records = await db.query('parking_records');

    if (records.isEmpty) {
      return '';
    }

    // Create CSV data
    List<List<dynamic>> csvData = [];

    // Add header
    csvData.add([
      'receipt_id',
      'vehicle_number',
      'vehicle_type',
      'checkin_time',
      'checkout_time',
      'checkedin_by',
      'checkedout_by',
      'amount',
      'duration',
    ]);

    // Add records
    for (var record in records) {
      csvData.add([
        record['receipt_id'],
        record['vehicle_number'],
        record['vehicle_type'],
        record['checkin_time'],
        record['checkout_time'],
        record['checkedin_by'],
        record['checkedout_by'],
        record['amount'],
        record['duration'],
      ]);
    }

    // Convert to CSV string
    return const ListToCsvConverter().convert(csvData);
  }
}
