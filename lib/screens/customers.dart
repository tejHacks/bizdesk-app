import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../widgets/common.dart';
import 'dashboard.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});
  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  String _query = '';

  void _openForm([Customer? c]) =>
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => CustomerForm(customer: c)));

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cur = store.settings.currency;
    final scheme = Theme.of(context).colorScheme;
    final q = _query.toLowerCase();
    final list = store.customers
        .where(
          (c) =>
              q.isEmpty ||
              c.name.toLowerCase().contains(q) ||
              c.phone.contains(q) ||
              c.email.toLowerCase().contains(q),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null, // tabs stay alive in an IndexedStack, so FAB hero tags would clash
        onPressed: _openForm,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Customer'),
      ),
      body: store.customers.isEmpty
          ? EmptyState(
              icon: Icons.people_outline,
              title: 'No customers yet',
              message: 'Save regular customers to track what they buy and how much they spend.',
              action: 'Add customer',
              onAction: _openForm,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              children: [
                SearchBox(
                  hint: 'Search name, phone or email',
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 10),
                if (list.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No matching customers')),
                  ),
                for (final c in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: scheme.tertiaryContainer,
                          child: Text(
                            c.initials,
                            style: TextStyle(
                              color: scheme.onTertiaryContainer,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        title: Text(
                          c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          [c.phone, c.email]
                              .where((s) => s.isNotEmpty)
                              .join(' · ')
                              .ifEmpty('No contact details'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          money(
                            store.salesFor(c.id).fold(0, (s, x) => s + x.total),
                            cur,
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CustomerDetail(customerId: c.id),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

class CustomerDetail extends StatelessWidget {
  const CustomerDetail({super.key, required this.customerId});
  final String customerId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final c = store.customerById(customerId);
    if (c == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Customer deleted')),
      );
    }
    final cur = store.settings.currency;
    final sales = store.salesFor(c.id);
    final spent = sales.fold(0, (s, x) => s + x.total);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer'),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => CustomerForm(customer: c)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: scheme.tertiaryContainer,
              child: Text(
                c.initials,
                style: TextStyle(
                  fontSize: 28,
                  color: scheme.onTertiaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            c.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          if (c.phone.isNotEmpty) Text(c.phone, textAlign: TextAlign.center),
          if (c.email.isNotEmpty)
            Text(
              c.email,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Total spent',
                  value: moneyCompact(spent, cur),
                  icon: Icons.payments_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: 'Purchases',
                  value: '${sales.length}',
                  icon: Icons.shopping_bag_outlined,
                ),
              ),
            ],
          ),
          if (c.notes.isNotEmpty) ...[
            const SectionHeader('Notes'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(c.notes),
              ),
            ),
          ],
          const SectionHeader('Purchase history'),
          if (sales.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.receipt_long_outlined),
                title: Text('No purchases yet'),
              ),
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

class CustomerForm extends StatefulWidget {
  const CustomerForm({super.key, this.customer});
  final Customer? customer;
  @override
  State<CustomerForm> createState() => _CustomerFormState();
}

class _CustomerFormState extends State<CustomerForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.customer?.name);
  late final _phone = TextEditingController(text: widget.customer?.phone);
  late final _email = TextEditingController(text: widget.customer?.email);
  late final _notes = TextEditingController(text: widget.customer?.notes);

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final c = widget.customer ?? Customer(name: '');
    c
      ..name = _name.text.trim()
      ..phone = _phone.text.trim()
      ..email = _email.text.trim()
      ..notes = _notes.text.trim();
    StoreScope.read(context).saveCustomer(c);
    Navigator.pop(context);
    toast(
      context,
      widget.customer == null ? '${c.name} added' : 'Customer updated',
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.customer != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit customer' : 'New customer'),
        actions: [
          if (editing)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await confirm(
                  context,
                  title: 'Delete ${widget.customer!.name}?',
                  message: 'Their past sales are kept as "Walk-in".',
                );
                if (ok && context.mounted) {
                  StoreScope.read(context).deleteCustomer(widget.customer!.id);
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
              decoration: const InputDecoration(
                labelText: 'Full name *',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (v) {
                final s = (v ?? '').trim();
                return s.isNotEmpty &&
                        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)
                    ? 'Enter a valid email'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(editing ? 'Save changes' : 'Add customer'),
            ),
          ],
        ),
      ),
    );
  }
}
