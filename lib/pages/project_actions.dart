import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../project_pdf.dart';
import '../theme.dart';
import 'project_editor_page.dart';
import 'project_preview_page.dart';

Future<void> openProjectPreview(
  BuildContext context,
  AppState appState,
  ProjectFile project,
) {
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          ProjectPreviewPage(appState: appState, projectId: project.id),
    ),
  );
}

/// Opens the editor. A new project is shown in the preview after saving.
Future<void> openProjectEditor(
  BuildContext context,
  AppState appState,
  ProjectFile project,
) async {
  final isNew = !appState.isProjectSaved(project.id);
  final saved = await Navigator.push<ProjectFile>(
    context,
    MaterialPageRoute(
      builder: (_) =>
          ProjectEditorPage(appState: appState, project: project, isNew: isNew),
    ),
  );
  if (saved != null && isNew && context.mounted) {
    await openProjectPreview(context, appState, saved);
  }
}

Future<void> createProject(
  BuildContext context,
  AppState appState, {
  Quotation? from,
}) => openProjectEditor(context, appState, appState.newProject(from: from));

Future<void> showProjectActions(
  BuildContext context,
  AppState appState,
  ProjectFile p, {
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
      }) => ListTile(
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

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Project #${p.projectNumber} · ${p.customerName}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Divider(),
            if (!fromPreview)
              tile(
                Icons.picture_as_pdf_outlined,
                'Preview PDF',
                () => openProjectPreview(context, appState, p),
              ),
            tile(
              Icons.edit_outlined,
              'Edit',
              () => openProjectEditor(context, appState, p),
            ),
            tile(
              Icons.share_outlined,
              'Share PDF',
              () => shareProjectPdf(context, p, appState.company),
            ),
            tile(Icons.delete_outline, 'Delete', () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete project file?'),
                  content: Text(
                    'Project #${p.projectNumber} for ${p.customerName} and '
                    'its photos will be permanently deleted.',
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
              if (ok == true) {
                await appState.deleteProject(p.id);
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
