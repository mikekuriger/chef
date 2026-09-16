// screens/recipe_edit_screen.dart
import 'package:flutter/material.dart';
import 'package:chef/constants.dart';
import 'package:chef/models/recipe.dart';
import 'package:chef/services/api_service.dart';
import 'package:chef/theme/colors.dart';

/// One editable ingredient row: quantity + unit + name text controllers.
class _IngredientRow {
  final TextEditingController quantity;
  final TextEditingController unit;
  final TextEditingController name;
  // The quantity this row started at, as a number — used as the anchor for
  // the servings stepper below so repeated taps always scale from the true
  // original instead of compounding rounding error. Null for a manually
  // added blank row, or a quantity that can't be parsed as a number (e.g.
  // "to taste") — those rows are simply left alone by the stepper.
  final double? originalQuantity;

  _IngredientRow({String? quantity, String? unit, String? name})
      : quantity = TextEditingController(text: quantity ?? ''),
        unit = TextEditingController(text: unit ?? ''),
        name = TextEditingController(text: name ?? ''),
        originalQuantity = RecipeIngredient(quantity: quantity, name: '').quantityAsDouble;

  void dispose() {
    quantity.dispose();
    unit.dispose();
    name.dispose();
  }
}

const Set<String> _kKnownUnits = {
  'cup', 'cups', 'tbsp', 'tablespoon', 'tablespoons', 'tsp', 'teaspoon', 'teaspoons',
  'oz', 'ounce', 'ounces', 'lb', 'lbs', 'pound', 'pounds',
  'g', 'gram', 'grams', 'kg', 'kilogram', 'kilograms',
  'ml', 'milliliter', 'milliliters', 'l', 'liter', 'liters',
  'pint', 'pints', 'quart', 'quarts', 'gallon', 'gallons',
  'clove', 'cloves', 'pinch', 'pinches', 'dash', 'can', 'cans',
  'slice', 'slices', 'stick', 'sticks', 'bunch', 'bunches',
  'head', 'heads', 'piece', 'pieces', 'sprig', 'sprigs',
};

/// Best-effort client-side split of a raw "- 2 cups flour" line into
/// quantity/unit/name, so legacy free-text recipes start with reasonable
/// pre-filled fields instead of dumping the whole line into "name".
/// Mirrors chef-backend's parse_ingredient_line; doesn't need to match it
/// exactly since the user can just edit the fields either way.
_IngredientRow _rowFromLegacyLine(String line) {
  var text = line.trim();
  text = text.replaceFirst(RegExp(r'^[-*•]\s*'), '');
  text = text.replaceFirst(RegExp(r'^\d+[.)]\s*'), '');
  if (text.isEmpty) return _IngredientRow();

  final qtyMatch = RegExp(r'^(\d+\s+\d+/\d+|\d+/\d+|\d+\.\d+|\d+)\s*').firstMatch(text);
  if (qtyMatch == null) {
    return _IngredientRow(name: text);
  }
  final quantity = qtyMatch.group(1);
  final rest = text.substring(qtyMatch.end).trim();
  if (rest.isEmpty) return _IngredientRow(quantity: quantity, name: text);

  final parts = rest.split(RegExp(r'\s+'));
  final firstWord = parts.first.replaceAll(RegExp(r'[.,]$'), '');
  if (_kKnownUnits.contains(firstWord.toLowerCase())) {
    final remainder = parts.skip(1).join(' ').trim();
    return _IngredientRow(quantity: quantity, unit: firstWord, name: remainder.isEmpty ? firstWord : remainder);
  }
  return _IngredientRow(quantity: quantity, name: rest);
}

class RecipeEditScreen extends StatefulWidget {
  final Recipe recipe;
  const RecipeEditScreen({super.key, required this.recipe});

  @override
  State<RecipeEditScreen> createState() => _RecipeEditScreenState();
}

class _RecipeEditScreenState extends State<RecipeEditScreen> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _time;
  late final TextEditingController _difficulty;
  late final TextEditingController _instructions;
  late final TextEditingController _notes;
  late final TextEditingController _variations;

  // Servings is a single number, kept in sync with ingredient quantities by
  // construction: the stepper always rescales every row from its original
  // amount, so there's never a moment where servings and ingredients can
  // say different things.
  late int _servings;
  late final int _originalServings;

  String? _course;
  final Set<String> _mainIngredients = {};
  final List<_IngredientRow> _ingredientRows = [];

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final r = widget.recipe;

    _title = TextEditingController(text: r.title);
    _description = TextEditingController(text: r.description);
    _time = TextEditingController(text: r.time);
    _difficulty = TextEditingController(text: r.difficulty);
    _servings = r.servingsNumber ?? 2;
    _originalServings = _servings;
    _instructions = TextEditingController(text: r.instructions);
    _notes = TextEditingController(text: r.notes);
    _variations = TextEditingController(text: r.variations);

    _course = (r.course != null && kRecipeCourses.contains(r.course)) ? r.course : null;
    if (r.mainIngredient != null) {
      _mainIngredients.addAll(
        r.mainIngredient!.split(',').map((s) => s.trim()).where(kRecipeMainIngredients.contains),
      );
    }

    if (r.isStructured) {
      for (final ing in r.ingredientsStructured) {
        _ingredientRows.add(_IngredientRow(quantity: ing.quantity, unit: ing.unit, name: ing.name));
      }
    } else if (r.ingredients.trim().isNotEmpty) {
      for (final line in r.ingredients.split('\n')) {
        if (line.trim().isEmpty) continue;
        _ingredientRows.add(_rowFromLegacyLine(line));
      }
    }
    if (_ingredientRows.isEmpty) _ingredientRows.add(_IngredientRow());
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _time.dispose();
    _difficulty.dispose();
    _instructions.dispose();
    _notes.dispose();
    _variations.dispose();
    for (final row in _ingredientRows) {
      row.dispose();
    }
    super.dispose();
  }

  void _addIngredientRow() {
    setState(() => _ingredientRows.add(_IngredientRow()));
  }

  void _removeIngredientRow(int index) {
    setState(() {
      _ingredientRows.removeAt(index).dispose();
      if (_ingredientRows.isEmpty) _ingredientRows.add(_IngredientRow());
    });
  }

  // Rescales every ingredient row from its ORIGINAL quantity (not the
  // currently-displayed one) so repeated taps don't compound rounding
  // error. Rows without a parseable original quantity (blank/added rows,
  // "to taste", etc.) are left untouched — nothing to scale.
  void _changeServings(int newServings) {
    if (newServings < 1) return;
    setState(() {
      _servings = newServings;
      final ratio = newServings / _originalServings;
      for (final row in _ingredientRows) {
        if (row.originalQuantity != null) {
          row.quantity.text = RecipeIngredient.formatQuantity(row.originalQuantity! * ratio);
        }
      }
    });
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Title can\'t be empty.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final ingredients = _ingredientRows
        .where((row) => row.name.text.trim().isNotEmpty)
        .map((row) => {
              'quantity': row.quantity.text.trim(),
              'unit': row.unit.text.trim(),
              'name': row.name.text.trim(),
            })
        .toList();

    try {
      final updated = await ApiService.updateRecipe(widget.recipe.id, {
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'course': _course,
        'main_ingredient': _mainIngredients.toList(),
        'time': _time.text.trim(),
        'servings': '$_servings',
        'ingredients': ingredients,
        'instructions': _instructions.text.trim(),
        'notes': _notes.text.trim(),
        'variations': _variations.text.trim(),
        'difficulty': _difficulty.text.trim(),
      });

      recipeDataChanged.value = true;
      if (mounted) Navigator.of(context).pop(updated);
    } catch (e) {
      if (mounted) setState(() => _error = 'Save failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _fieldDecoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      );

  Widget _choiceChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.purple400 : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.purple400 : Colors.white24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white70,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.purple900,
      appBar: AppBar(
        backgroundColor: AppColors.purple950,
        foregroundColor: Colors.white,
        elevation: 4,
        title: const Text('Edit Recipe', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: _saving
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check),
            tooltip: 'Save',
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ),

            TextField(controller: _title, style: const TextStyle(color: Colors.white), decoration: _fieldDecoration('Title')),
            const SizedBox(height: 10),
            TextField(
              controller: _description,
              maxLines: 2,
              style: const TextStyle(color: Colors.white),
              decoration: _fieldDecoration('Description'),
            ),

            _sectionLabel('Course'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kRecipeCourses
                  .map((c) => _choiceChip(c, _course == c, () => setState(() => _course = (_course == c) ? null : c)))
                  .toList(),
            ),

            _sectionLabel('Main Ingredient (up to 2)'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kRecipeMainIngredients.map((m) {
                final selected = _mainIngredients.contains(m);
                return _choiceChip(m, selected, () {
                  setState(() {
                    if (selected) {
                      _mainIngredients.remove(m);
                    } else if (_mainIngredients.length < 2) {
                      _mainIngredients.add(m);
                    }
                  });
                });
              }).toList(),
            ),

            _sectionLabel('Servings'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.white70),
                    onPressed: _servings > 1 ? () => _changeServings(_servings - 1) : null,
                  ),
                  SizedBox(
                    width: 32,
                    child: Text('$_servings', textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Colors.white70),
                    onPressed: () => _changeServings(_servings + 1),
                  ),
                  const Spacer(),
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Text(
                      'Adjusts ingredient amounts too',
                      style: TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            TextField(controller: _time, style: const TextStyle(color: Colors.white), decoration: _fieldDecoration('Time')),
            const SizedBox(height: 10),
            TextField(controller: _difficulty, style: const TextStyle(color: Colors.white), decoration: _fieldDecoration('Difficulty')),

            _sectionLabel('Ingredients'),
            ..._ingredientRows.asMap().entries.map((entry) {
              final i = entry.key;
              final row = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 60,
                      child: TextField(
                        controller: row.quantity,
                        style: const TextStyle(color: Colors.white),
                        decoration: _fieldDecoration('Qty'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: row.unit,
                        style: const TextStyle(color: Colors.white),
                        decoration: _fieldDecoration('Unit'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: row.name,
                        style: const TextStyle(color: Colors.white),
                        decoration: _fieldDecoration('Ingredient'),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                      onPressed: () => _removeIngredientRow(i),
                    ),
                  ],
                ),
              );
            }),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addIngredientRow,
                icon: const Icon(Icons.add, color: Colors.yellow),
                label: const Text('Add ingredient', style: TextStyle(color: Colors.yellow)),
              ),
            ),

            _sectionLabel('Instructions'),
            TextField(
              controller: _instructions,
              maxLines: 10,
              minLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: _fieldDecoration('Instructions'),
            ),

            _sectionLabel('Variations'),
            TextField(
              controller: _variations,
              maxLines: 4,
              minLines: 2,
              style: const TextStyle(color: Colors.white),
              decoration: _fieldDecoration('Variations'),
            ),

            _sectionLabel('Notes'),
            TextField(
              controller: _notes,
              maxLines: 4,
              minLines: 2,
              style: const TextStyle(color: Colors.white),
              decoration: _fieldDecoration('Notes'),
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save),
                label: Text(_saving ? 'Saving...' : 'Save Recipe'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.deepPurple.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
