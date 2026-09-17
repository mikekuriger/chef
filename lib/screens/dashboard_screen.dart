// screens/dashboard_screen.dart
import 'package:flutter/material.dart';
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
import 'package:chef/utils/recipe_pdf.dart';
// import 'package:mime/mime.dart';
import 'dart:io';
import 'dart:async';


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

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _controller = TextEditingController();
  final AudioPlayer _player = AudioPlayer();



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
    // _loadQuota();

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
    widget.refreshTrigger.removeListener(_refreshFromTrigger);
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

  void _refreshFromTrigger() async {
    // Clear old results — mirrors the "X" dismiss button. Without this, a
    // generated recipe stayed visible on this tab forever after navigating
    // away and back, since DashboardScreen's state is kept alive across tab
    // switches (IndexedStack) and nothing else was resetting _showRecipe.
    setState(() {
      _message = null;
      _showRecipe = false;
      _recipeImagePath = null;
      _imageGenerating = false;
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

    setState(() {
      _loading = true;
      _message = null;
      _lastRecipeText = text;
      // Clear any leftover image from a previous recipe so it can't briefly
      // (or, if this new recipe's image generation fails, permanently)
      // show attached to the wrong recipe.
      _recipeImagePath = null;
      _imageGenerating = false;
    });

    widget.onAnalyzingChange?.call(true);

    try {
      // Fire the request and get the response
      final prefsForServings = await SharedPreferences.getInstance();
      final defaultServings = prefsForServings.getInt('default_servings') ?? 2;
      final recipeData = await ApiService.submitRecipe(text, defaultServings: defaultServings);

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

      // Image generation no longer runs synchronously here — it was adding
      // real seconds (and cost) to every recipe creation for something the
      // cookbook doesn't need immediately. Images get backfilled by a
      // separate offline job instead; until then the recipe just shows its
      // placeholder image, same as any other recipe without one.

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
    final pdf = buildRecipePdf(
      title: _title,
      description: _description,
      time: _time,
      servings: _servings,
      difficulty: _difficulty,
      ingredients: _ingredients,
      instructions: _instructions,
      notes: _notes,
      variations: _variations,
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
                      "I will magically turn your ideas into a delicious recipe complete with ingredients & "
                      "instructions. \n",
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
        color: Colors.grey.shade100,
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
                  color: Colors.black87,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.black87),
                    onPressed: _shareRecipe,
                  ),
                  IconButton(
                    icon: const Icon(Icons.print, color: Colors.black87),
                    onPressed: _printRecipe,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black87),
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
                  color: Colors.black87,
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
                  color: Colors.black54,
                ),
              ),
            ),

          // Time and Servings - each its own line (Time can be a long
          // combined "Prep/Cook/Total" string that wraps badly in a Row).
          if (_time.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'Time: $_time',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ),
          if (_servings.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'Servings: $_servings',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ),
          if (_time.isNotEmpty || _servings.isNotEmpty) const SizedBox(height: 4),

          // Difficulty
          if (_difficulty.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Difficulty: $_difficulty',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
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
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  MarkdownBody(
                    data: _ingredients,
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                      p: const TextStyle(color: Colors.black87, fontSize: 14),
                      listBullet: const TextStyle(color: Colors.black87),
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
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  MarkdownBody(
                    data: _instructions,
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                      p: const TextStyle(color: Colors.black87, fontSize: 14),
                      listBullet: const TextStyle(color: Colors.black87),
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
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _notes,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
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
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _variations,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
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