import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show BuildContext;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'models.dart';
import 'pdf_service.dart';
import 'utils.dart';

// Expense report PDF: same logo header, "EXPENSE REPORT" heading, a band with
// the period / count / total, a dated table of expenses, a category summary
// and the signatory. [projectName] labels each row's linked project.

Future<Uint8List> generateExpenseReportBytes({
  required List<Expense> expenses,
  required CompanySettings company,
  required String period,
  String Function(String projectId)? projectName,
}) async {
  final kit = await PdfKit.load(company);
  final t = kit.t;
  final style = kit.style;
  final total = expenses.fold<double>(0, (acc, e) => acc + e.amount);

  // Oldest first reads naturally in a report.
  final rows = [...expenses]..sort((a, b) => a.date.compareTo(b.date));

  const cellPad = pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6);
  pw.Widget cell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    pw.TextStyle? textStyle,
  }) => pw.Padding(
    padding: cellPad,
    child: pw.Text(text, textAlign: align, style: textStyle ?? style()),
  );

  final thick = pw.BorderSide(color: pdfBlack, width: 2);
  final thin = pw.BorderSide(color: pdfLightGrey, width: 0.8);
  final head = style(size: 10, semi: true);

  final table = pw.Table(
    columnWidths: const {
      0: pw.FixedColumnWidth(62),
      1: pw.FixedColumnWidth(70),
      2: pw.FlexColumnWidth(),
      3: pw.FixedColumnWidth(52),
      4: pw.FixedColumnWidth(78),
    },
    children: [
      pw.TableRow(
        repeat: true,
        decoration: pw.BoxDecoration(
          border: pw.Border(top: thick, bottom: thick),
        ),
        children: [
          cell('DATE', textStyle: head),
          cell('CATEGORY', textStyle: head),
          cell('DETAILS', textStyle: head),
          cell('MODE', textStyle: head),
          cell('AMOUNT', align: pw.TextAlign.right, textStyle: head),
        ],
      ),
      for (final e in rows)
        pw.TableRow(
          decoration: pw.BoxDecoration(border: pw.Border(bottom: thin)),
          children: [
            cell(formatDate(e.date)),
            cell(e.category),
            pw.Padding(
              padding: cellPad,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    t(e.description.isEmpty ? e.category : e.description),
                    style: style(size: 10),
                  ),
                  if (_subline(e, projectName).isNotEmpty)
                    pw.Text(
                      t(_subline(e, projectName)),
                      style: style(size: 8, color: pdfGrey),
                    ),
                ],
              ),
            ),
            cell(e.paymentMode),
            cell(kit.money(e.amount), align: pw.TextAlign.right),
          ],
        ),
      pw.TableRow(
        decoration: pw.BoxDecoration(
          border: pw.Border(top: thick, bottom: thick),
        ),
        children: [
          cell('TOTAL', textStyle: style(size: 10.5, bold: true)),
          cell(''),
          cell('${rows.length} entries', textStyle: style(color: pdfGrey)),
          cell(''),
          cell(
            kit.money(total),
            align: pw.TextAlign.right,
            textStyle: style(size: 10.5, bold: true),
          ),
        ],
      ),
    ],
  );

  // Category totals, largest first.
  final byCategory = <String, double>{};
  for (final e in expenses) {
    byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
  }
  final categories = byCategory.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final summary = pw.Container(
    width: 240,
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: pdfLightGrey, width: 0.8),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          color: PdfColor.fromHex('#F3F4F6'),
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: pw.Text(
            'CATEGORY SUMMARY',
            style: style(size: 10, bold: true),
          ),
        ),
        for (final c in categories)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: pw.Row(
              children: [
                pw.Expanded(child: pw.Text(c.key, style: style(size: 10))),
                pw.Text(kit.money(c.value), style: style(size: 10)),
              ],
            ),
          ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: pdfBlack, width: 0.8)),
          ),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text('Total', style: style(size: 10.5, bold: true)),
              ),
              pw.Text(kit.money(total), style: style(size: 10.5, bold: true)),
            ],
          ),
        ),
      ],
    ),
  );

  final doc = kit.document('Expense Report $period');
  doc.addPage(
    kit.page(
      (context) => [
        kit.header(),
        pw.SizedBox(height: 14),
        kit.thickRule(),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 9),
          child: pw.Center(
            child: pw.Text(
              'EXPENSE REPORT',
              style: style(size: 18, bold: true).copyWith(letterSpacing: 4),
            ),
          ),
        ),
        kit.band([
          ('Period:', period),
          ('Entries:', '${rows.length}'),
          ('Total:', kit.money(total)),
        ]),
        pw.SizedBox(height: 14),
        if (rows.isEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Center(
              child: pw.Text(
                'No expenses in this period.',
                style: style(color: pdfGrey),
              ),
            ),
          )
        else
          table,
        pw.SizedBox(height: 16),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (categories.isNotEmpty) summary,
            pw.Spacer(),
            kit.signatory(),
          ],
        ),
      ],
    ),
  );
  return doc.save();
}

/// Paid to · project · added by, whichever are set.
String _subline(Expense e, String Function(String)? projectName) {
  final project = projectName == null ? '' : projectName(e.projectId);
  return [
    if (e.paidTo.isNotEmpty) 'Paid to ${e.paidTo}',
    if (project.isNotEmpty) 'Project: $project',
    if (e.createdByName.isNotEmpty) 'By ${e.createdByName}',
  ].join('  ·  ');
}

String expenseReportFileName(String period) =>
    'expense_report_${period.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}.pdf';

Future<void> shareExpenseReport(
  BuildContext context, {
  required Future<Uint8List> bytes,
  required String period,
  required CompanySettings company,
}) => sharePdfFile(
  context,
  bytes: bytes,
  fileName: expenseReportFileName(period),
  message: 'Expense report ($period) - ${company.name}',
);
