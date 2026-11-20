import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Add or edit a product. Also lets you receive (restock) items.
class ProductForm extends StatefulWidget {
  const ProductForm({super.key, this.product});
  final Product? product;
  @override
  State<ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<ProductForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.product?.name);
  late final _sku = TextEditingController(text: widget.product?.sku);
  late final _category = TextEditingController(
    text: widget.product?.category ?? 'General',
  );
  late final _price = TextEditingController(
    text: widget.product == null ? '' : moneyInput(widget.product!.price),
  );
  late final _cost = TextEditingController(
    text: widget.product == null ? '' : moneyInput(widget.product!.cost),
  );
  late final _stock = TextEditingController(
    text: '${widget.product?.stock ?? 0}',
  );
  late final _low = TextEditingController(
    text: '${widget.product?.lowStockAt ?? 5}',
  );

  bool get _editing => widget.product != null;

  @override
  void dispose() {
    for (final c in [_name, _sku, _category, _price, _cost, _stock, _low]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final store = StoreScope.read(context);
    final p = widget.product ?? Product(name: '', price: 0);
    p
      ..name = _name.text.trim()
      ..sku = _sku.text.trim()
      ..category = _category.text.trim().isEmpty
          ? 'General'
          : _category.text.trim()
      ..price = parseMoney(_price.text)!
      ..cost = parseMoney(_cost.text) ?? 0
      ..stock = int.parse(_stock.text.trim())
      ..lowStockAt = int.tryParse(_low.text.trim()) ?? 5;
    store.saveProduct(p);
    Navigator.pop(context);
    toast(context, _editing ? 'Product updated' : '${p.name} added');
  }

  Future<void> _restock() async {
    final ctrl = TextEditingController();
    final qty = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Receive stock'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Quantity received'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(ctrl.text.trim())),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (qty == null || qty <= 0 || !mounted) return;
    StoreScope.read(context).adjustStock(widget.product!.id, qty);
    setState(() => _stock.text = '${widget.product!.stock}');
    toast(context, 'Added $qty to stock');
  }

  String? _wholeNumber(String? v) {
    final n = int.tryParse((v ?? '').trim());
    return n == null || n < 0 ? 'Enter a whole number' : null;
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cur = store.settings.currency;
    final price = parseMoney(_price.text) ?? 0;
    final cost = parseMoney(_cost.text) ?? 0;
    final marginPct = price == 0 ? 0 : ((price - cost) / price * 100).round();

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit product' : 'New product'),
        actions: [
          if (_editing)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await confirm(
                  context,
                  title: 'Delete ${widget.product!.name}?',
                  message: 'Past sales and receipts are kept.',
                );
                if (ok && context.mounted) {
                  StoreScope.read(context).deleteProduct(widget.product!.id);
                  Navigator.pop(context);
                }
              },
            ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Product name *'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sku,
              decoration: const InputDecoration(
                labelText: 'SKU / code (optional)',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _category,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            if (store.categories.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in store.categories)
                    ActionChip(
                      label: Text(c),
                      onPressed: () => setState(() => _category.text = c),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Selling price *',
                prefixText: '$cur ',
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final m = parseMoney(v ?? '');
                return m == null || m <= 0 ? 'Enter a price' : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cost,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Cost price (what you paid)',
                prefixText: '$cur ',
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) =>
                  (v ?? '').trim().isNotEmpty && parseMoney(v!) == null
                  ? 'Invalid amount'
                  : null,
            ),
            if (price > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(
                  'Profit per item: ${money(price - cost, cur)} ($marginPct% margin)',
                  style: TextStyle(
                    color: price >= cost ? positive : negative,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stock,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'In stock *'),
                    validator: _wholeNumber,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _low,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Alert below'),
                    validator: _wholeNumber,
                  ),
                ),
              ],
            ),
            if (_editing) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _restock,
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text('Receive stock'),
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(_editing ? 'Save changes' : 'Add product'),
            ),
          ],
        ),
      ),
    );
  }
}
