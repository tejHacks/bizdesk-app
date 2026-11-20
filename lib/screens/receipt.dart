import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ReceiptScreen extends StatelessWidget {
  const ReceiptScreen({super.key, required this.saleId, this.justSold = false});
  final String saleId;
  final bool justSold;

  String _asText(Sale s, BizStore store) {
    final cur = store.settings.currency;
    final b = StringBuffer()
      ..writeln(store.settings.name)
      ..writeln(s.receiptNo)
      ..writeln(dateTime(s.date))
      ..writeln('-' * 28);
    for (final i in s.items) {
      b.writeln('${i.qty} x ${i.name}  ${money(i.total, cur)}');
    }
    b.writeln('-' * 28);
    if (s.discount > 0) b.writeln('Discount: -${money(s.discount, cur)}');
    b
      ..writeln('TOTAL: ${money(s.total, cur)}')
      ..writeln('Paid by ${s.payment.label}')
      ..writeln(store.settings.receiptFooter);
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final sale = store.sales.where((s) => s.id == saleId).firstOrNull;
    if (sale == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This sale was voided.')),
      );
    }
    final cur = store.settings.currency;
    final s = store.settings;
    final customer = store.customerById(sale.customerId);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(
        title: Text(sale.receiptNo),
        actions: [
          IconButton(
            tooltip: 'Copy receipt',
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _asText(sale, store)));
              toast(context, 'Receipt copied — paste it into WhatsApp or SMS');
            },
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v != 'void') return;
              final ok = await confirm(
                context,
                title: 'Void this sale?',
                message:
                    'The sale will be deleted and its items put back in stock.',
                action: 'Void sale',
              );
              if (ok && context.mounted) {
                StoreScope.read(context).voidSale(sale.id);
                Navigator.pop(context);
                toast(context, '${sale.receiptNo} voided');
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'void', child: Text('Void sale')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (justSold)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: positive.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: positive),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Sale complete! Stock has been updated.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    s.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (s.address.isNotEmpty)
                    Text(
                      s.address,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted),
                    ),
                  if (s.phone.isNotEmpty)
                    Text(
                      s.phone,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    '${sale.receiptNo} · ${dateTime(sale.date)}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted),
                  ),
                  Text(
                    'Customer: ${customer?.name ?? 'Walk-in'}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted),
                  ),
                  const Divider(height: 28),
                  for (final i in sale.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  i.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${i.qty} × ${money(i.price, cur)}',
                                  style: TextStyle(color: muted, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            money(i.total, cur),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 28),
                  _line('Subtotal', money(sale.subtotal, cur)),
                  if (sale.discount > 0)
                    _line('Discount', '− ${money(sale.discount, cur)}'),
                  _line('Total', money(sale.total, cur), big: true),
                  _line('Paid by', sale.payment.label),
                  const SizedBox(height: 16),
                  Text(
                    s.receiptFooter,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Profit on this sale: ${money(sale.profit, cur)}',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted),
          ),
          if (justSold) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('New sale'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _line(String a, String b, {bool big = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(
            a,
            style: TextStyle(
              fontSize: big ? 19 : 15,
              fontWeight: big ? FontWeight.w900 : null,
            ),
          ),
        ),
        Text(
          b,
          style: TextStyle(
            fontSize: big ? 19 : 15,
            fontWeight: big ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
