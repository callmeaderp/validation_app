class LogEntry {
  final String date; // Primary Key - Format "YYYY-MM-DD"
  final double? rawWeight; // Nullable if not logged
  final int? rawPreviousDayCalories; // Nullable if not logged

  LogEntry({required this.date, this.rawWeight, this.rawPreviousDayCalories});

  // Helper method to convert a LogEntry object into a Map.
  // Useful for inserting/updating data into the sqflite database.
  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'rawWeight': rawWeight,
      'rawPreviousDayCalories': rawPreviousDayCalories,
    };
  }

  // Optional: Helper method to create a LogEntry object from a Map.
  // Useful when reading data from the database.
  factory LogEntry.fromMap(Map<String, dynamic> map) {
    return LogEntry(
      date: map['date'] as String,
      rawWeight: map['rawWeight'] as double?,
      rawPreviousDayCalories: map['rawPreviousDayCalories'] as int?,
    );
  }

  // Optional: toString for easier debugging
  @override
  String toString() {
    return 'LogEntry(date: $date, weight: $rawWeight, calories: $rawPreviousDayCalories)';
  }
}
