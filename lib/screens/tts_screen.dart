import 'package:flutter/material.dart';

class TTSScreen extends StatelessWidget {
  const TTSScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Text to Speech')),
      body: const Center(child: Text('Text to Speech Screen')),
    );
  }
}
