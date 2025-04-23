import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_speech/endless_streaming_service.dart';
import 'package:google_speech/google_speech.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class GoogleSpeechExample extends StatefulWidget {
  @override
  _GoogleSpeechExampleState createState() => _GoogleSpeechExampleState();
}

class _GoogleSpeechExampleState extends State<GoogleSpeechExample> {
  bool _isListening = false;
  String _text = "Press the button and start speaking";
  final _recorder = AudioRecorder();
  Stream<List<int>>? _audioStream;
  EndlessStreamingService? _speechToText;
  StreamSubscription? _recognitionSubscription;
  String _selectedLanguage = 'en-US'; // Default language

  final Map<String, String> _supportedLanguages = {
    'en-US': 'English',
    'th-TH': 'Thai',
  };

  @override
  void initState() {
    super.initState();
    _initSpeechToText();
  }

  Future<void> _initSpeechToText() async {
    final serviceAccount = ServiceAccount.fromString(
      await rootBundle.loadString('assets/credentials.json'),
    );
    _speechToText = EndlessStreamingService.viaServiceAccount(serviceAccount);
  }

  Future<void> _listen() async {
    if (_isListening) {
      await _stopListening();
      return;
    }

    // Request microphone permission
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      print('Microphone permission not granted');
      return;
    }

    // Start recording
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );
    _audioStream = stream;

    if (!mounted) return; // Check if widget is still mounted
    setState(() {
      _isListening = true;
      _text = "Listening...";
    });

    // Create recognition config
    final config = RecognitionConfig(
      encoding: AudioEncoding.LINEAR16,
      model: RecognitionModel.basic,
      enableAutomaticPunctuation: true,
      sampleRateHertz: 16000,
      languageCode: _selectedLanguage,
    );

    // Create streaming config
    final streamingConfig = StreamingRecognitionConfig(
      config: config,
      interimResults: true,
    );

    // Start endless streaming recognition
    if (_audioStream != null) {
      _speechToText?.endlessStreamingRecognize(streamingConfig, _audioStream!);

      // Listen to recognition results
      _recognitionSubscription = _speechToText?.endlessStream.listen(
        (data) {
          if (data.results.isNotEmpty && mounted) {
            // Check if widget is still mounted
            setState(() {
              _text = data.results
                  .map((result) => result.alternatives.first.transcript)
                  .join('\n');
            });
          }
        },
        onError: (error) {
          print('Error: $error');
          if (mounted) {
            // Check if widget is still mounted
            _stopListening();
          }
        },
      );
    }
  }

  Future<void> _stopListening() async {
    await _recognitionSubscription?.cancel();
    _recognitionSubscription = null;
    await _recorder.stop();
    _speechToText = null;
    await _initSpeechToText(); // Reinitialize for next use

    if (!mounted) return; // Check if widget is still mounted
    setState(() {
      _isListening = false;
      if (_text == "Listening...") {
        _text = "Press the button and start speaking";
      }
    });
  }

  Widget _buildLanguageSelector() {
    return DropdownButton<String>(
      value: _selectedLanguage,
      items:
          _supportedLanguages.entries.map((entry) {
            return DropdownMenuItem<String>(
              value: entry.key,
              child: Text(entry.value),
            );
          }).toList(),
      onChanged: (String? newValue) {
        if (newValue != null) {
          setState(() {
            _selectedLanguage = newValue;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _stopListening(); // Clean up the listening session
    _recognitionSubscription?.cancel(); // Cancel any ongoing subscription
    _recorder.dispose(); // Dispose the recorder
    _speechToText = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Google Speech V2 Example')),
      body: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildLanguageSelector(),
            SizedBox(height: 20),
            Text(
              _text,
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            FloatingActionButton(
              onPressed: _listen,
              child: Icon(_isListening ? Icons.stop : Icons.mic),
            ),
          ],
        ),
      ),
    );
  }
}
