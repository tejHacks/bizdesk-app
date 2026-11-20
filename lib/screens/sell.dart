import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../widgets/common.dart';
import 'product_form.dart';
import 'receipt.dart';

/// Point of sale: tap products to build a cart, then check out.
class SellScreen extends StatefulWidget {
  const SellScreen({super.key});
  @override
  State<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends State<SellScreen> {
  final Map<String, int> _cart = {}; // productId -> qty
  String _query = '';
  String? _category;

  int _total(BizStore store) => _cart.entries.fold(
    0,
    (s, e) => s + (store.productById(e.key)?.price ?? 0) * e.value,
  );
  int get _count => _cart.values.fold(0, (s, q) => s + q);

  void _add(Product p) {
    final inCart = _cart[p.id] ?? 0;
    if (inCart >= p.stock) {
      toast(
        context,
        p.stock == 0
            ? '${p.name} is out of stock'
            : 'Only ${p.stock} × ${p.name} in stock',
      );
      return;
    }
    setState(() => _cart[p.id] = inCart + 1);
  }

  Future<void> _openCart() async {
    final sale = await showModalBottomSheet<Sale>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => StoreScope(
        store: StoreScope.read(context),
        child: _CheckoutSheet(cart: _cart),
      ),
    );
    if (!mounted) return;
    setState(() {}); // cart may have been edited in the sheet
    if (sale != null) {
      setState(_cart.clear);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReceiptScreen(saleId: sale.id, justSold: true),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cur = store.settings.currency;
    final q = _query.toLowerCase();
    final products = store.products
        .where((p) => _category == null || p.category == _category)
        .where(
          (p) =>
              q.isEmpty ||
              p.name.toLowerCase().contains(q) ||
              p.sku.toLowerCase().contains(q),
        )
        .toList();
    // Drop cart lines for products that were deleted meanwhile.
    _cart.removeWhere((id, _) => store.productById(id) == null);

    return Scaffold(
      appBar: AppBar(title: const Text('New sale')),
      body: store.products.isEmpty
          ? EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'Add products first',
              message: 'You need at least one product before you can sell.',
              action: 'Add product',
              onAction: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const ProductForm())),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: SearchBox(
                    hint: 'Search products or SKU',
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: const Text('All'),
                          selected: _category == null,
                          onSelected: (_) => setState(() => _category = null),
                        ),
                      ),
                      for (final c in store.categories)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(c),
                            selected: _category == c,
                            onSelected: (_) => setState(
                              () => _category = _category == c ? null : c,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: products.isEmpty
                      ? const Center(child: Text('No matching products'))
                      : GridView.builder(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            8,
                            16,
                            _cart.isEmpty ? 16 : 96,
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 200,
                                mainAxisExtent: 128,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                              ),
                          itemCount: products.length,
                          itemBuilder: (context, i) {
                            final p = products[i];
                            final inCart = _cart[p.id] ?? 0;
                            return _ProductTile(
                              product: p,
                              inCart: inCart,
                              currency: cur,
                              onTap: () => _add(p),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _cart.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _openCart,
                  child: Row(
                    children: [
                      Badge(
                        label: Text('$_count'),
                        child: const Icon(Icons.shopping_cart),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'Review & checkout',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        money(_total(store), cur),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.inCart,
    required this.currency,
    required this.onTap,
  });
  final Product product;
  final int inCart;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final out = product.stock == 0;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: inCart > 0
              ? scheme.primary
              : scheme.outlineVariant.withValues(alpha: 0.5),
          width: inCart > 0 ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: out ? 0.5 : 1,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (inCart > 0)
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: scheme.primary,
                        child: Text(
                          '$inCart',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    money(product.price, currency),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  out ? 'Out of stock' : '${product.stock} in stock',
                  style: TextStyle(
                    fontSize: 12,
                    color: out || product.isLowStock
                        ? Colors.orange.shade800
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckoutSheet extends StatefulWidget {
  const _CheckoutSheet({required this.cart});
  final Map<String, int> cart;
  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  String? _customerId;
  PaymentMethod _payment = PaymentMethod.cash;
  final _discount = TextEditingController();

  @override
  void dispose() {
    _discount.dispose();
    super.dispose();
  }

  void _checkout() {
    final store = StoreScope.read(context);
    try {
      final sale = store.recordSale(
        cart: widget.cart,
        customerId: _customerId,
        payment: _payment,
        discount: parseMoney(_discount.text) ?? 0,
      );
      Navigator.pop(context, sale);
    } on OutOfStockException catch (e) {
      toast(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cur = store.settings.currency;
    final lines = widget.cart.entries
        .where((e) => store.productById(e.key) != null)
        .toList();
    final subtotal = lines.fold(
      0,
      (s, e) => s + store.productById(e.key)!.price * e.value,
    );
    final discount = (parseMoney(_discount.text) ?? 0).clamp(0, subtotal);
    final total = subtotal - discount;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            const Text(
              'Checkout',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            for (final e in lines)
              () {
                final p = store.productById(e.key)!;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('${money(p.price, cur)} each'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => setState(() {
                          if (e.value <= 1) {
                            widget.cart.remove(e.key);
                          } else {
                            widget.cart[e.key] = e.value - 1;
                          }
                          if (widget.cart.isEmpty) Navigator.pop(context);
                        }),
                      ),
                      Text(
                        '${e.value}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: e.value >= p.stock
                            ? null
                            : () => setState(
                                () => widget.cart[e.key] = e.value + 1,
                              ),
                      ),
                    ],
                  ),
                );
              }(),
            const Divider(),
            DropdownButtonFormField<String?>(
              initialValue: _customerId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Customer',
                prefixIcon: Icon(Icons.person_outline),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Walk-in customer'),
                ),
                for (final c in store.customers)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() => _customerId = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _discount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Discount (optional)',
                prefixText: '$cur ',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            SegmentedButton<PaymentMethod>(
              segments: [
                for (final m in PaymentMethod.values)
                  ButtonSegment(value: m, label: Text(m.label)),
              ],
              selected: {_payment},
              onSelectionChanged: (s) => setState(() => _payment = s.first),
            ),
            const SizedBox(height: 16),
            _row('Subtotal', money(subtotal, cur)),
            if (discount > 0) _row('Discount', '− ${money(discount, cur)}'),
            _row('Total', money(total, cur), bold: true),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
              onPressed: lines.isEmpty ? null : _checkout,
              icon: const Icon(Icons.check_circle),
              label: Text(
                'Charge ${money(total, cur)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: bold ? 18 : 15,
              fontWeight: bold ? FontWeight.w900 : null,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 18 : 15,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
