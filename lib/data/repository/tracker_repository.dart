import 'package:validation_app/data/database/DatabaseHelper.dart';
import 'package:validation_app/data/database/log_entry.dart'; // Import your LogEntry class

class TrackerRepository {
  // Get the singleton instance of the DatabaseHelper
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // --- Log Entry Operations ---

  // Insert or update a log entry
  Future<void> insertOrUpdateLogEntry(LogEntry entry) async {
    await _dbHelper.insertOrUpdateLogEntry(entry);
    // TODO: Trigger CalculationEngine recalculation here
    // TODO: Notify listeners if using a reactive approach
  }

  // Get a single entry by date
  Future<LogEntry?> getLogEntry(String date) async {
    return await _dbHelper.getLogEntry(date);
  }

  // Get all entries ordered oldest first (useful for calculations)
  Future<List<LogEntry>> getAllLogEntriesOldestFirst() async {
    return await _dbHelper.getAllLogEntries();
  }

  // Get all entries ordered newest first (useful for display history)
  Future<List<LogEntry>> getAllLogEntriesNewestFirst() async {
    return await _dbHelper.getAllLogEntriesNewestFirst();
  }

  // Delete a log entry by date
  Future<void> deleteLogEntry(String date) async {
    await _dbHelper.deleteLogEntry(date);
    // TODO: Trigger CalculationEngine recalculation here
    // TODO: Notify listeners if using a reactive approach
  }

  // Clear all log entries
  Future<void> clearAllLogEntries() async {
    await _dbHelper.clearAllLogEntries();
    // TODO: Trigger CalculationEngine recalculation here
    // TODO: Notify listeners if using a reactive approach
  }

  // --- User Settings Operations ---
  // TODO: Implement methods to get/save user profile stats (Height, Age, etc.)
  // TODO: Implement methods to get/save Goal Rate
  // TODO: Implement methods to get/save Algorithm Parameters (Alphas, etc.)
  // These might use SharedPreferences, DataStore, or another table via DatabaseHelper

  // --- Calculation Engine Interaction ---
  // TODO: Instantiate or get reference to CalculationEngine
  // TODO: Add method to trigger calculations and get results
  //       e.g., Future<CalculatedStatus> getLatestStatus()

  // --- Import/Export ---
  // TODO: Implement logic for detailed JSON export
  // TODO: Implement logic for CSV import/export
}
