// Data models. Money is stored as integer minor units (cents/kobo) so totals
// never suffer from floating-point rounding errors.

String newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

class Product {
  Product({
    String? id,
    required this.name,
    this.sku = '',
    this.category = 'General',
    required this.price,
    this.cost = 0,
    this.stock = 0,
    this.lowStockAt = 5,
  }) : id = id ?? newId();

  final String id;
  String name;
  String sku;
  String category;
  int price; // minor units
  int cost; // minor units
  int stock;
  int lowStockAt;

  bool get isLowStock => stock <= lowStockAt;
  int get margin => price - cost;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'sku': sku,
    'category': category,
    'price': price,
    'cost': cost,
    'stock': stock,
    'lowStockAt': lowStockAt,
  };

  factory Product.fromJson(Map<String, dynamic> j) => Product(
    id: j['id'] as String,
    name: j['name'] as String,
    sku: j['sku'] as String? ?? '',
    category: j['category'] as String? ?? 'General',
    price: j['price'] as int,
    cost: j['cost'] as int? ?? 0,
    stock: j['stock'] as int? ?? 0,
    lowStockAt: j['lowStockAt'] as int? ?? 5,
  );
}

class Customer {
  Customer({
    String? id,
    required this.name,
    this.phone = '',
    this.email = '',
    this.notes = '',
  }) : id = id ?? newId();

  final String id;
  String name;
  String phone;
  String email;
  String notes;

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : ''))
        .toUpperCase();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'email': email,
    'notes': notes,
  };

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
    id: j['id'] as String,
    name: j['name'] as String,
    phone: j['phone'] as String? ?? '',
    email: j['email'] as String? ?? '',
    notes: j['notes'] as String? ?? '',
  );
}

enum PaymentMethod {
  cash('Cash'),
  card('Card'),
  transfer('Transfer');

  const PaymentMethod(this.label);
  final String label;
}

/// A line on a sale. Name/price/cost are copied at sale time so the receipt
/// stays correct even if the product is later edited or deleted.
class SaleItem {
  SaleItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.cost,
    required this.qty,
  });

  final String productId;
  final String name;
  final int price;
  final int cost;
  int qty;

  int get total => price * qty;
  int get costTotal => cost * qty;

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'name': name,
    'price': price,
    'cost': cost,
    'qty': qty,
  };

  factory SaleItem.fromJson(Map<String, dynamic> j) => SaleItem(
    productId: j['productId'] as String,
    name: j['name'] as String,
    price: j['price'] as int,
    cost: j['cost'] as int? ?? 0,
    qty: j['qty'] as int,
  );
}

class Sale {
  Sale({
    String? id,
    required this.number,
    required this.date,
    required this.items,
    this.customerId,
    this.discount = 0,
    this.payment = PaymentMethod.cash,
    this.note = '',
  }) : id = id ?? newId();

  final String id;
  final int number;
  final DateTime date;
  final List<SaleItem> items;
  final String? customerId;
  final int discount; // minor units
  final PaymentMethod payment;
  final String note;

  int get subtotal => items.fold(0, (s, i) => s + i.total);
  int get total => (subtotal - discount).clamp(0, 1 << 62);
  int get cost => items.fold(0, (s, i) => s + i.costTotal);
  int get profit => total - cost;
  int get itemCount => items.fold(0, (s, i) => s + i.qty);
  String get receiptNo => 'INV-${number.toString().padLeft(5, '0')}';

  Map<String, dynamic> toJson() => {
    'id': id,
    'number': number,
    'date': date.toIso8601String(),
    'items': [for (final i in items) i.toJson()],
    'customerId': customerId,
    'discount': discount,
    'payment': payment.name,
    'note': note,
  };

  factory Sale.fromJson(Map<String, dynamic> j) => Sale(
    id: j['id'] as String,
    number: j['number'] as int,
    date: DateTime.parse(j['date'] as String),
    items: [
      for (final i in j['items'] as List)
        SaleItem.fromJson(i as Map<String, dynamic>),
    ],
    customerId: j['customerId'] as String?,
    discount: j['discount'] as int? ?? 0,
    payment: PaymentMethod.values.byName(j['payment'] as String? ?? 'cash'),
    note: j['note'] as String? ?? '',
  );
}

class Expense {
  Expense({
    String? id,
    required this.date,
    required this.category,
    required this.amount,
    this.note = '',
  }) : id = id ?? newId();

  final String id;
  final DateTime date;
  final String category;
  final int amount; // minor units
  final String note;

  static const categories = [
    'Rent',
    'Stock purchase',
    'Salaries',
    'Utilities',
    'Transport',
    'Marketing',
    'Other',
  ];

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'category': category,
    'amount': amount,
    'note': note,
  };

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
    id: j['id'] as String,
    date: DateTime.parse(j['date'] as String),
    category: j['category'] as String,
    amount: j['amount'] as int,
    note: j['note'] as String? ?? '',
  );
}

class BusinessSettings {
  const BusinessSettings({
    this.name = 'My Business',
    this.currency = '₦',
    this.address = '',
    this.phone = '',
    this.receiptFooter = 'Thank you for your business!',
  });

  final String name;
  final String currency;
  final String address;
  final String phone;
  final String receiptFooter;

  BusinessSettings copyWith({
    String? name,
    String? currency,
    String? address,
    String? phone,
    String? receiptFooter,
  }) => BusinessSettings(
    name: name ?? this.name,
    currency: currency ?? this.currency,
    address: address ?? this.address,
    phone: phone ?? this.phone,
    receiptFooter: receiptFooter ?? this.receiptFooter,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'currency': currency,
    'address': address,
    'phone': phone,
    'receiptFooter': receiptFooter,
  };

  factory BusinessSettings.fromJson(Map<String, dynamic> j) => BusinessSettings(
    name: j['name'] as String? ?? 'My Business',
    currency: j['currency'] as String? ?? '₦',
    address: j['address'] as String? ?? '',
    phone: j['phone'] as String? ?? '',
    receiptFooter:
        j['receiptFooter'] as String? ?? 'Thank you for your business!',
  );
}

/// Date range used by reports and filters.
enum Period {
  today('Today'),
  week('7 days'),
  month('This month'),
  all('All time');

  const Period(this.label);
  final String label;

  bool contains(DateTime d, [DateTime? now]) {
    now ??= DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    return switch (this) {
      Period.today => !d.isBefore(startOfToday),
      Period.week => !d.isBefore(
        startOfToday.subtract(const Duration(days: 6)),
      ),
      Period.month => d.year == now.year && d.month == now.month,
      Period.all => true,
    };
  }
}
