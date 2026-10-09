import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'quotation_actions.dart';

/// Customers are derived from saved quotations; there is no separate list.
class CustomersPage extends StatefulWidget {
  final AppState appState;
  const CustomersPage({super.key, required this.appState});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final query = _query.trim().toLowerCase();
        final customers = appState.customers
            .where(
              (c) =>
                  query.isEmpty ||
                  c.name.toLowerCase().contains(query) ||
                  c.phone.contains(query),
            )
            .toList();

        return Scaffold(
          appBar: AppBar(title: const Text('Customers')),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Search customers',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              Expanded(
                child: customers.isEmpty
                    ? const EmptyState(
                        icon: Icons.people_outline,
                        title: 'No customers yet',
                        message:
                            'Customers appear here after you save a '
                            'quotation for them.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: customers.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) => _CustomerCard(
                          customer: customers[index],
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

class _CustomerCard extends StatelessWidget {
  final CustomerSummary customer;
  final AppState appState;
  const _CustomerCard({required this.customer, required this.appState});

  @override
  Widget build(BuildContext context) {
    final count = customer.quotations.length;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _CustomerDetailPage(
              appState: appState,
              name: customer.name,
              phone: customer.phone,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.green.withValues(alpha: 0.12),
                child: Text(
                  customer.name.characters.first.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.green,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (customer.phone.isNotEmpty) customer.phone,
                        '$count quotation${count == 1 ? '' : 's'}',
                      ].join('  •  '),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                formatMoney(customer.totalValue),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerDetailPage extends StatelessWidget {
  final AppState appState;
  final String name;
  final String phone;

  const _CustomerDetailPage({
    required this.appState,
    required this.name,
    required this.phone,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final match = appState.customers.where(
          (c) => c.name.toLowerCase() == name.toLowerCase() && c.phone == phone,
        );
        final customer = match.isEmpty ? null : match.first;
        final quotations = customer?.quotations ?? [];

        return Scaffold(
          appBar: AppBar(title: Text(name)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (phone.isNotEmpty)
                      _InfoLine(icon: Icons.phone_outlined, text: phone),
                    if ((customer?.address ?? '').isNotEmpty)
                      _InfoLine(
                        icon: Icons.location_on_outlined,
                        text: customer!.address,
                      ),
                    _InfoLine(
                      icon: Icons.currency_rupee,
                      text:
                          '${formatMoney(customer?.totalValue ?? 0)} across '
                          '${quotations.length} quotation'
                          '${quotations.length == 1 ? '' : 's'}',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => createQuotation(
                        context,
                        appState,
                        customerName: name,
                        customerPhone: phone,
                        customerAddress: customer?.address ?? '',
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('New quotation for this customer'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Quotations',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              for (final q in quotations) ...[
                QuotationCard(
                  quotation: q,
                  createdBy: appState.creatorName(
                    q.createdByUid,
                    q.createdByName,
                  ),
                  onTap: () => openPreview(context, appState, q),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.muted),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
