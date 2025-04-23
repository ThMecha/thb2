import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechToTextExample extends StatefulWidget {
  const SpeechToTextExample({super.key});

  @override
  SpeechToTextExampleState createState() => SpeechToTextExampleState();
}

class SpeechToTextExampleState extends State<SpeechToTextExample> {
  final ScrollController _scrollController = ScrollController();
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isInitialized = false;
  String _text = "Press the button and start speaking";
  String _currentLocaleId = 'th-TH';
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initializeSpeech();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initializeSpeech() async {
    try {
      bool available = await _speech.initialize(
        onStatus: _onStatus,
        onError: _onError,
        debugLogging: true,
      );
      setState(() => _isInitialized = available);
      if (!available) {
        _logs.add('Speech recognition not available');
      }
    } catch (e) {
      _logs.add('Error initializing: $e');
      setState(() => _isInitialized = false);
    }
  }

  void _onStatus(String status) {
    setState(() {
      _isListening = status == 'listening';
      _logs.add('Status: $status');
      _scrollToBottom();
    });
  }

  void _onError(dynamic val) {
    setState(() {
      _isListening = false;
      _logs.add('Error: ${val.errorMsg}');
      _scrollToBottom();
    });
    if (val.errorMsg == 'error_speech_timeout') {
      _logs.add('Note: Android has a short timeout for pauses in speech');
    }
  }

  void _toggleLanguage() {
    setState(() {
      _currentLocaleId = _currentLocaleId == 'th-TH' ? 'en-US' : 'th-TH';
    });
  }

  void _listen({stt.ListenMode listenMode = stt.ListenMode.dictation}) async {
    _logs.add('_listen method called with mode: $listenMode');
    if (!_isListening) {
      if (_isInitialized) {
        _startListening(listenMode: listenMode);
      } else {
        setState(() => _isListening = false);
        _logs.add('Speech recognition not initialized');
      }
    } else {
      _speech.stop();
      setState(() => _isListening = false);
      _logs.add('Stopped listening');
    }
  }

  void _startListening({stt.ListenMode listenMode = stt.ListenMode.dictation}) {
    _logs.add('_startListening method called with mode: $listenMode');
    setState(() => _isListening = true);
    _logs.add('');
    _logs.add('--');
    _logs.insert(
      0,
      'Starting ${listenMode.toString()} with locale: $_currentLocaleId',
    );
    _speech.listen(
      onResult:
          (val) => setState(() {
            if (val.finalResult) {
              _text = '$_text${_text.isEmpty ? '' : ' '}${val.recognizedWords}';
            } else {
              _logs.add('Partial: ${val.recognizedWords}...');
            }
            _logs.insert(
              0,
              'Dictation: ${val.recognizedWords} (Final: ${val.finalResult})',
            );
            _scrollToBottom();
          }),
      localeId: _currentLocaleId,
      pauseFor: Duration(milliseconds: 50000),
      listenOptions: stt.SpeechListenOptions(
        cancelOnError: false,
        partialResults: true,
        listenMode: listenMode,
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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
            'Note: Speech recognition will timeout after ~5 seconds of silence',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                children: [
                  ElevatedButton(
                    onPressed:
                        () => _listen(listenMode: stt.ListenMode.dictation),
                    child: Text('Dictate Text'),
                  ),
                  ElevatedButton(
                    onPressed: () => _listen(listenMode: stt.ListenMode.search),
                    child: Text('Search Query'),
                  ),
                  ElevatedButton(
                    onPressed:
                        () => _listen(listenMode: stt.ListenMode.confirmation),
                    child: Text('Confirm (Yes/No)'),
                  ),
                ],
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FloatingActionButton(
                heroTag: 'mic_button', // Add unique hero tag
                onPressed: _listen,
                child: Icon(_isListening ? Icons.mic : Icons.mic_none),
              ),
              SizedBox(width: 16),
              FloatingActionButton(
                heroTag: 'clear_button', // Add unique hero tag
                onPressed: () => setState(() => _text = ''),
                child: Icon(Icons.clear),
              ),
            ],
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
                controller: _scrollController,
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
