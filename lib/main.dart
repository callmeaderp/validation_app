import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:validation_app/ui/log_input_status/log_input_status_screen.dart';
import 'package:validation_app/viewmodel/log_input_status_notifier.dart';
import 'package:validation_app/data/database/database_helper.dart';
import 'package:validation_app/data/repository/tracker_repository.dart';
import 'package:validation_app/calculation/calculation_engine.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the database
  await DatabaseHelper.instance.database;

  // Instantiate repository and calculation engine
  final repository = TrackerRepository();
  final calculationEngine = CalculationEngine();

  runApp(
    ChangeNotifierProvider(
      create:
          (context) => LogInputStatusNotifier(repository, calculationEngine),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Validation App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const LogInputStatusScreen(),
    );
  }
}
