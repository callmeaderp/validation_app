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
      debugShowCheckedModeBanner: false,
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
  runApp(const ValidationAppWrapper());
}

/// Wraps the app with MultiProvider for dependency injection.
class ValidationAppWrapper extends StatefulWidget {
  const ValidationAppWrapper({super.key});

  @override
  State<ValidationAppWrapper> createState() => _ValidationAppWrapperState();
}

class _ValidationAppWrapperState extends State<ValidationAppWrapper> {
  // Create repositories here if their lifecycle is tied to the entire app,
  // and dispose them here.
  late final TrackerRepository _trackerRepository;
  late final SettingsRepository _settingsRepository;

  @override
  void initState() {
    super.initState();
    _trackerRepository = TrackerRepository();
    _settingsRepository = SettingsRepository();
  }

  @override
  void dispose() {
    _trackerRepository.dispose();
    _settingsRepository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Provide the instance of TrackerRepository
        Provider<TrackerRepository>.value(value: _trackerRepository),
        // Provide the instance of SettingsRepository
        Provider<SettingsRepository>.value(value: _settingsRepository),
        ChangeNotifierProvider<LogInputStatusNotifier>(
          create:
              (ctx) => LogInputStatusNotifier(
                repository: ctx.read<TrackerRepository>(),
                settingsRepo: ctx.read<SettingsRepository>(),
              ),
        ),
      ],
      child: const ValidationApp(),
    );
  }
}

/// The main application widget that holds the MaterialApp and primary Scaffold.
class ValidationApp extends StatefulWidget {
  const ValidationApp({super.key});
  @override
  _ValidationAppState createState() => _ValidationAppState();
}

class _ValidationAppState extends State<ValidationApp> {
  ThemeMode _themeMode = ThemeMode.system;
  int _currentIndex = 0;

  // The screens that will be displayed in the body of the main Scaffold.
  // Each of these screens should now build its own Scaffold and AppBar if needed.
  final List<Widget> _screens = [
    const LogInputStatusScreen(),
    const GraphScreen(),
    const LogHistoryScreen(),
    const SettingsScreen(),
  ];

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void _onTabTapped(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
      // If LogInputStatusScreen needs to refresh when it becomes visible,
      // it should handle that internally (e.g., in its initState or didChangeDependencies
      // or by listening to a stream/notifier if it needs to react to external changes).
      // The automatic refresh logic that was in HomeBottomNavBar might not be directly applicable
      // here or might need a different trigger.
      // For instance, if navigating TO the LogInputStatusScreen (index 0),
      // you might want to call refresh on its notifier.
      if (index == 0) {
        // Example: if navigating to the first screen
        // Potential to call refresh, but consider if it's always needed
        // or if LogInputStatusNotifier handles it better internally.
        // context.read<LogInputStatusNotifier>().refreshCalculations();
        // This might be too aggressive. Let LogInputStatusNotifier manage its state.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weight Tracker Validation App',
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: _themeMode,
      debugShowCheckedModeBanner: false, // Common to disable the debug banner
      home: Scaffold(
        // The AppBar is removed from here. Each screen in `_screens` will provide its own.
        // This allows each screen to have custom actions and titles.
        body: IndexedStack(index: _currentIndex, children: _screens),
        bottomNavigationBar: HomeBottomNavBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          // Pass theme toggle specifics if HomeBottomNavBar displays theme info or has a toggle button itself.
          // If the theme toggle is exclusively in an AppBar (e.g., settings screen's AppBar),
          // then HomeBottomNavBar might not need these.
          // For now, assuming it might still reflect the theme or have a quick toggle (as per original design).
          onThemeToggle:
              _toggleTheme, // This implies HomeBottomNavBar might have a way to call this.
          // If not, it can be removed from HomeBottomNavBar's parameters.
          currentTheme: _themeMode == ThemeMode.light ? 'light' : 'dark',
        ),
      ),
      // Removed routes, as the main navigation is handled by the IndexedStack and BottomNavigationBar.
      // If you have other, truly separate navigation flows (e.g., a one-time onboarding screen
      // or a completely different section of the app not part of the bottom tabs),
      // you might still use named routes for those. But for the main tabbed interface, this is cleaner.
    );
  }
}

/// Simplified BottomNavigationBar.
class HomeBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Function
  onThemeToggle; // Keep if HomeBottomNavBar has a theme toggle or reflects theme state.
  final String currentTheme; // Keep for the same reason.

  const HomeBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onThemeToggle, // If no theme toggle here, this can be removed.
    required this.currentTheme, // If no theme display here, this can be removed.
  });

  @override
  Widget build(BuildContext context) {
    // The theme toggle icon could be one of the items or an action in an AppBar.
    // For simplicity, I'm assuming the BottomNavigationBar itself doesn't have a dedicated theme toggle button.
    // If it does, you'd add it to the `items` or structure it differently.
    // The `onThemeToggle` and `currentTheme` might be for styling the BottomNav itself
    // or if one of its icons was a theme switcher.

    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed, // Good for 4+ items
      currentIndex: currentIndex,
      onTap: onTap,
      // Example: Use theme colors for selected item
      // selectedItemColor: Theme.of(context).colorScheme.primary,
      // unselectedItemColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.input), label: 'Log Input'),
        BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Graph'),
        BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        // If you wanted a theme toggle here as an item:
        // BottomNavigationBarItem(
        //   icon: Icon(currentTheme == 'light' ? Icons.dark_mode : Icons.light_mode),
        //   label: 'Theme',
        // ),
        // And then onTap would need to handle if index == 4, call onThemeToggle.
      ],
    );
  }
}
