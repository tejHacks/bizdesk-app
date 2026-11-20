import 'package:bizdesk/format.dart';
import 'package:bizdesk/main.dart';
import 'package:bizdesk/models.dart';
import 'package:bizdesk/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<BizStore> freshStore() async {
  SharedPreferences.setMockInitialValues({});
  return BizStore.load();
}

void main() {
  group('Money', () {
    test('parses user input into minor units', () {
      expect(parseMoney('1,500.50'), 150050);
      expect(parseMoney('20'), 2000);
      expect(parseMoney('0.1'), 10);
      expect(parseMoney(''), isNull);
      expect(parseMoney('abc'), isNull);
    });

    test('formats minor units', () {
      expect(money(150050, '₦'), '₦1,500.50');
      expect(moneyInput(150050), '1500.50');
    });
  });

  group('Store rules', () {
    late BizStore store;
    late Product water;

    setUp(() async {
      store = await freshStore();
      water = Product(name: 'Water', price: 30000, cost: 18000, stock: 10, lowStockAt: 3);
      store.saveProduct(water);
    });

    test('a sale deducts stock and computes totals and profit', () {
      final sale = store.recordSale(cart: {water.id: 4}, discount: 2000);
      expect(store.productById(water.id)!.stock, 6);
      expect(sale.subtotal, 120000);
      expect(sale.total, 118000);
      expect(sale.profit, 118000 - 72000);
      expect(sale.receiptNo, 'INV-00001');
    });

    test('selling more than in stock throws and changes nothing', () {
      expect(() => store.recordSale(cart: {water.id: 11}), throwsA(isA<OutOfStockException>()));
      expect(store.productById(water.id)!.stock, 10);
      expect(store.sales, isEmpty);
    });

    test('voiding a sale restores stock', () {
      final sale = store.recordSale(cart: {water.id: 5});
      store.voidSale(sale.id);
      expect(store.productById(water.id)!.stock, 10);
      expect(store.sales, isEmpty);
    });

    test('receipt numbers increase', () {
      store.recordSale(cart: {water.id: 1});
      final second = store.recordSale(cart: {water.id: 1});
      expect(second.number, 2);
    });

    test('low stock detection', () {
      store.recordSale(cart: {water.id: 7});
      expect(store.lowStock.map((p) => p.name), ['Water']);
    });

    test('report: revenue, costs, expenses and net profit', () {
      store.recordSale(cart: {water.id: 2});
      store.addExpense(Expense(date: DateTime.now(), category: 'Rent', amount: 10000));
      final r = store.report(Period.today);
      expect(r.salesCount, 1);
      expect(r.revenue, 60000);
      expect(r.grossProfit, 24000);
      expect(r.netProfit, 14000);
      expect(r.topProducts.first.$1, 'Water');
    });

    test('data persists across reloads', () async {
      store.recordSale(cart: {water.id: 1});
      final again = await BizStore.load();
      expect(again.products.single.stock, 9);
      expect(again.sales, hasLength(1));
    });

    test('demo data loads without errors', () async {
      final s = await freshStore();
      s.loadDemoData();
      expect(s.products, isNotEmpty);
      expect(s.sales, hasLength(7));
      expect(s.dailyRevenue(7).where((d) => d.$2 > 0), isNotEmpty);
    });
  });

  testWidgets('onboarding with sample data, then visit every tab on a small phone', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final store = await freshStore();
    await tester.pumpWidget(StoreScope(store: store, child: const BizDeskApp()));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to BizDesk'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Ada Store');
    await tester.tap(find.text('Explore with sample data'));
    await tester.pumpAndSettle();
    expect(find.text('Ada Store'), findsOneWidget);
    expect(find.text('Sales today'), findsOneWidget);

    for (final tab in ['Sell', 'Products', 'Customers', 'More', 'Home']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: tab);
    }

    // Sell flow: add an item, open checkout, charge.
    await tester.tap(find.text('Sell').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coca-Cola 50cl'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review & checkout'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Charge ₦'));
    await tester.pumpAndSettle();
    expect(find.text('Sale complete! Stock has been updated.'), findsOneWidget);
    expect(store.sales, hasLength(8));

    // Visit More screens.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    for (final screen in ['Sales history', 'Expenses', 'Reports', 'Settings']) {
      await tester.tap(find.text(screen));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: screen);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });
}
