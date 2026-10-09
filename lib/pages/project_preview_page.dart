import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../app_state.dart';
import '../models.dart';
import '../project_pdf.dart';
import '../theme.dart';
import 'project_actions.dart';

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

  /// Rebuilds the PDF only when the project or company data changed.
  Future<Uint8List> _pdfFor(ProjectFile p) {
    final key = '${p.toJson()}${widget.appState.company.toJson()}';
    if (_bytes == null || key != _builtFrom) {
      _builtFrom = key;
      _bytes = generateProjectPdfBytes(p, widget.appState.company);
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
          body: PdfPreview(
            key: ValueKey(_builtFrom),
            build: (_) => bytes,
            initialPageFormat: PdfPageFormat.a4,
            pdfFileName: projectPdfFileName(p),
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
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          openProjectEditor(context, widget.appState, p),
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
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.green,
                      ),
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
