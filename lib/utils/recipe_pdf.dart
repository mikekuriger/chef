// utils/recipe_pdf.dart
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Builds the printable recipe PDF. Shared by the freshly-generated recipe
/// view (dashboard_screen.dart) and the saved "My Recipes" view
/// (recipe_journal_widget.dart) - previously each had its own hand-written
/// copy of this, which had drifted out of sync (different field order,
/// inconsistent formatting). Keeping it in one place keeps print output
/// identical regardless of where it's triggered from.
pw.Document buildRecipePdf({
  required String title,
  required String description,
  required String time,
  required String servings,
  required String difficulty,
  required String ingredients,
  required String instructions,
  required String notes,
  required String variations,
}) {
  final pdf = pw.Document();

  pw.Widget section(String heading, String body) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            heading,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(body, style: const pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 16),
        ],
      );

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty)
              pw.Text(
                title,
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
            pw.SizedBox(height: 16),

            if (description.isNotEmpty)
              pw.Text(description, style: const pw.TextStyle(fontSize: 14)),
            pw.SizedBox(height: 16),

            // Time, Servings, Difficulty - each its own line (Time can be a
            // long combined "Prep/Cook/Total" string that wraps badly when
            // squeezed into a fraction of a Row's width).
            if (time.isNotEmpty)
              pw.Text('Time: $time', style: const pw.TextStyle(fontSize: 12)),
            if (servings.isNotEmpty)
              pw.Text('Servings: $servings', style: const pw.TextStyle(fontSize: 12)),
            if (difficulty.isNotEmpty)
              pw.Text('Difficulty: $difficulty', style: const pw.TextStyle(fontSize: 12)),
            if (time.isNotEmpty || servings.isNotEmpty || difficulty.isNotEmpty)
              pw.SizedBox(height: 16),

            if (ingredients.isNotEmpty) section('Ingredients', ingredients),
            if (instructions.isNotEmpty) section('Instructions', instructions),
            if (notes.isNotEmpty) section('Notes', notes),
            if (variations.isNotEmpty) section('Variations', variations),
          ],
        );
      },
    ),
  );

  return pdf;
}
