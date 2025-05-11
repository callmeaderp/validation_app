// lib/ui/log_history_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:validation_app/data/database/log_entry.dart';
import 'package:validation_app/data/repository/tracker_repository.dart';
// START OF CHANGES: Import UserSettings and SettingsRepository
import 'package:validation_app/models/user_settings.dart';
import 'package:validation_app/data/repository/settings_repository.dart';
// END OF CHANGES

class LogHistoryScreen extends StatefulWidget {
  const LogHistoryScreen({super.key});

  @override
  _LogHistoryScreenState createState() => _LogHistoryScreenState();
}

class _LogHistoryScreenState extends State<LogHistoryScreen> {
  final TrackerRepository _repository = TrackerRepository();
  Future<List<LogEntry>>? _entriesFuture;

  // START OF CHANGES: Add state for UserSettings and SettingsRepository instance
  final SettingsRepository _settingsRepo = SettingsRepository();
  UserSettings? _currentUserSettings;
  String _settingsErrorMessage = '';
  bool _areSettingsLoading = true;
  // END OF CHANGES

  @override
  void initState() {
    super.initState();
    _loadData(); // This will now load settings then entries
  }

  // START OF CHANGES: Combined loading method
  Future<void> _loadData() async {
    setState(() {
      _areSettingsLoading = true;
      _settingsErrorMessage = '';
    });
    try {
      final settings = await _settingsRepo.loadSettings();
      if (mounted) {
        setState(() {
          _currentUserSettings = settings;
          _areSettingsLoading = false;
        });
        // Now load entries as settings are available
        _loadEntries();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _settingsErrorMessage = 'Error loading settings: $e';
          _areSettingsLoading = false;
        });
      }
    }
  }
  // END OF CHANGES

  void _loadEntries() {
    // This is called after settings are loaded
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
            icon: const Icon(Icons.refresh),
            onPressed: _loadData, // Refresh both settings and entries
            tooltip: 'Refresh Data',
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _confirmClearAll,
            tooltip: 'Clear All Entries',
          ),
        ],
      ),
      // START OF CHANGES: Handle settings loading state
      body:
          _areSettingsLoading
              ? const Center(
                child: CircularProgressIndicator(
                  semanticsLabel: 'Loading settings...',
                ),
              )
              : _settingsErrorMessage.isNotEmpty
              ? _buildSettingsErrorView()
              : FutureBuilder<List<LogEntry>>(
                future: _entriesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        semanticsLabel: 'Loading entries...',
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return _buildEntriesErrorView(snapshot.error.toString());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return _buildEmptyView();
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
      // END OF CHANGES
    );
  }

  // START OF CHANGES: Error view for settings
  Widget _buildSettingsErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.settings_applications,
              size: 48,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _settingsErrorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
  // END OF CHANGES

  Widget _buildEntriesErrorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error loading entries: $error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadEntries,
              child: const Text('Retry Entries'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start logging your daily weight and calories to see them here',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              // Navigate to log input screen, which is the root.
              onPressed:
                  () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
              child: const Text('Go to Log Screen'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogEntryCard(LogEntry entry) {
    final date = DateTime.parse(entry.date);
    final formattedDate = DateFormat('E, MMM d, yyyy').format(date);
    // START OF CHANGES: Get weight unit from loaded settings
    final weightUnit =
        _currentUserSettings?.weightUnitString ??
        'kg'; // Default to 'kg' if settings not loaded
    // END OF CHANGES

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
                      // START OF CHANGES: Use dynamic unit
                      ? '${entry.rawWeight!.toStringAsFixed(1)} $weightUnit'
                      // END OF CHANGES
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
    // START OF CHANGES: Get weight unit for dialog
    final weightUnitSuffix = _currentUserSettings?.weightUnitString ?? 'kg';
    // END OF CHANGES

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Edit Entry for ${DateFormat('MMM d, yyyy').format(DateTime.parse(entry.date))}',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: weightController,
                  decoration: InputDecoration(
                    labelText: 'Weight',
                    // START OF CHANGES: Dynamic suffix in dialog
                    suffixText: weightUnitSuffix,
                    // END OF CHANGES
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    if (value != null &&
                        value.isNotEmpty &&
                        double.tryParse(value) == null) {
                      return 'Invalid number';
                    }
                    if (value != null &&
                        value.isNotEmpty &&
                        (double.tryParse(value) ?? -1) <= 0) {
                      return 'Must be positive';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: caloriesController,
                  decoration: const InputDecoration(
                    labelText: 'Previous Day\'s Calories',
                    suffixText: 'kcal',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value != null &&
                        value.isNotEmpty &&
                        int.tryParse(value) == null) {
                      return 'Invalid number';
                    }
                    if (value != null &&
                        value.isNotEmpty &&
                        (int.tryParse(value) ?? 0) < 0) {
                      return 'Cannot be negative';
                    }
                    return null;
                  },
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
                // Basic validation within dialog for quick feedback
                final currentContext =
                    context; // Capture context before async gap

                double? weight =
                    weightController.text.isNotEmpty
                        ? double.tryParse(weightController.text)
                        : null;
                int? calories =
                    caloriesController.text.isNotEmpty
                        ? int.tryParse(caloriesController.text)
                        : null;

                if (weightController.text.isNotEmpty && weight == null) {
                  ScaffoldMessenger.of(currentContext).showSnackBar(
                    const SnackBar(content: Text('Invalid weight format.')),
                  );
                  return;
                }
                if (weight != null && weight <= 0) {
                  ScaffoldMessenger.of(currentContext).showSnackBar(
                    const SnackBar(content: Text('Weight must be positive.')),
                  );
                  return;
                }
                if (caloriesController.text.isNotEmpty && calories == null) {
                  ScaffoldMessenger.of(currentContext).showSnackBar(
                    const SnackBar(content: Text('Invalid calorie format.')),
                  );
                  return;
                }
                if (calories != null && calories < 0) {
                  ScaffoldMessenger.of(currentContext).showSnackBar(
                    const SnackBar(
                      content: Text('Calories cannot be negative.'),
                    ),
                  );
                  return;
                }

                final updatedEntry = LogEntry(
                  date: entry.date,
                  rawWeight: weight,
                  rawPreviousDayCalories: calories,
                );

                await _repository.insertOrUpdateLogEntry(updatedEntry);

                if (!mounted) return;
                Navigator.of(currentContext).pop(); // Use captured context
                _loadEntries(); // Refresh the list

                ScaffoldMessenger.of(currentContext).showSnackBar(
                  const SnackBar(
                    content: Text('Entry updated successfully'),
                    duration: Duration(seconds: 2),
                  ),
                );
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
        final dialogContext = context; // Capture context
        return AlertDialog(
          title: const Text('Delete Entry?'),
          content: SingleChildScrollView(
            child: Text(
              'Are you sure you want to delete the entry for ${DateFormat('MMM d, yyyy').format(DateTime.parse(entry.date))}?',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await _repository.deleteLogEntry(entry.date);
                if (!mounted) return;
                Navigator.of(dialogContext).pop();
                _loadEntries();
                ScaffoldMessenger.of(context).showSnackBar(
                  // Original context should be fine here
                  const SnackBar(
                    content: Text('Entry deleted'),
                    duration: Duration(seconds: 2),
                  ),
                );
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
        final dialogContext = context; // Capture context
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
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await _repository.clearAllLogEntries();
                if (!mounted) return;
                Navigator.of(dialogContext).pop();
                _loadEntries();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All entries cleared'),
                    duration: Duration(seconds: 2),
                  ),
                );
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
