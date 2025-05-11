// lib/ui/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:validation_app/models/user_settings.dart';
import 'package:validation_app/data/repository/settings_repository.dart';
import 'package:validation_app/data/repository/tracker_repository.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:validation_app/data/database/DatabaseHelper.dart'; // For clearing DB on import
import 'package:validation_app/data/database/log_entry.dart'; // For LogEntry in import

/// Screen for editing user profile and algorithm settings
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late UserSettings _settings;
  late TextEditingController _heightController;
  late TextEditingController _ageController;
  BiologicalSex? _sex;
  ActivityLevel? _activityLevel;
  late TextEditingController _goalRateController;

  // START OF CHANGES: Add state for unit selection
  WeightUnitSystem? _selectedWeightUnit;
  HeightUnitSystem? _selectedHeightUnit;
  String _currentHeightLabel = 'Height'; // Dynamic label
  // END OF CHANGES

  // Algorithm parameters controllers
  late TextEditingController _weightAlphaController;
  late TextEditingController _weightAlphaMinController;
  late TextEditingController _weightAlphaMaxController;
  late TextEditingController _calorieAlphaController;
  late TextEditingController _calorieAlphaMinController;
  late TextEditingController _calorieAlphaMaxController;
  late TextEditingController _trendSmoothingDaysController;

  bool _isLoading = true;
  String _errorMessage = '';
  bool _isExporting = false;
  bool _isImporting = false;

  final SettingsRepository _settingsRepo = SettingsRepository();
  final TrackerRepository _trackerRepo = TrackerRepository();
  final DatabaseHelper _dbHelper =
      DatabaseHelper.instance; // For direct DB ops during import

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final settings = await _settingsRepo.loadSettings();
      setState(() {
        _settings = settings;

        // Profile controllers
        _heightController = TextEditingController(
          text: settings.height.toString(),
        );
        _ageController = TextEditingController(text: settings.age.toString());
        _sex = settings.sex;
        _activityLevel = settings.activityLevel;
        _goalRateController = TextEditingController(
          text: settings.goalRate.toString(),
        );

        // START OF CHANGES: Initialize unit selections and height label
        _selectedWeightUnit = settings.weightUnit;
        _selectedHeightUnit = settings.heightUnit;
        _updateHeightLabel(); // Set initial height label
        // END OF CHANGES

        // Algorithm parameters controllers
        _weightAlphaController = TextEditingController(
          text: settings.weightAlpha.toString(),
        );
        _weightAlphaMinController = TextEditingController(
          text: settings.weightAlphaMin.toString(),
        );
        _weightAlphaMaxController = TextEditingController(
          text: settings.weightAlphaMax.toString(),
        );
        _calorieAlphaController = TextEditingController(
          text: settings.calorieAlpha.toString(),
        );
        _calorieAlphaMinController = TextEditingController(
          text: settings.calorieAlphaMin.toString(),
        );
        _calorieAlphaMaxController = TextEditingController(
          text: settings.calorieAlphaMax.toString(),
        );
        _trendSmoothingDaysController = TextEditingController(
          text: settings.trendSmoothingDays.toString(),
        );

        _isLoading = false;
        _errorMessage = '';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading settings: $e';
      });
    }
  }

  // START OF CHANGES
  void _updateHeightLabel() {
    if (_selectedHeightUnit == HeightUnitSystem.cm) {
      _currentHeightLabel = 'Height (cm)';
    } else if (_selectedHeightUnit == HeightUnitSystem.ft_in) {
      _currentHeightLabel = 'Height (total inches for ft/in)';
    } else {
      _currentHeightLabel = 'Height';
    }
  }
  // END OF CHANGES

  @override
  void dispose() {
    _heightController.dispose();
    _ageController.dispose();
    _goalRateController.dispose();
    _weightAlphaController.dispose();
    _weightAlphaMinController.dispose();
    _weightAlphaMaxController.dispose();
    _calorieAlphaController.dispose();
    _calorieAlphaMinController.dispose();
    _calorieAlphaMaxController.dispose();
    _trendSmoothingDaysController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // START OF CHANGES: Ensure units are selected
    if (_selectedWeightUnit == null || _selectedHeightUnit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select units before saving.')),
      );
      return;
    }
    // END OF CHANGES

    setState(() => _isLoading = true);
    try {
      final updated = _settings.copyWith(
        height: double.parse(_heightController.text),
        age: int.parse(_ageController.text),
        sex: _sex,
        activityLevel: _activityLevel,
        // START OF CHANGES: Save selected units
        weightUnit: _selectedWeightUnit,
        heightUnit: _selectedHeightUnit,
        // END OF CHANGES
        goalRate: double.parse(_goalRateController.text),
        weightAlpha: double.parse(_weightAlphaController.text),
        weightAlphaMin: double.parse(_weightAlphaMinController.text),
        weightAlphaMax: double.parse(_weightAlphaMaxController.text),
        calorieAlpha: double.parse(_calorieAlphaController.text),
        calorieAlphaMin: double.parse(_calorieAlphaMinController.text),
        calorieAlphaMax: double.parse(_calorieAlphaMaxController.text),
        trendSmoothingDays: int.parse(_trendSmoothingDaysController.text),
      );
      await _settingsRepo.saveSettings(updated);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully')),
      );
      setState(() => _isLoading = false);
      // Optionally pop or inform LogInputStatusNotifier to refresh
      if (Navigator.canPop(context)) {
        Navigator.of(
          context,
        ).pop(true); // Pass true to indicate settings changed
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error saving settings: $e';
      });
    }
  }

  Future<void> _resetAlgorithmParameters() async {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Reset Algorithm Parameters?'),
            content: const Text(
              'This will reset all algorithm parameters to their default values. Your profile and unit settings will not be affected. This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  setState(() => _isLoading = true);
                  try {
                    await _settingsRepo.resetAlgorithmParameters();
                    // Reload all settings to reflect changes in UI,
                    // including potentially algorithm params if they were linked to UserSettings defaults
                    await _loadSettings();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Algorithm parameters reset to defaults'),
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    setState(() {
                      _isLoading = false;
                      _errorMessage = 'Error resetting parameters: $e';
                    });
                  }
                },
                child: const Text('Reset'),
              ),
            ],
          ),
    );
  }

  Future<void> _exportBasicCsv() async {
    setState(() => _isExporting = true);
    try {
      final entries = await _trackerRepo.getAllLogEntriesOldestFirst();
      if (entries.isEmpty) {
        setState(() => _isExporting = false);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No data to export')));
        return;
      }
      final csvData = await _settingsRepo.exportBasicCsv(entries);
      final filePath = await _settingsRepo.saveExportToFile(
        csvData,
        'weight_tracker_basic',
        'csv',
      );
      await Share.shareXFiles([
        XFile(filePath),
      ], text: 'Weight Tracker Basic Export');
      setState(() => _isExporting = false);
    } catch (e) {
      setState(() {
        _isExporting = false;
        _errorMessage = 'Error exporting data: $e';
      });
    }
  }

  Future<void> _exportDetailedJson() async {
    setState(() => _isExporting = true);
    try {
      final entries = await _trackerRepo.getAllLogEntriesOldestFirst();
      final currentSettings =
          await _settingsRepo
              .loadSettings(); // Load current settings for export

      if (entries.isEmpty) {
        setState(() => _isExporting = false);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No data to export')));
        return;
      }
      final jsonData = await _settingsRepo.exportDetailedJson(
        entries,
        currentSettings,
      );
      final filePath = await _settingsRepo.saveExportToFile(
        jsonData,
        'weight_tracker_detailed',
        'json',
      );
      await Share.shareXFiles([
        XFile(filePath),
      ], text: 'Weight Tracker Detailed Export');
      setState(() => _isExporting = false);
    } catch (e) {
      setState(() {
        _isExporting = false;
        _errorMessage = 'Error exporting data: $e';
      });
    }
  }

  Future<void> _importCsv() async {
    setState(() => _isImporting = true);
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _isImporting = false);
        return;
      }
      String? filePath = result.files.single.path;
      if (filePath == null) {
        setState(() => _isImporting = false);
        return;
      }
      final file = File(filePath);
      final csvData = await file.readAsString();

      if (!mounted) return;
      // Get parsed entries first
      final List<LogEntry> importedEntries = await _settingsRepo
          .parseBasicCsvToLogEntries(csvData);

      if (importedEntries.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid entries found in CSV file.')),
        );
        setState(() => _isImporting = false);
        return;
      }

      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Import Data'),
              content: Text(
                'Found ${importedEntries.length} entries to import. How should duplicate entries (by date) be handled?\n\n'
                'Skip: Keep existing entries.\n'
                'Overwrite: Replace existing entries with imported data.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() => _isImporting = false);
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _processImport(
                      importedEntries,
                      overwriteExisting: false,
                    );
                  },
                  child: const Text('Skip'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _processImport(
                      importedEntries,
                      overwriteExisting: true,
                    );
                  },
                  child: const Text('Overwrite'),
                ),
              ],
            ),
      );
    } catch (e) {
      setState(() {
        _isImporting = false;
        _errorMessage = 'Error importing data: $e';
      });
    }
  }

  Future<void> _processImport(
    List<LogEntry> entriesToImport, {
    required bool overwriteExisting,
  }) async {
    setState(() => _isImporting = true);
    int importedCount = 0;
    int skippedCount = 0;
    try {
      for (final entry in entriesToImport) {
        if (overwriteExisting) {
          await _dbHelper.insertOrUpdateLogEntry(
            entry,
          ); // Uses ConflictAlgorithm.replace
          importedCount++;
        } else {
          // Try to insert, if it fails (due to date conflict), it means entry exists
          try {
            // Attempt to insert with ConflictAlgorithm.abort to check existence
            // A more direct way is to query first.
            final existing = await _dbHelper.getLogEntry(entry.date);
            if (existing == null) {
              await _dbHelper.insertOrUpdateLogEntry(entry); // Insert new
              importedCount++;
            } else {
              skippedCount++; // Entry exists, skip
            }
          } catch (e) {
            // This catch might be for general DB errors, not just conflicts
            // depending on how insertOrUpdate is configured without replace.
            // For simplicity, we assume getLogEntry is reliable.
            skippedCount++;
          }
        }
      }
      if (!mounted) return;
      setState(() => _isImporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Import complete. Imported: $importedCount, Skipped: $skippedCount',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isImporting = false;
        _errorMessage = 'Error processing import: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _errorMessage.isNotEmpty ? _buildErrorView() : _buildSettingsForm(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSettings,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProfileSection(),
          const Divider(height: 32),
          // START OF CHANGES: Add Units Section
          _buildUnitsSection(),
          const Divider(height: 32),
          // END OF CHANGES
          _buildAlgorithmSection(),
          const Divider(height: 32),
          _buildDataManagementSection(),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _isExporting || _isImporting ? null : _save,
            child: const Text('Save Settings'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'User Profile',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _heightController,
          // START OF CHANGES: Dynamic height label
          decoration: InputDecoration(
            labelText: _currentHeightLabel, // Use dynamic label
            border: const OutlineInputBorder(),
            helperText:
                _selectedHeightUnit == HeightUnitSystem.ft_in
                    ? 'e.g., for 5ft 10in, enter 70' // Helper text for inches
                    : 'Enter height',
          ),
          // END OF CHANGES
          keyboardType: TextInputType.number,
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _ageController,
          decoration: const InputDecoration(
            labelText: 'Age',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<BiologicalSex>(
          value: _sex,
          decoration: const InputDecoration(
            labelText: 'Biological Sex',
            border: OutlineInputBorder(),
          ),
          items:
              BiologicalSex.values
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                  .toList(),
          onChanged: (v) => setState(() => _sex = v),
          validator: (v) => v == null ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<ActivityLevel>(
          value: _activityLevel,
          decoration: const InputDecoration(
            labelText: 'Activity Level',
            border: OutlineInputBorder(),
          ),
          items:
              ActivityLevel.values
                  .map(
                    (a) => DropdownMenuItem(
                      value: a,
                      child: Text(_getActivityLevelDescription(a)),
                    ),
                  )
                  .toList(),
          onChanged: (v) => setState(() => _activityLevel = v),
          validator: (v) => v == null ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _goalRateController,
          decoration: const InputDecoration(
            labelText: 'Goal Rate (%/week)',
            border: OutlineInputBorder(),
            helperText: 'Negative for weight loss, positive for weight gain',
          ),
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
      ],
    );
  }

  // START OF CHANGES: New section for unit settings
  Widget _buildUnitsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Units',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<WeightUnitSystem>(
          value: _selectedWeightUnit,
          decoration: const InputDecoration(
            labelText: 'Weight Unit',
            border: OutlineInputBorder(),
          ),
          items:
              WeightUnitSystem.values.map((unit) {
                String text;
                switch (unit) {
                  case WeightUnitSystem.kg:
                    text = 'Kilograms (kg)';
                    break;
                  case WeightUnitSystem.lbs:
                    text = 'Pounds (lbs)';
                    break;
                }
                return DropdownMenuItem(value: unit, child: Text(text));
              }).toList(),
          onChanged: (newValue) {
            setState(() {
              _selectedWeightUnit = newValue;
            });
          },
          validator: (v) => v == null ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<HeightUnitSystem>(
          value: _selectedHeightUnit,
          decoration: const InputDecoration(
            labelText: 'Height Unit',
            border: OutlineInputBorder(),
          ),
          items:
              HeightUnitSystem.values.map((unit) {
                String text;
                switch (unit) {
                  case HeightUnitSystem.cm:
                    text = 'Centimeters (cm)';
                    break;
                  case HeightUnitSystem.ft_in:
                    text = 'Feet/Inches (ft/in)';
                    break;
                }
                return DropdownMenuItem(value: unit, child: Text(text));
              }).toList(),
          onChanged: (newValue) {
            setState(() {
              _selectedHeightUnit = newValue;
              _updateHeightLabel(); // Update label when height unit changes
            });
          },
          validator: (v) => v == null ? 'Required' : null,
        ),
      ],
    );
  }
  // END OF CHANGES

  Widget _buildAlgorithmSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Algorithm Parameters',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: _resetAlgorithmParameters,
              child: const Text('Reset to Defaults'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Warning: Changing these parameters may affect calculation accuracy. Only adjust if you understand the algorithm.',
          style: TextStyle(color: Colors.orange, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 16),
        const Text(
          'Weight Smoothing Factor (Alpha)',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const Text(
          'Controls how quickly the EMA responds to new weight entries. Higher values respond faster, lower values provide more smoothing.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _weightAlphaController,
                decoration: const InputDecoration(
                  labelText: 'Current Alpha',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final value = double.tryParse(v);
                  if (value == null) return 'Invalid number';
                  if (value <= 0 || value >= 1) return 'Must be 0 < alpha < 1';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _weightAlphaMinController,
                decoration: const InputDecoration(
                  labelText: 'Min Value',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final value = double.tryParse(v);
                  if (value == null) return 'Invalid number';
                  if (value <= 0 || value >= 1) return 'Must be 0 < alpha < 1';
                  // TODO: Add validation: min < current < max
                  return null;
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _weightAlphaMaxController,
                decoration: const InputDecoration(
                  labelText: 'Max Value',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final value = double.tryParse(v);
                  if (value == null) return 'Invalid number';
                  if (value <= 0 || value >= 1) return 'Must be 0 < alpha < 1';
                  // TODO: Add validation: min < current < max
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Calorie Smoothing Factor (Alpha)',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const Text(
          'Controls how quickly the EMA responds to new calorie entries. Higher values respond faster, lower values provide more smoothing.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _calorieAlphaController,
                decoration: const InputDecoration(
                  labelText: 'Current Alpha',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final value = double.tryParse(v);
                  if (value == null) return 'Invalid number';
                  if (value <= 0 || value >= 1) return 'Must be 0 < alpha < 1';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _calorieAlphaMinController,
                decoration: const InputDecoration(
                  labelText: 'Min Value',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final value = double.tryParse(v);
                  if (value == null) return 'Invalid number';
                  if (value <= 0 || value >= 1) return 'Must be 0 < alpha < 1';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _calorieAlphaMaxController,
                decoration: const InputDecoration(
                  labelText: 'Max Value',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final value = double.tryParse(v);
                  if (value == null) return 'Invalid number';
                  if (value <= 0 || value >= 1) return 'Must be 0 < alpha < 1';
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _trendSmoothingDaysController,
          decoration: const InputDecoration(
            labelText: 'Trend Smoothing Days',
            border: OutlineInputBorder(),
            helperText:
                'Number of days used for calculating the weight trend (recommended: 7)',
          ),
          keyboardType: TextInputType.number,
          validator: (v) {
            if (v == null || v.isEmpty) return 'Required';
            final value = int.tryParse(v);
            if (value == null) return 'Invalid number';
            if (value < 1) return 'Must be positive';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDataManagementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Data Management',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Export Data',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isExporting ? null : _exportBasicCsv,
                icon: const Icon(Icons.file_download),
                label: const Text('Basic CSV'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isExporting ? null : _exportDetailedJson,
                icon: const Icon(Icons.file_download),
                label: const Text('Detailed JSON'),
              ),
            ),
          ],
        ),
        if (_isExporting)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: LinearProgressIndicator(),
          ),
        const SizedBox(height: 16),
        const Text(
          'Import Data',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _isImporting ? null : _importCsv,
          icon: const Icon(Icons.file_upload),
          label: const Text('Import from CSV'),
        ),
        if (_isImporting)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }

  String _getActivityLevelDescription(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.sedentary:
        return 'Sedentary (little to no exercise)';
      case ActivityLevel.lightlyActive:
        return 'Lightly Active (1-3 days/week)';
      case ActivityLevel.moderatelyActive:
        return 'Moderately Active (3-5 days/week)';
      case ActivityLevel.veryActive:
        return 'Very Active (6-7 days/week)';
      case ActivityLevel.extraActive:
        return 'Extra Active (physical job or 2x training)';
    }
  }
}
