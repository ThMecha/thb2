import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class GoogleSpeechExample extends StatefulWidget {
  @override
  _GoogleSpeechExampleState createState() => _GoogleSpeechExampleState();
}

class _GoogleSpeechExampleState extends State<GoogleSpeechExample> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = "Press the button and start speaking";

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => print('onStatus: $val'),
        onError: (val) => print('onError: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (val) => setState(() {
              _text = val.recognizedWords;
            }));
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Google Speech Example')),
      body: Column(
        children: [
          Text(_text),
          FloatingActionButton(
            onPressed: _listen,
            child: Icon(_isListening ? Icons.mic : Icons.mic_none),
          ),
        ],
      ),
    );
  }
}