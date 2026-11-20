import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'product_form.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String _query = '';
  bool _lowOnly = false;

  void _open([Product? product]) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => ProductForm(product: product)));

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cur = store.settings.currency;
    final scheme = Theme.of(context).colorScheme;
    final q = _query.toLowerCase();
    final list = store.products
        .where((p) => !_lowOnly || p.isLowStock)
        .where(
          (p) =>
              q.isEmpty ||
              p.name.toLowerCase().contains(q) ||
              p.sku.toLowerCase().contains(q) ||
              p.category.toLowerCase().contains(q),
        )
        .toList();
    final stockValue = store.products.fold<int>(
      0,
      (s, p) => s + p.cost * p.stock,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Products')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null, // tabs stay alive in an IndexedStack, so FAB hero tags would clash
        onPressed: _open,
        icon: const Icon(Icons.add),
        label: const Text('Product'),
      ),
      body: store.products.isEmpty
          ? EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No products yet',
              message:
                  'Add the items you sell, with their price, cost and stock.',
              action: 'Add product',
              onAction: _open,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              children: [
                SearchBox(
                  hint: 'Search name, SKU or category',
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    FilterChip(
                      label: Text('Low stock (${store.lowStock.length})'),
                      selected: _lowOnly,
                      onSelected: (v) => setState(() => _lowOnly = v),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Stock value: ${money(stockValue, cur)}',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (list.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No matching products')),
                  ),
                for (final p in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        onTap: () => _open(p),
                        leading: CircleAvatar(
                          backgroundColor: scheme.secondaryContainer,
                          child: Text(
                            p.name.isEmpty ? '?' : p.name[0].toUpperCase(),
                            style: TextStyle(
                              color: scheme.onSecondaryContainer,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        title: Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${p.category}${p.sku.isEmpty ? '' : ' · ${p.sku}'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              money(p.price, cur),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Pill(
                              '${p.stock} in stock',
                              color: p.stock == 0
                                  ? negative
                                  : (p.isLowStock ? warning : positive),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
