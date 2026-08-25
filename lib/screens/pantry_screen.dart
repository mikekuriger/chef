// screens/pantry_screen.dart
import 'package:chef/models/pantry_item.dart';
import 'package:chef/services/api_service.dart';
import 'package:chef/state/pantry_model.dart';
import 'package:chef/theme/colors.dart';
import 'package:chef/theme/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PantryScreen extends StatefulWidget {
  const PantryScreen({super.key});

  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: PantryLocation.values.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  PantryLocation get _currentLocation => PantryLocation.values[_tabs.index];

  Future<void> _openAddSheet() async {
    final model = context.read<PantryModel>();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.purple950,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _AddItemsSheet(initialLocation: _currentLocation),
    );

    if (saved == true) {
      await model.refresh();
    }
  }

  Future<void> _openAiImport() async {
    final model = context.read<PantryModel>();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.purple950,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _AiImportSheet(),
    );

    if (saved == true) {
      await model.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe so this screen rebuilds immediately when the theme changes.
    context.watch<ThemeProvider>();

    // NOTE: This screen is hosted inside MainScaffold (which provides the AppBar + bottom nav),
    // so we intentionally do NOT render an AppBar here.
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            // Inline action row (keeps bottom nav visible)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  Text(
                    'Cupboard / Fridge / Freezer',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _openAiImport,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('Import'),
                  ),
                ],
              ),
            ),

            Container(
              color: AppColors.purple950,
              child: TabBar(
                controller: _tabs,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: PantryLocation.values
                    .map((l) => Tab(text: l.displayName))
                    .toList(growable: false),
              ),
            ),

            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: PantryLocation.values
                    .map((l) => _PantryLocationView(location: l))
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddSheet,
        backgroundColor: AppColors.purple600,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add items'),
      ),
    );
  }
}

class _PantryLocationView extends StatefulWidget {
  final PantryLocation location;
  const _PantryLocationView({required this.location});

  @override
  State<_PantryLocationView> createState() => _PantryLocationViewState();
}

class _PantryLocationViewState extends State<_PantryLocationView> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _renameItem(BuildContext context, PantryItem item) async {
    final model = context.read<PantryModel>();
    final controller = TextEditingController(text: item.name);

    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) {
        return AlertDialog(
          backgroundColor: AppColors.purple950,
          title: const Text('Rename item', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'e.g. milk, chicken, salt',
              hintStyle: TextStyle(color: Colors.white54),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dctx).pop(false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () => Navigator.of(dctx).pop(true),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (ok == true) {
      await model.rename(id: item.id, newName: controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<PantryModel>();
    final all = model.itemsFor(widget.location);

    final q = _search.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? all
        : all.where((i) => i.name.toLowerCase().contains(q)).toList(growable: false);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        children: [
          TextField(
            controller: _search,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search ${widget.location.displayName.toLowerCase()}…',
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.search, color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: filtered.isEmpty
                ? _EmptyState(location: widget.location)
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (ctx, idx) {
                      final item = filtered[idx];
                      return Dismissible(
                        key: ValueKey('pantry_${item.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          decoration: BoxDecoration(
                            // Keep destructive affordance within the current theme palette.
                            color: AppColors.purple700.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => model.delete(item.id),
                        child: ListTile(
                          tileColor: AppColors.purple950,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: AppColors.purple400.withValues(alpha: 0.75),
                              width: 0.35,
                            ),
                          ),
                          title: Text(item.name, style: const TextStyle(color: Colors.white)),
                          subtitle: Text(
                            'Tap to rename • Swipe to delete',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                          ),
                          onTap: () => _renameItem(context, item),
                          trailing: PopupMenuButton<String>(
                            color: AppColors.purple900,
                            icon: const Icon(Icons.more_vert, color: Colors.white70),
                            onSelected: (value) async {
                              if (value == 'move_cupboard') {
                                await model.move(id: item.id, newLocation: PantryLocation.cupboard);
                              } else if (value == 'move_fridge') {
                                await model.move(id: item.id, newLocation: PantryLocation.fridge);
                              } else if (value == 'move_freezer') {
                                await model.move(id: item.id, newLocation: PantryLocation.freezer);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'move_cupboard',
                                child: Text('Move to Cupboard', style: TextStyle(color: Colors.white)),
                              ),
                              PopupMenuItem(
                                value: 'move_fridge',
                                child: Text('Move to Fridge', style: TextStyle(color: Colors.white)),
                              ),
                              PopupMenuItem(
                                value: 'move_freezer',
                                child: Text('Move to Freezer', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final PantryLocation location;
  const _EmptyState({required this.location});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.kitchen_outlined, color: AppColors.purple400, size: 48),
            const SizedBox(height: 12),
            Text(
              'No items in your ${location.displayName.toLowerCase()} yet.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a few staples so Chef can suggest recipes based on what you have on hand.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddItemsSheet extends StatefulWidget {
  final PantryLocation initialLocation;
  const _AddItemsSheet({required this.initialLocation});

  @override
  State<_AddItemsSheet> createState() => _AddItemsSheetState();
}

class _AddItemsSheetState extends State<_AddItemsSheet> {
  late PantryLocation _location;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _location = widget.initialLocation;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<String> _parseNames(String raw) {
    final lines = raw
        .split(RegExp(r'[\n,;]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);

    final seen = <String>{};
    final out = <String>[];
    for (final l in lines) {
      final norm = PantryItem.normalize(l);
      if (seen.add(norm)) out.add(l);
    }
    return out;
  }

  Future<void> _save() async {
    final names = _parseNames(_controller.text);
    if (names.isEmpty) {
      Navigator.of(context).pop(false);
      return;
    }

    await context.read<PantryModel>().addMany(location: _location, names: names);

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add pantry items',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<PantryLocation>(
            initialValue: _location,
            dropdownColor: AppColors.purple950,
            decoration: InputDecoration(
              labelText: 'Location',
              labelStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            items: PantryLocation.values
                .map(
                  (l) => DropdownMenuItem(
                    value: l,
                    child: Text(l.displayName, style: const TextStyle(color: Colors.white)),
                  ),
                )
                .toList(growable: false),
            onChanged: (val) {
              if (val == null) return;
              setState(() => _location = val);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 4,
            maxLines: 8,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'milk\nchicken\nsalt\nlettuce',
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.purple600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.save),
                label: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AiImportSheet extends StatefulWidget {
  const _AiImportSheet();

  @override
  State<_AiImportSheet> createState() => _AiImportSheetState();
}

class _AiImportSheetState extends State<_AiImportSheet> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _parse() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Paste a list of items first.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final parsed = await ApiService.parsePantryItems(raw);
      if (!mounted) return;

      final reviewed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.purple950,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => _AiImportReview(parsed: parsed),
      );

      if (!mounted) return;

      if (reviewed == true) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Import with AI',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Paste what you have, and the backend will organize it into cupboard/fridge/freezer.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 6,
            maxLines: 12,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'milk, eggs, chicken\nspinach\nsoy sauce\nparmesan\n…',
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(color: AppColors.yellow1.withValues(alpha: 0.9)),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: _loading ? null : () => Navigator.of(context).pop(false),
                child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _loading ? null : _parse,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.purple600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_loading ? 'Parsing…' : 'Parse'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AiImportReview extends StatefulWidget {
  final Map<PantryLocation, List<String>> parsed;
  const _AiImportReview({required this.parsed});

  @override
  State<_AiImportReview> createState() => _AiImportReviewState();
}

class _AiImportReviewState extends State<_AiImportReview> {
  late final Map<PantryLocation, List<_SelectableName>> _items;

  @override
  void initState() {
    super.initState();
    _items = {
      for (final loc in PantryLocation.values)
        loc: (widget.parsed[loc] ?? const [])
            .map((n) => _SelectableName(name: n.trim()))
            .where((n) => n.name.isNotEmpty)
            .toList(growable: true),
    };
  }

  int get _selectedCount {
    var n = 0;
    for (final loc in PantryLocation.values) {
      for (final it in _items[loc] ?? const []) {
        if (it.selected) n++;
      }
    }
    return n;
  }

  Future<void> _apply() async {
    final model = context.read<PantryModel>();

    for (final loc in PantryLocation.values) {
      final selected = (_items[loc] ?? const [])
          .where((i) => i.selected)
          .map((i) => i.name)
          .toList(growable: false);
      if (selected.isEmpty) continue;
      await model.addMany(location: loc, names: selected);
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Review import',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Select what to save. ($_selectedCount selected)',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: PantryLocation.values.map((loc) {
                final list = _items[loc] ?? const [];
                if (list.isEmpty) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.purple900,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.purple400.withValues(alpha: 0.75),
                        width: 0.35,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                          child: Text(
                            loc.displayName,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...list.map((it) {
                          return CheckboxListTile(
                            value: it.selected,
                            onChanged: (v) => setState(() => it.selected = v ?? false),
                            title: Text(it.name, style: const TextStyle(color: Colors.white)),
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: AppColors.purple600,
                            checkColor: Colors.white,
                          );
                        }),
                      ],
                    ),
                  ),
                );
              }).toList(growable: false),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _selectedCount == 0 ? null : _apply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.purple600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.download_done),
                label: const Text('Import'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SelectableName {
  final String name;
  bool selected = true;
  _SelectableName({required this.name});
}
