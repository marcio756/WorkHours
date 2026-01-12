// lib/features/stats/stats_screen.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:work_hours_tracker/features/settings/providers/settings_provider.dart';
import 'package:work_hours_tracker/features/settings/settings_screen.dart';
import 'package:work_hours_tracker/features/stats/providers/stats_provider.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  bool showHours = true; // Toggle: true = Horas, false = Ganhos

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(statsProvider);
    final viewModel = ref.read(statsProvider.notifier);
    final settings = ref.watch(settingsViewModelProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text("Estatísticas ${state.year}"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          )
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 1. Cabeçalho Seguro (Sem Overflow)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Seletor de Ano
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton.filledTonal(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: () => viewModel.changeYear(-1),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(
                              "${state.year}",
                              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton.filledTonal(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: () => viewModel.changeYear(1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Toggle Horas/Ganhos (Agora em baixo, com espaço total)
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(value: true, label: Text("Horas"), icon: Icon(Icons.access_time)),
                            ButtonSegment(value: false, label: Text("Ganhos"), icon: Icon(Icons.euro)),
                          ],
                          selected: {showHours},
                          onSelectionChanged: (Set<bool> newSelection) {
                            setState(() {
                              showHours = newSelection.first;
                            });
                          },
                        ),
                      )
                    ],
                  ),
                ),

                // 2. O Gráfico
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 24, 16),
                    child: _buildChart(state, theme, settings.currency),
                  ),
                ),

                const SizedBox(height: 24),

                // 3. Cartões de Resumo
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _SummaryItem(
                            label: "TOTAL ANUAL",
                            value: showHours 
                                ? "${state.totalAnnualHours.toStringAsFixed(1)} h"
                                : "${state.totalAnnualEarnings.toStringAsFixed(2)} ${settings.currency}",
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Container(width: 1, height: 40, color: Colors.grey.withValues(alpha: 0.3)),
                        Expanded(
                          child: _SummaryItem(
                            label: "MÉDIA MENSAL",
                            value: showHours
                                ? "${state.averageHours.toStringAsFixed(1)} h"
                                : "${state.averageEarnings.toStringAsFixed(2)} ${settings.currency}",
                            color: theme.colorScheme.tertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildChart(StatsState state, ThemeData theme, String currency) {
    double maxY = 0;
    for (var m in state.monthlyData) {
      final val = showHours ? m.hours : m.earnings;
      if (val > maxY) maxY = val;
    }
    maxY = maxY == 0 ? 10 : maxY * 1.2;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => theme.colorScheme.inverseSurface,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                "${rod.toY.toStringAsFixed(1)} ${showHours ? 'h' : currency}",
                TextStyle(color: theme.colorScheme.onInverseSurface, fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const style = TextStyle(fontWeight: FontWeight.bold, fontSize: 12);
                final index = value.toInt() - 1;
                if (index < 0 || index >= 12) return const SizedBox.shrink();
                const months = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(months[index], style: style),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return Text(
                  value >= 1000 ? '${(value/1000).toStringAsFixed(1)}k' : value.toInt().toString(),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  textAlign: TextAlign.right,
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        barGroups: state.monthlyData.map((data) {
          final value = showHours ? data.hours : data.earnings;
          
          return BarChartGroupData(
            x: data.month,
            barRods: [
              BarChartRodData(
                toY: value,
                color: showHours ? theme.colorScheme.primary : theme.colorScheme.secondary,
                width: 16,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY,
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.0)),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color),
        ),
      ],
    );
  }
}