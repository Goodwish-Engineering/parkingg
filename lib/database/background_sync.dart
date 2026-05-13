import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:parking/auth/api_endpoints.dart';
import 'package:parking/auth/auth_service.dart';
import 'package:parking/database/helper_class.dart';
import 'package:synchronized/synchronized.dart';

class SyncService {
  // Singleton pattern
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  Timer? _syncTimer;
  Timer? _midnightCleanupTimer;
  final _lock = Lock(reentrant: true); // For synchronizing database operations
  bool _isSyncStarted = false; // Flag to prevent duplicate startAutoSync calls

  void startAutoSync({int intervalMinutes = 1}) {
    if (_isSyncStarted) return; // Prevent duplicate calls
    _isSyncStarted = true;

    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(Duration(minutes: intervalMinutes), (timer) {
      _syncData();
    });

    // Start the midnight cleanup scheduler
    _scheduleMidnightCleanup();
  }

  void stopAutoSync() {
    _isSyncStarted = false;
    _syncTimer?.cancel();
    _syncTimer = null;
    _midnightCleanupTimer?.cancel();
    _midnightCleanupTimer = null;
  }

  Future<void> _syncData() async {
    debugPrint("awaiting lock");
    await _lock.synchronized(() async {
      try {
        final unsyncedRecords = await _dbHelper.getUnsyncedRecords();
        if (unsyncedRecords.isEmpty) return;

        final csvData = await _dbHelper.exportToCsv();
        if (csvData.isEmpty) return;

        final success = await SyncService.syncParkingData(csvData);
        if (success) {
          final ids = unsyncedRecords.map((r) => r['id'] as int).toList();
          await _dbHelper.markRecordsAsSynced(ids);
        }
      } catch (e) {
        debugPrint('Sync error: $e');
      }
    });
  }

  void _scheduleMidnightCleanup() {
    _midnightCleanupTimer?.cancel(); // Cancel any existing timer
    debugPrint("IN SCHEDULE");

    // Use local time instead of UTC to avoid timezone issues
    final nowNepal = DateTime.now().toUtc().add(
      Duration(hours: 5, minutes: 45),
    );
    final nextMidnightNepal = DateTime(
      nowNepal.year,
      nowNepal.month,
      nowNepal.day + 1,
    );
    var durationUntilMidnight =
        nextMidnightNepal.difference(nowNepal) +
        Duration(hours: 5, minutes: 45);

    debugPrint("nowNepal: $nowNepal");
    debugPrint("nextMidnightNepal: $nextMidnightNepal");
    debugPrint("duration Till midnight: $durationUntilMidnight");

    // Ensure duration is positive to avoid immediate execution
    final minDelay = Duration(seconds: 1);
    if (durationUntilMidnight.inSeconds <= 0) {
      debugPrint("Negative or zero duration detected, scheduling for next day");
      final nextDayMidnight = DateTime(
        nowNepal.year,
        nowNepal.month,
        nowNepal.day + 2,
      );
      durationUntilMidnight = nextDayMidnight.difference(nowNepal);
    }

    final effectiveDuration = durationUntilMidnight < minDelay
        ? minDelay
        : durationUntilMidnight;
    debugPrint("effectiveDuration: $effectiveDuration");

    _midnightCleanupTimer = Timer(effectiveDuration, () async {
      debugPrint("MIDNIGHT");
      await _clearDatabaseAtMidnight();
      _scheduleMidnightCleanup(); // Schedule next cleanup
    });
  }

  Future<void> _clearDatabaseAtMidnight() async {
    debugPrint("IN CLEAR METHOD");
    await _lock.synchronized(() async {
      try {
        debugPrint('inside clear method');
        // Sync unsynced records before clearing
        await _syncData();
        final db = await _dbHelper.database;
        await db.transaction((txn) async {
          await txn.delete('parking_records');
        });
        debugPrint('Database cleared at midnight');
      } catch (e) {
        debugPrint('Midnight cleanup error: $e');
      }
    });
  }

  static Future<bool> syncParkingData(String csvContent) async {
    final token = await SecureStorage.getAccessToken();

    try {
      final uri = Uri.parse(
        '${ApiEndpoints.baseUrl}sync/upload-parking-details/',
      );

      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll({'Authorization': 'Bearer $token'});

      request.files.add(
        http.MultipartFile.fromString(
          'file',
          csvContent,
          filename: 'parking_data.csv',
          contentType: http.MediaType('text', 'csv'),
        ),
      );

      request.fields['meta'] = jsonEncode({'extra_info': 'some_value'});

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('Status: ${response.statusCode}');
      debugPrint('Body: ${response.body}');

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Upload error: $e');
      return false;
    }
  }
}
