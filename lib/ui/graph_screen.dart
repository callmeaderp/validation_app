import 'package:flutter/material.dart';

class GraphScreen extends StatelessWidget {
  const GraphScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Progress Graph')),
      body: const Center(child: Text('📊 Combo Graph UI goes here')),
    );
  }
}
