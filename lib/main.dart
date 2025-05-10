import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:validation_app/ui/log_input_status_screen.dart';
import 'package:validation_app/ui/graph_screen.dart';
import 'package:validation_app/ui/log_history_screen.dart';
import 'package:validation_app/ui/settings_screen.dart';
import 'package:validation_app/data/repository/tracker_repository.dart';
import 'package:validation_app/data/repository/settings_repository.dart';
import 'package:validation_app/viewmodel/log_input_status_notifier.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ValidationApp());
}

class ValidationApp extends StatelessWidget {
  const ValidationApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<TrackerRepository>(create: (_) => TrackerRepository()),
        Provider<SettingsRepository>(create: (_) => SettingsRepository()),
        ChangeNotifierProvider<LogInputStatusNotifier>(
          create:
              (ctx) => LogInputStatusNotifier(
                repository: ctx.read<TrackerRepository>(),
                settingsRepo: ctx.read<SettingsRepository>(),
              ),
        ),
      ],
      child: Consumer<LogInputStatusNotifier>(
        builder: (context, notifier, _) {
          return MaterialApp(
            title: 'Validation App',
            theme: ThemeData(primarySwatch: Colors.blue),
            initialRoute: '/',
            routes: {
              '/': (ctx) => const LogInputStatusScreen(),
              '/graph': (ctx) => const GraphScreen(),
              '/history': (ctx) => const LogHistoryScreen(),
              '/settings': (ctx) => const SettingsScreen(),
            },
          );
        },
      ),
    );
  }
}
