import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for rootBundle
import 'package:google_speech/generated/google/cloud/speech/v2/cloud_speech.pb.dart'
    as v2;
import 'package:google_speech/generated/google/cloud/speech/v2/cloud_speech.pbgrpc.dart' show SpeechClient; // V2 Client
// Remove ServiceAccount import from google_speech, use googleapis_auth instead
// import 'package:google_speech/google_speech.dart' show ServiceAccount;
import 'package:grpc/grpc.dart'; // Import grpc
import 'package:googleapis_auth/auth_io.dart' as auth; // Import googleapis_auth
import 'package:permission_handler/permission_handler.dart';
// import 'package:sound_stream/sound_stream.dart'; // Replaced by mic_stream
import 'package:mic_stream/mic_stream.dart'; // Import mic_stream

// --- Recognizer Configuration ---
const String thaiRecognizerName =
    'projects/rewatt/locations/asia-southeast1/recognizers/stt-v001';
const String englishRecognizerName =
    'projects/rewatt/locations/asia-southeast1/recognizers/stt-v002-en';
// --- End Recognizer Configuration ---

enum Language { thai, english }

class GoogleSpeechV2Screen extends StatefulWidget { // Renamed class
  const GoogleSpeechV2Screen({super.key});

  @override
  State<GoogleSpeechV2Screen> createState() => _GoogleSpeechV2ScreenState(); // Renamed state class
}

class _GoogleSpeechV2ScreenState extends State<GoogleSpeechV2Screen> { // Renamed state class
  // Replace RecorderStream with MicStream specific variables
  // final RecorderStream _recorder = RecorderStream(); // From sound_stream
  Stream<List<int>>? _micStream; // Stream from mic_stream
  StreamSubscription<List<int>>? _micListener; // Listener for mic_stream

  bool _isRecording = false;
  bool _isClientReady = false;
  String _transcribedText = '';
  String _statusText = 'Initializing...';
  Language _selectedLanguage = Language.thai; // Default language

  // --- V2 gRPC Client ---
  ClientChannel? _channel;
  SpeechClient? _speechClient; // V2 Client
  auth.AuthClient? _httpClient; // Store the authenticated client
  StreamController<v2.StreamingRecognizeRequest>? _requestStreamController;
  StreamSubscription<v2.StreamingRecognizeResponse>? _responseSubscription;
  StreamSubscription<List<int>>? _audioStreamSubscription;
  // --- End V2 gRPC Client ---

  // Store cumulative final results
  String _cumulativeFinalTranscript = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDependencies();
    });
  }

  void dispose() {
    _stopRecording(cancelClient: true); // Ensure channel is closed on dispose
    super.dispose();
  }

  Future<void> _initializeDependencies() async {
    if (!mounted) return;

    try {
      setState(() {
        _statusText = 'Initializing audio recorder...';
      });
      // NOTE: mic_stream also typically defaults to a compatible sample rate (e.g., 16000 or 44100)
      // We might need to explicitly request 16000Hz if possible, or handle potential resampling.
      // MicStream doesn't have an explicit initialize method like sound_stream.
      // Initialization happens when you listen to the stream.
      print("Audio Recorder (mic_stream) ready to be used.");
      // No explicit initialization needed here for mic_stream
      setState(() { _statusText = 'Audio recorder ready.'; });
    } catch (e) {
      // This catch block might be less relevant for mic_stream initialization itself
      print('Error during dependency setup (mic_stream context): $e');
      if (mounted) {
        setState(() {
          _statusText = 'Error initializing audio recorder: $e';
        });
      }
      return; // Don't proceed if recorder fails
    }

    // Request permission first
    bool granted = await _requestPermission();

    // Initialize client only if permission is granted
    if (granted) {
      await _initializeSpeechClient();
    } else {
      print("Microphone permission not granted. Speech client not initialized.");
      if (mounted) {
        setState(() {
          _statusText = 'Microphone permission required.';
          _isClientReady = false;
        });
      }
    }
  }

  Future<bool> _requestPermission() async {
    PermissionStatus status = await Permission.microphone.request();
    if (!mounted) return false;

    bool granted = false;
    String statusMsg = '';

    if (status.isGranted) {
      statusMsg = 'Microphone permission granted.';
      granted = true;
    } else if (status.isDenied) {
      statusMsg = 'Microphone permission denied. Please grant permission.';
    } else if (status.isPermanentlyDenied) {
      statusMsg =
          'Microphone permission permanently denied. Please enable it in app settings.';
      _showOpenSettingsDialog(); // Show dialog to guide user
    } else {
      statusMsg = 'Microphone permission status: $status';
    }

    setState(() {
      _statusText = statusMsg;
      if (!granted) {
        _isClientReady = false; // Ensure client isn't marked ready if no permission
      }
    });
    return granted;
  }

   void _showOpenSettingsDialog() {
    showDialog(
      context: context,
      builder:
          (BuildContext context) => AlertDialog(
            title: const Text('Permission Required'),
            content: const Text(
              'Microphone permission is permanently denied. Please enable it in your app settings to use voice typing.',
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              TextButton(
                child: const Text('Open Settings'),
                onPressed: () {
                  openAppSettings(); // From permission_handler
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
    );
  }

  Future<void> _initializeSpeechClient() async {
    if (!mounted) return;
    // Permission should already be granted here
    if (!await Permission.microphone.isGranted) {
      print("FATAL: Attempted to initialize speech client without permission.");
      setState(() { _statusText = "Permission error."; _isClientReady = false; });
      return;
    }

    setState(() { _statusText = 'Initializing speech client...'; _isClientReady = false; });

    try {
      // 1. Load Credentials & Create Authenticated Client
      final String jsonCredentials = await rootBundle.loadString('assets/credentials.json');
      final credentials = auth.ServiceAccountCredentials.fromJson(jsonCredentials);
      // Define the required scope for the Speech API
      const scopes = ['https://www.googleapis.com/auth/cloud-platform'];
      _httpClient = await auth.clientViaServiceAccount(credentials, scopes); // Store the client

      // 2. Create a standard secure gRPC Channel (Auth applied per-call)
      _channel = ClientChannel(
        'speech.googleapis.com',
        port: 443,
        options: const ChannelOptions(
          credentials: ChannelCredentials.secure(), // Just secure transport
          // Optional KeepAlive
          // keepAlive: ClientKeepAliveOptions(...)
        ),
      );

      // 3. Create V2 SpeechClient Stub
      _speechClient = SpeechClient(_channel!);

      if (mounted) {
        setState(() { _isClientReady = true; _statusText = 'Ready to record.'; });
      }
      print("Speech client (V2) initialized successfully.");

    } catch (e, s) {
      print('Error initializing speech client (V2): $e');
      print(s); // Print stacktrace for detailed debugging
      if (mounted) {
        setState(() { _statusText = 'Error initializing client: $e'; _isClientReady = false; });
      }
      await _channel?.shutdown();
      _channel = null;
      _speechClient = null;
    }
  }

  void _toggleRecording() async {
    if (!_isClientReady || _speechClient == null) {
      print("Client not ready or null. Status: $_statusText");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_statusText.isNotEmpty ? _statusText : 'Client not ready.'),
      ));
      // Attempt re-initialization if needed
      if (!await Permission.microphone.isGranted) {
        await _requestPermission();
      } else if (_speechClient == null) {
        await _initializeSpeechClient();
      }
      return;
    }

    // Double-check permission just before starting
    if (!await Permission.microphone.isGranted) {
      print("Permission lost before toggling.");
      await _requestPermission();
      return;
    }

    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    if (_speechClient == null || !_isClientReady || _isRecording) {
      print("Cannot start: Client null: ${_speechClient == null}, Not ready: {!_isClientReady}, Recording: $_isRecording");
      return;
    }
    if (!mounted) return;

    setState(() {
      _isRecording = true;
      _transcribedText = ''; // Clear previous full transcript
      _cumulativeFinalTranscript = ''; // Clear cumulative final transcript
      _statusText = 'Connecting...';
    });

    try {
      // 1. Select Recognizer based on language
      final recognizer = _selectedLanguage == Language.thai
          ? thaiRecognizerName
          : englishRecognizerName;
      print("Using Recognizer: $recognizer");

      // 2. Prepare V2 Streaming Recognition Config
      const sampleRate = 16000; // Common rate for mic_stream/sound_stream
      final streamingConfig = v2.StreamingRecognitionConfig(
        config: v2.RecognitionConfig(
          // Explicitly set encoding and sample rate
          autoDecodingConfig: v2.AutoDetectDecodingConfig(), // Recommended for V2
          // Or specify manually:
          // explicitDecodingConfig: v2.ExplicitDecodingConfig(
          //   encoding: v2.ExplicitDecodingConfig_AudioEncoding.LINEAR16,
          //   sampleRateHertz: sampleRate,
          //   audioChannelCount: 1,
          // ),
          // Model selection is handled by the Recognizer resource
          features: v2.RecognitionFeatures(
            enableWordConfidence: true, // From your Recognizer config
            // Add other features matching your Recognizer if needed
          ),
        ),
        streamingFeatures: v2.StreamingRecognitionFeatures(
          interimResults: true,
          // enableVoiceActivityEvents: true, // Optional: for VAD events
        ),
      );

      // 3. Create Request Stream Controller
      _requestStreamController = StreamController<v2.StreamingRecognizeRequest>();

      // 4. Prepare Call Options with Authentication Provider
      print("Preparing call options with authentication...");
      final callOptions = CallOptions(
        providers: [ (metadata, uri) async {
            if (_httpClient == null) {
               print("Error: Auth client is null during call.");
               throw GrpcError.unauthenticated('Authentication client not initialized.');
            }
            try {
               final accessCredentials = await _httpClient!.credentials;
               final token = accessCredentials.accessToken.data;
               final expiry = accessCredentials.accessToken.expiry;
               print("Using access token (expires: $expiry)");
               metadata['authorization'] = 'Bearer $token';
            } catch (e) {
               print("Error fetching access token for gRPC call: $e");
               throw GrpcError.unauthenticated('Failed to obtain access token for call: $e');
            }
        }],
        // Optional: Set metadata or timeouts if needed
        // metadata: {'your-metadata-key': 'your-value'},
        // timeout: Duration(minutes: 5), // Example timeout
      );

      // 5. Initiate gRPC Bi-directional Stream Call with Auth Options
      print("Initiating V2 StreamingRecognize call...");
      final responseStream = _speechClient!.streamingRecognize(
        _requestStreamController!.stream,
        options: callOptions, // Pass the prepared options here
      );

      // 5. Send Initial Config Request
      print("Sending initial config request...");
      _requestStreamController!.add(v2.StreamingRecognizeRequest(
        recognizer: recognizer,
        streamingConfig: streamingConfig,
        // Do NOT send audio in the first request
      ));

      // 7. Start Audio Recorder (mic_stream) and Stream Audio Data
      print("Starting audio recorder (mic_stream)...");
      // Request the stream from mic_stream, potentially specifying sample rate if API allows
      // mic_stream might require error handling during stream creation itself.
      _micStream = await MicStream.microphone(
          audioSource: AudioSource.DEFAULT,
          sampleRate: 16000, // Explicitly request 16000Hz if supported
          channelConfig: ChannelConfig.CHANNEL_IN_MONO,
          audioFormat: AudioFormat.ENCODING_PCM_16BIT);

      if (_micStream == null) {
         throw Exception("MicStream.microphone returned null stream.");
      }
      print("Mic stream obtained. Listening...");

      // Cancel previous listener if any
      await _micListener?.cancel();

      _micListener = _micStream!.listen( // Use the _micListener for mic_stream
        (data) {
          // Send audio chunks
          if (_requestStreamController != null && !_requestStreamController!.isClosed) {
            _requestStreamController!.add(v2.StreamingRecognizeRequest(audio: data));
          }
        },
        onError: (e, s) {
          print("Audio stream error: $e");
          print(s);
          _handleError('Mic stream error: $e');
        },
        onDone: () {
          print("Mic stream finished (onDone).");
          // Signal end of audio to API by closing the request stream
          if (_requestStreamController != null && !_requestStreamController!.isClosed) {
             print("Closing request stream (mic stream finished).");
             _requestStreamController!.close();
          }
        },
        cancelOnError: true, // Important to stop on error
      );

      // 8. Listen to Response Stream
      _responseSubscription = responseStream.listen(
        _onSpeechResultV2, // Handle V2 responses
        onError: (e, s) {
          print("gRPC response stream error: $e");
          print(s);
          // Handle gRPC specific errors (e.g., status codes)
          String errorMsg = 'API stream error';
          if (e is GrpcError) {
             errorMsg = 'API Error: ${e.message} (Code: ${e.codeName})';
          } else {
             errorMsg = 'API stream error: $e';
          }
          _handleError(errorMsg);
        },
        onDone: _onSpeechDoneV2, // Handle stream closure
        cancelOnError: false, // Let onError handle stopping
      );

      if (mounted) {
        setState(() { _statusText = 'Listening...'; });
      }
      print("Recording started successfully (V2).");

    } catch (e, s) {
      print('Error starting V2 recording: $e');
      print(s);
      _handleError('Start recording error: $e');
    }
  }

  Future<void> _stopRecording({bool cancelClient = false}) async {
    if (!_isRecording && _audioStreamSubscription == null && _responseSubscription == null && _requestStreamController == null) {
      print("Stop recording called but nothing seems active.");
      // If cancelClient is true, ensure channel is closed even if nothing was active
      if (cancelClient) {
         await _channel?.shutdown();
         _channel = null;
         _speechClient = null;
         print("gRPC channel shut down due to cancelClient=true.");
      }
      return;
    }

    final wasRecording = _isRecording; // Store state before async gaps
    if (mounted) {
      setState(() { _isRecording = false; });
    } else {
      _isRecording = false; // Update state even if not mounted
    }

    print('Attempting to stop recording (V2)...');
    String finalStatus = 'Recording stopped.';

    try {
      // 1. Stop audio recorder (mic_stream) - Cancel the listener
      await _micListener?.cancel();
      _micListener = null;
      _micStream = null; // Clear the stream reference
      print('Mic stream listener cancelled.');
      // mic_stream doesn't have an explicit stop method like sound_stream

      // 2. Cancel audio stream subscription (This variable is now unused, replaced by _micListener)
      // await _audioStreamSubscription?.cancel();
      // _audioStreamSubscription = null;
      // print('Audio stream subscription cancelled.');

      // 3. Close the request stream (signals end of audio to API)
      if (_requestStreamController != null && !_requestStreamController!.isClosed) {
        await _requestStreamController!.close();
        print('Request stream closed.');
      }
      _requestStreamController = null;


      // 4. Cancel response stream subscription
      await _responseSubscription?.cancel();
      _responseSubscription = null;
      print('Response subscription cancelled.');

      // 5. Optionally shutdown the gRPC channel (usually only on dispose)
      if (cancelClient) {
        await _channel?.shutdown();
        _channel = null;
        _speechClient = null;
        _isClientReady = false; // Client is no longer ready
        finalStatus = 'Client shut down.';
        print("gRPC channel shut down.");
      }

      if (mounted && wasRecording) { // Only update status if we were actually recording
        setState(() { _statusText = finalStatus; });
      }
      print('Recording stopped successfully (V2).');

    } catch (e, s) {
      print('Error during stop recording sequence (V2): $e');
      print(s);
      finalStatus = 'Error stopping: $e';
      if (mounted) {
        setState(() { _statusText = finalStatus; });
      }
    } finally {
      // Ensure all resources are nullified
      _audioStreamSubscription = null;
      _requestStreamController = null;
      _responseSubscription = null;
      if (cancelClient) {
        _channel = null;
        _speechClient = null;
        if(mounted) setState(() => _isClientReady = false); else _isClientReady = false;
      }
       // Ensure recording state is false
      if(mounted) setState(() => _isRecording = false); else _isRecording = false;

      // Close the httpClient when the client is cancelled (e.g., on dispose)
      if (cancelClient) {
         _httpClient?.close();
         _httpClient = null;
         print("Auth HTTP client closed.");
      }
    }
  }

  // --- V2 Specific Handlers ---

  void _onSpeechResultV2(v2.StreamingRecognizeResponse response) {
    if (!mounted) return;

    String currentInterim = '';
    String currentFinal = '';
    bool isFinalEvent = false;

    if (response.results.isNotEmpty) {
      final result = response.results.first; // Process the first result
      if (result.alternatives.isNotEmpty) {
        final alternative = result.alternatives.first;
        if (result.isFinal) {
          currentFinal = alternative.transcript;
          isFinalEvent = true;
        } else {
          currentInterim = alternative.transcript;
        }
      }
    }

    // --- Handle Speech Recognition Event Types (Optional but useful) ---
    // Note: V2 uses different event types if enabled in config
    // switch (response.speechEventType) {
    //   case v2.StreamingRecognizeResponse_SpeechEventType.SPEECH_ACTIVITY_BEGIN:
    //     print("VAD: Speech started");
    //     break;
    //   case v2.StreamingRecognizeResponse_SpeechEventType.SPEECH_ACTIVITY_END:
    //     print("VAD: Speech ended");
    //     break;
    //   // Add other cases as needed
    // }
    // --- End Event Handling ---


    // Update cumulative final transcript if new final text arrived
    if (isFinalEvent && currentFinal.isNotEmpty) {
      _cumulativeFinalTranscript = (_cumulativeFinalTranscript.isEmpty ? '' : '$_cumulativeFinalTranscript ') + currentFinal.trim();
    }

    // Construct display text: cumulative final + current interim
    String displayText = _cumulativeFinalTranscript;
    if (currentInterim.isNotEmpty) {
      displayText += (displayText.isEmpty ? '' : ' ') + '... $currentInterim'; // Indicate interim
    }

    // Update UI state
    setState(() {
      _transcribedText = displayText.trim();
      _statusText = _isRecording ? 'Listening...' : 'Processing...'; // Update status based on interim/final
    });

     // Optional: Stop recording automatically on final result if desired
     // if (isFinalEvent && currentFinal.isNotEmpty) {
     //   print("Stopping recording after final result.");
     //   _stopRecording();
     // }
  }

   void _onSpeechDoneV2() {
    print('API response stream closed (onDone).');
    if (mounted && _isRecording) {
      print('API stream closed unexpectedly while recording was active.');
      // Don't necessarily stop recording here, wait for audio stream 'onDone'
      // which should close the request stream and trigger a clean stop.
      // However, if the API closes the stream prematurely, we might need to stop.
       _handleError("API stream closed unexpectedly.");
    } else if (mounted) {
       print('API stream closed.');
       // If we weren't recording, just update status
       if (!_isRecording) {
          setState(() { _statusText = _isClientReady ? 'Ready to record.' : 'Client stopped.'; });
       }
    } else {
       print('API stream closed, widget not mounted.');
       // Attempt cleanup if not mounted
       _stopRecording(cancelClient: true); // Force cleanup if widget is gone
    }
  }

  // Central error handling
  void _handleError(String message) {
     print("Error encountered: $message");
     if (mounted) {
       setState(() {
         _statusText = message;
         // Don't set _isRecording false here directly, let _stopRecording handle state
       });
       _stopRecording(); // Attempt to stop everything cleanly on error
     } else {
       _stopRecording(cancelClient: true); // Force cleanup if widget is gone
     }
  }


  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google STT v2 (Chirp)'), // Updated title
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding( // Use Padding instead of Center for better layout control
        padding: const EdgeInsets.all(16.0),
        child: Column(
          // mainAxisAlignment: MainAxisAlignment.center, // Remove to allow top alignment
          crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch children horizontally
          children: <Widget>[
            // Language Selector
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: SegmentedButton<Language>(
                segments: const <ButtonSegment<Language>>[
                  ButtonSegment<Language>(value: Language.thai, label: Text('ไทย (TH)')),
                  ButtonSegment<Language>(value: Language.english, label: Text('English (IN)')),
                ],
                selected: <Language>{_selectedLanguage},
                onSelectionChanged: (Set<Language> newSelection) {
                  if (!_isRecording) { // Prevent changing language while recording
                    setState(() {
                      _selectedLanguage = newSelection.first;
                      _statusText = 'Language set to ${_selectedLanguage == Language.thai ? 'Thai' : 'English'}. Ready.';
                      print("Language changed to: $_selectedLanguage");
                    });
                  } else {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                       content: Text('Stop recording to change language.'),
                       duration: Duration(seconds: 2),
                     ));
                  }
                },
                style: SegmentedButton.styleFrom(
                  // Adjust visual density if needed
                  // visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Status Text
            Text(
              _statusText,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _statusText.toLowerCase().contains('error') || _statusText.toLowerCase().contains('fail')
                        ? Colors.redAccent
                        : (_isRecording ? Colors.blueAccent : null),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 15),
            // Transcript Display Area
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8.0),
                  color: Colors.grey.shade50, // Slightly lighter background
                ),
                child: SingleChildScrollView(
                  reverse: true, // Scroll to bottom
                  child: Text(
                    _transcribedText.isEmpty
                        ? (_isClientReady
                            ? 'Press the button and start speaking...'
                            : 'Initializing / Waiting for permission...')
                        : _transcribedText,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: _transcribedText.isEmpty
                              ? Colors.grey.shade700
                              : Colors.black87,
                          height: 1.4, // Improve line spacing
                        ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Record Button
            Center( // Center the button itself
              child: FloatingActionButton.large( // Make button larger
                onPressed: _isClientReady ? _toggleRecording : null, // Disable if client not ready
                tooltip: _isRecording ? 'Stop Recording' : 'Start Recording',
                backgroundColor: !_isClientReady
                    ? Colors.grey.shade400 // Disabled color
                    : (_isRecording ? Colors.redAccent : Colors.greenAccent.shade700),
                foregroundColor: Colors.white,
                child: Icon(_isRecording ? Icons.stop_rounded : Icons.mic_rounded, size: 36), // Larger icon
              ),
            ),
            const SizedBox(height: 10), // Add some bottom padding
          ],
        ),
      ),
    );
  }
}

// Removed the GrpcAuthenticator class as it's no longer needed with the direct accessTokenProvider approach.
