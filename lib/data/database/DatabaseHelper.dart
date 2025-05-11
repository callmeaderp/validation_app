import 'dart:async'; // Needed for Future
import 'dart:io'; // Needed for Directory access (within path_provider)

import 'package:path/path.dart'; // Provides join function for paths
import 'package:path_provider/path_provider.dart'; // Finds correct directory for DB
import 'package:sqflite/sqflite.dart'; // The SQLite plugin

import 'log_entry.dart'; // Import your LogEntry class

class DatabaseHelper {
  // Define constants for database name, version, table, columns
  static const _databaseName = "TrackerValidation.db";
  static const _databaseVersion = 1;

  static const tableLogs = 'log_entries';
  static const columnDate = 'date'; // PRIMARY KEY, TEXT YYYY-MM-DD
  static const columnWeight = 'rawWeight'; // REAL, Nullable
  static const columnCalories = 'rawPreviousDayCalories'; // INTEGER, Nullable

  // Make this a singleton class (only one instance)
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  // Only have a single app-wide reference to the database
  static Database? _database; // Nullable Database object

  // Getter for the database, initializes it lazily if needed
  Future<Database> get database async {
    if (_database != null) {
      return _database!; // Return existing instance if available
    }
    // Lazily instantiate the db the first time it is accessed
    _database = await _initDatabase();
    return _database!;
  }

  // Opens the database (and creates it if it doesn't exist)
  _initDatabase() async {
    Directory documentsDirectory =
        await getApplicationDocumentsDirectory(); // Get standard doc directory
    String path = join(
      documentsDirectory.path,
      _databaseName,
    ); // Construct path using path package
    // Open database using sqflite
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    ); // Execute _onCreate only the first time DB is created
  }

  // SQL code to create the database table
  Future _onCreate(Database db, int version) async {
    await db.execute('''
          CREATE TABLE $tableLogs (
            $columnDate TEXT PRIMARY KEY NOT NULL,
            $columnWeight REAL,
            $columnCalories INTEGER
          )
          ''');
    print("Database table '$tableLogs' created!");
  }

  // --- Helper Methods (CRUD Operations) ---

  // Inserts a row in the database where the values are mapped columns.
  // Returns the ID of the inserted row (or rowid).
  // Using ConflictAlgorithm.replace ensures that if a log for the same
  // date exists, it gets updated instead of throwing an error.
  Future<int> insertOrUpdateLogEntry(LogEntry entry) async {
    Database db = await instance.database;
    return await db.insert(
      tableLogs,
      entry.toMap(), // Use the toMap() method from LogEntry
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Retrieves a single LogEntry by date.
  Future<LogEntry?> getLogEntry(String date) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> maps = await db.query(
      tableLogs,
      columns: [columnDate, columnWeight, columnCalories],
      where: '$columnDate = ?',
      whereArgs: [date],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      // Use the fromMap() factory constructor from LogEntry
      return LogEntry.fromMap(maps.first);
    } else {
      return null;
    }
  }

  // Retrieves all rows from the log_entries table, ordered by date ascending.
  Future<List<LogEntry>> getAllLogEntries() async {
    Database db = await instance.database;
    List<Map<String, dynamic>> maps = await db.query(
      tableLogs,
      orderBy: '$columnDate ASC', // Oldest first for calculations
    );
    if (maps.isNotEmpty) {
      return maps.map((map) => LogEntry.fromMap(map)).toList();
    } else {
      return [];
    }
  }

  // Retrieves all rows ordered by date descending (for display perhaps).
  Future<List<LogEntry>> getAllLogEntriesNewestFirst() async {
    Database db = await instance.database;
    List<Map<String, dynamic>> maps = await db.query(
      tableLogs,
      orderBy: '$columnDate DESC', // Newest first for display
    );
    if (maps.isNotEmpty) {
      return maps.map((map) => LogEntry.fromMap(map)).toList();
    } else {
      return [];
    }
  }

  // Updates a row in the database. Returns number of rows affected.
  Future<int> updateLogEntry(LogEntry entry) async {
    Database db = await instance.database;
    return await db.update(
      tableLogs,
      entry.toMap(),
      where: '$columnDate = ?',
      whereArgs: [entry.date],
    );
  }

  // Deletes the row specified by the date. Returns number of rows affected.
  Future<int> deleteLogEntry(String date) async {
    Database db = await instance.database;
    return await db.delete(
      tableLogs,
      where: '$columnDate = ?',
      whereArgs: [date],
    );
  }

  // Deletes all rows in the table. Returns number of rows affected.
  Future<int> clearAllLogEntries() async {
    Database db = await instance.database;
    return await db.delete(tableLogs);
  }
}
