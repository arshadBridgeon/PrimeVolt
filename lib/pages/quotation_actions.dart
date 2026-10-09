import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../pdf_service.dart';
import '../theme.dart';
import 'editor_page.dart';
import 'preview_page.dart';
import 'project_actions.dart';

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

Future<bool> confirmDelete(BuildContext context, Quotation q) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete quotation?'),
      content: Text(
        'Quotation #${q.quoteNumber} for ${q.customerName} will be '
        'permanently deleted.',
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
            tile(Icons.delete_outline, 'Delete', () async {
              if (await confirmDelete(context, q)) {
                await appState.deleteQuotation(q.id);
                if (fromPreview && context.mounted) Navigator.pop(context);
              }
            }, color: AppColors.red),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
