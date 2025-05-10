import 'package:flutter/material.dart';

class LogInputStatusScreen extends StatelessWidget {
  const LogInputStatusScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Input & Status'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: const Center(child: Text('📝 Log Input UI goes here')),
    );
  }
}
