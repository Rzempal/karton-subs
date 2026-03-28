// REFERENCE: Ten plik pochodzi z "Karton z lekami" (APPteczka).
// Wymaga adaptacji do domeny subskrypcji. Zobacz docs/database.md dla nowego modelu.
// Reusable: pipeline PDF (document -> layout -> save), _removeDiacritics(), share/print.
// Do wymiany: kolumny tabeli (Nazwa/Wskazania/Termin -> Nazwa/Kwota/Cykl/Kategoria).

import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/medicine.dart';

/// Serwis do eksportu tabeli leków do PDF
/// Styl czarno-biały zoptymalizowany do druku
class PdfExportService {
  /// Zamienia polskie znaki diakrytyczne na ASCII
  /// (wbudowane fonty PDF nie obsługują UTF-8)
  String _removeDiacritics(String text) {
    const Map<String, String> map = {
      'ą': 'a',
      'ć': 'c',
      'ę': 'e',
      'ł': 'l',
      'ń': 'n',
      'ó': 'o',
      'ś': 's',
      'ź': 'z',
      'ż': 'z',
      'Ą': 'A',
      'Ć': 'C',
      'Ę': 'E',
      'Ł': 'L',
      'Ń': 'N',
      'Ó': 'O',
      'Ś': 'S',
      'Ź': 'Z',
      'Ż': 'Z',
    };

    return text.replaceAllMapped(
      RegExp('[ąćęłńóśźżĄĆĘŁŃÓŚŹŻ]'),
      (match) => map[match.group(0)] ?? match.group(0)!,
    );
  }

  /// Formatuje datę do wyświetlenia
  String _formatDate(String? dateString) {
    if (dateString == null) return '-';
    final date = DateTime.tryParse(dateString);
    if (date == null) return '-';
    return DateFormat('dd.MM.yyyy').format(date);
  }

  /// Generuje dokument PDF z tabelą leków
  pw.Document _buildDocument(List<Medicine> medicines) {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateStr = DateFormat('dd.MM.yyyy').format(now);

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
                'Moja Apteczka',
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
                'Pudelko na leki - narzedzie informacyjne, nie porada medyczna.',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
              pw.SizedBox(height: 2),
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
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.center,
              3: pw.Alignment.centerLeft,
            },
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(1.2),
              3: const pw.FlexColumnWidth(2.5),
            },
            headers: ['Nazwa', 'Wskazania', 'Termin', 'Notatka'],
            data: medicines.map((m) {
              final wskazania = m.wskazania.take(2).join(', ');
              return [
                _removeDiacritics(m.nazwa ?? 'Nieznany'),
                _removeDiacritics(wskazania.isEmpty ? '-' : wskazania),
                _formatDate(m.terminWaznosci),
                _removeDiacritics(m.notatka ?? '-'),
              ];
            }).toList(),
          ),
        ],
      ),
    );

    return pdf;
  }

  /// Generuje PDF i zapisuje do urządzenia
  /// Zwraca ścieżkę do zapisanego pliku
  Future<File> generateAndSavePdf(List<Medicine> medicines) async {
    final pdf = _buildDocument(medicines);

    // Pobierz katalog downloads lub documents
    final directory = await getApplicationDocumentsDirectory();
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final fileName = 'apteczka_$dateStr.pdf';
    final file = File('${directory.path}/$fileName');

    await file.writeAsBytes(await pdf.save());
    return file;
  }

  /// Generuje PDF i otwiera dialog druku/udostępniania
  Future<void> printPdf(List<Medicine> medicines) async {
    final pdf = _buildDocument(medicines);
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    await Printing.layoutPdf(
      name: 'apteczka_$dateStr',
      onLayout: (format) async => pdf.save(),
    );
  }

  /// Generuje PDF i otwiera sheet udostępniania
  Future<void> sharePdf(List<Medicine> medicines) async {
    final pdf = _buildDocument(medicines);
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'apteczka_$dateStr.pdf',
    );
  }
}
