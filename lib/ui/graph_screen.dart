// lib/ui/graph_screen.dart
import 'dart:math'; // For max/min in axis calculations if needed
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
// import 'package:provider/provider.dart'; // Removed as it's unused currently
import 'package:validation_app/data/database/log_entry.dart';
import 'package:validation_app/data/repository/tracker_repository.dart';
import 'package:validation_app/calculation/calculation_engine.dart';
import 'package:validation_app/models/user_settings.dart';
import 'package:validation_app/data/repository/settings_repository.dart';

class GraphScreen extends StatefulWidget {
  const GraphScreen({super.key}); // Changed to super.key

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> {
  final TrackerRepository _repository = TrackerRepository();
  final SettingsRepository _settingsRepo = SettingsRepository();
  final CalculationEngine _calculationEngine = CalculationEngine();

  bool _isLoading = true;
  String _errorMessage = '';

  List<LogEntry> _allEntries = [];
  List<FlSpot> _rawWeightSpots = [];
  List<FlSpot> _trueWeightSpots = [];
  List<FlSpot> _calorieSpots = [];

  int _timeRangeMonths = 1;
  bool _showRawWeight = true;
  bool _showTrueWeight = true;
  bool _showCalories = false;
  bool _useAbsoluteScale = false;

  double _minWeightY = 0;
  double _maxWeightY = 100;
  double _minCalorieY = 0;
  double _maxCalorieY = 3000;
  double _minX = 0;
  double _maxX = 30;

  DateTime? _firstEntryDateForChart;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final allEntries = await _repository.getAllLogEntriesOldestFirst();
      final settings = await _settingsRepo.loadSettings();

      if (!mounted) return;

      if (allEntries.isEmpty) {
        setState(() {
          _isLoading = false;
          _allEntries = [];
          _rawWeightSpots = [];
          _trueWeightSpots = [];
          _calorieSpots = [];
        });
        return;
      }
      _allEntries = allEntries;
      await _processDataForChart(settings);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      if (!mounted) return;
      debugPrint(
        'Error loading graph data: $e\n$stackTrace',
      ); // Changed to debugPrint
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading data: $e';
      });
    }
  }

  Future<void> _processDataForChart(UserSettings settings) async {
    if (!mounted) return;

    List<LogEntry> filteredEntries = _getFilteredEntriesByTimeRange(
      _allEntries,
    );

    if (filteredEntries.isEmpty) {
      setState(() {
        _rawWeightSpots = [];
        _trueWeightSpots = [];
        _calorieSpots = [];
        _firstEntryDateForChart = null;
        _minX = 0;
        _maxX = _timeRangeMonths == 100 ? 365 : (30.0 * _timeRangeMonths);
      });
      return;
    }

    _firstEntryDateForChart = DateTime.parse(filteredEntries.first.date);

    List<FlSpot> rawWeightSpots = [];
    List<FlSpot> trueWeightSpots = [];
    List<FlSpot> calorieSpots = [];
    List<double> rawWeightsForMinMax = [];
    List<double> trueWeightsForMinMax = [];
    List<double> calorieEMAsForMinMax = [];

    for (int i = 0; i < filteredEntries.length; i++) {
      final currentFilteredEntry = filteredEntries[i];
      // Find the full history up to the current filtered entry to get accurate EMAs
      int originalIndex = _allEntries.indexWhere(
        (entry) => entry.date == currentFilteredEntry.date,
      );
      List<LogEntry> historyForCalc =
          (originalIndex != -1)
              ? _allEntries.sublist(0, originalIndex + 1)
              : [
                currentFilteredEntry,
              ]; // Fallback, though originalIndex should always be found

      final result = await _calculationEngine.calculateStatus(
        historyForCalc,
        settings,
      );

      final entryDate = DateTime.parse(currentFilteredEntry.date);
      final days =
          entryDate.difference(_firstEntryDateForChart!).inDays.toDouble();

      if (currentFilteredEntry.rawWeight != null) {
        rawWeightSpots.add(FlSpot(days, currentFilteredEntry.rawWeight!));
        rawWeightsForMinMax.add(currentFilteredEntry.rawWeight!);
      }
      if (result.trueWeight > 0) {
        trueWeightSpots.add(FlSpot(days, result.trueWeight));
        trueWeightsForMinMax.add(result.trueWeight);
      }
      if (result.averageCalories > 0) {
        calorieSpots.add(FlSpot(days, result.averageCalories));
        calorieEMAsForMinMax.add(result.averageCalories);
      }
    }

    if (!mounted) return;

    setState(() {
      _rawWeightSpots = rawWeightSpots;
      _trueWeightSpots = trueWeightSpots;
      _calorieSpots = calorieSpots;
      _updateAxisLimits(
        rawWeightsForMinMax,
        trueWeightsForMinMax,
        calorieEMAsForMinMax,
        filteredEntries,
      );
    });
  }

  List<LogEntry> _getFilteredEntriesByTimeRange(List<LogEntry> entries) {
    if (entries.isEmpty) {
      return [];
    }
    if (_timeRangeMonths == 100) {
      return entries;
    }

    final now = DateTime.now();
    int year = now.year;
    int month = now.month - _timeRangeMonths;
    while (month <= 0) {
      month += 12;
      year -= 1;
    }
    // Ensure day is valid for the calculated month and year
    int day = now.day;
    int lastDayOfMonth =
        DateTime(year, month + 1, 0).day; // Get last day of target month
    if (day > lastDayOfMonth) {
      day = lastDayOfMonth;
    }
    final cutoffDate = DateTime(year, month, day);

    return entries.where((entry) {
      try {
        final entryDate = DateTime.parse(entry.date);
        return !entryDate.isBefore(cutoffDate);
      } catch (e) {
        debugPrint(
          "Error parsing date in _getFilteredEntriesByTimeRange: ${entry.date}",
        );
        return false;
      }
    }).toList();
  }

  void _updateAxisLimits(
    List<double> rawWeights,
    List<double> trueWeights,
    List<double> calorieEMAs,
    List<LogEntry> displayedEntries,
  ) {
    List<double> allDisplayableWeights = [];
    if (_showRawWeight) allDisplayableWeights.addAll(rawWeights);
    if (_showTrueWeight) allDisplayableWeights.addAll(trueWeights);

    if (allDisplayableWeights.isNotEmpty) {
      allDisplayableWeights.sort();
      
      if (_useAbsoluteScale) {
        // Absolute scale starts from 0
        _minWeightY = 0;
        _maxWeightY = (allDisplayableWeights.last * 1.10).ceilToDouble();
      } else {
        // Relative scale fits to the data
        _minWeightY = (allDisplayableWeights.first * 0.95).floorToDouble() - 1;
        _maxWeightY = (allDisplayableWeights.last * 1.05).ceilToDouble() + 1;
      }
      
      if ((_maxWeightY - _minWeightY) < 5) {
        // Ensure a minimum range
        _maxWeightY = _minWeightY + 5;
      }
      if (_minWeightY == _maxWeightY) {
        _minWeightY -= 2.5;
        _maxWeightY += 2.5;
      }
    } else {
      _minWeightY = _useAbsoluteScale ? 0 : 60;
      _maxWeightY = 90; // Default sensible weight range
    }

    List<double> allDisplayableCalories = [];
    if (_showCalories) allDisplayableCalories.addAll(calorieEMAs);

    if (allDisplayableCalories.isNotEmpty) {
      allDisplayableCalories.sort();
      
      if (_useAbsoluteScale) {
        // Absolute scale starts from 0
        _minCalorieY = 0;
        _maxCalorieY = (allDisplayableCalories.last * 1.10).ceilToDouble() + 100;
      } else {
        // Relative scale fits to the data
        _minCalorieY = (allDisplayableCalories.first * 0.90).floorToDouble() - 50;
        _maxCalorieY = (allDisplayableCalories.last * 1.10).ceilToDouble() + 50;
      }
      
      if ((_maxCalorieY - _minCalorieY) < 200) {
        // Ensure a minimum range
        _maxCalorieY = _minCalorieY + 200;
      }
      if (_minCalorieY == _maxCalorieY) {
        _minCalorieY -= 100;
        _maxCalorieY += 100;
      }
    } else {
      _minCalorieY = _useAbsoluteScale ? 0 : 1500;
      _maxCalorieY = 3500; // Default sensible calorie range
    }

    if (displayedEntries.isNotEmpty && _firstEntryDateForChart != null) {
      _minX = 0; // Always start X from 0 for the current filtered view
      final lastEntryDate = DateTime.parse(displayedEntries.last.date);
      _maxX = max(
        0,
        lastEntryDate.difference(_firstEntryDateForChart!).inDays.toDouble(),
      );
      if (_maxX < 7) {
        // Ensure a minimum visible range, e.g., 1 week
        _maxX = 7;
      }
    } else {
      _minX = 0;
      _maxX =
          (_timeRangeMonths == 100)
              ? 30.0
              : (30.0 * _timeRangeMonths).toDouble().clamp(
                7,
                3650,
              ); // default for selected range
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress Graph'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage.isNotEmpty
              ? _buildErrorView()
              : _allEntries.isEmpty
              ? _buildEmptyLogView()
              : _buildGraphView(),
    );
  }

  Widget _buildErrorView() {
    /* ... (keep as is) ... */
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
            ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyLogView() {
    /* ... (keep as is) ... */
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.show_chart, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No data to display',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start logging your weight and calories to see your progress here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFilteredView() {
    /* ... (keep as is) ... */
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.zoom_out_map, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No data in selected range',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try selecting a different time range or adding more log entries.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraphView() {
    final bool noFilteredDataForChart =
        _rawWeightSpots.isEmpty &&
        _trueWeightSpots.isEmpty &&
        _calorieSpots.isEmpty;
    if (noFilteredDataForChart && !_isLoading) {
      // If filters result in no data points
      return _buildEmptyFilteredView();
    }

    final bool hasWeightData =
        (_showRawWeight && _rawWeightSpots.isNotEmpty) ||
        (_showTrueWeight && _trueWeightSpots.isNotEmpty);
    final bool hasCalorieData = _showCalories && _calorieSpots.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTimeRangeSelector(),
          const SizedBox(height: 8),
          _buildGraphOptions(),
          const SizedBox(height: 16),
          if (!hasWeightData && !hasCalorieData)
            Padding(
              // Message if options hide all data
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Text(
                  "No data selected to display.\nEnable 'Raw Weight', 'True Weight', or 'Calories' in options.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).hintColor),
                ),
              ),
            )
          else
            SizedBox(
              height: 400,
              child: Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                  child: _buildChart(),
                ),
              ),
            ),
          const SizedBox(height: 16),
          if (hasWeightData || hasCalorieData) _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    /* ... (keep as is, maybe add curly braces to if) ... */
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Time Range',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.spaceEvenly,
              spacing: 8.0,
              runSpacing: 4.0,
              children: [
                _timeRangeButton('1M', 1),
                _timeRangeButton('3M', 3),
                _timeRangeButton('6M', 6),
                _timeRangeButton('1Y', 12),
                _timeRangeButton('All', 100),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeRangeButton(String label, int months) {
    /* ... (add curly braces to if) ... */
    final isSelected = _timeRangeMonths == months;
    return ElevatedButton(
      onPressed: () async {
        if (_timeRangeMonths != months) {
          // Added curly braces
          setState(() {
            _timeRangeMonths = months;
            _isLoading = true;
          });
          final settings = await _settingsRepo.loadSettings();
          await _processDataForChart(settings);
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surface,
        foregroundColor:
            isSelected
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurface,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(fontSize: 13),
      ),
      child: Text(label),
    );
  }

  Widget _buildGraphOptions() {
    /* ... (keep as is) ... */
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Graph Options',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    title: const Text(
                      'Raw Weight',
                      style: TextStyle(fontSize: 14),
                    ),
                    value: _showRawWeight,
                    onChanged:
                        (value) =>
                            setState(() => _showRawWeight = value ?? true),
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Expanded(
                  child: CheckboxListTile(
                    title: const Text(
                      'True Weight',
                      style: TextStyle(fontSize: 14),
                    ),
                    value: _showTrueWeight,
                    onChanged:
                        (value) =>
                            setState(() => _showTrueWeight = value ?? true),
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            CheckboxListTile(
              title: const Text(
                'Avg. Calories',
                style: TextStyle(fontSize: 14),
              ),
              value: _showCalories,
              onChanged:
                  (value) => setState(() => _showCalories = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(height: 4),
            CheckboxListTile(
              title: const Text(
                'Absolute Scale (0-based)',
                style: TextStyle(fontSize: 14),
              ),
              value: _useAbsoluteScale,
              onChanged: (value) async {
                if (value != _useAbsoluteScale) {
                  setState(() {
                    _useAbsoluteScale = value ?? false;
                  });
                  // Reload data to update chart with new scale
                  final settings = await _settingsRepo.loadSettings();
                  await _processDataForChart(settings);
                }
              },
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  LineChartBarData _buildLineBarData(
    List<FlSpot> spots,
    Color color, {
    bool isCurved = true,
    double barWidth = 2.5,
    bool showDots = false,
    bool useCalorieScale = false,
  }) {
    if (useCalorieScale) {
      // Scale the calorie data points to weight scale for rendering
      // but show actual values in tooltip
      List<FlSpot> scaledSpots = spots.map((spot) {
        // Store original Y value as a tag for the tooltip to use
        return FlSpot(
          spot.x,
          _scaleCaloriesToWeightRange(spot.y),
        );
      }).toList();
      
      return LineChartBarData(
        spots: scaledSpots,
        isCurved: isCurved,
        color: color,
        barWidth: barWidth,
        isStrokeCapRound: true,
        dotData: FlDotData(show: showDots),
        belowBarData: BarAreaData(show: false),
      );
    }
    
    return LineChartBarData(
      spots: spots,
      isCurved: isCurved,
      color: color,
      barWidth: barWidth,
      isStrokeCapRound: true,
      dotData: FlDotData(show: showDots),
      belowBarData: BarAreaData(show: false),
    );
  }
  
  // Convert calorie value to equivalent position in weight scale
  double _scaleCaloriesToWeightRange(double calorieValue) {
    // Skip scaling if either range is invalid
    if (_maxCalorieY <= _minCalorieY || _maxWeightY <= _minWeightY) {
      return calorieValue;
    }
    
    // Calculate the relative position of the calorie value in its range (0.0 to 1.0)
    double relativePosition = (calorieValue - _minCalorieY) / (_maxCalorieY - _minCalorieY);
    
    // Map that relative position to the weight range
    return _minWeightY + relativePosition * (_maxWeightY - _minWeightY);
  }
  
  // Convert from weight scale back to calorie value (for tooltip)
  double _scaleWeightToCalorieRange(double scaledValue) {
    if (_maxCalorieY <= _minCalorieY || _maxWeightY <= _minWeightY) {
      return scaledValue;
    }
    
    double relativePosition = (scaledValue - _minWeightY) / (_maxWeightY - _minWeightY);
    return _minCalorieY + relativePosition * (_maxCalorieY - _minCalorieY);
  }

  Widget _buildChart() {
    final List<LineChartBarData> lineBarsData = [];
    if (_showRawWeight && _rawWeightSpots.isNotEmpty) {
      lineBarsData.add(
        _buildLineBarData(
          _rawWeightSpots,
          Theme.of(context).colorScheme.secondary.withOpacity(0.5),
          isCurved: false,
          barWidth: 1.5,
          showDots: true,
        ),
      );
    }
    if (_showTrueWeight && _trueWeightSpots.isNotEmpty) {
      lineBarsData.add(
        _buildLineBarData(
          _trueWeightSpots,
          Theme.of(context).colorScheme.primary,
          barWidth: 3,
        ),
      );
    }
    if (_showCalories && _calorieSpots.isNotEmpty) {
      bool shouldScale = _showRawWeight || _showTrueWeight;
      lineBarsData.add(
        _buildLineBarData(
          _calorieSpots, 
          Colors.orange.shade700, 
          barWidth: 2,
          useCalorieScale: shouldScale,
        ),
      );
    }

    double weightInterval = ((_maxWeightY - _minWeightY) / 6).clamp(1, 50);
    if (weightInterval <= 0) weightInterval = 1;
    if (weightInterval > 1 && weightInterval <= 2.5)
      weightInterval = 2.5;
    else if (weightInterval > 2.5 && weightInterval <= 5)
      weightInterval = 5;
    else if (weightInterval > 5)
      weightInterval = ((weightInterval / 5).ceil() * 5.0);
    if (weightInterval == 0 && _maxWeightY > _minWeightY)
      weightInterval = (_maxWeightY - _minWeightY) / 2; // Avoid 0 interval

    double calorieInterval = ((_maxCalorieY - _minCalorieY) / 6).clamp(
      50,
      1000,
    );
    if (calorieInterval <= 0) calorieInterval = 50;
    if (calorieInterval > 50 && calorieInterval <= 100)
      calorieInterval = 100;
    else if (calorieInterval > 100)
      calorieInterval = (calorieInterval / 100).ceil() * 100.0;
    if (calorieInterval == 0 && _maxCalorieY > _minCalorieY)
      calorieInterval = (_maxCalorieY - _minCalorieY) / 2;

    bool onlyShowingCalories =
        _showCalories && !_showRawWeight && !_showTrueWeight;
    bool onlyShowingWeight =
        (_showRawWeight || _showTrueWeight) && !_showCalories;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval:
              onlyShowingCalories ? calorieInterval : weightInterval,
          verticalInterval:
              (_maxX - _minX) > 35
                  ? (((_maxX - _minX).clamp(1, 3650)) / 7)
                      .roundToDouble()
                      .clamp(7, 30)
                  : 7,
          getDrawingHorizontalLine:
              (value) => FlLine(
                color: Theme.of(context).dividerColor.withOpacity(0.5),
                strokeWidth: 0.5,
              ),
          getDrawingVerticalLine:
              (value) => FlLine(
                color: Theme.of(context).dividerColor.withOpacity(0.5),
                strokeWidth: 0.5,
              ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles:
                  (_showRawWeight || _showTrueWeight) && !onlyShowingCalories,
              interval: weightInterval,
              reservedSize: 40,
              getTitlesWidget:
                  (value, meta) => Text(
                    value.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
            ),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: _showCalories, // Always show right titles when calories are enabled
              interval: calorieInterval,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                // For right axis with scaled calorie values, we need to convert
                // from the weight scale back to calorie values for display
                double displayValue = _showRawWeight || _showTrueWeight
                    ? _scaleWeightToCalorieRange(value)
                    : value;

                return Text(
                  displayValue.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.orange.shade700,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval:
                  (_maxX - _minX) > 45
                      ? (((_maxX - _minX).clamp(1, 3650)) / 5)
                          .roundToDouble()
                          .clamp(7, 30)
                      : 7,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                // meta is TitleMeta
                if (_firstEntryDateForChart == null)
                  return const SizedBox.shrink();
                final date = _firstEntryDateForChart!.add(
                  Duration(days: value.toInt()),
                );
                String label = DateFormat('M/d').format(date);
                if ((_maxX - _minX) <= 14 && (_maxX - _minX) > 0) {
                  label = DateFormat('d').format(date); // Just day
                } else if ((_maxX - _minX) > 90) {
                  // If more than ~3 months, show month initials
                  label = DateFormat('MMM').format(date);
                }
                // Correct usage of SideTitleWidget
                return SideTitleWidget(
                  meta: meta,
                  space: 8.0,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 9,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
        ),
        minX: _minX,
        maxX: _maxX,
        minY: onlyShowingCalories ? _minCalorieY : _minWeightY,
        maxY: onlyShowingCalories ? _maxCalorieY : _maxWeightY,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            // tooltipBgColor is deprecated, use getTooltipColor instead
            getTooltipColor: (LineBarSpot spot) {
              // Corrected
              return Theme.of(context).colorScheme.secondary.withOpacity(0.9);
            },
            getTooltipItems: (touchedSpots) {
              if (_firstEntryDateForChart == null) {
                return [];
              }
              return touchedSpots.map((LineBarSpot touchedSpot) {
                final date = _firstEntryDateForChart!.add(
                  Duration(days: touchedSpot.x.toInt()),
                );
                String formattedDate = DateFormat('MMM d, yyyy').format(date);
                String textContent =
                    'Value: ${touchedSpot.y.toStringAsFixed(1)}'; // Generic default

                // Identify which line this spot belongs to by checking the barIndex or spot's parent barData
                // This is a bit more robust than relying on list order of lineBarsData if it changes
                if (touchedSpot.barIndex < lineBarsData.length) {
                  final currentBarData = lineBarsData[touchedSpot.barIndex];
                  if (currentBarData.spots == _rawWeightSpots) {
                    textContent =
                        'Raw W: ${touchedSpot.y.toStringAsFixed(1)} ${(_settingsRepo.loadSettings().then((s) => s.weightUnitString)).toString()[0]}'; // Example, needs async handling or cached settings
                  } else if (currentBarData.spots == _trueWeightSpots) {
                    textContent = 'True W: ${touchedSpot.y.toStringAsFixed(1)}';
                  } else if (currentBarData.spots.length == _calorieSpots.length) {
                    // For calorie data that's been scaled, we need to retrieve the original value
                    // We can use the _scaleWeightToCalorieRange to convert back if both weight and calories are shown
                    double actualValue = _showRawWeight || _showTrueWeight 
                        ? _scaleWeightToCalorieRange(touchedSpot.y)
                        : touchedSpot.y;
                        
                    textContent = 'Avg Cal: ${actualValue.toStringAsFixed(0)} kcal';
                  }
                }

                return LineTooltipItem(
                  '$formattedDate\n$textContent',
                  TextStyle(
                    color: Theme.of(context).colorScheme.onSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: lineBarsData,
      ),
    );
  }

  Widget _buildLegend() {
    /* ... (keep as is, maybe add curly braces to ifs) ... */
    final legendItems = <Widget>[];
    if (_showRawWeight && _rawWeightSpots.isNotEmpty) {
      // Added curly braces
      legendItems.add(
        _buildLegendItem(
          Theme.of(context).colorScheme.secondary.withOpacity(0.5),
          'Raw Weight',
          'Daily logged weight',
        ),
      );
    }
    if (_showTrueWeight && _trueWeightSpots.isNotEmpty) {
      // Added curly braces
      legendItems.add(
        _buildLegendItem(
          Theme.of(context).colorScheme.primary,
          'True Weight',
          'Smoothed (EMA) weight',
        ),
      );
    }
    if (_showCalories && _calorieSpots.isNotEmpty) {
      // Added curly braces
      legendItems.add(
        _buildLegendItem(
          Colors.orange.shade700,
          'Avg. Calories',
          'Smoothed (EMA) daily intake',
        ),
      );
    }

    if (legendItems.isEmpty) {
      return const SizedBox.shrink();
    } // Added curly braces

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Legend',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 16.0, runSpacing: 8.0, children: legendItems),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String title, String description) {
    /* ... (keep as is) ... */
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 14, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
