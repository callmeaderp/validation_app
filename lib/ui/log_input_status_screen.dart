// lib/ui/log_input_status_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:validation_app/viewmodel/log_input_status_notifier.dart';
import 'package:intl/intl.dart';
// UserSettings import is likely still needed for notifier.currentUserSettings typing,
// but if all direct uses of UserSettings type are removed from this file, it might become unused.
// For now, let's keep it as notifier.currentUserSettings IS of type UserSettings?
import 'package:validation_app/models/user_settings.dart';

/// Main screen for entering daily weight and calories, and viewing calculation results
class LogInputStatusScreen extends StatefulWidget {
  const LogInputStatusScreen({super.key});

  @override
  // START OF CHANGES: Fix library_private_types_in_public_api
  LogInputStatusScreenState createState() => LogInputStatusScreenState();
  // END OF CHANGES
}

// START OF CHANGES: Fix library_private_types_in_public_api
class LogInputStatusScreenState extends State<LogInputStatusScreen> {
  // END OF CHANGES
  final _weightController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _weightController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  Future<void> _navigateToSettings(BuildContext context) async {
    // START OF CHANGES: Address use_build_context_synchronously
    // Capture the notifier instance before the await.
    final notifier = context.read<LogInputStatusNotifier>();
    // It's also good practice to capture ScaffoldMessenger if planning to use after await and context might change.
    // However, for showing a SnackBar, it's usually fine if checked with mounted.
    // The lint is more about using the BuildContext to find an inherited widget after an async gap.
    // END OF CHANGES

    final result = await Navigator.pushNamed(context, '/settings');

    // START OF CHANGES: Check mounted before using context-dependent things.
    if (!mounted) return; // Check mounted immediately after await.

    if (result == true) {
      notifier.refreshCalculations();
      _weightController.clear();
      _caloriesController.clear();
      notifier.weightInput = null;
      notifier.caloriesInput = null;
    }
    // END OF CHANGES
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Input & Status'),
        actions: [
          IconButton(
            icon: const Icon(Icons.show_chart),
            onPressed: () => Navigator.pushNamed(context, '/graph'),
            tooltip: 'View Graphs',
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.pushNamed(context, '/history'),
            tooltip: 'View History',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _navigateToSettings(context),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Consumer<LogInputStatusNotifier>(
        builder: (context, notifier, child) {
          final weightUnitSuffix =
              notifier.currentUserSettings?.weightUnitString ?? 'kg';

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child:
                notifier.isLoading && notifier.currentUserSettings == null
                    ? const Center(child: CircularProgressIndicator())
                    : Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Today: ${DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now())}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 24),
                            Card(
                              elevation: 4,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Daily Log Entry',
                                      style:
                                          Theme.of(
                                            context,
                                          ).textTheme.titleLarge,
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _weightController,
                                      decoration: InputDecoration(
                                        labelText: 'Today\'s Weight',
                                        hintText: 'Enter your weight',
                                        suffixText: weightUnitSuffix,
                                        border: const OutlineInputBorder(),
                                      ),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter your weight';
                                        }
                                        final number = double.tryParse(value);
                                        if (number == null) {
                                          return 'Please enter a valid number';
                                        }
                                        if (number <= 0) {
                                          return 'Weight must be positive';
                                        }
                                        return null;
                                      },
                                      onChanged: (value) {
                                        notifier.weightInput = double.tryParse(
                                          value,
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _caloriesController,
                                      decoration: const InputDecoration(
                                        labelText: 'Previous Day\'s Calories',
                                        hintText:
                                            'Enter calories consumed yesterday',
                                        suffixText: 'kcal',
                                        border: OutlineInputBorder(),
                                      ),
                                      keyboardType: TextInputType.number,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter calories';
                                        }
                                        final number = int.tryParse(value);
                                        if (number == null) {
                                          return 'Please enter a valid number';
                                        }
                                        if (number < 0) {
                                          return 'Calories cannot be negative';
                                        }
                                        return null;
                                      },
                                      onChanged: (value) {
                                        notifier.caloriesInput = int.tryParse(
                                          value,
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 24),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: ElevatedButton(
                                        onPressed:
                                            notifier.isLoading
                                                ? null
                                                : () {
                                                  if (_formKey.currentState!
                                                      .validate()) {
                                                    if (notifier.weightInput !=
                                                            null &&
                                                        notifier.caloriesInput !=
                                                            null) {
                                                      // Capture context before async gap for ScaffoldMessenger
                                                      final scaffoldMessenger =
                                                          ScaffoldMessenger.of(
                                                            context,
                                                          );
                                                      notifier
                                                          .logData(
                                                            notifier
                                                                .weightInput!,
                                                            notifier
                                                                .caloriesInput!,
                                                          )
                                                          .then((_) {
                                                            // Using .then to ensure it's after logData completes
                                                            if (mounted) {
                                                              // Re-check mounted if you use context after an async operation inside .then
                                                              _weightController
                                                                  .clear();
                                                              _caloriesController
                                                                  .clear();
                                                              FocusScope.of(
                                                                context,
                                                              ).unfocus();
                                                              scaffoldMessenger.showSnackBar(
                                                                // Use captured scaffoldMessenger
                                                                const SnackBar(
                                                                  content: Text(
                                                                    'Data logged successfully!',
                                                                  ),
                                                                  duration:
                                                                      Duration(
                                                                        seconds:
                                                                            2,
                                                                      ),
                                                                ),
                                                              );
                                                            }
                                                          });
                                                    }
                                                  }
                                                },
                                        child:
                                            notifier.isLoading
                                                ? const SizedBox(
                                                  height: 24,
                                                  width: 24,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.white,
                                                      ),
                                                )
                                                : const Text('LOG DATA'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (notifier.errorMessage.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                ),
                                child: Text(
                                  notifier.errorMessage,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            const SizedBox(height: 24),
                            if (notifier.trueWeight != null &&
                                notifier.trueWeight! > 0)
                              _buildResultsSection(context, notifier),
                          ],
                        ),
                      ),
                    ),
          );
        },
      ),
    );
  }

  Widget _buildResultsSection(
    BuildContext context,
    LogInputStatusNotifier notifier,
  ) {
    String formatNumber(double? value, {int decimals = 1}) {
      if (value == null) return 'N/A';
      String formatPattern = "0";
      if (decimals > 0) {
        formatPattern += ".";
        for (int i = 0; i < decimals; i++) {
          formatPattern += "0";
        }
      }
      return NumberFormat(formatPattern, "en_US").format(value);
    }

    final weightUnit = notifier.currentUserSettings?.weightUnitString ?? 'kg';
    final trendSmoothingDays =
        notifier.currentUserSettings?.trendSmoothingDays ?? 7;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Calculation Results',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(),
            _buildMetricTile(
              context,
              'True Weight',
              '${formatNumber(notifier.trueWeight)} $weightUnit',
              'Smoothed EMA weight filtering out daily fluctuations',
            ),
            _buildMetricTile(
              context,
              'Weight Trend',
              '${formatNumber(notifier.weightTrendPerWeek)} $weightUnit/week',
              'Average weekly weight change over the last $trendSmoothingDays days',
            ),
            _buildMetricTile(
              context,
              'Average Calories',
              '${formatNumber(notifier.averageCalories, decimals: 0)} kcal',
              'Smoothed EMA of daily caloric intake',
            ),
            const Divider(),
            Text(
              'Energy Expenditure & Targets',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _buildMetricTile(
              context,
              'Estimated TDEE (Algorithm)',
              '${formatNumber(notifier.estimatedTdeeAlgo, decimals: 0)} kcal',
              'Total Daily Energy Expenditure calculated from your data',
            ),
            _buildMetricTile(
              context,
              'Target Calories (Algorithm)',
              '${formatNumber(notifier.targetCaloriesAlgo, decimals: 0)} kcal',
              'Recommended daily calories based on your goal rate and algorithm TDEE',
            ),
            _buildMetricTile(
              context,
              'Estimated TDEE (Standard)',
              '${formatNumber(notifier.estimatedTdeeStandard, decimals: 0)} kcal',
              'TDEE calculated using standard formula (Mifflin-St Jeor) for comparison',
            ),
            _buildMetricTile(
              context,
              'Target Calories (Standard)',
              '${formatNumber(notifier.targetCaloriesStandard, decimals: 0)} kcal',
              'Recommended daily calories based on your goal rate and standard TDEE',
            ),
            const Divider(),
            Text(
              'Comparisons & Diagnostics',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _buildMetricTile(
              context,
              'TDEE Delta',
              '${formatNumber(notifier.deltaTdee, decimals: 0)} kcal',
              'Difference: Algorithm TDEE - Standard TDEE',
            ),
            _buildMetricTile(
              context,
              'Target Delta',
              '${formatNumber(notifier.deltaTarget, decimals: 0)} kcal',
              'Difference: Algorithm Target - Standard Target',
            ),
            _buildMetricTile(
              context,
              'Weight Alpha',
              formatNumber(notifier.currentAlphaWeight, decimals: 3),
              'Current smoothing factor for weight EMA (dynamic)',
            ),
            _buildMetricTile(
              context,
              'Calorie Alpha',
              formatNumber(notifier.currentAlphaCalorie, decimals: 3),
              'Current smoothing factor for calorie EMA (dynamic)',
            ),
            // START OF CHANGES: Correctly access tdeeBlendFactorUsed from notifier
            if (notifier.tdeeBlendFactorUsed != null &&
                notifier.tdeeBlendFactorUsed! < 1.0 &&
                notifier.tdeeBlendFactorUsed! > 0.0)
              _buildMetricTile(
                context,
                'TDEE Blend Factor',
                formatNumber(notifier.tdeeBlendFactorUsed, decimals: 2),
                'Weight of standard TDEE in current blend (1.0 = all standard, 0.0 = all algorithm)',
              ),
            // END OF CHANGES
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context,
    String title,
    String value,
    String tooltip,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: tooltip,
                  preferBelow: false,
                  child: Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
