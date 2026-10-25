import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../app_state.dart';
import '../models.dart';
import '../project_pdf.dart';
import '../theme.dart';
import '../utils.dart';
import 'project_actions.dart';
import 'quotation_account_page.dart';

class ProjectPreviewPage extends StatefulWidget {
  final AppState appState;
  final String projectId;

  const ProjectPreviewPage({
    super.key,
    required this.appState,
    required this.projectId,
  });

  @override
  State<ProjectPreviewPage> createState() => _ProjectPreviewPageState();
}

class _ProjectPreviewPageState extends State<ProjectPreviewPage> {
  Future<Uint8List>? _bytes;
  String _builtFrom = '';

  ProjectFile? get _project {
    for (final p in widget.appState.projects) {
      if (p.id == widget.projectId) return p;
    }
    return null;
  }

  /// Rebuilds the PDF only when the project, company or the linked
  /// quotation's account (quote, advances, expenses) changed.
  Future<Uint8List> _pdfFor(ProjectFile p) {
    final account = widget.appState.accountForProject(p);
    final key = [
      p.toJson(),
      widget.appState.company.toJson(),
      account?.quotation.toJson(),
      account?.advances.map((a) => a.toJson()).toList(),
      account?.expenses.map((e) => e.toJson()).toList(),
    ].toString();
    if (_bytes == null || key != _builtFrom) {
      _builtFrom = key;
      _bytes = generateProjectPdfBytes(
        p,
        widget.appState.company,
        account: account,
      );
    }
    return _bytes!;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, _) {
        final p = _project;
        if (p == null) return const Scaffold();
        final bytes = _pdfFor(p);

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Project File #${p.projectNumber}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  p.customerName,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () => showProjectActions(
                  context,
                  widget.appState,
                  p,
                  fromPreview: true,
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              _AccountBar(appState: widget.appState, project: p),
              Expanded(child: _pdf(p, bytes)),
            ],
          ),
          bottomNavigationBar: _bottomBar(p, bytes),
        );
      },
    );
  }

  Widget _pdf(ProjectFile p, Future<Uint8List> bytes) => PdfPreview(
    key: ValueKey(_builtFrom),
    build: (_) => bytes,
    initialPageFormat: PdfPageFormat.a4,
    pdfFileName: projectPdfFileName(p),
    canChangePageFormat: false,
    canChangeOrientation: false,
    canDebug: false,
    allowSharing: false,
    allowPrinting: true,
    scrollViewDecoration: const BoxDecoration(color: AppColors.background),
    previewPageMargin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    actionBarTheme: const PdfActionBarTheme(
      backgroundColor: Colors.white,
      iconColor: AppColors.navy,
    ),
  );

  Widget _bottomBar(ProjectFile p, Future<Uint8List> bytes) => SafeArea(
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => openProjectEditor(context, widget.appState, p),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => shareProjectPdf(
                context,
                p,
                widget.appState.company,
                bytes: bytes,
              ),
              icon: const Icon(Icons.share, size: 18),
              label: const Text('Share'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.green),
            ),
          ),
        ],
      ),
    ),
  );
}

/// The linked quotation's money above the PDF; tap for the full account.
class _AccountBar extends StatelessWidget {
  final AppState appState;
  final ProjectFile project;
  const _AccountBar({required this.appState, required this.project});

  @override
  Widget build(BuildContext context) {
    final a = appState.accountForProject(project);
    if (a == null) {
      return Material(
        color: Colors.white,
        child: ListTile(
          leading: const Icon(Icons.link_off, color: AppColors.muted),
          title: const Text('No quotation linked'),
          subtitle: const Text('Link one to see its advance and expenses'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => openProjectEditor(context, appState, project),
        ),
      );
    }

    Widget figure(String label, double value, Color color) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatMoney(value),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 14.5,
              ),
            ),
          ),
        ],
      ),
    );

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => openQuotationAccount(context, appState, a.quotation),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    size: 18,
                    color: AppColors.navy,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Quotation #${a.quotation.quoteNumber}  •  '
                      '${formatMoney(a.quoteValue)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  const Text(
                    'Add / view',
                    style: TextStyle(
                      color: AppColors.blue,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.blue),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  figure('Advance', a.advanceReceived, AppColors.green),
                  figure('Expenses', a.totalExpenses, AppColors.red),
                  figure(
                    a.margin < 0 ? 'Loss' : 'Balance',
                    a.margin,
                    a.margin < 0 ? AppColors.red : AppColors.navy,
                  ),
                  figure('Pending', a.pendingFromCustomer, AppColors.text),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
