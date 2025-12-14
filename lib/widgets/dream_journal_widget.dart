// widgets/dream_journal_widget.dart
import 'dart:io';
import 'package:chef/models/dream.dart';
import 'package:chef/services/api_service.dart';
import 'package:chef/services/dio_client.dart';
import 'package:chef/services/image_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:chef/theme/colors.dart';



class RecipeJournalWidget extends StatefulWidget { 
  final VoidCallback? onRecipesLoaded;
  final List<Recipe>? filteredRecipes;
  final bool autoExpandSingle;
  final bool embeddedInScrollView;

  const RecipeJournalWidget({
    super.key,
    this.onRecipesLoaded,
    this.filteredRecipes,
    this.autoExpandSingle = false,
    this.embeddedInScrollView = true,
  });

  @override
  State<RecipeJournalWidget> createState() => RecipeJournalWidgetState();
}

class ToneStyle {
  final Color background;
  final Color text;
  const ToneStyle(this.background, this.text);
}

class NotesSheet extends StatefulWidget {
  final int recipeId;
  const NotesSheet({super.key, required this.recipeId});

  @override
  State<NotesSheet> createState() => _NotesSheetState();
}

class _NotesSheetState extends State<NotesSheet> {
  final _controller = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _lastSeenIso;
  String? _error;
  Map<String, dynamic>? _serverCopy;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.getRecipeNotes(widget.recipeId);
      if (!mounted) return;
      _controller.text = (data['notes'] as String?) ?? '';
      _lastSeenIso = data['notes_updated_at'] as String?;
    } catch (_) {
      if (!mounted) return;
      _error = 'Failed to load notes';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save({bool overwrite = false}) async {
    setState(() { _saving = true; _error = null; _serverCopy = null; });
    try {
      final res = await ApiService.saveRecipeNotes(
        recipeId: widget.recipeId,
        notes: _controller.text,
        lastSeen: overwrite ? null : _lastSeenIso,
      );
      if (!mounted) return;
      _lastSeenIso = res['notes_updated_at'] as String?;
      Navigator.of(context).pop(true); // close sheet
      return;
    } on NotesTooLarge {
      if (mounted) setState(() => _error = 'Keep it under 8000 characters.');
    } on NotesConflict catch (c) {
      if (!mounted) return;
      _serverCopy = c.current;
      setState(() {}); // show conflict UI

      final action = await showDialog<String>(
        context: context,
        builder: (dctx) => AlertDialog(
          title: const Text('Notes changed elsewhere'),
          content: const Text('Load the latest from server or overwrite yours?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dctx, 'load'), child: const Text('Load theirs')),
            TextButton(onPressed: () => Navigator.pop(dctx, 'overwrite'), child: const Text('Overwrite')),
            TextButton(onPressed: () => Navigator.pop(dctx, 'cancel'), child: const Text('Cancel')),
          ],
        ),
      );
      if (!mounted) return;

      if (action == 'load' && _serverCopy != null) {
        _controller.text = (_serverCopy!['notes'] as String?) ?? '';
        _lastSeenIso = _serverCopy!['notes_updated_at'] as String?;
        setState(() => _serverCopy = null);
      } else if (action == 'overwrite') {
        await _save(overwrite: true); // will pop
        return;
      }
    } on NotesHttp {
      if (mounted) setState(() => _error = 'Save failed');
    }
    if (mounted) setState(() => _saving = false); // only if we didn’t pop
  }

  Future<void> _clear() async {
    setState(() { _saving = true; _error = null; _serverCopy = null; });
    try {
      final res = await ApiService.saveRecipeNotes(
        recipeId: widget.recipeId,
        notes: null,
        lastSeen: _lastSeenIso,
      );
      if (!mounted) return;
      _lastSeenIso = res['notes_updated_at'] as String?;
      _controller.clear();
      Navigator.of(context).pop(true);
      return;
    } on NotesConflict catch (c) {
      if (!mounted) return;
      _serverCopy = c.current;
      setState(() {});
      final action = await showDialog<String>(
        context: context,
        builder: (dctx) => AlertDialog(
          title: const Text('Notes changed elsewhere'),
          content: const Text('Load latest or overwrite with clear?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dctx, 'load'), child: const Text('Load theirs')),
            TextButton(onPressed: () => Navigator.pop(dctx, 'overwrite'), child: const Text('Overwrite')),
            TextButton(onPressed: () => Navigator.pop(dctx, 'cancel'), child: const Text('Cancel')),
          ],
        ),
      );
      if (!mounted) return;

      if (action == 'load' && _serverCopy != null) {
        _controller.text = (_serverCopy!['notes'] as String?) ?? '';
        _lastSeenIso = _serverCopy!['notes_updated_at'] as String?;
        setState(() => _serverCopy = null);
      } else if (action == 'overwrite') {
        await ApiService.saveRecipeNotes(recipeId: widget.recipeId, notes: null, lastSeen: null);
        if (mounted) Navigator.of(context).pop(true);
        return;
      }
    } on NotesHttp {
      if (mounted) setState(() => _error = 'Failed to clear');
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Expanded(child: Text('Notes (private)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.white))),
              if (_saving) const SizedBox(height: 16, width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ]),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              TextField(
                controller: _controller,
                maxLines: null,
                maxLength: 8000,
                decoration: const InputDecoration(
                  hintText: 'Jot down anything about this recipe…',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(),
                  filled: true,
                ),
                style: const TextStyle(color: Colors.black),
                enabled: !_saving,
              ),
              const SizedBox(height: 8),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                ),
              Row(children: [
                ElevatedButton(onPressed: _saving ? null : () => _save(overwrite: false), child: const Text('Save')),
                const SizedBox(width: 8),
                TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                const Spacer(),
                TextButton(onPressed: _saving ? null : _clear, child: const Text('Clear')),
              ]),
              if (_lastSeenIso != null) ...[
                const SizedBox(height: 6),
                Text('Last edited: $_lastSeenIso',
                    style: const TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ],
          ],
        ),
      ),
    );
  }
}


class RecipeJournalWidgetState extends State<RecipeJournalWidget> {
  
  List<Recipe> _recipes = [];
  // Return filtered recipes if available, otherwise return all recipes
  List<Recipe> getRecipes() => widget.filteredRecipes ?? _recipes;

  final Map<int, bool> _expanded = {};
  bool _loading = true;
  bool get _anyExpanded => _expanded.values.any((v) => v);

  @override
  void initState() {
    super.initState();
    if (widget.filteredRecipes != null) {
      _loading = false;
      widget.onRecipesLoaded?.call();
    } else {
      _loadRecipes();
    }
  }

  
  ToneStyle _getToneStyle(String tone) {
    final t = tone.toLowerCase().trim();
    switch (t) {
      case 'peaceful / gentle':
        return ToneStyle(Colors.blue.shade100, Colors.black87);
      case 'epic / heroic':
        return ToneStyle(Colors.orange.shade100, Colors.black87);
      case 'whimsical / surreal':
        return ToneStyle(Colors.purple.shade100, Colors.black87);
      case 'nightmarish / dark':
        // return ToneStyle(Colors.black, Colors.red.shade500);  // 👈 spooky red
        return ToneStyle(const Color.fromARGB(255, 26, 25, 25), const Color.fromARGB(255, 255, 167, 43));  // 👈 spooky orange
        // return ToneStyle(Colors.grey.shade900, const Color.fromARGB(255, 81, 255, 241));  // 👈 glowing blue
      case 'romantic / nostalgic':
        return ToneStyle(Colors.pink.shade100, Colors.black87);
      case 'ancient / mythic':
        return ToneStyle(Colors.brown.shade100, Colors.black87);
      case 'futuristic / uncanny':
        return ToneStyle(Colors.teal.shade100, Colors.black87);
      case 'elegant / ornate':
        return ToneStyle(Colors.indigo.shade100, Colors.black87);
      default:
        return ToneStyle(Colors.grey.shade100, Colors.black87);
    }
  }

  // Tone symbol helper 
  String toneSymbol(String tone) {
    final t = tone.toLowerCase();
    if (t.contains('peaceful')) return '☁️';             // soft cloud
    if (t.contains('epic')) return '⚔️';                 // sword/courage
    if (t.contains('whimsical')) return '✨';            // stars
    if (t.contains('nightmarish')) return '🕷️';          // spider
    if (t.contains('romantic')) return '🩷';             // flowers
    if (t.contains('ancient')) return '⚱️';              // urn / ancient relic
    if (t.contains('futuristic')) return '🔮';           // crystal ball
    // if (t.contains('elegant')) return '༻❁༺';           // ornate flower
    if (t.contains('elegant')) return '••࿐••';           // ornate flower
    return '✨';                                         // default separator
  }

// Compute origin rect for share sheets (iPad/macOS need an anchor).
  Rect _shareOrigin() {
    final size = MediaQuery.of(context).size;

    // Tiny 1×1 rect centered on screen – always valid:
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: 1,
      height: 1,
    );
  }

  String combinedRecipeText(Recipe d) {
    final parts = <String>[];
    
    if (d.title.isNotEmpty) parts.add(d.title);
    if (d.description.isNotEmpty) parts.add(d.description);
    
    final details = <String>[];
    if (d.time.isNotEmpty) details.add('Time: ${d.time}');
    if (d.servings.isNotEmpty) details.add('Servings: ${d.servings}');
    if (d.difficulty.isNotEmpty) details.add('Difficulty: ${d.difficulty}');
    if (details.isNotEmpty) parts.add(details.join(' | '));
    
    if (d.ingredients.isNotEmpty) parts.add('Ingredients:\n${d.ingredients}');
    if (d.instructions.isNotEmpty) parts.add('Instructions:\n${d.instructions}');
    if (d.notes.isNotEmpty) parts.add('Notes:\n${d.notes}');
    if (d.variations.isNotEmpty) parts.add('Variations:\n${d.variations}');
    
    return parts.join('\n\n');
  }


// Share recipe with image and text
  Future<void> _shareRecipe(Recipe d) async {
    final shareText = combinedRecipeText(d);
    if (shareText.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to share yet')),
      );
      return;
    }

    final origin = _shareOrigin();
    await SharePlus.instance.share(
      ShareParams(
        text: shareText,
        sharePositionOrigin: origin,
      ),
    );
  }

  // Print recipe as PDF
  Future<void> _printRecipe(Recipe d) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Title
              if (d.title.isNotEmpty)
                pw.Text(
                  d.title,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              
              pw.SizedBox(height: 16),
              
              // Description
              if (d.description.isNotEmpty)
                pw.Text(
                  d.description,
                  style: const pw.TextStyle(fontSize: 14),
                ),
              
              pw.SizedBox(height: 16),
              
              // Details row
              pw.Row(
                children: [
                  // if (d.difficulty.isNotEmpty)
                    pw.Expanded(
                      child: pw.Text('Difficulty: ${d.difficulty}', style: const pw.TextStyle(fontSize: 12)),
                    ),
                  if (d.servings.isNotEmpty)
                    pw.Expanded(
                      child: pw.Text('Servings: ${d.servings}', style: const pw.TextStyle(fontSize: 12)),
                    ),
                  if (d.time.isNotEmpty)
                    pw.Expanded(
                      child: pw.Text('Time: ${d.time}', style: const pw.TextStyle(fontSize: 12)),
                    ),
                ],
              ),
              
              pw.SizedBox(height: 16),
              
              // Ingredients
              if (d.ingredients.isNotEmpty) ...[
                pw.Text(
                  'Ingredients',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  d.ingredients,
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 16),
              ],
              
              // Instructions
              if (d.instructions.isNotEmpty) ...[
                pw.Text(
                  'Instructions',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  d.instructions,
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 16),
              ],
              
              // Variations
              if (d.variations.isNotEmpty) ...[
                pw.Text(
                  'Variations',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  d.variations,
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ],

              // Notes
              if (d.notes.isNotEmpty) ...[
                pw.Text(
                  'Notes',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  d.notes,
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 16),
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

    // Share just the recipe image

  
// Load recipes from API
  Future<void> _loadRecipes() async {
    try {
      final recipes = await ApiService.fetchRecipes();
      setState(() {
        _recipes = recipes;
        _loading = false;
      });
      widget.onRecipesLoaded?.call();
    } catch (e) {
      // print("❌ Failed to fetch recipes: $e");
      setState(() {
        _loading = false;
      });
    }
  }

  void refresh() {
    setState(() => _loading = true);
    _loadRecipes();
  }

  Future<void> _openNotesEditor(int recipeId) async {
    final changed = await showModalBottomSheet<bool>(
    // await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black87,
      builder: (_) => NotesSheet(recipeId: recipeId),
    );

    if (changed == true && mounted) {
      // Pull latest notes from server and update just this recipe
      final data  = await ApiService.getRecipeNotes(recipeId);
      final notes = (data['notes'] as String?)?.trim() ?? "";

      setState(() {
        final i = _recipes.indexWhere((d) => d.id == recipeId);
        if (i != -1) {
          _recipes[i] = _recipes[i].copyWith(notes: notes);
        }
      });
    }
  }

    // Drop-in helper with fallback
    Widget netImageWithFallback(
    String? url, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? radius,
  }) {
    final widget = (url == null || url.isEmpty)
        ? Image.asset('assets/images/missing.png', width: width, height: height, fit: fit)
        : Image.network(
            url,
            width: width,
            height: height,
            fit: fit,
            // Show placeholder while loading
            loadingBuilder: (ctx, child, prog) =>
                prog == null ? child : Image.asset('assets/images/missing.png', width: width, height: height, fit: fit),
            // Show placeholder on 404/any error
            errorBuilder: (ctx, err, stack) =>
                Image.asset('assets/images/missing.png', width: width, height: height, fit: fit),
          );

    if (radius != null) {
      return ClipRRect(borderRadius: radius, child: widget);
    }
    return widget;
  }

  // Local-first image with same ergonomics as netImageWithFallback
  Widget localFirstImage({
    required int recipeId,
    required String? url,
    required RecipeImageKind kind, // RecipeImageKind.tile or RecipeImageKind.file
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? radius,
  }) {
    Widget buildPlaceholder() =>
        Image.asset('assets/images/missing.png', width: width, height: height, fit: fit);

    return FutureBuilder<File?>(
      future: () async {
        if (url == null || url.isEmpty) return null;

        // 1) Try local
        final hit = await ImageStore.localIfExists(recipeId, kind, url);
        if (hit != null) return hit;

        // 2) Download once, then it lives on disk
        try {
          final f = await ImageStore.download(recipeId, kind, url, dio: DioClient.dio);
          return f;
        } catch (_) {
          return null;
        }
      }(),
      builder: (ctx, snap) {
        final file = snap.data;
        final w = (file != null)
            ? Image.file(file, width: width, height: height, fit: fit)
            : buildPlaceholder();

        if (radius != null) {
          return ClipRRect(borderRadius: radius, child: w);
        }
        return w;
      },
    );
  }

  String _sanitizeAnalysis(String raw) {
    return raw.replaceAll(RegExp(r'\n[-*_]{3,}\s*$'), '');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final recipesToDisplay = getRecipes();

    // If this widget is being used to show a single recipe (e.g. in a detail page),
    // optionally auto-expand that recipe so the full content is visible by default.
    if (widget.autoExpandSingle &&
        recipesToDisplay.length == 1 &&
        !(_expanded[recipesToDisplay.first.id] ?? false)) {
      _expanded[recipesToDisplay.first.id] = true;
    }

    if (recipesToDisplay.isEmpty) {
      return const Text("Your Recipes will appear here...");
    }

    final bool interceptBack = widget.embeddedInScrollView;

    return PopScope<Object?>(
      // In the journal screen we intercept back when a card is expanded;
      // in standalone views we let the route pop normally.
      canPop: !interceptBack || !_anyExpanded,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!interceptBack) return;
        // If the route actually popped, do nothing.
        if (didPop) return;

        // We intercepted back: collapse expanded cards instead of leaving.
        if (_anyExpanded) {
          setState(() {
            _expanded.updateAll((key, value) => false);
          });
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),              //  side gap (width)
        child: ListView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: widget.embeddedInScrollView,
          physics: widget.embeddedInScrollView
              ? const NeverScrollableScrollPhysics()
              : const AlwaysScrollableScrollPhysics(),
          itemCount: recipesToDisplay.length,
          itemBuilder: (context, index) {
            final recipe = recipesToDisplay[index];
            final isExpanded = _expanded[recipe.id] ?? false;
            final toneStyle = _getToneStyle(recipe.categories);
            final formattedDate = DateFormat('EEE, MMM d, y h:mm a')
                .format(recipe.createdAt.toLocal());

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),         // space between cards
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.zero,                               // no global padding
                decoration: BoxDecoration(
                  color: toneStyle.background,
                  borderRadius: BorderRadius.circular(6),               // BORDER settings
                  border: Border.all(
                    // color: toneStyle.text.withValues(alpha: 1),
                    color: Color.fromARGB(255, 81, 255, 241).withValues(alpha: 1),
                    width: .5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromARGB(200, 114, 210, 255),
                      blurRadius: 7,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // COLLAPSED ROW (image + title line)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _expanded[recipe.id] = !isExpanded;
                        });
                      },
                      child: widget.embeddedInScrollView
                          // Main journal view: show tile image + text like before
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Always render the tile using localFirstImage;
                                // it will show missing.png when imageTile is
                                // NULL/empty, or the real tile when present.
                                ClipRRect(
                                  // image hugs the card’s left/top/bottom
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(6),
                                    bottomLeft: Radius.circular(6),
                                    topRight: Radius.circular(6),
                                    bottomRight: Radius.circular(6),
                                  ),
                                  child: localFirstImage(
                                    recipeId: recipe.id,
                                    url: recipe.imageFile,
                                    kind: RecipeImageKind.tile,
                                    width: 52,                                  // ICON size
                                    height: 52,
                                    fit: BoxFit.cover,
                                    radius: BorderRadius.zero,
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    // padding only around text, not image
                                    padding: const EdgeInsets.all(6),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Text(
                                        //   recipe.title,
                                        //   style: TextStyle(
                                        //     fontSize: 12,
                                        //     color: toneStyle.text,
                                        //   ),
                                        // ),
                                        Text(
                                          recipe.title,
                                          maxLines: 1,
                                          softWrap: false,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: toneStyle.text,
                                          ),
                                        ),
                                         Text(
                                          recipe.categories,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: toneStyle.text,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          // Detail view (My Recipe page): text-only header
                          : Padding(
                              padding: const EdgeInsets.all(6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    formattedDate,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: toneStyle.text,
                                    ),
                                  ),
                                  Text(
                                    recipe.title,
                                    maxLines: 1,
                                    softWrap: false,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: toneStyle.text,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),

                    // EXPANDED CONTENT
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: isExpanded
                          ? Padding(
                              padding: const EdgeInsets.all(6), // expanded area padding
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Divider row with tone symbol
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Divider(
                                          color: toneStyle.text
                                              .withValues(alpha: 0.25),
                                          thickness: 1,
                                          indent: 16,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                        child: Text(
                                          toneSymbol(recipe.categories), // 🕷️, 🌸, ☁️, etc.
                                          style: TextStyle(
                                            fontSize: 20,
                                            color: toneStyle.text
                                                .withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Divider(
                                          color: toneStyle.text
                                              .withValues(alpha: 0.25),
                                          thickness: 1,
                                          endIndent: 16,
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Recipe Text Header
                                  // Row(
                                  //   children: [
                                  //     Text(
                                  //       "My Recipe:",
                                  //       style: TextStyle(
                                  //         fontSize: 14,
                                  //         fontWeight: FontWeight.bold,
                                  //         color: toneStyle.text,
                                  //       ),
                                  //     ),
                                  //     const SizedBox(width: 6),
                                  //     Text(
                                  //       recipe.title,
                                  //       style: TextStyle(
                                  //         fontSize: 10,
                                  //         fontStyle: FontStyle.italic,
                                  //         color: toneStyle.text,
                                  //       ),
                                  //     ),
                                  //   ],
                                  // ),

                                  // Recipe Text
                                  // if (recipe.text.isNotEmpty) ...[
                                  //   const SizedBox(height: 6),
                                  //   SelectableText(
                                  //     recipe.text,
                                  //     style: TextStyle(
                                  //       fontSize: 13,
                                  //       fontStyle: FontStyle.italic,
                                  //       color: toneStyle.text,
                                  //     ),
                                  //   ),
                                  //   const SizedBox(height: 10),
                                  // ],

                                  // Recipe Image (full-size)
                                  if (recipe.imageFile != null &&
                                      recipe.imageFile!.isNotEmpty)
                                    localFirstImage(
                                      recipeId: recipe.id,
                                      url: recipe.imageFile,
                                      kind: RecipeImageKind.file,
                                      fit: BoxFit.cover,
                                      radius: BorderRadius.circular(8),
                                    ),

                                  // // Gradient Divider
                                  // Container(
                                  //   height: 1,
                                  //   margin:
                                  //       const EdgeInsets.symmetric(vertical: 12),
                                  //   decoration: BoxDecoration(
                                  //     gradient: LinearGradient(
                                  //       colors: [
                                  //         Colors.transparent,
                                  //         toneStyle.text
                                  //             .withValues(alpha: 0.7),
                                  //         Colors.transparent,
                                  //       ],
                                  //     ),
                                  //   ),
                                  // ),

                                  // Recipe Analysis
                                  if (recipe.aiResponse.isNotEmpty) ...[
                                    // Text(
                                    //   "Analysis:",
                                    //   style: TextStyle(
                                    //     fontSize: 14,
                                    //     fontWeight: FontWeight.bold,
                                    //     color: toneStyle.text,
                                    //   ),
                                    // ),
                                    const SizedBox(height: 4),
                                    MarkdownBody(
                                      // data: recipe.analysis,
                                      data: _sanitizeAnalysis(recipe.aiResponse),  // remove trailing divider
                                      styleSheet:
                                          MarkdownStyleSheet.fromTheme(
                                                  Theme.of(context))
                                              .copyWith(
                                        p: TextStyle(
                                          color: toneStyle.text,
                                          fontSize: 13,
                                        ),
                                        strong: TextStyle(
                                          color: toneStyle.text,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        em: TextStyle(
                                          color: toneStyle.text,
                                          fontStyle: FontStyle.italic,
                                        ),
                                        h1: TextStyle(
                                          color: toneStyle.text,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        h2: TextStyle(
                                          color: toneStyle.text,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                  ],

                                  // Recipe Notes
                                  if (recipe.notes.isNotEmpty) ...[
                                    Text(
                                      "Personal Notes:",
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: toneStyle.text,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    MarkdownBody(
                                      data: recipe.notes,
                                      styleSheet:
                                          MarkdownStyleSheet.fromTheme(
                                                  Theme.of(context))
                                              .copyWith(
                                        p: TextStyle(
                                          color: toneStyle.text,
                                          fontSize: 12,
                                        ),
                                        strong: TextStyle(
                                          color: toneStyle.text,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        em: TextStyle(
                                          color: toneStyle.text,
                                          fontStyle: FontStyle.italic,
                                        ),
                                        h1: TextStyle(
                                          color: toneStyle.text,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        h2: TextStyle(
                                          color: toneStyle.text,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                  ],

                                  // Notes + Share buttons
                                  Row(
                                    children: [
                                      // Notes button
                                      // ElevatedButton.icon(
                                      //   onPressed: () =>
                                      //       _openNotesEditor(recipe.id),
                                      //   icon: const Icon(Icons.edit_note,
                                      //       size: 16),
                                      //   label: Text(
                                      //     (recipe.notes.trim().isNotEmpty)
                                      //         ? 'Edit notes'
                                      //         : 'Add notes',
                                      //   ),
                                      //   style: ElevatedButton.styleFrom(
                                      //     backgroundColor:
                                      //         const Color.fromARGB(
                                      //             255, 75, 3, 143),
                                      //     foregroundColor: Colors.white,
                                      //     padding: const EdgeInsets.symmetric(
                                      //         horizontal: 10, vertical: 8),
                                      //     minimumSize: const Size(0, 0),
                                      //     tapTargetSize:
                                      //         MaterialTapTargetSize.shrinkWrap,
                                      //     shape: RoundedRectangleBorder(
                                      //       borderRadius:
                                      //           BorderRadius.circular(10),
                                      //     ),
                                      //     textStyle: const TextStyle(
                                      //       fontSize: 13,
                                      //       fontWeight: FontWeight.w600,
                                      //     ),
                                      //     elevation: 0,
                                      //   ),
                                      // ),
                                      // const SizedBox(width: 8),

                                      // Share button
                                      Material(
                                        color: AppColors.purple400,
                                        borderRadius: BorderRadius.circular(10),
                                        elevation: 0,
                                        child: IconButton(
                                          tooltip: 'Share Recipe',
                                          onPressed: () => _shareRecipe(recipe),
                                          icon: const Icon(Icons.share,
                                              size: 18, color: Color.fromARGB(255, 0, 0, 0)),
                                        ),
                                      ),

                                      const SizedBox(width: 8),

                                      // Print button
                                      Material(
                                        color: AppColors.purple400,
                                        borderRadius: BorderRadius.circular(10),
                                        elevation: 0,
                                        child: IconButton(
                                          tooltip: 'Print Recipe',
                                          onPressed: () => _printRecipe(recipe),
                                          icon: const Icon(Icons.print,
                                              size: 18, color: Color.fromARGB(255, 0, 0, 0)),
                                        ),
                                      ),

                                      const Spacer(),
                                      // Caret ^ close icon (only needed in main journal view)
                                      if (widget.embeddedInScrollView)
                                        IconButton(
                                          icon: Icon(
                                            // Icons.keyboard_arrow_up, // or Icons.expand_less
                                            Icons.expand_less,
                                            size: 32,
                                            color: toneStyle.text,
                                          ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () {
                                            setState(() {
                                              _expanded[recipe.id] = false;
                                            });
                                          },
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      )
    );
  }
}
