import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import 'dashboard.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    void open(Widget w) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    final items = [
      (
        Icons.receipt_long_outlined,
        'Sales history',
        '${store.sales.length} sales',
        const SalesHistoryScreen(),
      ),
      (
        Icons.money_off_outlined,
        'Expenses',
        '${store.expenses.length} recorded',
        const ExpensesScreen(),
      ),
      (
        Icons.insights_outlined,
        'Reports',
        'Revenue, profit & best sellers',
        const ReportsScreen(),
      ),
      (
        Icons.settings_outlined,
        'Settings',
        'Business details, currency, data',
        const SettingsScreen(),
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          for (final (icon, title, sub, screen) in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(sub),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => open(screen),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- sales history
class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});
  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  Period _period = Period.all;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cur = store.settings.currency;
    final sales = store.sales.where((s) => _period.contains(s.date)).toList();
    final total = sales.fold(0, (t, s) => t + s.total);
    return Scaffold(
      appBar: AppBar(title: const Text('Sales history')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          _PeriodPicker(
            value: _period,
            onChanged: (p) => setState(() => _period = p),
          ),
          const SizedBox(height: 10),
          Text(
            '${sales.length} sales · ${money(total, cur)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (sales.isEmpty)
            const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No sales',
              message: 'Nothing recorded in this period.',
            )
          else
            Card(
              child: Column(
                children: [for (final s in sales) SaleTile(sale: s)],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- expenses
class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  Future<void> _add(BuildContext context) async {
    final store = StoreScope.read(context);
    final amount = TextEditingController();
    final note = TextEditingController();
    var category = Expense.categories.first;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'New expense',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '${store.settings.currency} ',
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in Expense.categories)
                    ChoiceChip(
                      label: Text(c),
                      selected: c == category,
                      onSelected: (_) => setSheet(() => category = c),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  if ((parseMoney(amount.text) ?? 0) <= 0) return;
                  Navigator.pop(context, true);
                },
                child: const Text('Save expense'),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true) {
      store.addExpense(
        Expense(
          date: DateTime.now(),
          category: category,
          amount: parseMoney(amount.text)!,
          note: note.text.trim(),
        ),
      );
    }
    amount.dispose();
    note.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cur = store.settings.currency;
    final list = store.expenses;
    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null, // tabs stay alive in an IndexedStack, so FAB hero tags would clash
        onPressed: () => _add(context),
        icon: const Icon(Icons.add),
        label: const Text('Expense'),
      ),
      body: list.isEmpty
          ? EmptyState(
              icon: Icons.money_off_outlined,
              title: 'No expenses yet',
              message: 'Record rent, transport, salaries and more to see your true profit.',
              action: 'Add expense',
              onAction: () => _add(context),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              children: [
                for (final e in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Dismissible(
                      key: ValueKey(e.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: negative,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) =>
                          StoreScope.read(context).deleteExpense(e.id),
                      child: Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0x22DC2626),
                            child: Icon(Icons.south_west, color: negative),
                          ),
                          title: Text(
                            e.category,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            [
                              dateShort(e.date),
                              if (e.note.isNotEmpty) e.note,
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            '− ${money(e.amount, cur)}',
                            style: const TextStyle(
                              color: negative,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Text(
                  'Swipe left to delete',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------- reports
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  Period _period = Period.month;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cur = store.settings.currency;
    final r = store.report(_period);
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          _PeriodPicker(
            value: _period,
            onChanged: (p) => setState(() => _period = p),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Revenue',
                  value: moneyCompact(r.revenue, cur),
                  icon: Icons.trending_up,
                  color: positive,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: 'Sales',
                  value: '${r.salesCount}',
                  sub: 'avg ${moneyCompact(r.averageSale, cur)}',
                  icon: Icons.receipt,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _line('Revenue', money(r.revenue, cur)),
                  _line('Cost of goods sold', '− ${money(r.cost, cur)}'),
                  const Divider(),
                  _line('Gross profit', money(r.grossProfit, cur), bold: true),
                  _line('Expenses', '− ${money(r.expenses, cur)}'),
                  const Divider(),
                  _line(
                    'Net profit',
                    money(r.netProfit, cur),
                    bold: true,
                    color: r.netProfit >= 0 ? positive : negative,
                  ),
                ],
              ),
            ),
          ),
          const SectionHeader('Last 7 days'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
              child: SizedBox(
                height: 170,
                child: BarChart(data: store.dailyRevenue(7), currency: cur),
              ),
            ),
          ),
          const SectionHeader('Best sellers'),
          if (r.topProducts.isEmpty)
            const Card(child: ListTile(title: Text('No sales in this period')))
          else
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < r.topProducts.length; i++)
                    ListTile(
                      leading: CircleAvatar(
                        radius: 14,
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      title: Text(
                        r.topProducts[i].$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('${r.topProducts[i].$2} sold'),
                      trailing: Text(
                        money(r.topProducts[i].$3, cur),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _line(String a, String b, {bool bold = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                a,
                style: TextStyle(fontWeight: bold ? FontWeight.w800 : null),
              ),
            ),
            Text(
              b,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      );
}

class _PeriodPicker extends StatelessWidget {
  const _PeriodPicker({required this.value, required this.onChanged});
  final Period value;
  final ValueChanged<Period> onChanged;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final p in Period.values)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(p.label),
              selected: p == value,
              onSelected: (_) => onChanged(p),
            ),
          ),
      ],
    ),
  );
}

// ---------------------------------------------------------------- settings
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final _store = StoreScope.read(context);
  late final _name = TextEditingController(text: _store.settings.name);
  late final _address = TextEditingController(text: _store.settings.address);
  late final _phone = TextEditingController(text: _store.settings.phone);
  late final _footer = TextEditingController(
    text: _store.settings.receiptFooter,
  );
  late String _currency = _store.settings.currency;

  @override
  void dispose() {
    for (final c in [_name, _address, _phone, _footer]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    _store.saveSettings(
      _store.settings.copyWith(
        name: _name.text.trim().isEmpty ? 'My Business' : _name.text.trim(),
        address: _address.text.trim(),
        phone: _phone.text.trim(),
        receiptFooter: _footer.text.trim(),
        currency: _currency,
      ),
    );
    toast(context, 'Settings saved');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          const SectionHeader('Business (shown on receipts)'),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Business name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _address,
            decoration: const InputDecoration(labelText: 'Address'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _footer,
            decoration: const InputDecoration(
              labelText: 'Receipt footer message',
            ),
          ),
          const SizedBox(height: 16),
          const Text('Currency', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in ['₦', '\$', '£', '€', 'GH₵', 'KSh', 'R', '₹'])
                ChoiceChip(
                  label: Text(c),
                  selected: c == _currency,
                  onSelected: (_) => setState(() => _currency = c),
                ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Save settings'),
          ),
          const SectionHeader('Data'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.auto_awesome_outlined),
                  title: const Text('Load sample data'),
                  subtitle: const Text(
                    'Adds demo products, customers and a week of sales',
                  ),
                  onTap: () {
                    _store.loadDemoData();
                    toast(context, 'Sample data added');
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.delete_forever_outlined,
                    color: negative,
                  ),
                  title: const Text(
                    'Erase all data',
                    style: TextStyle(color: negative),
                  ),
                  subtitle: const Text(
                    'Products, customers, sales and expenses',
                  ),
                  onTap: () async {
                    final ok = await confirm(
                      context,
                      title: 'Erase everything?',
                      message: 'This permanently deletes all business data on this device.',
                      action: 'Erase',
                    );
                    if (ok) {
                      await _store.eraseAll();
                      if (context.mounted) toast(context, 'All data erased');
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'BizDesk v1.0 · data is stored on this device',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
