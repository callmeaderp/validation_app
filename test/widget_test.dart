import 'package:flutter/material.dart';
import 'package:validation_app/models/user_settings.dart';
import 'package:validation_app/data/repository/settings_repository.dart';

/// Screen for editing user profile and algorithm settings
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _heightController;
  late TextEditingController _ageController;
  late TextEditingController _goalRateController;
  BiologicalSex? _selectedSex;
  ActivityLevel? _selectedActivity;

  bool _isLoading = true;
  late UserSettings _settings;
  final SettingsRepository _repo = SettingsRepository();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _repo.loadSettings();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _heightController = TextEditingController(
        text: settings.height.toString(),
      );
      _ageController = TextEditingController(text: settings.age.toString());
      _goalRateController = TextEditingController(
        text: settings.goalRate.toString(),
      );
      _selectedSex = settings.sex;
      _selectedActivity = settings.activityLevel;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    final updated = _settings.copyWith(
      height: double.parse(_heightController.text),
      age: int.parse(_ageController.text),
      sex: _selectedSex,
      activityLevel: _selectedActivity,
      goalRate: double.parse(_goalRateController.text),
    );
    await _repo.saveSettings(updated);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _heightController.dispose();
    _ageController.dispose();
    _goalRateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _heightController,
                decoration: const InputDecoration(labelText: 'Height'),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _ageController,
                decoration: const InputDecoration(labelText: 'Age'),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              DropdownButtonFormField<BiologicalSex>(
                value: _selectedSex,
                decoration: const InputDecoration(labelText: 'Sex'),
                items:
                    BiologicalSex.values
                        .map(
                          (e) =>
                              DropdownMenuItem(value: e, child: Text(e.name)),
                        )
                        .toList(),
                onChanged: (v) => setState(() => _selectedSex = v!),
                validator: (v) => v == null ? 'Required' : null,
              ),
              DropdownButtonFormField<ActivityLevel>(
                value: _selectedActivity,
                decoration: const InputDecoration(labelText: 'Activity Level'),
                items:
                    ActivityLevel.values
                        .map(
                          (e) =>
                              DropdownMenuItem(value: e, child: Text(e.name)),
                        )
                        .toList(),
                onChanged: (v) => setState(() => _selectedActivity = v!),
                validator: (v) => v == null ? 'Required' : null,
              ),
              TextFormField(
                controller: _goalRateController,
                decoration: const InputDecoration(
                  labelText: 'Goal Rate (%/week)',
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveSettings,
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
