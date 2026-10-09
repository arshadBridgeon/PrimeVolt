import 'package:flutter/material.dart';

import '../app_state.dart';
import '../glass_nav_bar.dart';
import '../models.dart';
import '../pdf_service.dart';
import '../theme.dart';
import '../widgets.dart';
import 'quotation_actions.dart';

class QuotationsPage extends StatefulWidget {
  final AppState appState;
  const QuotationsPage({super.key, required this.appState});

  @override
  State<QuotationsPage> createState() => _QuotationsPageState();
}

class _QuotationsPageState extends State<QuotationsPage> {
  String _query = '';
  String? _status;

  List<Quotation> _filtered() {
    final query = _query.trim().toLowerCase();
    return widget.appState.quotations.where((q) {
      if (_status != null && q.status != _status) return false;
      if (query.isEmpty) return true;
      return q.customerName.toLowerCase().contains(query) ||
          q.customerPhone.contains(query) ||
          q.quoteNumber.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final list = _filtered();
        return Scaffold(
          appBar: AppBar(title: const Text('Quotations')),
          floatingActionButton: Padding(
            padding: EdgeInsets.only(bottom: navBarClearance(context)),
            child: FloatingActionButton.extended(
              onPressed: () => createQuotation(context, appState),
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
                    hintText: 'Search customer, mobile or number',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final status in [null, ...quotationStatuses])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(status ?? 'All'),
                          selected: _status == status,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _status = status),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: list.isEmpty
                    ? EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: appState.quotations.isEmpty
                            ? 'No quotations yet'
                            : 'Nothing found',
                        message: appState.quotations.isEmpty
                            ? 'Create a quotation and it will appear here.'
                            : 'Try a different search or filter.',
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
                        itemBuilder: (context, index) {
                          final q = list[index];
                          return GestureDetector(
                            onLongPress: () =>
                                showQuotationActions(context, appState, q),
                            child: QuotationCard(
                              quotation: q,
                              createdBy: appState.creatorName(
                                q.createdByUid,
                                q.createdByName,
                              ),
                              onTap: () => openPreview(context, appState, q),
                              trailing: IconButton(
                                tooltip: 'Share PDF',
                                icon: const Icon(
                                  Icons.share,
                                  color: AppColors.green,
                                ),
                                onPressed: () =>
                                    sharePdf(context, q, appState.company),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
