import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:validation_app/data/database/log_entry.dart';
import 'package:validation_app/data/repository/tracker_repository.dart';
import 'package:validation_app/calculation/calculation_engine.dart';
import 'package:validation_app/models/user_settings.dart';
import 'package:validation_app/data/repository/settings_repository.dart';

class GraphScreen extends StatefulWidget {
  const GraphScreen({Key? key}) : super(key: key);

  @override
  _GraphScreenState createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> {
  final TrackerRepository _repository = TrackerRepository();
  final SettingsRepository _settingsRepo = SettingsRepository();
  final CalculationEngine _calculationEngine = CalculationEngine();

  bool _isLoading = true;
  String _errorMessage = '';

  // Graph data
  List<LogEntry> _entries = [];
  List<FlSpot> _rawWeightSpots = [];
  List<FlSpot> _trueWeightSpots = [];
  List<FlSpot> _calorieSpots = [];

  // Graph options and filters
  int _timeRangeMonths = 1;
  bool _showRawWeight = true;
  bool _showTrueWeight = true;
  bool _showCalories = false;

  // Min/max values for y-axes scaling
  double _minWeight = 0;
  double _maxWeight = 100;
  double _minCalorie = 0;
  double _maxCalorie = 3000;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Load data from repository
      final entries = await _repository.getAllLogEntriesOldestFirst();
      final settings = await _settingsRepo.loadSettings();

      if (entries.isEmpty) {
        setState(() {
          _isLoading = false;
          _entries = entries;
        });
        return;
      }

      // Process data for the graph
      await _processData(entries, settings);

      setState(() {
        _isLoading = false;
        _entries = entries;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading data: $e';
      });
    }
  }

  Future<void> _processData(
    List<LogEntry> entries,
    UserSettings settings,
  ) async {
    // Clear existing data
    _rawWeightSpots = [];
    _trueWeightSpots = [];
    _calorieSpots = [];

    // Filter entries based on time range
    final filteredEntries = _getFilteredEntries(entries);
    if (filteredEntries.isEmpty) return;

    // Set min/max values for better graph scaling
    _setMinMaxValues(filteredEntries);

    // Get x coordinate starting point (days since first entry)
    final firstDate = DateTime.parse(filteredEntries.first.date);

    // Add raw weight spots
    for (int i = 0; i < filteredEntries.length; i++) {
      final entry = filteredEntries[i];
      if (entry.rawWeight != null) {
        final entryDate = DateTime.parse(entry.date);
        final days = entryDate.difference(firstDate).inDays.toDouble();
        _rawWeightSpots.add(FlSpot(days, entry.rawWeight!));
      }
    }

    // Calculate and add true weight and calorie EMA spots
    // This requires running the calculation engine on the data
    List<double> weightEmaValues = [];
    List<double> calorieEmaValues = [];

    // Process entries one by one to get historical EMAs
    // In a real app, this might be optimized or cached
    List<LogEntry> processedEntries = [];
    for (int i = 0; i < filteredEntries.length; i++) {
      processedEntries.add(filteredEntries[i]);

      final result = await _calculationEngine.calculateStatus(
        processedEntries,
        settings,
      );

      final entryDate = DateTime.parse(filteredEntries[i].date);
      final days = entryDate.difference(firstDate).inDays.toDouble();

      if (result.trueWeight > 0) {
        _trueWeightSpots.add(FlSpot(days, result.trueWeight));
        weightEmaValues.add(result.trueWeight);
      }

      if (result.averageCalories > 0) {
        _calorieSpots.add(FlSpot(days, result.averageCalories));
        calorieEmaValues.add(result.averageCalories);
      }
    }

    // If we have EMAs, adjust min/max for better scaling
    if (weightEmaValues.isNotEmpty) {
      final minEmaWeight = weightEmaValues.reduce((a, b) => a < b ? a : b);
      final maxEmaWeight = weightEmaValues.reduce((a, b) => a > b ? a : b);
      // Pad by 5% to give some space
      _minWeight = (minEmaWeight * 0.95).roundToDouble();
      _maxWeight = (maxEmaWeight * 1.05).roundToDouble();
    }

    if (calorieEmaValues.isNotEmpty) {
      final minEmaCalorie = calorieEmaValues.reduce((a, b) => a < b ? a : b);
      final maxEmaCalorie = calorieEmaValues.reduce((a, b) => a > b ? a : b);
      // Pad by 10% to give some space
      _minCalorie = (minEmaCalorie * 0.9).roundToDouble();
      _maxCalorie = (maxEmaCalorie * 1.1).roundToDouble();
    }
  }

  List<LogEntry> _getFilteredEntries(List<LogEntry> entries) {
    if (entries.isEmpty) return [];

    // Filter based on selected time range
    final now = DateTime.now();
    final cutoffDate = DateTime(
      now.year,
      now.month - _timeRangeMonths,
      now.day,
    );

    return entries.where((entry) {
      final entryDate = DateTime.parse(entry.date);
      return entryDate.isAfter(cutoffDate) ||
          entryDate.isAtSameMomentAs(cutoffDate);
    }).toList();
  }

  void _setMinMaxValues(List<LogEntry> entries) {
    // Find min/max weights from raw data for initial scaling
    final weights =
        entries
            .where((e) => e.rawWeight != null)
            .map((e) => e.rawWeight!)
            .toList();

    if (weights.isNotEmpty) {
      _minWeight = weights.reduce((a, b) => a < b ? a : b) * 0.95;
      _maxWeight = weights.reduce((a, b) => a > b ? a : b) * 1.05;
    }

    // Find min/max calories for scaling
    final calories =
        entries
            .where((e) => e.rawPreviousDayCalories != null)
            .map((e) => e.rawPreviousDayCalories!.toDouble())
            .toList();

    if (calories.isNotEmpty) {
      _minCalorie = calories.reduce((a, b) => a < b ? a : b) * 0.9;
      _maxCalorie = calories.reduce((a, b) => a > b ? a : b) * 1.1;
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
              : _entries.isEmpty
              ? _buildEmptyView()
              : _buildGraphView(),
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
            ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
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
            const Icon(Icons.show_chart, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No data available',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start logging your daily weight and calories to see your progress here',
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

  Widget _buildGraphView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Time range selector
          _buildTimeRangeSelector(),

          const SizedBox(height: 16),

          // Graph options
          _buildGraphOptions(),

          const SizedBox(height: 24),

          // Main chart
          Container(
            height: 400,
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: _buildChart(),
          ),

          const SizedBox(height: 24),

          // Legend
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Time Range',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _timeRangeButton('1M', 1),
                _timeRangeButton('3M', 3),
                _timeRangeButton('6M', 6),
                _timeRangeButton('1Y', 12),
                _timeRangeButton('All', 100), // Large value to show all data
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeRangeButton(String label, int months) {
    final isSelected = _timeRangeMonths == months;

    return ElevatedButton(
      onPressed: () {
        if (_timeRangeMonths != months) {
          setState(() {
            _timeRangeMonths = months;
          });
          _loadData();
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surface,
        foregroundColor:
            isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
      ),
      child: Text(label),
    );
  }

  Widget _buildGraphOptions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Graph Options',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    title: const Text('Raw Weight'),
                    value: _showRawWeight,
                    onChanged: (value) {
                      setState(() {
                        _showRawWeight = value ?? true;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  ),
                ),
                Expanded(
                  child: CheckboxListTile(
                    title: const Text('True Weight'),
                    value: _showTrueWeight,
                    onChanged: (value) {
                      setState(() {
                        _showTrueWeight = value ?? true;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  ),
                ),
              ],
            ),
            CheckboxListTile(
              title: const Text('Calories'),
              value: _showCalories,
              onChanged: (value) {
                setState(() {
                  _showCalories = value ?? false;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    // Prepare date axis labels
    final firstEntryDate =
        _entries.isNotEmpty
            ? DateTime.parse(_entries.first.date)
            : DateTime.now().subtract(const Duration(days: 30));

    // Empty state
    if (_rawWeightSpots.isEmpty && _trueWeightSpots.isEmpty) {
      return const Center(
        child: Text(
          'Not enough data to display chart',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 16.0, bottom: 8.0),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: 5, // Adjust based on weight range
            verticalInterval: 7, // Weekly intervals
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 5, // Adjust based on weight range
                reservedSize: 40,
                getTitlesWidget:
                    (value, meta) => Text(
                      value.toInt().toString(),
                      style: const TextStyle(fontSize: 10),
                    ),
              ),
            ),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: _showCalories,
                interval: 500, // Adjust based on calorie range
                reservedSize: 40,
                getTitlesWidget:
                    (value, meta) => Text(
                      value.toInt().toString(),
                      style: TextStyle(fontSize: 10, color: Colors.orange[700]),
                    ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 7, // Weekly interval
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  final date = firstEntryDate.add(
                    Duration(days: value.toInt()),
                  );
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      DateFormat('MM/dd').format(date),
                      style: const TextStyle(fontSize: 9),
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: true),
          minX: 0,
          maxX:
              _rawWeightSpots.isNotEmpty
                  ? _rawWeightSpots.last.x
                  : _trueWeightSpots.last.x,
          minY: _minWeight,
          maxY: _maxWeight,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((touchedSpot) {
                  final date = firstEntryDate.add(
                    Duration(days: touchedSpot.x.toInt()),
                  );
                  String formattedDate = DateFormat('MMM d, yyyy').format(date);

                  String label;
                  if (touchedSpot.barIndex == 0 && _showRawWeight) {
                    label =
                        'Raw Weight: ${touchedSpot.y.toStringAsFixed(1)} kg';
                  } else if ((touchedSpot.barIndex == 1 && _showRawWeight) ||
                      (touchedSpot.barIndex == 0 && !_showRawWeight)) {
                    label =
                        'True Weight: ${touchedSpot.y.toStringAsFixed(1)} kg';
                  } else {
                    label = 'Calories: ${touchedSpot.y.toInt()} kcal';
                  }

                  return LineTooltipItem(
                    '$formattedDate\n$label',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            // Raw Weight
            if (_showRawWeight && _rawWeightSpots.isNotEmpty)
              LineChartBarData(
                spots: _rawWeightSpots,
                isCurved: false,
                color: Colors.blue.withOpacity(0.5),
                barWidth: 2,
                isStrokeCapRound: true,
                dotData: FlDotData(show: true),
                belowBarData: BarAreaData(show: false),
              ),

            // True Weight (EMA)
            if (_showTrueWeight && _trueWeightSpots.isNotEmpty)
              LineChartBarData(
                spots: _trueWeightSpots,
                isCurved: true,
                color: Colors.blue[800],
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(show: false),
              ),

            // Calories (if enabled)
            if (_showCalories && _calorieSpots.isNotEmpty)
              LineChartBarData(
                spots: _calorieSpots,
                isCurved: true,
                color: Colors.orange[700],
                barWidth: 2.5,
                isStrokeCapRound: true,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(show: false),
              ),
          ],
          extraLinesData: ExtraLinesData(
            horizontalLines:
                _showCalories
                    ? [
                      HorizontalLine(y: _minCalorie, color: Colors.transparent),
                      HorizontalLine(y: _maxCalorie, color: Colors.transparent),
                    ]
                    : [],
          ),
        ),
        swapAnimationDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  Widget _buildLegend() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Legend',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (_showRawWeight)
              _buildLegendItem(
                Colors.blue.withOpacity(0.5),
                'Raw Weight',
                'Daily weigh-in values',
              ),
            if (_showTrueWeight)
              _buildLegendItem(
                Colors.blue[800]!,
                'True Weight (EMA)',
                'Exponential moving average of weight',
              ),
            if (_showCalories)
              _buildLegendItem(
                Colors.orange[700]!,
                'Calories (EMA)',
                'Exponential moving average of calorie intake',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(width: 16, height: 3, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
