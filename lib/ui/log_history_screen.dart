import 'package:flutter/material.dart';

class LogHistoryScreen extends StatelessWidget {
  const LogHistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log History')),
      body: const Center(child: Text('📜 Log entries list goes here')),
    );
  }
}
