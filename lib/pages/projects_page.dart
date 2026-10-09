import 'package:flutter/material.dart';

import '../app_state.dart';
import '../glass_nav_bar.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'project_actions.dart';

class ProjectsPage extends StatefulWidget {
  final AppState appState;
  const ProjectsPage({super.key, required this.appState});

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final query = _query.trim().toLowerCase();
        final list = appState.projects.where((p) {
          if (query.isEmpty) return true;
          return p.customerName.toLowerCase().contains(query) ||
              p.customerPhone.contains(query) ||
              p.consumerNo.contains(query) ||
              p.projectNumber.contains(query);
        }).toList();

        return Scaffold(
          appBar: AppBar(title: const Text('Project Files')),
          floatingActionButton: Padding(
            padding: EdgeInsets.only(bottom: navBarClearance(context)),
            child: FloatingActionButton.extended(
              onPressed: () => createProject(context, appState),
              icon: const Icon(Icons.add),
              label: const Text('New'),
            ),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Search customer, consumer no. or number',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? EmptyState(
                        icon: Icons.folder_open_outlined,
                        title: appState.projects.isEmpty
                            ? 'No project files yet'
                            : 'Nothing found',
                        message: appState.projects.isEmpty
                            ? 'Create a project file for each installation, '
                                  'or make one from a quotation.'
                            : 'Try a different search.',
                      )
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          4,
                          16,
                          navBarClearance(context) + 84,
                        ),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) => ProjectCard(
                          project: list[index],
                          appState: appState,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ProjectCard extends StatelessWidget {
  final ProjectFile project;
  final AppState appState;
  const ProjectCard({super.key, required this.project, required this.appState});

  @override
  Widget build(BuildContext context) {
    final p = project;
    final creator = appState.creatorName(p.createdByUid, p.createdByName);
    final subtitle = [
      '#${p.projectNumber}',
      if (p.systemCapacity.isNotEmpty) p.systemCapacity,
      if (p.installationDate != null) formatDateShort(p.installationDate!),
    ].join('  •  ');

    Widget dot(String label, String status) => Padding(
      padding: const EdgeInsets.only(right: 6, top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: projectStatusColor(status).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: projectStatusColor(status),
          ),
        ),
      ),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openProjectPreview(context, appState, p),
        onLongPress: () => showProjectActions(context, appState, p),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.sun.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.solar_power, color: AppColors.sun),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.customerName.isEmpty ? 'No customer' : p.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12.5,
                      ),
                    ),
                    if (creator.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      CreatedByTag(creator),
                    ],
                    Wrap(
                      children: [
                        dot('Inspection', p.inspectionStatus),
                        dot('Net meter', p.netMeterStatus),
                        dot('Subsidy', p.subsidyStatus),
                        dot('Payment', p.paymentStatus),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${p.stagesDone}/4',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.navy,
                    ),
                  ),
                  const Text(
                    'done',
                    style: TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
