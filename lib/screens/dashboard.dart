import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import 'product_form.dart';
import 'receipt.dart';
import 'shell.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cur = store.settings.currency;
    final today = store.report(Period.today);
    final month = store.report(Period.month);
    final week = store.dailyRevenue(7);
    final low = store.lowStock;
    final recent = store.sales.take(5).toList();
    final scheme = Theme.of(context).colorScheme;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : (hour < 17 ? 'Good afternoon' : 'Good evening');

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text(greeting, style: TextStyle(color: scheme.onSurfaceVariant)),
            Text(
              store.settings.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),

            // Hero card: today's sales
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF134E4A)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sales today',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      money(today.revenue, cur),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${today.salesCount} sale${today.salesCount == 1 ? '' : 's'} · profit ${money(today.grossProfit, cur)}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: brand,
                          ),
                          onPressed: () => Shell.goTo(context, 1),
                          icon: const Icon(Icons.add_shopping_cart),
                          label: const Text('New sale'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ProductForm(),
                            ),
                          ),
                          icon: const Icon(Icons.add_box_outlined),
                          label: const Text('Add product'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SectionHeader('This month'),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'Revenue',
                    value: moneyCompact(month.revenue, cur),
                    sub: '${month.salesCount} sales',
                    icon: Icons.trending_up,
                    color: positive,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatTile(
                    label: 'Net profit',
                    value: moneyCompact(month.netProfit, cur),
                    sub: 'after ${moneyCompact(month.expenses, cur)} expenses',
                    icon: Icons.account_balance_wallet_outlined,
                    color: month.netProfit >= 0 ? brand : negative,
                  ),
                ),
              ],
            ),

            const SectionHeader('Last 7 days'),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
                child: SizedBox(
                  height: 160,
                  child: BarChart(data: week, currency: cur),
                ),
              ),
            ),

            if (low.isNotEmpty) ...[
              SectionHeader(
                'Low stock (${low.length})',
                action: 'View all',
                onAction: () => Shell.goTo(context, 2),
              ),
              Card(
                child: Column(
                  children: [
                    for (final p in low.take(4))
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0x22D97706),
                          child: Icon(
                            Icons.warning_amber_rounded,
                            color: warning,
                          ),
                        ),
                        title: Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text('Reorder at ${p.lowStockAt}'),
                        trailing: Pill(
                          '${p.stock} left',
                          color: p.stock == 0 ? negative : warning,
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProductForm(product: p),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],

            SectionHeader(
              'Recent sales',
              action: recent.isEmpty ? null : 'History',
              onAction: () => Shell.goTo(context, 4),
            ),
            if (recent.isEmpty)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: const Text('No sales yet'),
                  subtitle: const Text(
                    'Tap "New sale" to record your first one.',
                  ),
                  onTap: () => Shell.goTo(context, 1),
                ),
              )
            else
              Card(
                child: Column(
                  children: [for (final s in recent) SaleTile(sale: s)],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SaleTile extends StatelessWidget {
  const SaleTile({super.key, required this.sale});
  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final customer = store.customerById(sale.customerId);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(
          Icons.receipt_long,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          size: 20,
        ),
      ),
      title: Text(
        '${sale.receiptNo} · ${customer?.name ?? 'Walk-in'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${relativeDay(sale.date)} · ${sale.itemCount} item${sale.itemCount == 1 ? '' : 's'}',
      ),
      trailing: Text(
        money(sale.total, store.settings.currency),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => ReceiptScreen(saleId: sale.id))),
    );
  }
}
