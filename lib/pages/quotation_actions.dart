import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../pdf_service.dart';
import '../theme.dart';
import '../utils.dart';
import 'editor_page.dart';
import 'preview_page.dart';
import 'project_actions.dart';
import 'quotation_account_page.dart';

Future<void> openPreview(
  BuildContext context,
  AppState appState,
  Quotation quotation,
) {
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          PreviewPage(appState: appState, quotationId: quotation.id),
    ),
  );
}

/// Opens the editor. A new quotation is shown in the preview after saving.
Future<void> openEditor(
  BuildContext context,
  AppState appState,
  Quotation quotation,
) async {
  final isNew = !appState.isSaved(quotation.id);
  final saved = await Navigator.push<Quotation>(
    context,
    MaterialPageRoute(
      builder: (_) => QuotationEditorPage(
        appState: appState,
        quotation: quotation,
        isNew: isNew,
      ),
    ),
  );
  if (saved != null && isNew && context.mounted) {
    await openPreview(context, appState, saved);
  }
}

Future<void> createQuotation(
  BuildContext context,
  AppState appState, {
  String customerName = '',
  String customerPhone = '',
  String customerAddress = '',
}) {
  return openEditor(
    context,
    appState,
    appState.newQuotation(
      customerName: customerName,
      customerPhone: customerPhone,
      customerAddress: customerAddress,
    ),
  );
}

/// Searchable quotation list. Returns the picked id, '' for [noneLabel], or
/// null when dismissed. With [showProjects], quotations that already have a
/// project file are tagged so the same job isn't filed twice by mistake.
Future<String?> pickQuotation(
  BuildContext context,
  AppState appState, {
  String selectedId = '',
  String title = 'Select quotation',
  String noneLabel = 'No quotation',
  bool showProjects = false,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    builder: (context) => _QuotationPickerSheet(
      appState: appState,
      selectedId: selectedId,
      title: title,
      noneLabel: noneLabel,
      showProjects: showProjects,
    ),
  );
}

class _QuotationPickerSheet extends StatefulWidget {
  final AppState appState;
  final String selectedId;
  final String title;
  final String noneLabel;
  final bool showProjects;
  const _QuotationPickerSheet({
    required this.appState,
    required this.selectedId,
    required this.title,
    required this.noneLabel,
    required this.showProjects,
  });

  @override
  State<_QuotationPickerSheet> createState() => _QuotationPickerSheetState();
}

class _QuotationPickerSheetState extends State<_QuotationPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final list = widget.appState.quotations.where(
      (q) =>
          query.isEmpty ||
          q.customerName.toLowerCase().contains(query) ||
          q.quoteNumber.contains(query) ||
          q.customerPhone.contains(query),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Search customer or quotation no.',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.block),
                      title: Text(widget.noneLabel),
                      onTap: () => Navigator.pop(context, ''),
                    ),
                    for (final q in list)
                      ListTile(
                        leading: const Icon(
                          Icons.receipt_long_outlined,
                          color: AppColors.navy,
                        ),
                        title: Text(
                          q.customerName.isEmpty ? 'No name' : q.customerName,
                        ),
                        subtitle: Text(
                          [
                            '#${q.quoteNumber}',
                            formatMoney(q.total),
                            if (widget.showProjects)
                              for (final p in widget.appState.projects)
                                if (p.quotationId == q.id)
                                  'Project #${p.projectNumber} exists',
                          ].join('  •  '),
                        ),
                        selected: q.id == widget.selectedId,
                        onTap: () => Navigator.pop(context, q.id),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool> confirmDelete(BuildContext context, Quotation q) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete quotation?'),
      content: Text(
        'Quotation #${q.quoteNumber} for ${q.customerName} and the advances '
        'recorded against it will be permanently deleted. Its expenses stay '
        'in the expense list.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.red,
            minimumSize: const Size(0, 40),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Bottom sheet with every action available on a saved quotation.
Future<void> showQuotationActions(
  BuildContext context,
  AppState appState,
  Quotation q, {
  bool fromPreview = false,
}) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    // Lets the sheet grow past the default 9/16 height; the content scrolls
    // when it is still taller than the screen.
    isScrollControlled: true,
    backgroundColor: Colors.white,
    builder: (sheetContext) {
      Widget tile(
        IconData icon,
        String label,
        VoidCallback onTap, {
        Color? color,
      }) {
        return ListTile(
          leading: Icon(icon, color: color ?? AppColors.navy),
          title: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: color ?? AppColors.text,
            ),
          ),
          onTap: () {
            Navigator.pop(sheetContext);
            onTap();
          },
        );
      }

      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  '#${q.quoteNumber} · ${q.customerName}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final status in quotationStatuses)
                      ChoiceChip(
                        label: Text(status),
                        selected: q.status == status,
                        selectedColor: statusColor(
                          status,
                        ).withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          color: q.status == status
                              ? statusColor(status)
                              : AppColors.text,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (_) {
                          Navigator.pop(sheetContext);
                          appState.setStatus(q, status);
                        },
                      ),
                  ],
                ),
              ),
              const Divider(),
              if (!fromPreview)
                tile(
                  Icons.picture_as_pdf_outlined,
                  'Preview PDF',
                  () => openPreview(context, appState, q),
                ),
              tile(
                Icons.edit_outlined,
                'Edit',
                () => openEditor(context, appState, q),
              ),
              tile(
                Icons.account_balance_wallet_outlined,
                'Advance & expenses',
                () => openQuotationAccount(context, appState, q),
              ),
              tile(
                Icons.share_outlined,
                'Share PDF',
                () => sharePdf(context, q, appState.company),
              ),
              tile(
                Icons.copy_all_outlined,
                'Duplicate',
                () => openEditor(context, appState, appState.duplicate(q)),
              ),
              tile(
                Icons.create_new_folder_outlined,
                'Create project file',
                () => createProject(context, appState, from: q),
              ),
              if (appState.canDeleteQuotation(q))
                tile(Icons.delete_outline, 'Delete', () async {
                  if (await confirmDelete(context, q)) {
                    await appState.deleteQuotation(q.id);
                    if (fromPreview && context.mounted) Navigator.pop(context);
                  }
                }, color: AppColors.red)
              else
                ListTile(
                  enabled: false,
                  leading: const Icon(Icons.lock_outline),
                  title: Text(
                    'Only ${appState.creatorName(q.createdByUid, q.createdByName)} '
                    'can delete this',
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}
