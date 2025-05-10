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
  late UserSettings _settings;
  late TextEditingController _heightController;
  late TextEditingController _ageController;
  BiologicalSex? _sex;
  ActivityLevel? _activityLevel;
  late TextEditingController _goalRateController;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final repo = SettingsRepository();
    final settings = await repo.loadSettings();
    setState(() {
      _settings = settings;
      _heightController = TextEditingController(
        text: settings.height.toString(),
      );
      _ageController = TextEditingController(text: settings.age.toString());
      _sex = settings.sex;
      _activityLevel = settings.activityLevel;
      _goalRateController = TextEditingController(
        text: settings.goalRate.toString(),
      );
    });
  }

  @override
  void dispose() {
    _heightController.dispose();
    _ageController.dispose();
    _goalRateController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final updated = _settings.copyWith(
      height: double.parse(_heightController.text),
      age: int.parse(_ageController.text),
      sex: _sex,
      activityLevel: _activityLevel,
      goalRate: double.parse(_goalRateController.text),
    );
    final repo = SettingsRepository();
    await repo.saveSettings(updated);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (!(_heightController != null && _ageController != null)) {
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
                validator:
                    (v) => v == null || v.isEmpty ? 'Enter height' : null,
              ),
              TextFormField(
                controller: _ageController,
                decoration: const InputDecoration(labelText: 'Age'),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Enter age' : null,
              ),
              DropdownButtonFormField<BiologicalSex>(
                value: _sex,
                items:
                    BiologicalSex.values
                        .map(
                          (s) =>
                              DropdownMenuItem(value: s, child: Text(s.name)),
                        )
                        .toList(),
                onChanged: (v) => setState(() => _sex = v),
                decoration: const InputDecoration(labelText: 'Sex'),
                validator: (v) => v == null ? 'Select sex' : null,
              ),
              DropdownButtonFormField<ActivityLevel>(
                value: _activityLevel,
                items:
                    ActivityLevel.values
                        .map(
                          (a) =>
                              DropdownMenuItem(value: a, child: Text(a.name)),
                        )
                        .toList(),
                onChanged: (v) => setState(() => _activityLevel = v),
                decoration: const InputDecoration(labelText: 'Activity Level'),
                validator: (v) => v == null ? 'Select activity level' : null,
              ),
              TextFormField(
                controller: _goalRateController,
                decoration: const InputDecoration(
                  labelText: 'Goal Rate (%/week)',
                ),
                keyboardType: TextInputType.number,
                validator:
                    (v) => v == null || v.isEmpty ? 'Enter goal rate' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _save, child: const Text('Save')),
            ],
          ),
        ),
      ),
    );
  }
}
