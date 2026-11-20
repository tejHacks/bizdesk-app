import 'package:flutter/material.dart';

import '../store.dart';
import '../theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _name = TextEditingController();
  String _currency = '₦';
  static const _currencies = ['₦', '\$', '£', '€', 'GH₵', 'KSh', 'R', '₹'];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _start({required bool demo}) {
    final store = StoreScope.read(context);
    final name = _name.text.trim();
    store.saveSettings(
      store.settings.copyWith(
        name: name.isEmpty ? 'My Business' : name,
        currency: _currency,
      ),
    );
    if (demo) store.loadDemoData();
    store.completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: brand,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Welcome to BizDesk',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Sell, track stock, know your customers and see your profit — all in one place. Works offline.',
              style: TextStyle(
                fontSize: 16,
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Business name',
                hintText: 'e.g. Ada\'s Store',
                prefixIcon: Icon(Icons.store),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Currency',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in _currencies)
                  ChoiceChip(
                    label: Text(c),
                    selected: c == _currency,
                    onSelected: (_) => setState(() => _currency = c),
                  ),
              ],
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () => _start(demo: false),
              child: const Text('Start with an empty business'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () => _start(demo: true),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Explore with sample data'),
            ),
            const SizedBox(height: 12),
            Text(
              'You can change these later in More → Settings.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}
