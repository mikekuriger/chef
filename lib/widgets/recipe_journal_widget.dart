// widgets/recipe_journal_widget.dart
import 'dart:io';
import 'package:chef/constants.dart';
import 'package:chef/models/recipe.dart';
import 'package:chef/services/api_service.dart';
import 'package:chef/services/dio_client.dart';
import 'package:chef/services/image_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:chef/utils/recipe_pdf.dart';
import 'package:chef/theme/colors.dart';
import 'package:chef/screens/recipe_detail_screen.dart';



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
  // Ids removed via swipe-to-delete, pending or already confirmed on the
  // server. Filtered out of every source (own list or a parent-supplied
  // filteredRecipes) so the swiped card leaves the tree immediately instead
  // of only doing so once a later full reload happens to catch up - a stale
  // Dismissible still in the tree throws.
  final Set<int> _dismissedRecipeIds = {};
  // Return filtered recipes if available, otherwise return all recipes
  List<Recipe> getRecipes() => (widget.filteredRecipes ?? _recipes)
      .where((r) => !_dismissedRecipeIds.contains(r.id))
      .toList();
  // Always return all recipes for stats calculation
  List<Recipe> getAllRecipes() => _recipes;

  final Map<int, bool> _expanded = {};
  // Purely local "what if I made this for N people" preview — never
  // persisted. The only way to actually change a recipe's servings/
  // ingredients in the database is the edit screen (pencil icon), which is
  // a deliberate, saved action. This is a temporary view, nothing more.
  final Map<int, int> _servingsPreview = {};
  static const int _minPreviewServings = 1;
  static const int _maxPreviewServings = 10;
  bool _loading = true;
  bool get _anyExpanded => _expanded.values.any((v) => v);

  @override
  void initState() {
    super.initState();
    // Always load all recipes for stats, even when filtered
    _loadRecipes();
    if (widget.filteredRecipes != null) {
      _loading = false;
    }
  }

  @override
  void didUpdateWidget(RecipeJournalWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If filteredRecipes changed, update loading state
    if (widget.filteredRecipes != oldWidget.filteredRecipes) {
      if (widget.filteredRecipes != null) {
        _loading = false;
        // Clear expanded state when filtering changes
        _expanded.clear();
      } else if (oldWidget.filteredRecipes != null) {
        // Switched from filtered to unfiltered, set loading until recipes load
        _loading = true;
        _loadRecipes();
      }
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

  PageRouteBuilder<void> _recipeFadeRoute(Widget page) => PageRouteBuilder(
        opaque: false,
        barrierColor: AppColors.purple950,
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      );

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
    final pdf = buildRecipePdf(
      title: d.title,
      description: d.description,
      time: d.time,
      servings: d.servings,
      difficulty: d.difficulty,
      ingredients: d.ingredients,
      instructions: d.instructions,
      notes: d.notes,
      variations: d.variations,
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

  MarkdownStyleSheet _recipeMarkdownStyle(BuildContext context, ToneStyle toneStyle) {
    return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: TextStyle(color: toneStyle.text, fontSize: 13),
      strong: TextStyle(color: toneStyle.text, fontWeight: FontWeight.bold),
      em: TextStyle(color: toneStyle.text, fontStyle: FontStyle.italic),
      h1: TextStyle(color: toneStyle.text, fontSize: 18, fontWeight: FontWeight.bold),
      h2: TextStyle(color: toneStyle.text, fontSize: 16, fontWeight: FontWeight.bold),
    );
  }

  // --- Serving-size preview (local only, never saved) -------------------
  // The database always keeps the recipe's real servings + ingredients
  // exactly as generated or as last saved via the edit screen. This control
  // is purely a "what if I made this for N people" view, clamped to a
  // sensible range — nothing here is persisted.

  int _previewServings(Recipe recipe) =>
      _servingsPreview[recipe.id] ?? recipe.servingsNumber ?? 1;

  Widget _buildIngredientsSection(Recipe recipe, ToneStyle toneStyle) {
    final storedServings = recipe.servingsNumber!;
    final preview = _previewServings(recipe);
    final ratio = preview / storedServings;

    Widget servingsButton(IconData icon, VoidCallback? onTap) => Material(
          color: AppColors.purple400,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(icon, size: 18, color: Colors.black),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ingredients', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: toneStyle.text)),
          const SizedBox(height: 8),
          // Servings preview lives in its own bordered chip, clearly
          // separated from the ingredient list below it, so it doesn't
          // read as if it's adjusting the first ingredient's quantity.
          // Colors follow toneStyle.text (not hardcoded white/yellow) since
          // recipe cards are usually a light background with dark text.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: toneStyle.text.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: toneStyle.text.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Servings', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: toneStyle.text)),
                const SizedBox(width: 10),
                servingsButton(Icons.remove, preview > _minPreviewServings
                    ? () => setState(() => _servingsPreview[recipe.id] = preview - 1)
                    : null),
                SizedBox(
                  width: 28,
                  child: Text('$preview', textAlign: TextAlign.center,
                      style: TextStyle(color: toneStyle.text, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                servingsButton(Icons.add, preview < _maxPreviewServings
                    ? () => setState(() => _servingsPreview[recipe.id] = preview + 1)
                    : null),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ...recipe.ingredientsStructured.map((ing) {
            final qty = ing.quantityAsDouble;
            final displayQty = qty != null ? RecipeIngredient.formatQuantity(qty * ratio) : (ing.quantity ?? '');
            final line = [displayQty, ing.unit, ing.name].where((s) => s != null && s.isNotEmpty).join(' ');
            return Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text('•  $line', style: TextStyle(fontSize: 13, color: toneStyle.text)),
            );
          }),
        ],
      ),
    );
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

            final card = Padding(
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
                      onTap: widget.embeddedInScrollView
                          ? () {
                              Navigator.push(
                                context,
                                _recipeFadeRoute(RecipeDetailScreen(recipe: recipe)),
                              ).then((_) => _loadRecipes());
                            }
                          : () {
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

                                  // Time + Difficulty - each on its own line;
                                  // Time in particular can be a long combined
                                  // "Prep/Cook/Total" string that wraps badly
                                  // when squeezed into half a Row.
                                  if (recipe.time.isNotEmpty || recipe.difficulty.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    if (recipe.time.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          'Time: ${recipe.time}',
                                          style: TextStyle(fontSize: 13, color: toneStyle.text),
                                        ),
                                      ),
                                    if (recipe.difficulty.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          'Difficulty: ${recipe.difficulty}',
                                          style: TextStyle(fontSize: 13, color: toneStyle.text),
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                  ],

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

                                  if (recipe.isStructured) ...[
                                    // Structured recipe: build each section
                                    // from the parsed fields directly instead
                                    // of dumping the whole raw AI response —
                                    // that blob repeats title/description/
                                    // ingredients a second time, which is
                                    // exactly the duplication this replaces.

                                    // Description
                                    if (recipe.description.isNotEmpty) ...[
                                      Text(
                                        recipe.description,
                                        style: TextStyle(color: toneStyle.text, fontSize: 13),
                                      ),
                                      const SizedBox(height: 10),
                                    ],

                                    // Ingredients + serving-size scaler
                                    _buildIngredientsSection(recipe, toneStyle),
                                    const SizedBox(height: 6),

                                    // Photo
                                    // if (recipe.imageFile != null && recipe.imageFile!.isNotEmpty) ...[
                                    //   localFirstImage(
                                    //     recipeId: recipe.id,
                                    //     url: recipe.imageFile,
                                    //     kind: RecipeImageKind.file,
                                    //     fit: BoxFit.cover,
                                    //     radius: BorderRadius.circular(8),
                                    //   ),
                                    //   const SizedBox(height: 10),
                                    // ],

                                    // Instructions
                                    if (recipe.instructions.isNotEmpty) ...[
                                      Text(
                                        "Instructions",
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: toneStyle.text),
                                      ),
                                      const SizedBox(height: 4),
                                      MarkdownBody(data: recipe.instructions, styleSheet: _recipeMarkdownStyle(context, toneStyle)),
                                      const SizedBox(height: 10),
                                    ],

                                    // Variations
                                    if (recipe.variations.isNotEmpty) ...[
                                      Text(
                                        "Variations",
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: toneStyle.text),
                                      ),
                                      const SizedBox(height: 4),
                                      MarkdownBody(data: recipe.variations, styleSheet: _recipeMarkdownStyle(context, toneStyle)),
                                      const SizedBox(height: 6),
                                    ],

                                    // Photo
                                    if (recipe.imageFile != null && recipe.imageFile!.isNotEmpty) ...[
                                      localFirstImage(
                                        recipeId: recipe.id,
                                        url: recipe.imageFile,
                                        kind: RecipeImageKind.file,
                                        fit: BoxFit.cover,
                                        radius: BorderRadius.circular(8),
                                      ),
                                      const SizedBox(height: 10),
                                    ],
                                  ] else ...[
                                    // Legacy (un-edited) recipe: unchanged —
                                    // photo, then the full raw AI response.
                                    if (recipe.imageFile != null &&
                                        recipe.imageFile!.isNotEmpty)
                                      localFirstImage(
                                        recipeId: recipe.id,
                                        url: recipe.imageFile,
                                        kind: RecipeImageKind.file,
                                        fit: BoxFit.cover,
                                        radius: BorderRadius.circular(8),
                                      ),

                                    if (recipe.aiResponse.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      MarkdownBody(
                                        data: _sanitizeAnalysis(recipe.aiResponse),  // remove trailing divider
                                        styleSheet: _recipeMarkdownStyle(context, toneStyle),
                                      ),
                                      const SizedBox(height: 6),
                                    ],
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

            // Swipe-to-delete only makes sense in the scrollable list view,
            // not the single-recipe detail page.
            if (!widget.embeddedInScrollView) return card;

            return Dismissible(
              key: ValueKey('recipe-dismiss-${recipe.id}'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              confirmDismiss: (_) async {
                return await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Recipe'),
                        content: const Text('Are you sure you want to delete this recipe?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                        ],
                      ),
                    ) ??
                    false;
              },
              onDismissed: (_) async {
                final messenger = ScaffoldMessenger.of(context);
                // Remove from view immediately (needed either way - covers
                // both the plain `_recipes` list and a parent-supplied
                // filteredRecipes list, which this widget can't mutate
                // directly). Restored on failure below.
                setState(() => _dismissedRecipeIds.add(recipe.id));
                try {
                  await ApiService.deleteRecipe(recipe.id);
                  setState(() => _recipes.removeWhere((r) => r.id == recipe.id));
                  recipeDataChanged.value = true;
                  messenger.showSnackBar(const SnackBar(content: Text('🗑️ Recipe deleted')));
                } catch (e) {
                  if (mounted) {
                    setState(() => _dismissedRecipeIds.remove(recipe.id));
                  }
                  messenger.showSnackBar(const SnackBar(content: Text('❌ Failed to delete recipe')));
                }
              },
              child: card,
            );
          },
        ),
      )
    );
  }
}
