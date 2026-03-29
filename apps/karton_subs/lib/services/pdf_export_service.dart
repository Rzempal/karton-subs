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

  String _d(String text) {
    const map = {
      'ą': 'a', 'ć': 'c', 'ę': 'e', 'ł': 'l', 'ń': 'n',
      'ó': 'o', 'ś': 's', 'ź': 'z', 'ż': 'z',
      'Ą': 'A', 'Ć': 'C', 'Ę': 'E', 'Ł': 'L', 'Ń': 'N',
      'Ó': 'O', 'Ś': 'S', 'Ź': 'Z', 'Ż': 'Z',
    };
    return text.replaceAllMapped(
      RegExp('[ąćęłńóśźżĄĆĘŁŃÓŚŹŻ]'),
      (m) => map[m.group(0)] ?? m.group(0)!,
    );
  }

  pw.Document _build(
    List<Subscription> subs,
    List<Category> categories,
    String currencyLabel,
  ) {
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
        header: (ctx) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 20),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Karton na subskrypcje',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text(dateStr,
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
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
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
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
                _item('Miesiecznie', '${nf.format(monthlyTotal)} $currencyLabel'),
                _item('Rocznie', '${nf.format(yearlyTotal)} $currencyLabel'),
                _item('Aktywne', '${active.length}'),
                _item('Anulowane', '${cancelled.length}'),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          if (active.isNotEmpty) ...[
            pw.Text('Aktywne subskrypcje',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              context: ctx,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
              headerDecoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(width: 1, color: PdfColors.black)),
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
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
                  _d(s.name),
                  '${nf.format(s.amount)} ${s.currency.symbol}',
                  '${nf.format(s.monthlyAmount)} $currencyLabel',
                  _d(cat?.name ?? 'Inne'),
                ];
              }).toList(),
            ),
          ],

          if (cancelled.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text('Anulowane subskrypcje',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              context: ctx,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
              headerDecoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(width: 1, color: PdfColors.grey600)),
              ),
              cellStyle: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
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
                  _d(s.name),
                  '${nf.format(s.amount)} ${s.currency.symbol}',
                  _d(cat?.name ?? 'Inne'),
                ];
              }).toList(),
            ),
          ],
        ],
      ),
    );

    return pdf;
  }

  pw.Widget _item(String label, String value) {
    return pw.Column(children: [
      pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 2),
      pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
    ]);
  }

  Future<void> sharePdf(
    List<Subscription> subs,
    List<Category> categories,
    String currencyLabel,
  ) async {
    final pdf = _build(subs, categories, currencyLabel);
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'subskrypcje_$dateStr.pdf',
    );
  }
}
