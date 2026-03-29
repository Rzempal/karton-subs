// pdf_export_service.dart — Eksport raportu subskrypcji do PDF

import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/subscription.dart';
import '../models/category.dart';
import '../services/analytics_service.dart';

class PdfExportService {
  const PdfExportService();

  /// Zamienia polskie znaki diakrytyczne na ASCII
  /// (wbudowane fonty PDF nie obsługują UTF-8)
  String _removeDiacritics(String text) {
    const Map<String, String> map = {
      'ą': 'a', 'ć': 'c', 'ę': 'e', 'ł': 'l', 'ń': 'n',
      'ó': 'o', 'ś': 's', 'ź': 'z', 'ż': 'z',
      'Ą': 'A', 'Ć': 'C', 'Ę': 'E', 'Ł': 'L', 'Ń': 'N',
      'Ó': 'O', 'Ś': 'S', 'Ź': 'Z', 'Ż': 'Z',
    };
    return text.replaceAllMapped(
      RegExp('[ąćęłńóśźżĄĆĘŁŃÓŚŹŻ]'),
      (match) => map[match.group(0)] ?? match.group(0)!,
    );
  }

  pw.Document _buildDocument(
    List<Subscription> subscriptions,
    List<Category> categories,
    Currency defaultCurrency,
  ) {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateStr = DateFormat('dd.MM.yyyy').format(now);
    final d = _removeDiacritics;

    const analytics = AnalyticsService();
    final active = subscriptions.where((s) => s.isActive).toList();
    final cancelled = subscriptions.where((s) => !s.isActive).toList();
    final monthlyTotal = analytics.getMonthlyTotal(subscriptions);
    final yearlyTotal = analytics.getYearlyProjection(subscriptions);

    Category? findCategory(String? id) {
      if (id == null) return null;
      try {
        return categories.firstWhere((c) => c.id == id);
      } catch (_) {
        return null;
      }
    }

    String formatCycle(Subscription s) {
      return '${s.amount.toStringAsFixed(2)} ${s.currency.symbol} ${s.billingCycle.shortLabel}';
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 20),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Karton na subskrypcje',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                dateStr,
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 20),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 4),
              pw.Text(
                'Strona ${context.pageNumber} z ${context.pagesCount}',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey500,
                ),
              ),
            ],
          ),
        ),
        build: (context) => [
          // Summary
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _summaryItem(
                    'Miesiecznie', '${monthlyTotal.toStringAsFixed(2)} ${defaultCurrency.symbol}'),
                _summaryItem(
                    'Rocznie', '${yearlyTotal.toStringAsFixed(0)} ${defaultCurrency.symbol}'),
                _summaryItem('Aktywne', '${active.length}'),
                _summaryItem('Anulowane', '${cancelled.length}'),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Active subscriptions table
          if (active.isNotEmpty) ...[
            pw.Text(
              'Aktywne subskrypcje',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              context: context,
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
              headerDecoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(width: 1, color: PdfColors.black),
                ),
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 6,
              ),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerLeft,
              },
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(2),
              },
              headers: ['Nazwa', 'Kwota', 'Mies.', 'Kategoria'],
              data: active.map((s) {
                final cat = findCategory(s.categoryId);
                return [
                  d(s.name),
                  formatCycle(s),
                  '${s.monthlyAmount.toStringAsFixed(2)} ${s.currency.symbol}',
                  d(cat?.name ?? 'Inne'),
                ];
              }).toList(),
            ),
          ],

          // Cancelled subscriptions table
          if (cancelled.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text(
              'Anulowane subskrypcje',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              context: context,
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
              headerDecoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(width: 1, color: PdfColors.grey600),
                ),
              ),
              cellStyle: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey600,
              ),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 6,
              ),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(2),
              },
              headers: ['Nazwa', 'Kwota', 'Kategoria'],
              data: cancelled.map((s) {
                final cat = findCategory(s.categoryId);
                return [
                  d(s.name),
                  formatCycle(s),
                  d(cat?.name ?? 'Inne'),
                ];
              }).toList(),
            ),
          ],
        ],
      ),
    );

    return pdf;
  }

  pw.Widget _summaryItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ],
    );
  }

  /// Generuje PDF i zapisuje do dokumentów
  Future<File> generateAndSavePdf(
    List<Subscription> subscriptions,
    List<Category> categories,
    Currency defaultCurrency,
  ) async {
    final pdf = _buildDocument(subscriptions, categories, defaultCurrency);
    final directory = await getApplicationDocumentsDirectory();
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final fileName = 'subskrypcje_$dateStr.pdf';
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  /// Generuje PDF i otwiera dialog druku
  Future<void> printPdf(
    List<Subscription> subscriptions,
    List<Category> categories,
    Currency defaultCurrency,
  ) async {
    final pdf = _buildDocument(subscriptions, categories, defaultCurrency);
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await Printing.layoutPdf(
      name: 'subskrypcje_$dateStr',
      onLayout: (format) async => pdf.save(),
    );
  }

  /// Generuje PDF i otwiera sheet udostępniania
  Future<void> sharePdf(
    List<Subscription> subscriptions,
    List<Category> categories,
    Currency defaultCurrency,
  ) async {
    final pdf = _buildDocument(subscriptions, categories, defaultCurrency);
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'subskrypcje_$dateStr.pdf',
    );
  }
}
