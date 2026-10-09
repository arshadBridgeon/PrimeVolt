import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'models.dart';
import 'utils.dart';

// Shared PDF building blocks (PdfKit) plus the quotation PDF, which mirrors
// the company's myBillBook layout: logo header, thick rule, grey number/date
// band, BILL TO, item table (qty only), notes/terms beside the totals, amount
// in words and signatory. The project file PDF (project_pdf.dart) reuses the
// same header and signatory so both documents look like one family.

const _logoAsset = 'assets/company_logo.png';

final pdfBlack = PdfColor.fromHex('#111111');
final pdfGrey = PdfColor.fromHex('#555555');
final pdfLightGrey = PdfColor.fromHex('#D9D9D9');
final pdfBand = PdfColor.fromHex('#E6E6E6');

class _PdfFonts {
  final pw.Font base;
  final pw.Font medium;
  final pw.Font bold;
  final pw.Font emoji;
  final pw.Font boldItalic;
  _PdfFonts(this.base, this.medium, this.bold, this.emoji, this.boldItalic);
}

_PdfFonts? _fontsCache;

/// Roboto has the ₹ glyph that the built-in Helvetica lacks; Noto Color Emoji
/// renders the 📌/📍 markers. `printing` downloads these once and caches them.
/// Returns null when offline on first use, and the PDF falls back to "Rs.".
Future<_PdfFonts?> _loadFonts() async {
  if (_fontsCache != null) return _fontsCache;
  try {
    _fontsCache = _PdfFonts(
      await PdfGoogleFonts.robotoRegular(),
      await PdfGoogleFonts.robotoMedium(),
      await PdfGoogleFonts.robotoBold(),
      await PdfGoogleFonts.notoColorEmoji(),
      await PdfGoogleFonts.robotoBoldItalic(),
    );
  } catch (e) {
    debugPrint('PDF font load failed, using built-in font: $e');
  }
  return _fontsCache;
}

/// Drops emoji and other characters the built-in PDF font cannot draw.
String _stripUnsupported(String text) => String.fromCharCodes(
  text.runes.where((r) => r <= 0x2000 || (r >= 0x2010 && r <= 0x2027)),
);

/// Fonts, logo, signature and the common header/footer widgets.
class PdfKit {
  final CompanySettings company;
  final _PdfFonts? _fonts;
  final pw.MemoryImage logo;
  final pw.MemoryImage? signature;

  PdfKit._(this.company, this._fonts, this.logo, this.signature);

  static Future<PdfKit> load(CompanySettings company) async {
    final fonts = await _loadFonts();
    final logo = pw.MemoryImage(
      (await rootBundle.load(_logoAsset)).buffer.asUint8List(),
    );
    pw.MemoryImage? signature;
    if (company.signaturePath.isNotEmpty) {
      final file = File(company.signaturePath);
      if (await file.exists()) {
        signature = pw.MemoryImage(await file.readAsBytes());
      }
    }
    return PdfKit._(company, fonts, logo, signature);
  }

  /// Text safe for the current font set.
  String t(String s) => _fonts == null ? _stripUnsupported(s) : s;

  String money(double v) =>
      formatMoney(v, symbol: _fonts == null ? 'Rs. ' : '₹ ');

  pw.TextStyle style({
    double size = 10,
    bool bold = false,
    bool semi = false,
    PdfColor? color,
  }) => pw.TextStyle(
    fontSize: size,
    font: semi ? _fonts?.medium : null,
    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    color: color ?? pdfBlack,
    lineSpacing: 1.5,
  );

  pw.Widget labelValue(String label, String value, {double size = 10.5}) =>
      pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$label ',
              style: style(size: size, bold: true),
            ),
            pw.TextSpan(
              text: t(value),
              style: style(size: size),
            ),
          ],
        ),
      );

  pw.Document document(String title) => pw.Document(
    theme: _fonts == null
        ? null
        : pw.ThemeData.withFont(
            base: _fonts.base,
            bold: _fonts.bold,
            boldItalic: _fonts.boldItalic,
            fontFallback: [_fonts.emoji],
          ),
    title: title,
    author: company.name,
  );

  /// Logo + company name (bold italic), address, mobiles, email, GSTIN.
  pw.Widget header() {
    final mobiles = [
      company.phone,
      company.phone2,
    ].where((p) => p.trim().isNotEmpty).join(', ');
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          width: 100,
          height: 100,
          child: pw.Image(logo, fit: pw.BoxFit.contain),
        ),
        pw.SizedBox(width: 18),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                t(company.name),
                style: style(
                  size: 22,
                  bold: true,
                ).copyWith(fontStyle: pw.FontStyle.italic),
              ),
              pw.SizedBox(height: 6),
              if (company.address.isNotEmpty)
                pw.Text(t(company.address), style: style(size: 10.5)),
              if (mobiles.isNotEmpty) labelValue('Mobile:', mobiles),
              if (company.email.isNotEmpty) labelValue('Email:', company.email),
              if (company.gst.isNotEmpty) labelValue('GSTIN:', company.gst),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget thickRule() => pw.Container(height: 5, color: pdfBlack);

  /// Grey strip of label/value pairs spread across the page.
  pw.Widget band(List<(String, String)> pairs) => pw.Container(
    color: pdfBand,
    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [for (final (l, v) in pairs) labelValue(l, v, size: 11)],
    ),
  );

  /// Signature image (if set) + "AUTHORISED SIGNATORY FOR" + company name.
  pw.Widget signatory() => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.end,
    children: [
      if (signature != null)
        pw.Container(
          height: 56,
          width: 130,
          alignment: pw.Alignment.centerRight,
          child: pw.Image(signature!, fit: pw.BoxFit.contain),
        )
      else
        pw.SizedBox(height: 56),
      pw.SizedBox(height: 6),
      pw.Text(
        '${t(company.signatory.toUpperCase())} FOR',
        style: style(size: 10, bold: true),
      ),
      pw.Text(t(company.name), style: style(size: 10)),
    ],
  );

  pw.MultiPage page(List<pw.Widget> Function(pw.Context) build) => pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(32, 26, 32, 28),
    footer: (context) => context.pagesCount < 2
        ? pw.SizedBox()
        : pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: style(size: 8, color: pdfGrey),
            ),
          ),
    build: build,
  );
}

// ------------------------------------------------------------
// Quotation PDF
// ------------------------------------------------------------

Future<Uint8List> generatePdfBytes(Quotation q, CompanySettings company) async {
  final kit = await PdfKit.load(company);
  final t = kit.t;
  final style = kit.style;
  final money = kit.money;

  final billTo = pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('BILL TO', style: style(size: 11, semi: true)),
      pw.SizedBox(height: 4),
      pw.Text(
        t(q.customerName.toUpperCase()),
        style: style(size: 11.5, bold: true),
      ),
      if (q.customerAddress.isNotEmpty)
        pw.Text(t(q.customerAddress), style: style(size: 10.5)),
      if (q.customerPhone.isNotEmpty)
        kit.labelValue('Mobile:', q.customerPhone),
      if (q.customerEmail.isNotEmpty) kit.labelValue('Email:', q.customerEmail),
    ],
  );

  // ---------- Items table ----------
  const cellPad = pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7);
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

  final headerStyle = style(size: 10.5, semi: true);
  final rows = <pw.TableRow>[
    pw.TableRow(
      repeat: true,
      decoration: pw.BoxDecoration(
        border: pw.Border(top: thick, bottom: thick),
      ),
      children: [
        cell('ITEMS', textStyle: headerStyle),
        cell('QTY.', align: pw.TextAlign.center, textStyle: headerStyle),
      ],
    ),
    for (final item in q.items)
      pw.TableRow(
        decoration: pw.BoxDecoration(border: pw.Border(bottom: thin)),
        children: [
          pw.Padding(
            padding: cellPad,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(t(item.name), style: style(size: 10.5)),
                if (item.description.trim().isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 2),
                    child: pw.Text(
                      t(item.description.trim()),
                      style: style(size: 8.5, color: pdfGrey),
                    ),
                  ),
              ],
            ),
          ),
          cell(
            '${formatQty(item.quantity)} ${item.unit}'.trim(),
            align: pw.TextAlign.center,
          ),
        ],
      ),
    pw.TableRow(
      decoration: pw.BoxDecoration(
        border: pw.Border(top: thick, bottom: thick),
      ),
      children: [
        cell('SUBTOTAL', textStyle: style(size: 10.5, bold: true)),
        cell(
          formatQty(q.totalQuantity),
          align: pw.TextAlign.center,
          textStyle: style(size: 10.5, bold: true),
        ),
      ],
    ),
  ];

  // Prices are not shown per item; only the totals block shows money.
  final table = pw.Table(
    columnWidths: const {0: pw.FlexColumnWidth(8), 1: pw.FlexColumnWidth(1.5)},
    children: rows,
  );

  // ---------- Notes & terms (left) ----------
  pw.Widget block(String title, String body) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 14),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: style(size: 10.5, bold: true)),
        pw.SizedBox(height: 4),
        pw.Text(t(body.trim()), style: style(size: 10)),
      ],
    ),
  );

  final left = pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      if (q.notes.trim().isNotEmpty) block('NOTES', q.notes),
      if (q.terms.trim().isNotEmpty) block('TERMS AND CONDITIONS', q.terms),
    ],
  );

  // ---------- Totals (right) ----------
  pw.Widget summaryRow(String label, String value, {bool strong = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 5),
        child: pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                label,
                textAlign: pw.TextAlign.center,
                style: style(size: 10.5, bold: strong),
              ),
            ),
            pw.Text(value, style: style(size: 10.5, bold: strong)),
          ],
        ),
      );

  final right = pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.end,
    children: [
      if (q.subtotal != 0 && q.total != q.subtotal)
        summaryRow('Subtotal', money(q.subtotal)),
      if (q.discount > 0) summaryRow('Discount', '- ${money(q.discount)}'),
      if (q.tax > 0)
        summaryRow('Tax (${formatQty(q.tax)}%)', money(q.taxAmount)),
      if (q.additional > 0)
        summaryRow('Additional Charges', money(q.additional)),
      if (q.roundOff != 0) summaryRow('Round Off', money(q.roundOff)),
      pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border(
            top: pw.BorderSide(color: pdfBlack, width: 0.8),
            bottom: pw.BorderSide(color: pdfBlack, width: 0.8),
          ),
        ),
        child: summaryRow('Total Amount', money(q.total), strong: true),
      ),
      pw.SizedBox(height: 18),
      pw.Text('Total Amount (in words)', style: style(size: 10.5, bold: true)),
      pw.SizedBox(height: 3),
      pw.Text(
        amountInWords(q.total),
        textAlign: pw.TextAlign.right,
        style: style(size: 10.5),
      ),
      pw.SizedBox(height: 18),
      kit.signatory(),
    ],
  );

  final doc = kit.document('Quotation ${q.quoteNumber}');
  doc.addPage(
    kit.page(
      (context) => [
        pw.Text('QUOTATION', style: style(size: 10.5, semi: true)),
        pw.SizedBox(height: 10),
        kit.header(),
        pw.SizedBox(height: 14),
        kit.thickRule(),
        kit.band([
          ('Quotation No.:', q.quoteNumber),
          ('Quotation Date:', formatDate(q.quotationDate)),
          ('Expiry Date:', formatDate(q.expiryDate)),
        ]),
        pw.SizedBox(height: 12),
        billTo,
        pw.SizedBox(height: 14),
        table,
        pw.SizedBox(height: 12),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(flex: 11, child: left),
            pw.SizedBox(width: 28),
            pw.Expanded(flex: 8, child: right),
          ],
        ),
      ],
    ),
  );

  return doc.save();
}

/// "0259_quotation_LATHEEFKA.pdf" style names.
String buildPdfFileName(String number, String kind, String customerName) {
  final customer = customerName
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return '${number}_$kind${customer.isEmpty ? '' : '_$customer'}.pdf';
}

String pdfFileName(Quotation q) =>
    buildPdfFileName(q.quoteNumber, 'quotation', q.customerName);

/// Writes PDF bytes to the temp dir and opens the share sheet (e.g. WhatsApp).
Future<void> sharePdfFile(
  BuildContext context, {
  required Future<Uint8List> bytes,
  required String fileName,
  required String message,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final pdfBytes = await bytes;
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$fileName';
    await File(path).writeAsBytes(pdfBytes);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path, mimeType: 'application/pdf')],
        text: message,
      ),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Could not share PDF: $e')));
  }
}

Future<void> sharePdf(
  BuildContext context,
  Quotation q,
  CompanySettings company, {
  Future<Uint8List>? bytes,
}) => sharePdfFile(
  context,
  bytes: bytes ?? generatePdfBytes(q, company),
  fileName: pdfFileName(q),
  message: 'Quotation #${q.quoteNumber} from ${company.name}',
);
