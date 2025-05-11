// lib/ui/home_bottom_nav_bar.dart
import 'package:flutter/material.dart';

class HomeBottomNavBar extends StatefulWidget {
  final VoidCallback onThemeToggle;
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
  final List<String> _routes = ['/', '/graph', '/history', '/settings'];

  @override
  Widget build(BuildContext context) {
    final currentRoute = ModalRoute.of(context)?.settings.name ?? '/';
    _currentIndex = _routes.indexOf(currentRoute).clamp(0, _routes.length - 1);

    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: _currentIndex,
      onTap: (i) {
        if (i == _currentIndex) return;
        Navigator.of(context).pushReplacementNamed(_routes[i]);
        setState(() => _currentIndex = i);
      },
      items: [
        BottomNavigationBarItem(icon: Icon(Icons.input), label: 'Log'),
        BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Graph'),
        BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
      ],
    );
  }
}
