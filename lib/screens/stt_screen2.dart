import 'package:flutter/material.dart';

import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechToTextExample extends StatefulWidget {
  const SpeechToTextExample({super.key});

  @override
  SpeechToTextExampleState createState() => SpeechToTextExampleState();
}

class SpeechToTextExampleState extends State<SpeechToTextExample> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = "Press the button and start speaking";
  String _currentLocaleId = 'th-TH'; // Default to Thai
  double _pauseDuration = 3.0; // Add this line for pause duration in seconds
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  void _toggleLanguage() {
    setState(() {
      _currentLocaleId = _currentLocaleId == 'th-TH' ? 'en-US' : 'th-TH';
    });
  }

  // void _listen() async {
  //   if (!_isListening) {
  //     bool available = await _speech.initialize(
  //       onStatus: (status) {
  //         setState(() {
  //           _isListening = status == 'listening';
  //           _logs.add('Status: $status');
  //         });
  //         print('onStatus: $status');
  //       },
  //       onError: (val) => setState(() {
  //         _logs.add('Error: ${val.errorMsg}');
  //       }),
  //     );
  //     if (available) {
  //       setState(() => _isListening = true);
  //       _speech.listen(
  //         onResult: (val) => setState(() {
  //           _text = val.recognizedWords;
  //         }),
  //         localeId: _currentLocaleId,
  //         listenFor: Duration(seconds: _pauseDuration.round()),
  //       );
  //     }
  //   } else {
  //     setState(() => _isListening = false);
  //     _speech.stop();
  //   }
  // }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) {
          setState(() {
            _isListening = status == 'listening';
            _logs.add('Status: $status');
          });
          print('onStatus: $status');
          // Auto-restart listening when the session ends naturally
          if (status == 'done' || status == 'notListening') {
            if (_isListening) {
              // Only restart if the user hasn't manually stopped
              _startListening();
            }
          }
        },
        onError: (val) {
          setState(() {
            _isListening = false;
            _logs.add('Error: ${val.errorMsg}, Details: ${val.toString()}');
          });
          print('Error: ${val.errorMsg}, Details: ${val.toString()}');
          if (val.errorMsg == 'error_no_match') {
            print('No match detected. Please speak clearly or check locale.');
          }
          // Optionally restart listening on error
          if (_isListening) {
            _startListening();
          }
        },
      );
      if (available) {
        _startListening();
      } else {
        setState(() => _isListening = false);
        print('Speech recognition not available');
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      print('Stopped listening');
    }
  }

  // Helper method to start or restart listening
  void _startListening() {
    setState(() => _isListening = true);
    print('Starting listening with locale: $_currentLocaleId');
    _speech.listen(
      onResult:
          (val) => setState(() {
            _text = val.recognizedWords;
            print('Recognized: ${val.recognizedWords}');
          }),
      localeId: _currentLocaleId,
      listenFor: Duration(minutes: 5), // Set a large duration (e.g., 5 minutes)
      pauseFor: Duration(seconds: 5), // Optional: Pause duration for silence
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Speech to Text Example'),
        actions: [
          IconButton(
            icon: Text(_currentLocaleId == 'th-TH' ? '🇹🇭' : '🇺🇸'),
            onPressed: _toggleLanguage,
          ),
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _text,
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ),
          Text(
            'Current Language: ${_currentLocaleId == 'th-TH' ? 'Thai' : 'English'}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),
          Text(
            'Pause Duration: ${_pauseDuration.round()} seconds',
            style: TextStyle(fontSize: 16),
          ),
          Slider(
            value: _pauseDuration,
            min: 1.0,
            max: 60.0,
            divisions: 59,
            label: _pauseDuration.round().toString(),
            onChanged: (double value) {
              setState(() {
                _pauseDuration = value;
              });
            },
          ),
          SizedBox(height: 20),
          FloatingActionButton(
            onPressed: _listen,
            child: Icon(_isListening ? Icons.mic : Icons.mic_none),
          ),
          Expanded(
            child: Container(
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  return Text(_logs[index], style: TextStyle(fontSize: 12));
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
