import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../app_state.dart';
import '../glass_nav_bar.dart';
import '../expense_pdf.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';

IconData expenseIcon(String category) => switch (category) {
  'Materials' => Icons.inventory_2_outlined,
  'Labour' => Icons.engineering_outlined,
  'Transport' => Icons.local_shipping_outlined,
  'Fuel' => Icons.local_gas_station_outlined,
  'Food' => Icons.restaurant_outlined,
  'Salary' => Icons.badge_outlined,
  'Office' => Icons.business_center_outlined,
  _ => Icons.receipt_outlined,
};

Color expenseColor(String category) => switch (category) {
  'Materials' => AppColors.navy,
  'Labour' => const Color(0xFF7C3AED),
  'Transport' => AppColors.blue,
  'Fuel' => const Color(0xFFC77700),
  'Food' => const Color(0xFFDB2777),
  'Salary' => AppColors.green,
  'Office' => const Color(0xFF0D9488),
  // Custom categories get a stable colour from their name.
  _ => _customPalette[category.hashCode.abs() % _customPalette.length],
};

const _customPalette = [
  Color(0xFF0891B2),
  Color(0xFF9333EA),
  Color(0xFFEA580C),
  Color(0xFF65A30D),
  Color(0xFFBE123C),
  Color(0xFF4F46E5),
];

/// Asks for a new category name; null when cancelled or blank.
Future<String?> askCategoryName(BuildContext context) async {
  final controller = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('New category'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Category name',
          hintText: 'e.g. Rent, Tools, Advertising',
        ),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Add'),
        ),
      ],
    ),
  );
  final clean = name?.trim() ?? '';
  return clean.isEmpty ? null : clean;
}

/// Bottom sheet to add or remove the shared expense categories.
Future<void> showManageCategories(BuildContext context, AppState appState) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    builder: (sheetContext) => ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final list = appState.expenseCategoryList;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.75,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: Text(
                    'Expense categories',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    'Shared with everyone. Removing one does not change old '
                    'expenses.',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final c in list)
                        ListTile(
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: expenseColor(
                              c,
                            ).withValues(alpha: 0.12),
                            child: Icon(
                              expenseIcon(c),
                              size: 18,
                              color: expenseColor(c),
                            ),
                          ),
                          title: Text(c),
                          trailing: IconButton(
                            tooltip: 'Remove',
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.red,
                            ),
                            onPressed: list.length <= 1
                                ? null
                                : () => appState.removeExpenseCategory(c),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: FilledButton.icon(
                    onPressed: () async {
                      final name = await askCategoryName(context);
                      if (name != null) appState.addExpenseCategory(name);
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add category'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class ExpensesPage extends StatefulWidget {
  final AppState appState;
  const ExpensesPage({super.key, required this.appState});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  /// First day of the month being viewed; null = all time.
  DateTime? _month = DateTime(DateTime.now().year, DateTime.now().month);
  String? _category;

  String get _periodLabel =>
      _month == null ? 'All time' : DateFormat('MMMM yyyy').format(_month!);

  List<Expense> _filtered() => widget.appState.expenses.where((e) {
    if (_month != null &&
        (e.date.year != _month!.year || e.date.month != _month!.month)) {
      return false;
    }
    return _category == null || e.category == _category;
  }).toList();

  /// Whole month's (or all-time) total, ignoring the category filter.
  double _periodTotal() => widget.appState.expenses
      .where(
        (e) =>
            _month == null ||
            (e.date.year == _month!.year && e.date.month == _month!.month),
      )
      .fold<double>(0, (acc, e) => acc + e.amount);

  void _shiftMonth(int delta) {
    final m = _month ?? DateTime(DateTime.now().year, DateTime.now().month);
    setState(() => _month = DateTime(m.year, m.month + delta));
  }

  void _openReport(List<Expense> list) {
    final label = _category == null
        ? _periodLabel
        : '$_periodLabel - $_category';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExpenseReportPage(
          appState: widget.appState,
          expenses: list,
          period: label,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final list = _filtered();
        final total = list.fold<double>(0, (acc, e) => acc + e.amount);

        // Group by day, newest first (appState.expenses is already sorted).
        final groups = <DateTime, List<Expense>>{};
        for (final e in list) {
          final day = DateTime(e.date.year, e.date.month, e.date.day);
          groups.putIfAbsent(day, () => []).add(e);
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Expenses'),
            actions: [
              IconButton(
                tooltip: 'Manage categories',
                icon: const Icon(Icons.category_outlined),
                onPressed: () => showManageCategories(context, appState),
              ),
              IconButton(
                tooltip: 'Download PDF report',
                icon: const Icon(Icons.picture_as_pdf_outlined),
                onPressed: () => _openReport(list),
              ),
            ],
          ),
          floatingActionButton: Padding(
            padding: EdgeInsets.only(bottom: navBarClearance(context)),
            child: FloatingActionButton.extended(
              onPressed: () => showExpenseEditor(context, appState),
              icon: const Icon(Icons.add),
              label: const Text('Add expense'),
            ),
          ),
          body: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              navBarClearance(context) + 84,
            ),
            children: [
              _summaryCard(_periodTotal(), total, list.length),
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final c in [null, ...appState.expenseCategoryList])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(c ?? 'All'),
                          selected: _category == c,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _category = c),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: EmptyState(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'No expenses',
                    message: 'Tap "Add expense" to record one.',
                  ),
                )
              else
                for (final entry in groups.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
                    child: Row(
                      children: [
                        Text(
                          formatDateShort(entry.key),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          formatMoney(
                            entry.value.fold<double>(
                              0,
                              (acc, e) => acc + e.amount,
                            ),
                          ),
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (final e in entry.value) ...[
                    _ExpenseTile(expense: e, appState: appState),
                    const SizedBox(height: 8),
                  ],
                ],
            ],
          ),
        );
      },
    );
  }

  Widget _summaryCard(double periodTotal, double total, int count) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navy, AppColors.navyDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _shiftMonth(-1),
                icon: const Icon(Icons.chevron_left, color: Colors.white),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(
                    () => _month = _month == null
                        ? DateTime(DateTime.now().year, DateTime.now().month)
                        : null,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      _periodLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _shiftMonth(1),
                icon: const Icon(Icons.chevron_right, color: Colors.white),
              ),
            ],
          ),
          Text(
            _month == null ? 'Total expenses (all time)' : 'Total expenses',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            formatMoney(periodTotal),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (_category != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$_category: ${formatMoney(total)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            '$count expense${count == 1 ? '' : 's'}'
            '${_month == null ? '' : '  •  tap month for all time'}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  final Expense expense;
  final AppState appState;
  const _ExpenseTile({required this.expense, required this.appState});

  @override
  Widget build(BuildContext context) {
    final e = expense;
    final color = expenseColor(e.category);
    final project = appState.projectById(e.projectId);
    final creator = appState.creatorName(e.createdByUid, e.createdByName);
    final sub = [
      e.category,
      e.paymentMode,
      if (e.paidTo.isNotEmpty) e.paidTo,
      if (project != null) 'Project #${project.projectNumber}',
    ].join('  •  ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showExpenseEditor(context, appState, expense: e),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(expenseIcon(e.category), color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.description.isEmpty ? e.category : e.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
              const SizedBox(width: 8),
              Text(
                formatMoney(e.amount),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15.5,
                  color: AppColors.red,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// Add / edit expense sheet
// ------------------------------------------------------------

Future<void> showExpenseEditor(
  BuildContext context,
  AppState appState, {
  Expense? expense,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => _ExpenseSheet(
      appState: appState,
      expense: expense?.copy() ?? appState.newExpense(),
      isNew: expense == null,
    ),
  );
}

class _ExpenseSheet extends StatefulWidget {
  final AppState appState;
  final Expense expense;
  final bool isNew;
  const _ExpenseSheet({
    required this.appState,
    required this.expense,
    required this.isNew,
  });

  @override
  State<_ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends State<_ExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  late final Expense e = widget.expense;
  late final _amount = TextEditingController(
    text: e.amount == 0 ? '' : formatQty(e.amount),
  );
  late final _description = TextEditingController(text: e.description);
  late final _paidTo = TextEditingController(text: e.paidTo);
  late final _notes = TextEditingController(text: e.notes);

  @override
  void dispose() {
    for (final c in [_amount, _description, _paidTo, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    e
      ..amount = parseNumber(_amount.text)
      ..description = _description.text.trim()
      ..paidTo = _paidTo.text.trim()
      ..notes = _notes.text.trim();
    widget.appState.saveExpense(e);
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete expense?'),
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
    widget.appState.deleteExpense(e.id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: e.date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => e.date = picked);
  }

  Future<void> _pickProject() async {
    final projects = widget.appState.projects;
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('No project'),
              onTap: () => Navigator.pop(context, ''),
            ),
            for (final p in projects)
              ListTile(
                leading: const Icon(Icons.solar_power, color: AppColors.sun),
                title: Text(p.customerName),
                subtitle: Text('Project #${p.projectNumber}'),
                selected: p.id == e.projectId,
                onTap: () => Navigator.pop(context, p.id),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => e.projectId = picked);
  }

  Widget _chips(
    List<String> options,
    String value,
    ValueChanged<String> onPick,
  ) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final o in options)
        ChoiceChip(
          label: Text(o),
          selected: value == o,
          showCheckmark: false,
          onSelected: (_) => setState(() => onPick(o)),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final project = widget.appState.projectById(e.projectId);
    const label = TextStyle(color: AppColors.muted, fontSize: 13);

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
                widget.isNew ? 'Add expense' : 'Edit expense',
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
                  labelText: 'Amount *',
                  prefixText: '₹ ',
                ),
                validator: (v) =>
                    parseNumber(v ?? '') <= 0 ? 'Enter the amount' : null,
              ),
              const SizedBox(height: 14),
              const Text('Category', style: label),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final o in {
                    ...widget.appState.expenseCategoryList,
                    // Keep an old category selectable even if removed.
                    e.category,
                  })
                    ChoiceChip(
                      label: Text(o),
                      selected: e.category == o,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => e.category = o),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: const Text('New'),
                    onPressed: () async {
                      final name = await askCategoryName(context);
                      if (name == null) return;
                      final stored = widget.appState.addExpenseCategory(name);
                      setState(() => e.category = stored);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                  ),
                  child: Text(formatDate(e.date)),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Details',
                  hintText: 'e.g. DC cable 4mm, 100 m',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _paidTo,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Paid to',
                  hintText: 'Shop / person',
                ),
              ),
              const SizedBox(height: 14),
              const Text('Payment mode', style: label),
              const SizedBox(height: 6),
              _chips(paymentModes, e.paymentMode, (v) => e.paymentMode = v),
              const SizedBox(height: 14),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _pickProject,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Project (optional)',
                    suffixIcon: Icon(Icons.arrow_drop_down),
                  ),
                  child: Text(
                    project == null
                        ? 'Not linked'
                        : '#${project.projectNumber}  ${project.customerName}',
                    style: TextStyle(
                      color: project == null ? AppColors.muted : AppColors.text,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Notes'),
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
                      child: Text(widget.isNew ? 'Add expense' : 'Save'),
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

// ------------------------------------------------------------
// PDF report preview
// ------------------------------------------------------------

class ExpenseReportPage extends StatefulWidget {
  final AppState appState;
  final List<Expense> expenses;
  final String period;

  const ExpenseReportPage({
    super.key,
    required this.appState,
    required this.expenses,
    required this.period,
  });

  @override
  State<ExpenseReportPage> createState() => _ExpenseReportPageState();
}

class _ExpenseReportPageState extends State<ExpenseReportPage> {
  late final Future<Uint8List> _bytes = generateExpenseReportBytes(
    expenses: widget.expenses,
    company: widget.appState.company,
    period: widget.period,
    projectName: (id) {
      final p = widget.appState.projectById(id);
      return p == null ? '' : '#${p.projectNumber} ${p.customerName}';
    },
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Expense Report',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text(
              widget.period,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: PdfPreview(
        build: (_) => _bytes,
        initialPageFormat: PdfPageFormat.a4,
        pdfFileName: expenseReportFileName(widget.period),
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        allowSharing: false,
        allowPrinting: true,
        scrollViewDecoration: const BoxDecoration(color: AppColors.background),
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
          child: FilledButton.icon(
            onPressed: () => shareExpenseReport(
              context,
              bytes: _bytes,
              period: widget.period,
              company: widget.appState.company,
            ),
            icon: const Icon(Icons.download_outlined),
            label: const Text('Download / Share PDF'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.green),
          ),
        ),
      ),
    );
  }
}
