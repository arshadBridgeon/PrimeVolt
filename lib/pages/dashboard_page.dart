import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../glass_nav_bar.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'customers_page.dart';
import 'project_actions.dart';
import 'quotation_actions.dart';

class DashboardPage extends StatelessWidget {
  final AppState appState;
  final VoidCallback onOpenQuotations;

  const DashboardPage({
    super.key,
    required this.appState,
    required this.onOpenQuotations,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final recent = appState.quotations.take(5).toList();
        final pending =
            appState.countWithStatus('Draft') +
            appState.countWithStatus('Sent');

        // Light status-bar icons over the navy header.
        return Scaffold(
          body: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _Header(appState: appState)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            _StatTile(
                              icon: Icons.receipt_long,
                              label: 'Quotations',
                              value: '${appState.totalQuotations}',
                              color: AppColors.navy,
                            ),
                            const SizedBox(width: 12),
                            _StatTile(
                              icon: Icons.check_circle,
                              label: 'Accepted',
                              value: '${appState.countWithStatus('Accepted')}',
                              color: AppColors.green,
                            ),
                            const SizedBox(width: 12),
                            _StatTile(
                              icon: Icons.schedule,
                              label: 'Pending',
                              value: '$pending',
                              color: AppColors.sun,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () => createQuotation(context, appState),
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('Create New Quotation'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    createProject(context, appState),
                                icon: const Icon(
                                  Icons.create_new_folder_outlined,
                                ),
                                label: const Text('Project File'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(52),
                                  backgroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        CustomersPage(appState: appState),
                                  ),
                                ),
                                icon: const Icon(Icons.people_outline),
                                label: const Text('Customers'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(52),
                                  backgroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            const Text(
                              'Recent quotations',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                            ),
                            const Spacer(),
                            if (appState.quotations.isNotEmpty)
                              TextButton(
                                onPressed: onOpenQuotations,
                                child: const Text('See all'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
                if (recent.isEmpty)
                  const SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.description_outlined,
                      title: 'No quotations yet',
                      message:
                          'Tap "Create New Quotation" to make your first one.\n'
                          'The standard items are filled in for you.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      navBarClearance(context) + 12,
                    ),
                    sliver: SliverList.separated(
                      itemCount: recent.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final q = recent[index];
                        return QuotationCard(
                          quotation: q,
                          createdBy: appState.creatorName(
                            q.createdByUid,
                            q.createdByName,
                          ),
                          onTap: () => openPreview(context, appState, q),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final AppState appState;
  const _Header({required this.appState});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 18, 20, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.navy, AppColors.navyDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Image.asset('assets/app_icon.png', fit: BoxFit.contain),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appState.company.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Quotation Generator',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _HeaderValue(
                    label: 'This month',
                    value: formatMoney(appState.thisMonthValue),
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _HeaderValue(
                    label: 'All quotations',
                    value: formatMoney(appState.totalValue),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderValue extends StatelessWidget {
  final String label;
  final String value;
  const _HeaderValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12.5,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
