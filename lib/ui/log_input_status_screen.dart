import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:validation_app/viewmodel/log_input_status_notifier.dart';
import 'package:intl/intl.dart';

/// Main screen for entering daily weight and calories, and viewing calculation results
class LogInputStatusScreen extends StatefulWidget {
  const LogInputStatusScreen({Key? key}) : super(key: key);

  @override
  _LogInputStatusScreenState createState() => _LogInputStatusScreenState();
}

class _LogInputStatusScreenState extends State<LogInputStatusScreen> {
  final _weightController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _weightController.dispose();
    _caloriesController.dispose();
    super.dispose();
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
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Consumer<LogInputStatusNotifier>(
        builder: (context, notifier, child) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child:
                notifier.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Today's date
                            Text(
                              'Today: ${DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now())}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 24),

                            // Input Card
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

                                    // Weight input
                                    TextFormField(
                                      controller: _weightController,
                                      decoration: const InputDecoration(
                                        labelText: 'Today\'s Weight',
                                        hintText: 'Enter your weight',
                                        suffixText:
                                            'kg', // TODO: Make this dynamic based on settings
                                        border: OutlineInputBorder(),
                                      ),
                                      keyboardType: TextInputType.number,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter your weight';
                                        }
                                        if (double.tryParse(value) == null) {
                                          return 'Please enter a valid number';
                                        }
                                        return null;
                                      },
                                      onChanged: (value) {
                                        if (value.isNotEmpty) {
                                          notifier.weightInput =
                                              double.tryParse(value);
                                        } else {
                                          notifier.weightInput = null;
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 16),

                                    // Calories input
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
                                        if (int.tryParse(value) == null) {
                                          return 'Please enter a valid number';
                                        }
                                        return null;
                                      },
                                      onChanged: (value) {
                                        if (value.isNotEmpty) {
                                          notifier.caloriesInput = int.tryParse(
                                            value,
                                          );
                                        } else {
                                          notifier.caloriesInput = null;
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 24),

                                    // Log data button
                                    SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: ElevatedButton(
                                        onPressed: () {
                                          if (_formKey.currentState!
                                                  .validate() &&
                                              notifier.weightInput != null &&
                                              notifier.caloriesInput != null) {
                                            notifier.logData(
                                              notifier.weightInput!,
                                              notifier.caloriesInput!,
                                            );
                                            _weightController.clear();
                                            _caloriesController.clear();
                                            // Show success message
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Data logged successfully!',
                                                ),
                                                duration: Duration(seconds: 2),
                                              ),
                                            );
                                          }
                                        },
                                        child: const Text('LOG DATA'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Error message if any
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
                                ),
                              ),

                            const SizedBox(height: 24),

                            // Results section - Only show if we have data
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
    NumberFormat numberFormat = NumberFormat("###.0", "en_US");

    // Helper function to format numbers cleanly
    String formatNumber(double? value, {int decimals = 1}) {
      if (value == null) return 'N/A';
      return NumberFormat(
        "###.${decimals > 0 ? '#' * decimals : 0}",
        "en_US",
      ).format(value);
    }

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

            // Core metrics section
            _buildMetricTile(
              context,
              'True Weight',
              '${formatNumber(notifier.trueWeight)} kg', // TODO: Make unit dynamic
              'Smoothed EMA weight filtering out daily fluctuations',
            ),

            _buildMetricTile(
              context,
              'Weight Trend',
              '${formatNumber(notifier.weightTrendPerWeek)} kg/week', // TODO: Make unit dynamic
              'Average weekly weight change over the last 7 days',
            ),

            _buildMetricTile(
              context,
              'Average Calories',
              '${formatNumber(notifier.averageCalories, decimals: 0)} kcal',
              'Smoothed EMA of daily caloric intake',
            ),

            const Divider(),

            // TDEE & Target Calories section
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
              'Recommended daily calories based on your goal rate',
            ),

            _buildMetricTile(
              context,
              'Estimated TDEE (Standard)',
              '${formatNumber(notifier.estimatedTdeeStandard, decimals: 0)} kcal',
              'TDEE calculated using standard formula (for comparison)',
            ),

            _buildMetricTile(
              context,
              'Target Calories (Standard)',
              '${formatNumber(notifier.targetCaloriesStandard, decimals: 0)} kcal',
              'Standard formula recommended calories',
            ),

            const Divider(),

            // Comparisons & Diagnostics section
            Text(
              'Comparisons & Diagnostics',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),

            _buildMetricTile(
              context,
              'TDEE Delta',
              '${formatNumber(notifier.deltaTdee, decimals: 0)} kcal',
              'Difference between algorithm and standard TDEE',
            ),

            _buildMetricTile(
              context,
              'Target Delta',
              '${formatNumber(notifier.deltaTarget, decimals: 0)} kcal',
              'Difference between algorithm and standard target',
            ),

            _buildMetricTile(
              context,
              'Weight Alpha',
              formatNumber(notifier.currentAlphaWeight, decimals: 3),
              'Current smoothing factor for weight EMA',
            ),

            _buildMetricTile(
              context,
              'Calorie Alpha',
              formatNumber(notifier.currentAlphaCalorie, decimals: 3),
              'Current smoothing factor for calorie EMA',
            ),
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
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: tooltip,
                  child: const Icon(Icons.info_outline, size: 16),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
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
