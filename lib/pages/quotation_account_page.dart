import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'expenses_page.dart';
import 'quotation_actions.dart';

Future<void> openQuotationAccount(
  BuildContext context,
  AppState appState,
  Quotation quotation,
) {
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          QuotationAccountPage(appState: appState, quotationId: quotation.id),
    ),
  );
}

/// One quotation's money: quote value, advances received, expenses spent
/// against it (by category) and what is left.
class QuotationAccountPage extends StatelessWidget {
  final AppState appState;
  final String quotationId;
  const QuotationAccountPage({
    super.key,
    required this.appState,
    required this.quotationId,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final q = appState.quotationById(quotationId);
        if (q == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Quotation not found',
              message: 'It may have been deleted.',
            ),
          );
        }
        final account = appState.accountFor(q);

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  q.customerName.isEmpty ? 'No name' : q.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Quotation #${q.quoteNumber}',
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
                tooltip: 'Edit quotation',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => openEditor(context, appState, q),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              _SummaryCard(account: account),
              if (account.byCategory.isNotEmpty) ...[
                const SizedBox(height: 14),
                _CategoryCard(account: account),
              ],
              const SizedBox(height: 14),
              SectionCard(
                title: 'Advance received',
                icon: Icons.savings_outlined,
                trailing: TextButton.icon(
                  onPressed: () =>
                      showAdvanceEditor(context, appState, quotationId: q.id),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
                child: account.advances.isEmpty
                    ? const Text(
                        'No advance yet.',
                        style: TextStyle(color: AppColors.muted),
                      )
                    : Column(
                        children: [
                          for (final a in account.advances)
                            _AdvanceTile(advance: a, appState: appState),
                        ],
                      ),
              ),
              const SizedBox(height: 14),
              SectionCard(
                title: 'Expenses',
                icon: Icons.account_balance_wallet_outlined,
                trailing: TextButton.icon(
                  onPressed: () =>
                      showExpenseEditor(context, appState, quotationId: q.id),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
                child: account.expenses.isEmpty
                    ? const Text(
                        'No expenses yet. Fuel, food, labour, materials and '
                        'others added here are deducted from the quote.',
                        style: TextStyle(color: AppColors.muted, height: 1.4),
                      )
                    : Column(
                        children: [
                          for (final e in account.expenses) ...[
                            ExpenseTile(
                              expense: e,
                              appState: appState,
                              showQuotation: false,
                            ),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final QuotationAccount account;
  const _SummaryCard({required this.account});

  @override
  Widget build(BuildContext context) {
    final a = account;
    final spentShare = a.quoteValue <= 0
        ? 0.0
        : (a.totalExpenses / a.quoteValue).clamp(0.0, 1.0);
    final marginPct = a.quoteValue <= 0 ? 0 : a.margin / a.quoteValue * 100;
    final dim = Colors.white.withValues(alpha: 0.72);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navy, AppColors.navyDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quote value', style: TextStyle(color: dim, fontSize: 13)),
          const SizedBox(height: 2),
          Text(
            formatMoney(a.quoteValue),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: spentShare,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              color: a.margin < 0 ? AppColors.red : AppColors.sun,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(spentShare * 100).toStringAsFixed(0)}% of the quote spent',
            style: TextStyle(color: dim, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _figure('Advance received', a.advanceReceived, dim),
              _figure('Total expenses', a.totalExpenses, dim),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _figure('Pending from customer', a.pendingFromCustomer, dim),
              _figure(
                'Advance left after expenses',
                a.cashInHand,
                dim,
                color: a.cashInHand < 0 ? const Color(0xFFFCA5A5) : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.margin < 0 ? 'Loss' : 'Balance / Profit',
                        style: TextStyle(color: dim, fontSize: 13),
                      ),
                      Text(
                        'Quote value − Total expenses',
                        style: TextStyle(color: dim, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatMoney(a.margin),
                      style: TextStyle(
                        color: a.margin < 0
                            ? const Color(0xFFFCA5A5)
                            : const Color(0xFF86EFAC),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${marginPct.toStringAsFixed(1)}% margin',
                      style: TextStyle(color: dim, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _figure(String label, double value, Color dim, {Color? color}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: dim, fontSize: 12)),
          const SizedBox(height: 2),
          Text(
            formatMoney(value),
            style: TextStyle(
              color: color ?? Colors.white,
              fontSize: 16.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final QuotationAccount account;
  const _CategoryCard({required this.account});

  @override
  Widget build(BuildContext context) {
    final total = account.totalExpenses;
    return SectionCard(
      title: 'Expenses by category',
      icon: Icons.pie_chart_outline,
      child: Column(
        children: [
          for (final entry in account.byCategory)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(
                    expenseIcon(entry.key),
                    size: 20,
                    color: expenseColor(entry.key),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.key,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              formatMoney(entry.value),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: total <= 0 ? 0 : entry.value / total,
                            minHeight: 6,
                            backgroundColor: AppColors.border,
                            color: expenseColor(entry.key),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 8),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Total expenses',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  formatMoney(total),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.red,
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

class _AdvanceTile extends StatelessWidget {
  final Advance advance;
  final AppState appState;
  const _AdvanceTile({required this.advance, required this.appState});

  @override
  Widget build(BuildContext context) {
    final a = advance;
    final creator = appState.creatorName(a.createdByUid, a.createdByName);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => showAdvanceEditor(context, appState, advance: a),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.south_west,
                color: AppColors.green,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.notes.isEmpty ? 'Advance' : a.notes,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${formatDateShort(a.date)}  •  ${a.paymentMode}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12.5,
                    ),
                  ),
                  if (creator.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    CreatedByTag(creator),
                  ],
                ],
              ),
            ),
            Text(
              formatMoney(a.amount),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15.5,
                color: AppColors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card in the Expenses tab's quotation list.
class QuotationAccountCard extends StatelessWidget {
  final QuotationAccount account;
  final VoidCallback onTap;
  const QuotationAccountCard({
    super.key,
    required this.account,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final a = account;
    final q = a.quotation;
    final spentShare = a.quoteValue <= 0
        ? 0.0
        : (a.totalExpenses / a.quoteValue).clamp(0.0, 1.0);

    Widget figure(String label, double value, Color color) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatMoney(value),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          q.customerName.isEmpty ? 'No name' : q.customerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15.5,
                          ),
                        ),
                        Text(
                          '#${q.quoteNumber}  •  ${formatDateShort(q.quotationDate)}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatMoney(a.quoteValue),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.navy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: spentShare,
                  minHeight: 6,
                  backgroundColor: AppColors.border,
                  color: a.margin < 0 ? AppColors.red : AppColors.sun,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  figure('Advance', a.advanceReceived, AppColors.green),
                  figure('Spent', a.totalExpenses, AppColors.red),
                  figure(
                    'Balance',
                    a.margin,
                    a.margin < 0 ? AppColors.red : AppColors.navy,
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

// ------------------------------------------------------------
// Add / edit advance sheet
// ------------------------------------------------------------

Future<void> showAdvanceEditor(
  BuildContext context,
  AppState appState, {
  Advance? advance,
  String quotationId = '',
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => _AdvanceSheet(
      appState: appState,
      advance: advance?.copy() ?? appState.newAdvance(quotationId),
      isNew: advance == null,
    ),
  );
}

class _AdvanceSheet extends StatefulWidget {
  final AppState appState;
  final Advance advance;
  final bool isNew;
  const _AdvanceSheet({
    required this.appState,
    required this.advance,
    required this.isNew,
  });

  @override
  State<_AdvanceSheet> createState() => _AdvanceSheetState();
}

class _AdvanceSheetState extends State<_AdvanceSheet> {
  final _formKey = GlobalKey<FormState>();
  late final Advance a = widget.advance;
  late final _amount = TextEditingController(
    text: a.amount == 0 ? '' : formatQty(a.amount),
  );
  late final _notes = TextEditingController(text: a.notes);

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    a
      ..amount = parseNumber(_amount.text)
      ..notes = _notes.text.trim();
    widget.appState.saveAdvance(a);
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete advance?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    widget.appState.deleteAdvance(a.id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: a.date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => a.date = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.isNew ? 'Add advance' : 'Edit advance',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amount,
                autofocus: widget.isNew,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
                decoration: const InputDecoration(
                  labelText: 'Advance amount *',
                  prefixText: '₹ ',
                ),
                validator: (v) =>
                    parseNumber(v ?? '') <= 0 ? 'Enter the amount' : null,
              ),
              const SizedBox(height: 14),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Received date',
                    suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                  ),
                  child: Text(formatDate(a.date)),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Payment mode',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final o in paymentModes)
                    ChoiceChip(
                      label: Text(o),
                      selected: a.paymentMode == o,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => a.paymentMode = o),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _notes,
                minLines: 1,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  hintText: 'e.g. First advance, by GPay',
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  if (!widget.isNew) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _delete,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.red,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _save,
                      child: Text(widget.isNew ? 'Add advance' : 'Save'),
                    ),
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
