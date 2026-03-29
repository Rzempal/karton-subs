// pdf_export_service.dart — Eksport raportu subskrypcji do PDF

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/subscription.dart';
import '../models/category.dart';
import 'analytics_service.dart';

class PdfExportService {
  const PdfExportService();

  Future<pw.Document> _build(
    List<Subscription> subs,
    List<Category> categories,
    String currencyLabel,
  ) async {
    // Font z obsługą polskich znaków
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final baseStyle = pw.TextStyle(font: font, fontSize: 8);
    final boldStyle = pw.TextStyle(font: fontBold, fontSize: 9);

    final pdf = pw.Document();
    final dateStr = DateFormat('dd.MM.yyyy').format(DateTime.now());
    final nf = NumberFormat('#,##0.00', 'pl_PL');

    const analytics = AnalyticsService();
    final active = subs.where((s) => s.isActive).toList();
    final cancelled = subs.where((s) => !s.isActive).toList();
    final monthlyTotal = analytics.getMonthlyTotal(subs);
    final yearlyTotal = analytics.getYearlyProjection(subs);

    Category? findCat(String? id) {
      if (id == null) return null;
      try { return categories.firstWhere((c) => c.id == id); }
      catch (_) { return null; }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        header: (ctx) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 20),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Karton na subskrypcje',
                  style: pw.TextStyle(font: fontBold, fontSize: 16)),
              pw.Text(dateStr,
                  style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
            ],
          ),
        ),
        footer: (ctx) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 20),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 4),
              pw.Text('Strona ${ctx.pageNumber} z ${ctx.pagesCount}',
                  style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey500)),
            ],
          ),
        ),
        build: (ctx) => [
          // Summary
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _item('Miesięcznie', '${nf.format(monthlyTotal)} $currencyLabel', fontBold, font),
                _item('Rocznie', '${nf.format(yearlyTotal)} $currencyLabel', fontBold, font),
                _item('Aktywne', '${active.length}', fontBold, font),
                _item('Anulowane', '${cancelled.length}', fontBold, font),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          if (active.isNotEmpty) ...[
            pw.Text('Aktywne subskrypcje',
                style: pw.TextStyle(font: fontBold, fontSize: 12)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              context: ctx,
              headerStyle: boldStyle,
              headerDecoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(width: 1, color: PdfColors.black)),
              ),
              cellStyle: baseStyle,
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(2),
              },
              headers: ['Nazwa', 'Kwota', 'Mies.', 'Kategoria'],
              data: active.map((s) {
                final cat = findCat(s.categoryId);
                return [
                  s.name,
                  '${nf.format(s.amount)} ${s.currency.symbol}',
                  '${nf.format(s.monthlyAmount)} $currencyLabel',
                  cat?.name ?? 'Inne',
                ];
              }).toList(),
            ),
          ],

          if (cancelled.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text('Anulowane subskrypcje',
                style: pw.TextStyle(font: fontBold, fontSize: 12)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              context: ctx,
              headerStyle: boldStyle,
              headerDecoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(width: 1, color: PdfColors.grey600)),
              ),
              cellStyle: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(2),
              },
              headers: ['Nazwa', 'Kwota', 'Kategoria'],
              data: cancelled.map((s) {
                final cat = findCat(s.categoryId);
                return [
                  s.name,
                  '${nf.format(s.amount)} ${s.currency.symbol}',
                  cat?.name ?? 'Inne',
                ];
              }).toList(),
            ),
          ],
        ],
      ),
    );

    return pdf;
  }

  pw.Widget _item(String label, String value, pw.Font bold, pw.Font base) {
    return pw.Column(children: [
      pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 14)),
      pw.SizedBox(height: 2),
      pw.Text(label, style: pw.TextStyle(font: base, fontSize: 9, color: PdfColors.grey600)),
    ]);
  }

  Future<void> sharePdf(
    List<Subscription> subs,
    List<Category> categories,
    String currencyLabel,
  ) async {
    final pdf = await _build(subs, categories, currencyLabel);
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'subskrypcje_$dateStr.pdf',
    );
  }
}
