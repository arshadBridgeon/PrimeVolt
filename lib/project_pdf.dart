import 'dart:io';

import 'package:flutter/material.dart' show BuildContext;
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'models.dart';
import 'pdf_service.dart';
import 'utils.dart';

// Project file PDF: same logo header as the quotation, then a "PROJECT FILE"
// heading and number/date band, followed by compact bordered sections laid
// out in two-column field grids, a one-row status strip, payment summary
// boxes, serial numbers, notes, site photos and the signatory.

const _doneStatuses = {'Completed', 'Installed', 'Received', 'Paid'};
const _idleStatuses = {'Pending', 'Not Applied'};

final _sectionFill = PdfColor.fromHex('#F3F4F6');
final _green = PdfColor.fromHex('#2E7D32');
final _red = PdfColor.fromHex('#C62828');

PdfColor _statusColor(String status) {
  if (_doneStatuses.contains(status)) return _green;
  if (_idleStatuses.contains(status)) return PdfColor.fromHex('#6B7280');
  return PdfColor.fromHex('#C77700');
}

/// [account] is the linked quotation's money (advances, expenses, balance);
/// its section is left out when the project has no quotation.
Future<Uint8List> generateProjectPdfBytes(
  ProjectFile p,
  CompanySettings company, {
  QuotationAccount? account,
}) async {
  final kit = await PdfKit.load(company);
  final t = kit.t;
  final style = kit.style;

  String orDash(String v) => v.trim().isEmpty ? '-' : t(v.trim());
  final line = pw.BorderSide(color: pdfLightGrey, width: 0.8);
  final gap = pw.SizedBox(height: 12);

  pw.Widget titleBar(String title) => pw.Container(
    color: _sectionFill,
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    child: pw.Text(title, style: style(size: 10, bold: true)),
  );

  /// Bordered box with a full-width grey title bar.
  pw.Widget section(String title, List<pw.Widget> children) => pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: pdfLightGrey, width: 0.8),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [titleBar(title), ...children],
    ),
  );

  /// Small grey label above the value.
  pw.Widget field(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label.toUpperCase(), style: style(size: 7.5, color: pdfGrey)),
        pw.SizedBox(height: 2),
        pw.Text(orDash(value), style: style(size: 10.5)),
      ],
    ),
  );

  /// One grid row: fields side by side, hairline below (except the last).
  pw.Widget fieldRow(List<pw.Widget> fields, {bool last = false}) =>
      pw.Container(
        decoration: last
            ? null
            : pw.BoxDecoration(border: pw.Border(bottom: line)),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [for (final f in fields) pw.Expanded(child: f)],
        ),
      );

  /// Equal-width cells in one row (status strip, payment summary).
  pw.Widget tiles(List<pw.Widget> cells) => pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < cells.length; i++)
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: i == 0
                ? null
                : pw.BoxDecoration(border: pw.Border(left: line)),
            child: cells[i],
          ),
        ),
    ],
  );

  pw.Widget statusTile(String label, String value) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(label.toUpperCase(), style: style(size: 7.5, color: pdfGrey)),
      pw.SizedBox(height: 4),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: pw.BoxDecoration(
          color: _statusColor(value),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Text(
          value.toUpperCase(),
          style: style(size: 8, bold: true, color: PdfColors.white),
        ),
      ),
    ],
  );

  pw.Widget amountTile(String label, double value, {PdfColor? color}) =>
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label.toUpperCase(), style: style(size: 7.5, color: pdfGrey)),
          pw.SizedBox(height: 2),
          pw.Text(
            kit.money(value),
            style: style(size: 12, bold: true, color: color),
          ),
        ],
      );

  final serials = p.serialNumbers
      .split('\n')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  // Serial numbers in two numbered columns.
  final serialRows = <pw.Widget>[
    for (var i = 0; i < serials.length; i += 2)
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: i + 2 >= serials.length
            ? null
            : pw.BoxDecoration(border: pw.Border(bottom: line)),
        child: pw.Row(
          children: [
            for (final j in [i, i + 1])
              pw.Expanded(
                child: j < serials.length
                    ? pw.Text(
                        '${j + 1}.  ${t(serials[j])}',
                        style: style(size: 10),
                      )
                    : pw.SizedBox(),
              ),
          ],
        ),
      ),
  ];

  // Photos: two per row, fixed height so pages break cleanly.
  final images = <pw.MemoryImage>[];
  for (final path in p.photos) {
    final file = File(path);
    if (await file.exists()) {
      images.add(pw.MemoryImage(await file.readAsBytes()));
    }
  }
  final photoRows = <pw.Widget>[
    for (var i = 0; i < images.length; i += 2)
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 8),
        child: pw.Row(
          children: [
            for (final j in [i, i + 1]) ...[
              pw.Expanded(
                child: j < images.length
                    ? pw.Container(
                        height: 170,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(
                            color: pdfLightGrey,
                            width: 0.8,
                          ),
                        ),
                        child: pw.Image(images[j], fit: pw.BoxFit.cover),
                      )
                    : pw.SizedBox(),
              ),
              if (j == i) pw.SizedBox(width: 10),
            ],
          ],
        ),
      ),
  ];

  final hasPayment = p.projectAmount != 0 || p.amountReceived != 0;

  /// Date / description / amount table with a bold total row.
  pw.Widget ledger(
    List<(DateTime, String, double)> rows,
    String totalLabel,
    double total,
    PdfColor color,
  ) {
    pw.Widget cell(
      String text, {
      bool bold = false,
      PdfColor? textColor,
      pw.TextAlign align = pw.TextAlign.left,
    }) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: style(size: 9.5, bold: bold, color: textColor),
      ),
    );

    return pw.Table(
      columnWidths: const {
        0: pw.FixedColumnWidth(78),
        1: pw.FlexColumnWidth(),
        2: pw.FixedColumnWidth(90),
      },
      border: pw.TableBorder(horizontalInside: line),
      children: [
        for (final (date, text, amount) in rows)
          pw.TableRow(
            children: [
              cell(formatDate(date)),
              cell(orDash(text)),
              cell(kit.money(amount), align: pw.TextAlign.right),
            ],
          ),
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _sectionFill),
          children: [
            pw.SizedBox(),
            cell(totalLabel, bold: true),
            cell(
              kit.money(total),
              bold: true,
              textColor: color,
              align: pw.TextAlign.right,
            ),
          ],
        ),
      ],
    );
  }

  final a = account;
  final accountSections = a == null
      ? <pw.Widget>[]
      : [
          gap,
          section('ACCOUNT  (QUOTATION #${a.quotation.quoteNumber})', [
            tiles([
              amountTile('Quote Value', a.quoteValue),
              amountTile('Advance Received', a.advanceReceived, color: _green),
              amountTile('Total Expenses', a.totalExpenses, color: _red),
              amountTile(
                a.margin < 0 ? 'Loss' : 'Balance',
                a.margin,
                color: a.margin < 0 ? _red : _green,
              ),
            ]),
            pw.Container(
              decoration: pw.BoxDecoration(border: pw.Border(top: line)),
              child: tiles([
                amountTile('Pending From Customer', a.pendingFromCustomer),
                amountTile(
                  'Advance Left After Expenses',
                  a.cashInHand,
                  color: a.cashInHand < 0 ? _red : null,
                ),
              ]),
            ),
          ]),
          if (a.advances.isNotEmpty) ...[
            gap,
            section('ADVANCES RECEIVED', [
              ledger(
                [
                  for (final x in a.advances)
                    (
                      x.date,
                      [
                        x.paymentMode,
                        if (x.notes.trim().isNotEmpty) x.notes.trim(),
                      ].join(' - '),
                      x.amount,
                    ),
                ],
                'Total advance',
                a.advanceReceived,
                _green,
              ),
            ]),
          ],
          if (a.expenses.isNotEmpty) ...[
            gap,
            section('EXPENSES', [
              ledger(
                [
                  for (final e in [
                    ...a.expenses,
                  ]..sort((x, y) => x.date.compareTo(y.date)))
                    (
                      e.date,
                      [
                        e.category,
                        if (e.description.trim().isNotEmpty)
                          e.description.trim(),
                        if (e.paidTo.trim().isNotEmpty) e.paidTo.trim(),
                      ].join(' - '),
                      e.amount,
                    ),
                ],
                'Total expenses',
                a.totalExpenses,
                _red,
              ),
              pw.Container(
                decoration: pw.BoxDecoration(border: pw.Border(top: line)),
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: pw.Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    for (final c in a.byCategory)
                      pw.Text(
                        '${t(c.key)}: ${kit.money(c.value)}',
                        style: style(size: 9, color: pdfGrey),
                      ),
                  ],
                ),
              ),
            ]),
          ],
        ];

  final doc = kit.document('Project File ${p.projectNumber}');
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
              'PROJECT FILE',
              style: style(size: 18, bold: true).copyWith(letterSpacing: 4),
            ),
          ),
        ),
        kit.band([
          ('Project No.:', p.projectNumber),
          ('Date:', formatDate(p.createdDate)),
          (
            'Installation Date:',
            p.installationDate == null ? '-' : formatDate(p.installationDate!),
          ),
        ]),
        gap,
        section('CUSTOMER DETAILS', [
          fieldRow([
            field('Customer Name', p.customerName.toUpperCase()),
            field('Mobile', p.customerPhone),
          ]),
          fieldRow([
            field('Consumer No.', p.consumerNo),
            field('KSEB Application No.', p.ksebApplicationNo),
          ]),
          fieldRow([field('Address', p.customerAddress)], last: true),
        ]),
        gap,
        section('SYSTEM DETAILS', [
          fieldRow([
            field('System Capacity', p.systemCapacity),
            field('Panel Details', p.panelDetails),
          ]),
          fieldRow([field('Inverter Details', p.inverterDetails)], last: true),
        ]),
        if (serialRows.isNotEmpty) ...[
          gap,
          section('SERIAL NUMBERS', [
            pw.SizedBox(height: 3),
            ...serialRows,
            pw.SizedBox(height: 3),
          ]),
        ],
        gap,
        section('PROJECT STATUS', [
          tiles([
            statusTile('Inspection', p.inspectionStatus),
            statusTile('Net Meter', p.netMeterStatus),
            statusTile('Subsidy', p.subsidyStatus),
            statusTile('Payment', p.paymentStatus),
          ]),
        ]),
        if (hasPayment) ...[
          gap,
          section('PAYMENT', [
            tiles([
              amountTile('Project Amount', p.projectAmount),
              amountTile('Amount Received', p.amountReceived, color: _green),
              amountTile(
                'Balance',
                p.balance,
                color: p.balance > 0 ? _red : _green,
              ),
            ]),
          ]),
        ],
        ...accountSections,
        if (p.notes.trim().isNotEmpty) ...[
          gap,
          section('NOTES', [
            pw.Padding(
              padding: const pw.EdgeInsets.all(10),
              child: pw.Text(t(p.notes.trim()), style: style(size: 10)),
            ),
          ]),
        ],
        if (photoRows.isNotEmpty) ...[
          gap,
          titleBar('SITE PHOTOS'),
          ...photoRows,
        ],
        pw.SizedBox(height: 22),
        pw.Align(alignment: pw.Alignment.centerRight, child: kit.signatory()),
      ],
    ),
  );

  return doc.save();
}

String projectPdfFileName(ProjectFile p) =>
    buildPdfFileName(p.projectNumber, 'project_file', p.customerName);

Future<void> shareProjectPdf(
  BuildContext context,
  ProjectFile p,
  CompanySettings company, {
  Future<Uint8List>? bytes,
  QuotationAccount? account,
}) => sharePdfFile(
  context,
  bytes: bytes ?? generateProjectPdfBytes(p, company, account: account),
  fileName: projectPdfFileName(p),
  message: 'Project File #${p.projectNumber} from ${company.name}',
);
