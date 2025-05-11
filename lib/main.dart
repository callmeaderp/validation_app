import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:validation_app/ui/log_input_status_screen.dart';
import 'package:validation_app/ui/graph_screen.dart';
import 'package:validation_app/ui/log_history_screen.dart';
import 'package:validation_app/ui/settings_screen.dart';
import 'package:validation_app/data/repository/tracker_repository.dart';
import 'package:validation_app/data/repository/settings_repository.dart';
import 'package:validation_app/viewmodel/log_input_status_notifier.dart';
import 'package:validation_app/ui/app_theme.dart';
import 'package:validation_app/data/database/DatabaseHelper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

/// Application initialization class to manage startup sequence
class AppInitializer {
  /// Initialize all required services before app startup
  static Future<void> initialize() async {
    // Ensure Flutter binding is initialized first
    WidgetsFlutterBinding.ensureInitialized();

    // Set preferred orientations
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    try {
      // Initialize shared preferences
      await SharedPreferences.getInstance();
      debugPrint('SharedPreferences initialized successfully');

      // Initialize database by accessing it once
      final db = await DatabaseHelper.instance.database;
      debugPrint('Database initialized successfully with path: ${db.path}');
    } catch (e) {
      debugPrint('Error during initialization: $e');
      // Forward the error - app will show error UI later
      rethrow;
    }
  }
}

/// Splash screen shown during initialization
class SplashScreen extends StatelessWidget {
  final String? error;

  const SplashScreen({Key? key, this.error}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weight Tracker Validation App',
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App logo or title
              const Text(
                'Weight Tracker',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              // Show progress indicator if no error, otherwise show error
              if (error == null)
                const CircularProgressIndicator()
              else
                Column(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error during initialization:\n$error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // Try to restart the app
                        main();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() async {
  // Run a simplified app first to show splash screen
  runApp(const SplashScreen());

  // Initialize app dependencies
  String? initError;
  try {
    await AppInitializer.initialize();
  } catch (e) {
    initError = e.toString();
    // Show error in splash screen but don't crash the app
    runApp(SplashScreen(error: initError));
    return;
  }

  // If initialization was successful, run the full app
  runApp(const ValidationApp());
}

class ValidationApp extends StatefulWidget {
  const ValidationApp({super.key});

  @override
  _ValidationAppState createState() => _ValidationAppState();
}

class _ValidationAppState extends State<ValidationApp> {
  ThemeMode _themeMode = ThemeMode.system;
  final TrackerRepository _trackerRepository = TrackerRepository();

  @override
  void dispose() {
    // Clean up repository resources when app is terminated
    _trackerRepository.dispose();
    super.dispose();
  }

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Repositories
        Provider<TrackerRepository>(create: (_) => _trackerRepository),
        Provider<SettingsRepository>(create: (_) => SettingsRepository()),

        // ViewModels
        ChangeNotifierProvider<LogInputStatusNotifier>(
          create:
              (ctx) => LogInputStatusNotifier(
                repository: ctx.read<TrackerRepository>(),
                settingsRepo: ctx.read<SettingsRepository>(),
              ),
        ),
      ],
      child: MaterialApp(
        title: 'Weight Tracker Validation App',
        theme: AppTheme.lightTheme(),
        darkTheme: AppTheme.darkTheme(),
        themeMode: _themeMode,

        // Define routes
        initialRoute: '/',
        routes: {
          '/': (ctx) => const LogInputStatusScreen(),
          '/graph': (ctx) => const GraphScreen(),
          '/history': (ctx) => const LogHistoryScreen(),
          '/settings': (ctx) => const SettingsScreen(),
        },

        // Builder to provide theme toggle function
        builder: (context, child) {
          return Scaffold(
            body: child,
            bottomNavigationBar: HomeBottomNavBar(
              onThemeToggle: _toggleTheme,
              currentTheme: _themeMode == ThemeMode.light ? 'light' : 'dark',
            ),
          );
        },
      ),
    );
  }
}

class HomeBottomNavBar extends StatefulWidget {
  final Function onThemeToggle;
  final String currentTheme;

  const HomeBottomNavBar({
    super.key,
    required this.onThemeToggle,
    required this.currentTheme,
  });

  @override
  _HomeBottomNavBarState createState() => _HomeBottomNavBarState();
}

class _HomeBottomNavBarState extends State<HomeBottomNavBar> {
  int _currentIndex = 0;

  // Navigation mapping
  final List<String> _routes = ['/', '/graph', '/history', '/settings'];

  @override
  Widget build(BuildContext context) {
    // Determine the current route
    final currentRoute = ModalRoute.of(context)?.settings.name ?? '/';
    _currentIndex = _routes.indexOf(currentRoute);
    if (_currentIndex < 0) _currentIndex = 0;

    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: _currentIndex,
      onTap: (index) {
        // Don't navigate if already on the same page
        if (_currentIndex == index) return;

        // Navigate to the selected page
        Navigator.of(context).pushReplacementNamed(_routes[index]);

        // Update the index
        setState(() {
          _currentIndex = index;
        });

        // Refresh calculations if returning to home screen
        if (index == 0 && _currentIndex != 0) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (!mounted) return;
            context.read<LogInputStatusNotifier>().refreshCalculations();
          });
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.input), label: 'Log Input'),
        BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Graph'),
        BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
      ],
    );
  }
}
