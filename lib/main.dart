import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:validation_app/calculation/calculation_engine.dart';
import 'package:validation_app/data/database/DatabaseHelper.dart';
import 'package:validation_app/data/repository/tracker_repository.dart';
import 'package:validation_app/viewmodel/log_input_status_notifier.dart';

// Use async main because initializing the database is asynchronous
void main() async {
  // Required for Flutter apps before calling async code in main
  WidgetsFlutterBinding.ensureInitialized();

  // --- Initialize Services ---
  // We need instances of our data/logic classes to pass to the Notifier.
  // Note: In a larger app, this might be handled by a Dependency Injection framework like GetIt or Riverpod,
  // but creating them here is fine for this simple validation app.

  // 1. Get the Database instance (this also initializes it and creates the table if needed)
  final database = await DatabaseHelper.instance.database;

  // 2. Get the DAO from the Database instance
  final logEntryDao = database.logEntryDao(); // Correct way to get DAO

  // 3. Create the Repository, passing in the DAO
  final repository = TrackerRepository(logEntryDao);

  // 4. Create the Calculation Engine
  final calculationEngine = CalculationEngine();
  // --------------------------

  runApp(
    // Use ChangeNotifierProvider to make the LogInputStatusNotifier available
    // to widgets further down the tree (like LogInputStatusScreen).
    ChangeNotifierProvider(
      // The 'create' function builds the Notifier instance, passing its dependencies.
      create:
          (context) => LogInputStatusNotifier(repository, calculationEngine),
      child: const MyApp(), // Your root application widget
    ),
  );
}

// Basic root widget for the application
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Validation App', // Changed title
      theme: ThemeData(
        // Configure the dark theme as planned
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.blueAccent, // Or another seed color you like
        useMaterial3: true,
      ),
      // The initial screen of the app
      home: const LogInputStatusScreen(),
    );
  }
}
