import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Thrown when a sale asks for more stock than is available.
class OutOfStockException implements Exception {
  OutOfStockException(this.productName, this.available);
  final String productName;
  final int available;
  @override
  String toString() => 'Only $available × $productName left in stock.';
}

/// All business data + business rules. Persists to the device as JSON.
class BizStore extends ChangeNotifier {
  BizStore._(this._prefs) {
    _products.addAll(_readList('products', Product.fromJson));
    _customers.addAll(_readList('customers', Customer.fromJson));
    _sales.addAll(_readList('sales', Sale.fromJson));
    _expenses.addAll(_readList('expenses', Expense.fromJson));
    final s = _prefs.getString('settings');
    if (s != null) {
      _settings = BusinessSettings.fromJson(
        jsonDecode(s) as Map<String, dynamic>,
      );
    }
    _onboarded = _prefs.getBool('onboarded') ?? false;
  }

  static Future<BizStore> load() async =>
      BizStore._(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;
  final List<Product> _products = [];
  final List<Customer> _customers = [];
  final List<Sale> _sales = [];
  final List<Expense> _expenses = [];
  BusinessSettings _settings = const BusinessSettings();
  bool _onboarded = false;

  List<Product> get products => List.unmodifiable(
    _products
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
  );
  List<Customer> get customers => List.unmodifiable(
    _customers
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
  );
  List<Sale> get sales =>
      List.unmodifiable(_sales..sort((a, b) => b.date.compareTo(a.date)));
  List<Expense> get expenses =>
      List.unmodifiable(_expenses..sort((a, b) => b.date.compareTo(a.date)));
  BusinessSettings get settings => _settings;
  bool get onboarded => _onboarded;

  Product? productById(String id) =>
      _products.where((p) => p.id == id).firstOrNull;
  Customer? customerById(String? id) =>
      id == null ? null : _customers.where((c) => c.id == id).firstOrNull;
  List<Product> get lowStock => products.where((p) => p.isLowStock).toList();
  List<String> get categories =>
      {for (final p in _products) p.category}.toList()..sort();

  // ---------------------------------------------------------------- products
  void saveProduct(Product p) {
    final i = _products.indexWhere((x) => x.id == p.id);
    i >= 0 ? _products[i] = p : _products.add(p);
    _save('products', _products);
  }

  void deleteProduct(String id) {
    _products.removeWhere((p) => p.id == id);
    _save('products', _products);
  }

  void adjustStock(String productId, int delta) {
    final p = productById(productId);
    if (p == null) return;
    p.stock = (p.stock + delta).clamp(0, 1 << 31);
    _save('products', _products);
  }

  // ---------------------------------------------------------------- customers
  void saveCustomer(Customer c) {
    final i = _customers.indexWhere((x) => x.id == c.id);
    i >= 0 ? _customers[i] = c : _customers.add(c);
    _save('customers', _customers);
  }

  void deleteCustomer(String id) {
    _customers.removeWhere((c) => c.id == id);
    _save('customers', _customers);
  }

  List<Sale> salesFor(String customerId) =>
      sales.where((s) => s.customerId == customerId).toList();

  // ---------------------------------------------------------------- sales
  int get _nextNumber =>
      _sales.fold(0, (m, s) => s.number > m ? s.number : m) + 1;

  /// Records a sale and deducts stock. Throws [OutOfStockException] if any
  /// line asks for more than is in stock (nothing is changed in that case).
  Sale recordSale({
    required Map<String, int> cart, // productId -> qty
    String? customerId,
    int discount = 0,
    PaymentMethod payment = PaymentMethod.cash,
    String note = '',
    DateTime? date,
  }) {
    final items = <SaleItem>[];
    for (final e in cart.entries) {
      final p = productById(e.key);
      if (p == null || e.value <= 0) continue;
      if (e.value > p.stock) throw OutOfStockException(p.name, p.stock);
      items.add(
        SaleItem(
          productId: p.id,
          name: p.name,
          price: p.price,
          cost: p.cost,
          qty: e.value,
        ),
      );
    }
    if (items.isEmpty) throw ArgumentError('Cart is empty');
    for (final i in items) {
      productById(i.productId)!.stock -= i.qty;
    }
    final sale = Sale(
      number: _nextNumber,
      date: date ?? DateTime.now(),
      items: items,
      customerId: customerId,
      discount: discount,
      payment: payment,
      note: note,
    );
    _sales.add(sale);
    _save('products', _products, notify: false);
    _save('sales', _sales);
    return sale;
  }

  /// Deletes (voids) a sale and puts its items back in stock.
  void voidSale(String saleId) {
    final sale = _sales.where((s) => s.id == saleId).firstOrNull;
    if (sale == null) return;
    for (final i in sale.items) {
      final p = productById(i.productId);
      if (p != null) p.stock += i.qty;
    }
    _sales.remove(sale);
    _save('products', _products, notify: false);
    _save('sales', _sales);
  }

  // ---------------------------------------------------------------- expenses
  void addExpense(Expense e) {
    _expenses.add(e);
    _save('expenses', _expenses);
  }

  void deleteExpense(String id) {
    _expenses.removeWhere((e) => e.id == id);
    _save('expenses', _expenses);
  }

  // ---------------------------------------------------------------- reports
  Report report(Period period, [DateTime? now]) {
    final s = _sales.where((x) => period.contains(x.date, now)).toList();
    final e = _expenses.where((x) => period.contains(x.date, now)).toList();
    final byProduct =
        <String, (String, int, int)>{}; // id -> (name, qty, revenue)
    for (final sale in s) {
      for (final i in sale.items) {
        final cur = byProduct[i.productId];
        byProduct[i.productId] = (
          i.name,
          (cur?.$2 ?? 0) + i.qty,
          (cur?.$3 ?? 0) + i.total,
        );
      }
    }
    final top = byProduct.values.toList()..sort((a, b) => b.$3.compareTo(a.$3));
    return Report(
      salesCount: s.length,
      revenue: s.fold(0, (t, x) => t + x.total),
      cost: s.fold(0, (t, x) => t + x.cost),
      expenses: e.fold(0, (t, x) => t + x.amount),
      topProducts: top.take(5).toList(),
    );
  }

  /// Revenue for each of the last [days] days, oldest first.
  List<(DateTime, int)> dailyRevenue(int days, [DateTime? now]) {
    now ??= DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return [
      for (var i = days - 1; i >= 0; i--)
        () {
          final day = today.subtract(Duration(days: i));
          final next = day.add(const Duration(days: 1));
          final total = _sales
              .where((s) => !s.date.isBefore(day) && s.date.isBefore(next))
              .fold(0, (t, s) => t + s.total);
          return (day, total);
        }(),
    ];
  }

  // ---------------------------------------------------------------- settings
  void saveSettings(BusinessSettings s) {
    _settings = s;
    _prefs.setString('settings', jsonEncode(s.toJson()));
    notifyListeners();
  }

  void completeOnboarding() {
    _onboarded = true;
    _prefs.setBool('onboarded', true);
    notifyListeners();
  }

  Future<void> eraseAll() async {
    _products.clear();
    _customers.clear();
    _sales.clear();
    _expenses.clear();
    for (final k in ['products', 'customers', 'sales', 'expenses']) {
      await _prefs.remove(k);
    }
    notifyListeners();
  }

  /// Sample data so a new user can explore every screen.
  void loadDemoData() {
    final now = DateTime.now();
    final items = [
      Product(
        name: 'Bottled Water 75cl',
        sku: 'BW-75',
        category: 'Drinks',
        price: 30000,
        cost: 18000,
        stock: 120,
        lowStockAt: 20,
      ),
      Product(
        name: 'Coca-Cola 50cl',
        sku: 'CC-50',
        category: 'Drinks',
        price: 50000,
        cost: 35000,
        stock: 60,
        lowStockAt: 12,
      ),
      Product(
        name: 'Bread (Large)',
        sku: 'BR-L',
        category: 'Bakery',
        price: 150000,
        cost: 110000,
        stock: 8,
        lowStockAt: 10,
      ),
      Product(
        name: 'Meat Pie',
        sku: 'MP-01',
        category: 'Bakery',
        price: 80000,
        cost: 50000,
        stock: 25,
        lowStockAt: 8,
      ),
      Product(
        name: 'Indomie (Pack)',
        sku: 'IN-40',
        category: 'Groceries',
        price: 1200000,
        cost: 1000000,
        stock: 4,
        lowStockAt: 5,
      ),
      Product(
        name: 'Rice 5kg',
        sku: 'RC-5',
        category: 'Groceries',
        price: 950000,
        cost: 820000,
        stock: 15,
        lowStockAt: 4,
      ),
      Product(
        name: 'Phone Charger',
        sku: 'EL-CH',
        category: 'Electronics',
        price: 450000,
        cost: 280000,
        stock: 10,
        lowStockAt: 3,
      ),
      Product(
        name: 'Earphones',
        sku: 'EL-EP',
        category: 'Electronics',
        price: 350000,
        cost: 200000,
        stock: 2,
        lowStockAt: 3,
      ),
    ];
    for (final p in items) {
      saveProduct(p);
    }
    final people = [
      Customer(
        name: 'Ada Okafor',
        phone: '0803 123 4567',
        email: 'ada@example.com',
      ),
      Customer(name: 'Tunde Bakare', phone: '0812 555 0101'),
      Customer(
        name: 'Grace Hopper',
        email: 'grace@example.com',
        notes: 'Prefers transfer',
      ),
    ];
    for (final c in people) {
      saveCustomer(c);
    }
    // A week of sales history.
    final plan = [
      (6, {items[0].id: 6, items[3].id: 2}, people[0].id, PaymentMethod.cash),
      (5, {items[1].id: 4, items[2].id: 1}, null, PaymentMethod.card),
      (
        4,
        {items[5].id: 1, items[0].id: 10},
        people[1].id,
        PaymentMethod.transfer,
      ),
      (3, {items[6].id: 1}, people[2].id, PaymentMethod.transfer),
      (2, {items[3].id: 5, items[1].id: 3}, null, PaymentMethod.cash),
      (1, {items[4].id: 1, items[0].id: 4}, people[0].id, PaymentMethod.cash),
      (0, {items[2].id: 2, items[1].id: 2}, null, PaymentMethod.card),
    ];
    for (final (daysAgo, cart, customer, pay) in plan) {
      recordSale(
        cart: cart,
        customerId: customer,
        payment: pay,
        date: now.subtract(Duration(days: daysAgo, hours: 2)),
      );
    }
    addExpense(
      Expense(
        date: now.subtract(const Duration(days: 3)),
        category: 'Transport',
        amount: 250000,
        note: 'Restock trip',
      ),
    );
    addExpense(
      Expense(
        date: now.subtract(const Duration(days: 1)),
        category: 'Utilities',
        amount: 800000,
        note: 'Electricity',
      ),
    );
  }

  // ---------------------------------------------------------------- persistence
  List<T> _readList<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    try {
      return [
        for (final j in jsonDecode(raw) as List)
          fromJson(j as Map<String, dynamic>),
      ];
    } catch (_) {
      return []; // corrupted data shouldn't crash the app
    }
  }

  void _save(String key, List<dynamic> items, {bool notify = true}) {
    _prefs.setString(key, jsonEncode([for (final i in items) i.toJson()]));
    if (notify) notifyListeners();
  }
}

class Report {
  const Report({
    required this.salesCount,
    required this.revenue,
    required this.cost,
    required this.expenses,
    required this.topProducts,
  });

  final int salesCount;
  final int revenue;
  final int cost;
  final int expenses;
  final List<(String, int, int)> topProducts; // (name, qty, revenue)

  int get grossProfit => revenue - cost;
  int get netProfit => grossProfit - expenses;
  int get averageSale => salesCount == 0 ? 0 : revenue ~/ salesCount;
}

/// Exposes [BizStore] to the widget tree.
class StoreScope extends InheritedNotifier<BizStore> {
  const StoreScope({super.key, required BizStore store, required super.child})
    : super(notifier: store);

  static BizStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;
  static BizStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}
