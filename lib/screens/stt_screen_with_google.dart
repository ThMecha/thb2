import 'package:flutter/material.dart';
import 'package:google_speech/google_speech.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

enum SpeechLanguage { en, th }

class GoogleSpeechExample extends StatefulWidget {
  @override
  _GoogleSpeechExampleState createState() => _GoogleSpeechExampleState();
}

class _GoogleSpeechExampleState extends State<GoogleSpeechExample> {
  bool _isListening = false;
  String _text = "Press the button and start speaking";
  StreamSubscription<List<int>>? _audioStreamSubscription;
  StreamController<List<int>>? _audioStreamController;
  late SpeechToText speechToText;
  SpeechLanguage _currentLanguage = SpeechLanguage.en;

  String get _languageCode {
    switch (_currentLanguage) {
      case SpeechLanguage.en:
        return 'en-US';
      case SpeechLanguage.th:
        return 'th-TH';
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeGoogleSpeech();
  }

  void _initializeGoogleSpeech() async {
    final credentialsString = await DefaultAssetBundle.of(context)
        .loadString('assets/credentials.json');
    final serviceAccount = ServiceAccount.fromString(credentialsString);
    speechToText = SpeechToText.viaServiceAccount(serviceAccount);
  }

  void _listen() async {
    if (!_isListening) {
      _audioStreamController = StreamController<List<int>>();
      final config = RecognitionConfig(
        encoding: AudioEncoding.LINEAR16,
        model: RecognitionModel.basic,
        enableAutomaticPunctuation: true,
        sampleRateHertz: 16000,
        languageCode: _languageCode,
      );

      final responseStream = speechToText.streamingRecognize(
        StreamingRecognitionConfig(config: config, interimResults: true),
        _audioStreamController!.stream,
      );

      responseStream.listen(
        (data) {
          setState(() {
            _text = data.results
                .map((e) => e.alternatives.first.transcript)
                .join('\n');
          });
        },
        onError: (error) {
          print('Error: $error');
        },
      );

      setState(() => _isListening = true);

      // Here you would add your audio data to the stream
      // _audioStreamController!.add(audioData);
    } else {
      setState(() => _isListening = false);
      await _audioStreamController?.close();
      _audioStreamSubscription?.cancel();
    }
  }

  @override
  void dispose() {
    _audioStreamController?.close();
    _audioStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Google Speech Example')),
      body: Column(
        children: [
          DropdownButton<SpeechLanguage>(
            value: _currentLanguage,
            items: SpeechLanguage.values.map((lang) {
              return DropdownMenuItem(
                value: lang,
                child: Text(lang == SpeechLanguage.en ? 'English' : 'ไทย'),
              );
            }).toList(),
            onChanged: (SpeechLanguage? newValue) {
              if (newValue != null) {
                setState(() => _currentLanguage = newValue);
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(_text),
          ),
          FloatingActionButton(
            onPressed: _listen,
            child: Icon(_isListening ? Icons.mic : Icons.mic_none),
          ),
        ],
      ),
    );
  }
}
