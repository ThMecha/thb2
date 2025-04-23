import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TTSScreen extends StatefulWidget {
  const TTSScreen({super.key});

  @override
  State<TTSScreen> createState() => _TTSScreenState();
}

class _TTSScreenState extends State<TTSScreen> {
  final FlutterTts flutterTts = FlutterTts();
  final TextEditingController textController = TextEditingController();
  String? language;
  double volume = 1.0;
  double pitch = 1.0;
  double rate = 0.5;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await flutterTts.setLanguage("th-TH");
    await flutterTts.setPitch(pitch);
    await flutterTts.setVolume(volume);
    await flutterTts.setSpeechRate(rate);
  }

  Future<void> _speak() async {
    if (textController.text.isNotEmpty) {
      await flutterTts.speak(textController.text);
    }
  }

  Future<void> _stop() async {
    await flutterTts.stop();
  }

  void _toggleLanguage() async {
    if (language == "th-TH") {
      language = "en-US";
    } else {
      language = "th-TH";
    }
    await flutterTts.setLanguage(language!);
    setState(() {});
  }

  @override
  void dispose() {
    flutterTts.stop();
    textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Text to Speech'),
        actions: [
          IconButton(
            icon: Text(language == "th-TH" ? '🇹🇭' : '🇺🇸'),
            onPressed: _toggleLanguage,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: textController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Enter text to speak',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(onPressed: _speak, child: const Text('Speak')),
                ElevatedButton(onPressed: _stop, child: const Text('Stop')),
              ],
            ),
            const SizedBox(height: 20),
            Slider(
              value: pitch,
              onChanged: (value) async {
                await flutterTts.setPitch(value);
                setState(() => pitch = value);
              },
              min: 0.5,
              max: 2.0,
              label: "Pitch: ${pitch.toStringAsFixed(2)}",
            ),
            Slider(
              value: rate,
              onChanged: (value) async {
                await flutterTts.setSpeechRate(value);
                setState(() => rate = value);
              },
              min: 0.0,
              max: 1.0,
              label: "Rate: ${rate.toStringAsFixed(2)}",
            ),
          ],
        ),
      ),
    );
  }
}
