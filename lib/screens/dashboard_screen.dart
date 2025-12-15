// screens/dashboard_screen.dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';  // Added for rootBundle
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';
// import 'package:cached_network_image/cached_network_image.dart';
import 'package:chef/services/api_service.dart';
// import 'package:chef/constants.dart';
import 'package:chef/theme/colors.dart';
import 'package:chef/services/image_store.dart';
import 'package:chef/services/dio_client.dart';
// import 'package:chef/services/notification_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
// import 'package:mime/mime.dart';
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'package:permission_handler/permission_handler.dart';
import 'package:google_speech/google_speech.dart';
import 'package:flutter_sound/flutter_sound.dart';


class DashboardScreen extends StatefulWidget {
  final ValueNotifier<int> refreshTrigger;
  final ValueChanged<bool>? onAnalyzingChange;

  const DashboardScreen({
    super.key,
    required this.refreshTrigger,
    this.onAnalyzingChange,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final AudioPlayer _player = AudioPlayer();

  late final AnimationController _micAnim;
  late final Animation<double> _micScale;
  late final Animation<double> _micOpacity;

  // Compute RMS of 16-bit little-endian PCM audio data
  double _rmsInt16Le(Uint8List bytes) {
    if (bytes.length < 2) return 0.0;
    final bd = ByteData.sublistView(bytes);
    double acc = 0.0;
    int n = 0;
    for (int i = 0; i + 1 < bytes.length; i += 2) {
      final s = bd.getInt16(i, Endian.little); // -32768..32767
      acc += (s * s).toDouble();
      n++;
    }
    if (n == 0) return 0.0;
    return math.sqrt(acc / n);
  }

  // Speech recognition variables
  late SpeechToText _speech;

  // Auto-stop on silence
  Timer? _silenceTimer;
  DateTime _lastHeard = DateTime.now();
  final Duration _silenceTimeout = const Duration(seconds: 3);

  // Simple VAD (noise calibration)
  bool _vadCalibrating = false;
  int _vadCalibFrames = 0;
  double _noiseFloor = 0.0;

  // Audio recording variables
  FlutterSoundRecorder? _audioRecorder;
  StreamController<List<int>>? _googleAudioCtl; 
  StreamController<Uint8List>? _micCtl;
  
  StreamSubscription? _recognitionSub;

  bool _isRecording = false;
  String _committedText = '';
  String _interimText = '';
  DateTime _lastInterimAt = DateTime.fromMillisecondsSinceEpoch(0);

  String _applySpokenPunctuation(String input) {
    var s = ' $input ';

    final rules = <RegExp, String>{
      RegExp(r'\b(ellipsis|dot dot dot)\b', caseSensitive: false): ' … ',
      RegExp(r'\b(question mark)\b',        caseSensitive: false): ' ? ',
      RegExp(r'\b(exclamation (?:point|mark))\b', caseSensitive: false): ' ! ',
      RegExp(r'\b(semicolon)\b',            caseSensitive: false): ' ; ',
      RegExp(r'\b(colon)\b',                caseSensitive: false): ' : ',
      RegExp(r'\b(dash|hyphen)\b',          caseSensitive: false): ' - ',
      RegExp(r'\b(comma)\b',                caseSensitive: false): ' , ',
      RegExp(r'\b(period|full stop)\b',     caseSensitive: false): ' . ',
      RegExp(r'\b(new line)\b',             caseSensitive: false): '\n',
      RegExp(r'\b(new paragraph)\b',        caseSensitive: false): '\n\n',
      RegExp(r'\b(open quote)\b',           caseSensitive: false): ' “',
      RegExp(r'\b(close quote)\b',          caseSensitive: false): '” ',
    };
    rules.forEach((re, sym) => s = s.replaceAll(re, sym));

    // Use replaceAllMapped for “$1”-style fixes
    s = s.replaceAllMapped(RegExp(r'\s+([,.;:!?…])'), (m) => '${m[1]} ');
    s = s.replaceAllMapped(RegExp(r'\s+([”“])'),      (m) => '${m[1]}');
    s = s.replaceAllMapped(RegExp(r'([\(])\s+'),       (m) => '${m[1]}');
    s = s.replaceAllMapped(RegExp(r'\s+([\)])'),       (m) => '${m[1]}');

    s = s.replaceAll(RegExp(r'\s+\n'), '\n');
    s = s.replaceAll(RegExp(r'\n\s+'), '\n');
    s = s.replaceAll(RegExp(r' {2,}'), ' ');
    s = s.trim();

    // Optional capitalization
    s = s.replaceAllMapped(RegExp(r'(^|[.!?\n]\s+)([a-z])'), (m) => '${m[1]}${m[2]!.toUpperCase()}');

    return s;
  }

  void _renderTextField() {
    final committed = _committedText.trimRight();
    final interim   = _interimText.trimLeft();
    final shown     = (interim.isEmpty ? committed : '$committed $interim'.trim());

    // Mark only the interim as "composing" so platforms visually hint it's provisional.
    final start = committed.length + (committed.isEmpty || interim.isEmpty ? 0 : 1);
    final end   = shown.length;

    final value = TextEditingValue(
      text: shown,
      selection: TextSelection.collapsed(offset: shown.length),
      composing: (interim.isEmpty || end <= start)
          ? TextRange.empty
          : TextRange(start: start, end: end),
    );

    if (_controller.value.text != value.text ||
        _controller.value.selection.baseOffset != value.selection.baseOffset) {
      _controller.value = value;
    }
  }


  String? _userName;
  // bool _enableAudio = false;
  // bool _hasPlayedIntroAudio = false;

  bool _loading = false;
  // bool _imageGenerating = false;
  bool _imageGenerating = false;
  String? _message;
  String? _recipeImagePath;
  String? _lastRecipeText;
  int? _lastRecipeId;

  // Structured recipe fields from backend
  int? _recipeId;
  String _title        = '';
  String _description  = '';
  String _categories   = '';
  String _tags         = '';
  String _time         = '';
  String _servings     = '';
  String _ingredients  = '';
  String _instructions = '';
  String _notes        = '';
  String _variations   = '';
  String _difficulty   = '';

  int? _textRemainingWeek; // track # of free recipes left
  bool? _isPro;
  bool _showRecipe = false;
  
  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadDraftText();
    _initSpeechApi();
    // _loadQuota();


    _micAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _micScale = Tween<double>(begin: 1.0, end: 1.25)
        .chain(CurveTween(curve: Curves.easeInOutCubic))
        .animate(_micAnim);
    _micOpacity = Tween<double>(begin: 0.5, end: 1.0)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_micAnim);

    _controller.addListener(() {
      if (_controller.text.trim().isNotEmpty) {
        _saveDraft(_controller.text);
      }
    });

    widget.refreshTrigger.addListener(_refreshFromTrigger);
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh quota data when screen becomes visible again
    // _loadQuota();
    debugPrint('DashboardScreen: refreshing subscription data in didChangeDependencies');
  }

  @override
  void dispose() {
    _player.dispose();
    _audioRecorder?.closeRecorder();
    _googleAudioCtl?.close();
    _micCtl?.close();
    widget.refreshTrigger.removeListener(_refreshFromTrigger);
    _stopRecording();
    _micAnim.dispose();
    super.dispose();
  }

  // Load user's subscription quota
//   Future<void> _loadQuota() async {
//   try {
//     final status = await ApiService.getSubscriptionStatus();
//     if (!mounted) return;
//     setState(() {
//       _isPro = status.isActive;
//       _textRemainingWeek = status.textRemainingWeek;
//     });
//   } catch (_) {
//     // optional: ignore or snackbar
//   }
// }
  
  // Initialize speech recognition with Google Cloud Speech API
  Future<void> _initSpeechApi() async {
    try {
      _audioRecorder = FlutterSoundRecorder();
      await _audioRecorder!.openRecorder();
      // iOS stability tweaks
      try {
        await _audioRecorder!.setSubscriptionDuration(const Duration(milliseconds: 50));
      } catch (_) {}

      final raw = await rootBundle.loadString('assets/gcloud-key.json');
      final sa  = ServiceAccount.fromString(raw);
      _speech   = SpeechToText.viaServiceAccount(sa);

      debugPrint('STT init ok');
    } catch (e) {
      debugPrint('STT init failed: $e');
      _showErrorSnackBar('Failed to initialize speech recognition');
    }
  }

  
  // Stop recording and clean up
  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    try {
      debugPrint('stopping recorder…');
      if (_audioRecorder?.isRecording == true) {
        await _audioRecorder!.stopRecorder();
      }
      debugPrint('recorder stopped');

      await _recognitionSub?.cancel();
      _recognitionSub = null;

      if (_googleAudioCtl != null && !_googleAudioCtl!.isClosed) {
        await _googleAudioCtl!.close();
      }
      if (_micCtl != null && !_micCtl!.isClosed) {
        await _micCtl!.close();
      }
      _googleAudioCtl = null;
      _micCtl = null;
    } catch (e, st) {
      debugPrint('stop error: $e\n$st');
    } finally {
      if (mounted) setState(() => _isRecording = false);
      _silenceTimer?.cancel();
      _silenceTimer = null;
      _micAnim.stop();
      _micAnim.value = 0.0;
    }
  }
  
  // Request microphone permission
  Future<bool> _requestMicPermission() async {
    var status = await Permission.microphone.status;
    
    if (status.isDenied) {
      status = await Permission.microphone.request();
    }
    
    if (status.isPermanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Microphone permission is required for voice recording. Please enable it in app settings."),
          duration: Duration(seconds: 4),
        ),
      );
      return false;
    }
    
    return status.isGranted;
  }

  void _refreshFromTrigger() async {
    // clear old results
    setState(() {
      _message = null;
      // _recipeImagePath = null;
    });

    _loadUserName();
    final prefs = await SharedPreferences.getInstance();
    final savedText = prefs.getString('draft_text');
    if (savedText != null && savedText.isNotEmpty) {
      setState(() {
        _controller.text = savedText;
      });
    }
  }

  // Future<void> _playIntroAudioOnce() async {
  //   if (_hasPlayedIntroAudio || !_enableAudio) return;
  //   _hasPlayedIntroAudio = true;
  //   try {
  //     await _player.setAsset('assets/sound/tell_me_about.mp3');
  //     await _player.play();
  //   } catch (_) {}
  // }

  Future<void> _loadUserName() async {
    try {
      final authData = await ApiService.checkAuth();
      if (authData['authenticated'] == true) {
        setState(() {
          _userName = authData['first_name'];
          // _enableAudio = authData['enable_audio'] == true || authData['enable_audio'] == '1';
        });
        // _playIntroAudioOnce();
      }
    } catch (_) {}
  }

  Future<void> _loadDraftText() async {
    final prefs = await SharedPreferences.getInstance();
    final savedText = prefs.getString('draft_text');
    if (savedText != null && savedText.isNotEmpty) {
      _controller.text = savedText;
    }
  }

  Future<void> _saveDraft(String text) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      await prefs.remove('draft_text');
    } else {
      await prefs.setString('draft_text', trimmed);
    }
  }

  Future<void> _submitRecipe() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // Hard-stop any active recording before we do anything else
    await _stopRecording();

    setState(() {
      _loading = true;
      _message = null;
      _lastRecipeText = text;
    });

    widget.onAnalyzingChange?.call(true);

    try {
      // Fire the request and get the response
      final recipeData = await ApiService.submitRecipe(text);

      // Set the recipe fields
      setState(() {
        _recipeId = int.tryParse(recipeData['recipe_id'] ?? '');
        _title = recipeData['title'] ?? '';
        _description = recipeData['description'] ?? '';
        _categories = recipeData['categories'] ?? '';
        _tags = recipeData['tags'] ?? '';
        _time = recipeData['time'] ?? '';
        _servings = recipeData['servings'] ?? '';
        _ingredients = recipeData['ingredients'] ?? '';
        _instructions = recipeData['instructions'] ?? '';
        _notes = recipeData['notes'] ?? '';
        _variations = recipeData['variations'] ?? '';
        _difficulty = recipeData['difficulty'] ?? '';
        _showRecipe = true;
      });

      // Generate image if recipe ID is available
      if (_recipeId != null) {
        setState(() => _imageGenerating = true);
        _generateRecipeImage(_recipeId!);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('draft_text');
      // _loadQuota(); // refresh quota after submission
      _controller.clear();

      // Do not navigate, stay on dashboard to show the recipe
    } catch (e) {
      setState(() {
        _message = "Recipe submission failed.";
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      widget.onAnalyzingChange?.call(false);
    }
  }



  Future<void> _generateRecipeImage(int recipeId) async {
    try {
      final imagePath = await ApiService.generateRecipeImage(recipeId);
      setState(() {
        _recipeImagePath = imagePath;
        _imageGenerating = false;
      });
    } catch (_) {
      setState(() => _imageGenerating = false);
    }
  }
  
  // Show error snackbar - only for critical errors
  void _showErrorSnackBar(String message) {
    if (mounted) {
      // Only show errors that would prevent recording
      if (message.contains('initialize') || message.contains('permission')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red.shade700,
          ),
        );
      } else {
        // Just log other errors without showing popup
        debugPrint('Speech error (no popup): $message');
      }
    }
  }

  // Start voice recording and transcription
  Future<void> _startVoiceRecording() async {
    // toggle
    if (_isRecording) {
      await _stopRecording();
      return;
    }

    // mic permission once
    final granted = await _requestMicPermission();
    if (!granted) return;

    // client ready
    if (_audioRecorder == null) await _initSpeechApi();

    // stop any audio that may hold session
    try { await _player.stop(); } catch (_) {}

    // state
    _committedText = _controller.text;
    _interimText = '';
    _micAnim.repeat(reverse: true);
    setState(() => _isRecording = true);

    // controllers
    _googleAudioCtl?.close();
    _micCtl?.close();
    _googleAudioCtl = StreamController<List<int>>();
    _micCtl = StreamController<Uint8List>.broadcast();

    // bridge mic → chunk → Google
    _micCtl!.stream.listen((Uint8List data) {
      if (data.isEmpty) return;

      // --- VAD: compute RMS on 16-bit little-endian PCM
      final rms = _rmsInt16Le(data);
      if (_vadCalibrating) {
        // ≈ first 1s: learn noise floor using your 50ms subscription duration
        _vadCalibFrames++;
        _noiseFloor += rms;
        if (_vadCalibFrames >= 20) {
          _noiseFloor /= _vadCalibFrames;
          _vadCalibrating = false;
          debugPrint('VAD noiseFloor=${_noiseFloor.toStringAsFixed(1)}');
        }
      } else {
        // Dynamic threshold a bit above ambient
        final threshold = (_noiseFloor * 2.5).clamp(150.0, 800.0);
        if (rms > threshold) _lastHeard = DateTime.now();
      }

      // --- Forward to Google in ≤24 KB chunks
      const max = 24 * 1024;
      for (var i = 0; i < data.length; i += max) {
        final end = (i + max > data.length) ? data.length : i + max;
        _googleAudioCtl?.add(data.sublist(i, end));
      }
    }, onError: (e) {
      debugPrint('mic stream error: $e');
    });


    // recognition config
    final cfg = RecognitionConfig(
      encoding: AudioEncoding.LINEAR16,
      sampleRateHertz: 16000,
      audioChannelCount: 1,
      languageCode: 'en-US',
      // enableAutomaticPunctuation: true,
      enableAutomaticPunctuation: false,
      maxAlternatives: 1,
      model: RecognitionModel.basic,
      speechContexts: [
        SpeechContext([
          'period', 'full stop', 'comma', 'question mark',
          'exclamation point', 'exclamation mark',
          'semicolon', 'colon',
          'dash', 'hyphen', 'ellipsis', 'dot dot dot',
          'quote', 'open quote', 'close quote',
          'new line', 'new paragraph',
        ]),
      ],
    );

    // streaming config
    final scfg = StreamingRecognitionConfig(
      config: cfg,
      interimResults: true,
      singleUtterance: false,
    );

    // start Google stream
    debugPrint('creating google stream…');
    final responses = _speech.streamingRecognize(scfg, _googleAudioCtl!.stream);
    _recognitionSub = responses.listen((resp) {
      for (final r in resp.results) {
        if (r.alternatives.isEmpty) continue;
        var t = r.alternatives.first.transcript;
        if (t.isEmpty) continue;

        if (r.isFinal) {
          // Map punctuation ONLY on finals
          t = _applySpokenPunctuation(t);

          _committedText = _committedText.isEmpty ? t : '$_committedText $t';
          _interimText = '';
          _renderTextField();
        } else {
          // Interim: debounce + optional stability filter to reduce churn
          final now = DateTime.now();
          final debounceOk = now.difference(_lastInterimAt).inMilliseconds >= 120;
          final stabilityOk = (r.stability >= 0.7); // if field present; otherwise ignore
          if (debounceOk && stabilityOk) {
            _interimText = t;
            _lastInterimAt = now;
            _renderTextField();
          }
        }
      }
    }, onError: (e, st) {
      _interimText = '';
      _renderTextField();
      _showErrorSnackBar('Speech recognition error');
      _stopRecording();
    });

    // start mic AFTER stream exists
    await _audioRecorder!.startRecorder(
      codec: Codec.pcm16,
      sampleRate: 16000,
      numChannels: 1,
      toStream: _micCtl!.sink, // required StreamSink<Uint8List>
    );
    debugPrint('recorder started: ${_audioRecorder!.isRecording}');

    // --- Reset silence/VAD state
    _lastHeard = DateTime.now();
    _vadCalibrating = true;
    _vadCalibFrames = 0;
    _noiseFloor = 0.0;

    // --- Kick off periodic silence check
    _silenceTimer?.cancel();
    _silenceTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      if (!_isRecording) return;
      final idle = DateTime.now().difference(_lastHeard) > _silenceTimeout;
      if (idle) {
        debugPrint('auto-stop: silence > ${_silenceTimeout.inSeconds}s');
        await _stopRecording();
      }
    });
  }


// sharing
// Anchor key for share button
  final GlobalKey _shareAnchorKey = GlobalKey();

// Get origin Rect from GlobalKey
  Rect _originFromKey(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return const Rect.fromLTWH(100, 100, 1, 1); // safe fallback
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || box.size.isEmpty) {
      return const Rect.fromLTWH(100, 100, 1, 1);
    }
    final topLeft = box.localToGlobal(Offset.zero);
    return topLeft & box.size;
  }

// Build shareable text content
  String _buildShareText() {
    final parts = <String>[];
    
    if (_title.isNotEmpty) parts.add(_title);
    if (_description.isNotEmpty) parts.add(_description);
    
    final details = <String>[];
    if (_time.isNotEmpty) details.add('Time: $_time');
    if (_servings.isNotEmpty) details.add('Servings: $_servings');
    if (_difficulty.isNotEmpty) details.add('Difficulty: $_difficulty');
    if (details.isNotEmpty) parts.add(details.join(' | '));
    
    if (_ingredients.isNotEmpty) parts.add('Ingredients:\n$_ingredients');
    if (_instructions.isNotEmpty) parts.add('Instructions:\n$_instructions');
    if (_notes.isNotEmpty) parts.add('Notes:\n$_notes');
    if (_variations.isNotEmpty) parts.add('Variations:\n$_variations');
    
    return parts.join('\n\n');
  }

// Resolve image file for sharing
  Future<File?> _resolveImageFileForShare() async {
    if (_recipeImagePath == null || _recipeImagePath!.isEmpty) return null;
    final id = _lastRecipeId;
    if (id == null) return null;

    // Local-first; download once if missing
    final hit = await ImageStore.localIfExists(id, RecipeImageKind.file, _recipeImagePath!);
    if (hit != null) return hit;
    try {
      return await ImageStore.download(id, RecipeImageKind.file, _recipeImagePath!, dio: DioClient.dio);
    } catch (_) {
      return null;
    }
  }

// Share recipe text
  Future<void> _shareRecipe() async {
    final shareText = _buildShareText();
    if (shareText.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to share yet')),
      );
      return;
    }

    await SharePlus.instance.share(ShareParams(text: shareText));
  }

  // Print recipe as PDF
  Future<void> _printRecipe() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Title
              if (_title.isNotEmpty)
                pw.Text(
                  _title,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              
              pw.SizedBox(height: 16),
              
              // Description
              if (_description.isNotEmpty)
                pw.Text(
                  _description,
                  style: const pw.TextStyle(fontSize: 14),
                ),
              
              pw.SizedBox(height: 16),
              
              // Details row
              pw.Row(
                children: [
                  if (_time.isNotEmpty)
                    pw.Expanded(
                      child: pw.Text('Time: $_time', style: const pw.TextStyle(fontSize: 12)),
                    ),
                  if (_servings.isNotEmpty)
                    pw.Expanded(
                      child: pw.Text('Servings: $_servings', style: const pw.TextStyle(fontSize: 12)),
                    ),
                  if (_difficulty.isNotEmpty)
                    pw.Expanded(
                      child: pw.Text('Difficulty: $_difficulty', style: const pw.TextStyle(fontSize: 12)),
                    ),
                ],
              ),
              
              pw.SizedBox(height: 16),
              
              // Ingredients
              if (_ingredients.isNotEmpty) ...[
                pw.Text(
                  'Ingredients',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  _ingredients,
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 16),
              ],
              
              // Instructions
              if (_instructions.isNotEmpty) ...[
                pw.Text(
                  'Instructions',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  _instructions,
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 16),
              ],
              
              // Notes
              if (_notes.isNotEmpty) ...[
                pw.Text(
                  'Notes',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  _notes,
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 16),
              ],
              
              // Variations
              if (_variations.isNotEmpty) ...[
                pw.Text(
                  'Variations',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  _variations,
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ],
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }


  
  @override
  Widget build(BuildContext context) {
    // final bool canAnalyze = !(_loading || _imageGenerating) &&
    //     (
    //       _isPro == null
    //         ? true                                  // while unknown, don't block the user
    //         : (_isPro! || ((_textRemainingWeek ?? 0) > 0))
    //     );
    final bool isOutOfCredits = (_isPro == false) && ((_textRemainingWeek ?? 0) <= 0);
    final bool canAnalyze = !(_loading) && !isOutOfCredits;

    return SafeArea(
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 👋 Greeting
                Text(
                  "Hello, ${_userName ?? ""}",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),

                // 📜 Intro - Show different text for users out of credits
                Text(
                  isOutOfCredits
                    ? "You've reached your free recipe credits for this week. 🌙 "
                      "New credits arrive every Sunday, but why wait? "
                      "Upgrade to Chef Pro for unlimited recipe analysis, high-resolution recipe images, "
                      "and the ability to share your recipes and images with others. "
                      "Unlock the full recipe experience ✨"
                    : "Tell me what you'd like to make! "
                      "I will magically turn your ideas into a delicious recipe complete with ingredients, "
                      "instructions, and a beautiful image. \n",
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                ),
                const SizedBox(height: 16),

                // ✏️ Recipe entry (locked while analyzing)
                TextField(
                  enabled: !_loading, // ✅ disable typing while analyzing
                  controller: _controller,
                  keyboardType: TextInputType.multiline,
                  minLines: 9,
                  maxLines: null,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                  ),
                  decoration: const InputDecoration(
                    hintText: "Describe your dish here...",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 16),

                // Button row with mic and analyze
                Row(
                  children: [
                    // Analyze button
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          // backgroundColor: AppColors.purple600,
                          backgroundColor: isOutOfCredits ? Colors.orange.shade700 : AppColors.purple600,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.purple600.withValues(alpha: 0.5),
                          disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          overlayColor: Colors.white.withValues(alpha: 0.1),
                        ),
                        // onPressed: (_loading || _imageGenerating) ? null : _submitRecipe,
                        onPressed: (_loading || _imageGenerating)
                          ? null
                          : (canAnalyze
                              ? _submitRecipe
                              : () => Navigator.pushNamed(context, '/subscription')),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_loading || _imageGenerating)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            if (_loading || _imageGenerating)
                              const SizedBox(width: 8),
                            Text(
                              _loading
                                    ? "Magic things happening..."
                                    : _imageGenerating ? "Generating image..." : canAnalyze ? "Build My Recipe" : "Upgrade to Pro",
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // 🖼️ Results
                if (_message != null)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MarkdownBody(
                          data: _message!,
                          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                            p: const TextStyle(color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Recipe Display
                if (_showRecipe) _buildRecipeDisplay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecipeDisplay() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.purple950,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.purple600, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with close and share buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Your Recipe',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.white),
                    onPressed: _shareRecipe,
                  ),
                  IconButton(
                    icon: const Icon(Icons.print, color: Colors.white),
                    onPressed: _printRecipe,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        _showRecipe = false;
                        _controller.clear();
                        // Reset fields if needed
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Title
          if (_title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),

          // Description
          if (_description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _description,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
            ),

          // Time and Servings
          Row(
            children: [
              if (_time.isNotEmpty)
                Expanded(
                  child: Text(
                    'Time: $_time',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              if (_servings.isNotEmpty)
                Expanded(
                  child: Text(
                    'Servings: $_servings',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          if (_time.isNotEmpty || _servings.isNotEmpty) const SizedBox(height: 8),

          // Difficulty
          if (_difficulty.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Difficulty: $_difficulty',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),

          // Ingredients
          if (_ingredients.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ingredients:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  MarkdownBody(
                    data: _ingredients,
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                      p: const TextStyle(color: Colors.white, fontSize: 14),
                      listBullet: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

          // Instructions
          if (_instructions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Instructions:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  MarkdownBody(
                    data: _instructions,
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                      p: const TextStyle(color: Colors.white, fontSize: 14),
                      listBullet: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

          // Notes
          if (_notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Notes:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _notes,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

          // Variations
          if (_variations.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Variations:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _variations,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

          // Image if available
          if (_recipeImagePath != null && _recipeImagePath!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  _recipeImagePath!,
                  fit: BoxFit.cover,
                  height: 200,
                  width: double.infinity,
                ),
              ),
            )
          else if (_imageGenerating)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 8),
                      Text(
                        'Generating image...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}