import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:validation_app/data/database/log_entry.dart';
import 'package:validation_app/data/repository/tracker_repository.dart';

class LogHistoryScreen extends StatefulWidget {
  const LogHistoryScreen({Key? key}) : super(key: key);

  @override
  _LogHistoryScreenState createState() => _LogHistoryScreenState();
}

class _LogHistoryScreenState extends State<LogHistoryScreen> {
  final TrackerRepository _repository = TrackerRepository();
  Future<List<LogEntry>>? _entriesFuture;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  void _loadEntries() {
    setState(() {
      _entriesFuture = _repository.getAllLogEntriesNewestFirst();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _confirmClearAll,
            tooltip: 'Clear All Entries',
          ),
        ],
      ),
      body: FutureBuilder<List<LogEntry>>(
        future: _entriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading entries: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadEntries,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.history, size: 48, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'No log entries yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Start logging your daily weight and calories to see them here',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Go to Log Screen'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final entry = snapshot.data![index];
              return _buildLogEntryCard(entry);
            },
          );
        },
      ),
    );
  }

  Widget _buildLogEntryCard(LogEntry entry) {
    // Parse the date string (YYYY-MM-DD) into a DateTime
    final date = DateTime.parse(entry.date);
    final formattedDate = DateFormat('E, MMM d, yyyy').format(date);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(
          formattedDate,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.monitor_weight, size: 16, color: Colors.blue[700]),
                const SizedBox(width: 4),
                Text(
                  entry.rawWeight != null
                      ? '${entry.rawWeight!.toStringAsFixed(1)} kg' // TODO: Make unit dynamic
                      : 'No weight logged',
                  style: TextStyle(
                    color: entry.rawWeight != null ? null : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.local_fire_department,
                  size: 16,
                  color: Colors.orange[700],
                ),
                const SizedBox(width: 4),
                Text(
                  entry.rawPreviousDayCalories != null
                      ? '${entry.rawPreviousDayCalories} kcal'
                      : 'No calories logged',
                  style: TextStyle(
                    color:
                        entry.rawPreviousDayCalories != null
                            ? null
                            : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _showEditDialog(entry),
              tooltip: 'Edit Entry',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _confirmDelete(entry),
              tooltip: 'Delete Entry',
            ),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Future<void> _showEditDialog(LogEntry entry) async {
    final weightController = TextEditingController(
      text: entry.rawWeight?.toString() ?? '',
    );
    final caloriesController = TextEditingController(
      text: entry.rawPreviousDayCalories?.toString() ?? '',
    );

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit Entry for ${entry.date}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: weightController,
                  decoration: const InputDecoration(
                    labelText: 'Weight',
                    suffixText: 'kg', // TODO: Make unit dynamic
                  ),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: caloriesController,
                  decoration: const InputDecoration(
                    labelText: 'Previous Day\'s Calories',
                    suffixText: 'kcal',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                // Parse inputs, allowing for empty strings
                double? weight =
                    weightController.text.isNotEmpty
                        ? double.tryParse(weightController.text)
                        : null;

                int? calories =
                    caloriesController.text.isNotEmpty
                        ? int.tryParse(caloriesController.text)
                        : null;

                // Create updated entry
                final updatedEntry = LogEntry(
                  date: entry.date,
                  rawWeight: weight,
                  rawPreviousDayCalories: calories,
                );

                // Save to database
                await _repository.insertOrUpdateLogEntry(updatedEntry);

                // Refresh the list
                if (mounted) {
                  Navigator.of(context).pop();
                  _loadEntries();

                  // Show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Entry updated successfully'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDelete(LogEntry entry) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Entry?'),
          content: SingleChildScrollView(
            child: Text(
              'Are you sure you want to delete the entry for ${entry.date}?',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await _repository.deleteLogEntry(entry.date);

                if (mounted) {
                  Navigator.of(context).pop();
                  _loadEntries();

                  // Show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Entry deleted'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmClearAll() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear All Entries?'),
          content: const SingleChildScrollView(
            child: Text(
              'Are you sure you want to delete ALL log entries? This action cannot be undone.',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await _repository.clearAllLogEntries();

                if (mounted) {
                  Navigator.of(context).pop();
                  _loadEntries();

                  // Show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All entries cleared'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: const Text(
                'Clear All',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
}
