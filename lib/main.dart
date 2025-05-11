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

void main() {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const ValidationApp());
}

class ValidationApp extends StatefulWidget {
  const ValidationApp({Key? key}) : super(key: key);

  @override
  _ValidationAppState createState() => _ValidationAppState();
}

class _ValidationAppState extends State<ValidationApp> {
  ThemeMode _themeMode = ThemeMode.system;

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
        Provider<TrackerRepository>(create: (_) => TrackerRepository()),
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
    Key? key,
    required this.onThemeToggle,
    required this.currentTheme,
  }) : super(key: key);

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
