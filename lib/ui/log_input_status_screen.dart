// lib/ui/log_input_status_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:validation_app/viewmodel/log_input_status_notifier.dart';
import 'package:intl/intl.dart';
// Keep for notifier.currentUserSettings type

/// Main screen for entering daily weight and calories, and viewing calculation results
class LogInputStatusScreen extends StatefulWidget {
  const LogInputStatusScreen({super.key});

  @override
  LogInputStatusScreenState createState() => LogInputStatusScreenState();
}

class LogInputStatusScreenState extends State<LogInputStatusScreen> {
  final _weightController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // If there's any specific data loading or refreshing this screen needs
    // when it becomes active, it can be initiated here or in didChangeDependencies.
    // For example, ensuring the LogInputStatusNotifier has the latest data.
    // The notifier itself already calls _loadDataAndCalculate in its constructor.
    // If a refresh is needed when this tab becomes visible after being inactive,
    // more complex state management or visibility detection might be needed,
    // but IndexedStack keeps its state, so often it's not an issue unless
    // background data changes significantly.
  }

  @override
  void dispose() {
    _weightController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  // The _navigateToSettings method is removed as main navigation
  // to the Settings screen is now handled by the BottomNavigationBar.
  // If this screen had specific sub-settings, that would be a different navigation.

  @override
  Widget build(BuildContext context) {
    // This screen now builds its own Scaffold and AppBar
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Input & Status'),
        // Actions for navigating to other main screens (Graph, History, Settings)
        // are removed because the main BottomNavigationBar now handles this.
        // If this screen had other specific actions (e.g., "Refresh data for this screen"),
        // they would go here. For now, we'll keep it simple.
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.refresh),
        //     onPressed: () {
        //       context.read<LogInputStatusNotifier>().refreshCalculations();
        //     },
        //     tooltip: 'Refresh Calculations',
        //   ),
        // ],
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
                                          // Allow empty if user just wants to log calories,
                                          // but if they log, it must be valid.
                                          // Or, make it required always:
                                          // return 'Please enter your weight';
                                          return null; // Making it optional for now, can be changed
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
                                          // Allow empty if user just wants to log weight.
                                          // Or, make it required always:
                                          // return 'Please enter calories';
                                          return null; // Making it optional for now
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
                                                    // Check if at least one field has data
                                                    if (notifier.weightInput ==
                                                            null &&
                                                        notifier.caloriesInput ==
                                                            null &&
                                                        (_weightController
                                                                .text
                                                                .isNotEmpty ||
                                                            _caloriesController
                                                                .text
                                                                .isNotEmpty)) {
                                                      // This case implies validation passed but parsing failed for non-empty fields,
                                                      // which shouldn't happen if validators are correct.
                                                      // However, if both are truly null and fields were empty, we might not log.
                                                      // For this app, we usually want to log if *either* is present.
                                                    }

                                                    // If both are null AND both text fields are empty, maybe show a message or don't log.
                                                    // For simplicity, if form is valid, and at least one input exists, proceed.
                                                    // The notifier's logData can handle nulls if DB allows.
                                                    // Your DB allows nulls, so logging with one value is fine.

                                                    final weightToLog =
                                                        notifier.weightInput;
                                                    final caloriesToLog =
                                                        notifier.caloriesInput;

                                                    if (weightToLog == null &&
                                                        caloriesToLog == null &&
                                                        _weightController
                                                            .text
                                                            .isEmpty &&
                                                        _caloriesController
                                                            .text
                                                            .isEmpty) {
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        const SnackBar(
                                                          content: Text(
                                                            'Please enter weight or calories to log.',
                                                          ),
                                                        ),
                                                      );
                                                      return;
                                                    }

                                                    final scaffoldMessenger =
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ); // Capture before async
                                                    FocusScope.of(
                                                      context,
                                                    ).unfocus(); // Dismiss keyboard

                                                    notifier
                                                        .logData(
                                                          weightToLog, // Pass potentially null
                                                          caloriesToLog, // Pass potentially null
                                                        )
                                                        .then((success) {
                                                          // Assuming logData returns bool for success
                                                          if (mounted) {
                                                            if (success) {
                                                              _weightController
                                                                  .clear();
                                                              _caloriesController
                                                                  .clear();
                                                              notifier.weightInput =
                                                                  null; // Reset internal notifier state too
                                                              notifier.caloriesInput =
                                                                  null;
                                                              scaffoldMessenger.showSnackBar(
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
                                                            } else {
                                                              // Notifier should set its own errorMessage
                                                              // if (notifier.errorMessage.isNotEmpty) {
                                                              //   scaffoldMessenger.showSnackBar(
                                                              //     SnackBar(
                                                              //       content: Text(notifier.errorMessage),
                                                              //       backgroundColor: Theme.of(context).colorScheme.error,
                                                              //     ),
                                                              //   );
                                                              // }
                                                            }
                                                          }
                                                        });
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
                                  vertical: 16.0,
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
                            // Show results only if there's something meaningful to display
                            if (notifier.trueWeight != null &&
                                    notifier.trueWeight! > 0 ||
                                notifier.estimatedTdeeAlgo != null &&
                                    notifier.estimatedTdeeAlgo! > 0)
                              _buildResultsSection(context, notifier),
                          ],
                        ),
                      ),
                    ),
          );
        },
      ),
      // NO BottomNavigationBar here, it's provided by the main Scaffold in main.dart
    );
  }

  Widget _buildResultsSection(
    BuildContext context,
    LogInputStatusNotifier notifier,
  ) {
    String formatNumber(
      double? value, {
      int decimals = 1,
      bool showPlus = false,
    }) {
      if (value == null) return 'N/A';
      String formatPattern = "";
      if (showPlus && value > 0) formatPattern += "+";
      formatPattern += "0";
      if (decimals > 0) {
        formatPattern += ".";
        for (int i = 0; i < decimals; i++) {
          formatPattern += "0";
        }
      }
      return NumberFormat(formatPattern, "en_US").format(value);
    }

    final weightUnit = notifier.currentUserSettings?.weightUnitString ?? 'kg';
    final algorithmParams = notifier.algorithmParams;
    final trendSmoothingDays = algorithmParams?.trendSmoothingDays ?? 7;

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
            if (notifier.trueWeight != null && notifier.trueWeight! > 0) ...[
              _buildMetricTile(
                context,
                'True Weight',
                '${formatNumber(notifier.trueWeight, decimals: 1)} $weightUnit',
                'Estimated true weight from Kalman filter state, filtering out daily fluctuations and noise.',
              ),
              _buildMetricTile(
                context,
                'Weight Trend',
                '${formatNumber(notifier.weightTrendPerWeek, decimals: 2, showPlus: true)} $weightUnit/week',
                'Weekly weight change rate calculated from the Kalman filter state estimation.',
              ),
              _buildMetricTile(
                context,
                'Goal Rate',
                '${formatNumber(notifier.trueWeight != null && notifier.trueWeight! > 0 ? (notifier.currentUserSettings?.goalRate ?? 0) * notifier.trueWeight! / 100 : 0, decimals: 2, showPlus: true)} $weightUnit/week',
                'Your targeted rate of weight change per week (${notifier.currentUserSettings?.goalRate ?? 0}% of body weight).',
              ),
            ],
            if (notifier.averageCalories != null &&
                notifier.averageCalories! > 0)
              _buildMetricTile(
                context,
                'Average Calories',
                '${formatNumber(notifier.averageCalories, decimals: 0)} kcal',
                'Smoothed EMA of daily caloric intake.',
              ),

            if ((notifier.trueWeight != null && notifier.trueWeight! > 0) ||
                (notifier.averageCalories != null &&
                    notifier.averageCalories! > 0))
              const Divider(),

            Text(
              'Energy Expenditure & Targets',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _buildMetricTile(
              context,
              'Est. TDEE (Algorithm)',
              '${formatNumber(notifier.estimatedTdeeAlgo, decimals: 0)} kcal',
              'Total Daily Energy Expenditure calculated using average calories minus daily weight change effect (weekly trend divided by 7).',
            ),
            _buildMetricTile(
              context,
              'Target Calories (Algorithm)',
              '${formatNumber(notifier.targetCaloriesAlgo, decimals: 0)} kcal',
              'Recommended daily calories based on your goal rate and algorithm TDEE (calculated using weekly trend divided by 7).',
            ),
            if (notifier.currentUserSettings != null &&
                notifier.currentUserSettings!.age > 0 &&
                notifier.currentUserSettings!.height > 0) ...[
              _buildMetricTile(
                context,
                'Est. TDEE (Standard)',
                '${formatNumber(notifier.estimatedTdeeStandard, decimals: 0)} kcal',
                'TDEE calculated using Mifflin-St Jeor formula for comparison.',
              ),
              _buildMetricTile(
                context,
                'Target Calories (Standard)',
                '${formatNumber(notifier.targetCaloriesStandard, decimals: 0)} kcal',
                'Recommended daily calories based on your goal and standard TDEE.',
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
                '${formatNumber(notifier.deltaTdee, decimals: 0, showPlus: true)} kcal',
                'Difference: Algorithm TDEE - Standard TDEE.',
              ),
              _buildMetricTile(
                context,
                'Target Delta',
                '${formatNumber(notifier.deltaTarget, decimals: 0, showPlus: true)} kcal',
                'Difference: Algorithm Target - Standard Target.',
              ),
            ],
            _buildMetricTile(
              context,
              'Weight Alpha',
              formatNumber(notifier.currentAlphaWeight, decimals: 3),
              'Current smoothing factor for weight computation (used in legacy EMA mode or for UI display purposes when Kalman filter is active). Range: ${notifier.algorithmParams?.weightAlphaMin ?? "N/A"} - ${notifier.algorithmParams?.weightAlphaMax ?? "N/A"}',
            ),
            _buildMetricTile(
              context,
              'Calorie Alpha',
              formatNumber(notifier.currentAlphaCalorie, decimals: 3),
              'Current smoothing factor for calorie EMA (dynamic). Range: ${notifier.algorithmParams?.calorieAlphaMin ?? "N/A"} - ${notifier.algorithmParams?.calorieAlphaMax ?? "N/A"}',
            ),
            if (notifier.tdeeBlendFactorUsed != null &&
                notifier.tdeeBlendFactorUsed! <
                    1.0 && // Only show if blending is active (not 1.0)
                notifier.tdeeBlendFactorUsed! >=
                    0.0) // and not fully data-driven (0.0)
              _buildMetricTile(
                context,
                'TDEE Blend Factor',
                '${formatNumber(notifier.tdeeBlendFactorUsed, decimals: 2)} (Std. TDEE Weight)',
                'Weight of standard TDEE in current blend (1.0 = all standard, 0.0 = all algorithm). Decays over ~3 weeks.',
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5, // Give more space to title and icon
            child: Row(
              children: [
                Flexible(
                  // Allow title to wrap if needed
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: tooltip,
                  preferBelow: false, // Adjust as needed based on layout
                  triggerMode: TooltipTriggerMode.tap, // Good for mobile
                  showDuration: const Duration(seconds: 5), // Let user read
                  child: Icon(
                    Icons.info_outline,
                    size: 16,
                    color:
                        Theme.of(context).textTheme.bodySmall?.color ??
                        Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3, // Give reasonable space for value
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
