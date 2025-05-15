// lib/data/repository/tracker_repository.dart
import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:validation_app/data/database/DatabaseHelper.dart';
import 'package:validation_app/data/database/log_entry.dart';
import 'package:validation_app/calculation/calculation_engine.dart';
import 'package:validation_app/models/user_settings.dart';

/// Repository for tracking data operations
/// Manages CRUD operations for log entries and facilitates interactions
/// with the CalculationEngine
class TrackerRepository {
  // Get the singleton instance of the DatabaseHelper
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Stream controller for reactive updates
  final _logEntryStreamController =
      StreamController<List<LogEntry>>.broadcast();

  // Public stream that UI components can listen to for updates
  Stream<List<LogEntry>> get logEntriesStream =>
      _logEntryStreamController.stream;

  // --- Log Entry Operations ---

  /// Insert or update a log entry
  /// Returns the row ID of the inserted/updated entry
  Future<int> insertOrUpdateLogEntry(LogEntry entry) async {
    // Insert/update in database
    final rowId = await _dbHelper.insertOrUpdateLogEntry(entry);

    // Notify listeners about the change
    _notifyListeners();

    return rowId;
  }

  /// Get a single entry by date
  Future<LogEntry?> getLogEntry(String date) async {
    return await _dbHelper.getLogEntry(date);
  }

  /// Get all entries ordered oldest first (useful for calculations)
  Future<List<LogEntry>> getAllLogEntriesOldestFirst() async {
    return await _dbHelper.getAllLogEntries();
  }

  /// Get all entries ordered newest first (useful for display history)
  Future<List<LogEntry>> getAllLogEntriesNewestFirst() async {
    return await _dbHelper.getAllLogEntriesNewestFirst();
  }

  /// Delete a log entry by date
  Future<void> deleteLogEntry(String date) async {
    await _dbHelper.deleteLogEntry(date);

    // Notify listeners about the change
    _notifyListeners();
  }

  /// Clear all log entries
  Future<void> clearAllLogEntries() async {
    await _dbHelper.clearAllLogEntries();

    // Notify listeners about the change
    _notifyListeners();
  }

  /// Get entries for a specific date range
  Future<List<LogEntry>> getEntriesInDateRange(
    String startDate,
    String endDate,
  ) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableLogs,
      where:
          '${DatabaseHelper.columnDate} >= ? AND ${DatabaseHelper.columnDate} <= ?',
      whereArgs: [startDate, endDate],
      orderBy: '${DatabaseHelper.columnDate} ASC',
    );

    return maps.map((map) => LogEntry.fromMap(map)).toList();
  }

  /// Get the most recent entry
  Future<LogEntry?> getMostRecentEntry() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableLogs,
      orderBy: '${DatabaseHelper.columnDate} DESC',
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return LogEntry.fromMap(maps.first);
    }
    return null;
  }

  /// Calculate current status using the provided CalculationEngine
  Future<CalculationResult> calculateCurrentStatus(
    CalculationEngine engine,
    UserSettings settings,
  ) async {
    final entries = await getAllLogEntriesOldestFirst();
    return await engine.calculateStatus(entries, settings);
  }

  /// Helper method to notify listeners about data changes
  Future<void> _notifyListeners() async {
    // Get the updated list of entries
    final entries = await getAllLogEntriesOldestFirst();

    // Emit the updated list to any listeners
    if (!_logEntryStreamController.isClosed) {
      _logEntryStreamController.add(entries);
    }
  }

  /// Get count of entries in the database
  Future<int> getEntryCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM ${DatabaseHelper.tableLogs}',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Check if an entry exists for today
  Future<bool> hasTodayEntry() async {
    final today = DateTime.now();
    final dateString =
        "${today.year.toString().padLeft(4, '0')}-"
        "${today.month.toString().padLeft(2, '0')}-"
        "${today.day.toString().padLeft(2, '0')}";

    final entry = await getLogEntry(dateString);
    return entry != null;
  }

  /// Get stats about logging consistency
  Future<Map<String, dynamic>> getLoggingStats() async {
    final entries = await getAllLogEntriesOldestFirst();

    if (entries.isEmpty) {
      return {
        'totalDays': 0,
        'daysWithWeight': 0,
        'daysWithCalories': 0,
        'completeDataPercentage': 0.0,
        'longestStreak': 0,
        'currentStreak': 0,
      };
    }

    int daysWithWeight = entries.where((e) => e.rawWeight != null).length;
    int daysWithCalories =
        entries.where((e) => e.rawPreviousDayCalories != null).length;
    int daysWithBoth =
        entries
            .where(
              (e) => e.rawWeight != null && e.rawPreviousDayCalories != null,
            )
            .length;

    // Calculate streaks (consecutive days with data)
    int currentStreak = 0;
    int longestStreak = 0;
    int tempStreak = 0;

    // Sort entries by date to calculate streaks properly
    final sortedEntries = List<LogEntry>.from(entries)
      ..sort((a, b) => a.date.compareTo(b.date));

    DateTime? previousDate;
    for (var entry in sortedEntries) {
      final currentDate = DateTime.parse(entry.date);

      // Check if this entry has both weight and calories data
      bool hasCompleteData =
          entry.rawWeight != null && entry.rawPreviousDayCalories != null;

      // Check if this entry is consecutive with the previous one
      if (previousDate != null) {
        final difference = currentDate.difference(previousDate).inDays;

        if (difference == 1 && hasCompleteData) {
          // Consecutive day with data - increment streak
          tempStreak++;
        } else {
          // Break in streak - reset counter
          tempStreak = hasCompleteData ? 1 : 0;
        }
      } else {
        // First entry
        tempStreak = hasCompleteData ? 1 : 0;
      }

      // Update longest streak if current one is better
      longestStreak = tempStreak > longestStreak ? tempStreak : longestStreak;

      // Save for next iteration
      previousDate = currentDate;
    }

    // Current streak is the value of tempStreak at the end if the most recent entry is today or yesterday
    final today = DateTime.now();
    final lastEntryDate = DateTime.parse(sortedEntries.last.date);
    final daysSinceLastEntry = today.difference(lastEntryDate).inDays;

    if (daysSinceLastEntry <= 1) {
      currentStreak = tempStreak;
    } else {
      currentStreak = 0; // Reset if more than 1 day has passed
    }

    // Calculate complete data percentage
    double completeDataPercentage =
        entries.isEmpty ? 0.0 : (daysWithBoth / entries.length) * 100.0;

    return {
      'totalDays': entries.length,
      'daysWithWeight': daysWithWeight,
      'daysWithCalories': daysWithCalories,
      'completeDataPercentage': completeDataPercentage,
      'longestStreak': longestStreak,
      'currentStreak': currentStreak,
    };
  }

  /// Clean up resources
  void dispose() {
    _logEntryStreamController.close();
  }
}
