import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/stt_screen2.dart';

class STTScreen extends StatelessWidget {
  const STTScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Speech to Text')),
      body: Center(
        child: Column(
          children: [
            const Text('Speech to Text Screen'),
            ElevatedButton(
              onPressed: () {
                // go to page SpeechToTextExample
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SpeechToTextExample(),
                  ),
                );
              },
              child: const Text('Start Listening'),
            ),
          ],
        ),
      ),
    );
  }
}
