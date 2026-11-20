import 'package:flutter/material.dart';

import '../format.dart';

/// Simple, dependency-free bar chart of (day, amount) pairs.
class BarChart extends StatelessWidget {
  const BarChart({super.key, required this.data, required this.currency});
  final List<(DateTime, int)> data;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxV = data.fold<int>(0, (m, e) => e.$2 > m ? e.$2 : m);
    final total = data.fold<int>(0, (s, e) => s + e.$2);
    if (total == 0) {
      return Center(
        child: Text(
          'No sales in this period yet',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < data.length; i++)
              Expanded(
                child: Tooltip(
                  message:
                      '${dateShort(data[i].$1)}: ${money(data[i].$2, currency)}',
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      FittedBox(
                        child: Text(
                          data[i].$2 == 0
                              ? ''
                              : moneyCompact(data[i].$2, currency),
                          style: TextStyle(
                            fontSize: 10,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        height: maxV == 0
                            ? 2
                            : ((c.maxHeight - 40) * data[i].$2 / maxV).clamp(
                                2,
                                c.maxHeight - 40,
                              ),
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: i == data.length - 1
                              ? scheme.primary
                              : scheme.primary.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        weekday(data[i].$1),
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
