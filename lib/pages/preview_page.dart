import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../app_state.dart';
import '../models.dart';
import '../pdf_service.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'quotation_actions.dart';

class PreviewPage extends StatefulWidget {
  final AppState appState;
  final String quotationId;

  const PreviewPage({
    super.key,
    required this.appState,
    required this.quotationId,
  });

  @override
  State<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> {
  Future<Uint8List>? _bytes;
  String _builtFrom = '';

  Quotation? get _quotation {
    for (final q in widget.appState.quotations) {
      if (q.id == widget.quotationId) return q;
    }
    return null;
  }

  /// Rebuilds the PDF only when the quotation or company data changed.
  Future<Uint8List> _pdfFor(Quotation q) {
    final key = '${q.toJson()}${widget.appState.company.toJson()}';
    if (_bytes == null || key != _builtFrom) {
      _builtFrom = key;
      _bytes = generatePdfBytes(q, widget.appState.company);
    }
    return _bytes!;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, _) {
        final q = _quotation;
        if (q == null) return const Scaffold();
        final bytes = _pdfFor(q);

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quotation #${q.quoteNumber}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  q.customerName,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Center(child: StatusChip(q.status)),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () => showQuotationActions(
                  context,
                  widget.appState,
                  q,
                  fromPreview: true,
                ),
              ),
            ],
          ),
          body: PdfPreview(
            key: ValueKey(_builtFrom),
            build: (_) => bytes,
            initialPageFormat: PdfPageFormat.a4,
            pdfFileName: pdfFileName(q),
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
            allowSharing: false,
            allowPrinting: true,
            scrollViewDecoration: const BoxDecoration(
              color: AppColors.background,
            ),
            previewPageMargin: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            actionBarTheme: const PdfActionBarTheme(
              backgroundColor: Colors.white,
              iconColor: AppColors.navy,
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Amount',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          formatMoney(q.total),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => openEditor(context, widget.appState, q),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: () => sharePdf(
                      context,
                      q,
                      widget.appState.company,
                      bytes: bytes,
                    ),
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Share'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
