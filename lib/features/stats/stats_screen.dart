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
  // 0 = Horas, 1 = Ganhos, 2 = Despesas
  int _selectedMode = 0; 

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(statsProvider);
    final viewModel = ref.read(statsProvider.notifier);
    final settings = ref.watch(settingsViewModelProvider);
    final theme = Theme.of(context);

    // Determinar valores para os cartões de resumo
    String totalValueStr;
    String averageValueStr;
    Color highlightColor;

    if (_selectedMode == 0) { // Horas
      totalValueStr = "${state.totalAnnualHours.toStringAsFixed(1)} h";
      averageValueStr = "${state.averageHours.toStringAsFixed(1)} h";
      highlightColor = theme.colorScheme.primary;
    } else if (_selectedMode == 1) { // Ganhos
      totalValueStr = "${state.totalAnnualEarnings.toStringAsFixed(2)} ${settings.currency}";
      averageValueStr = "${state.averageEarnings.toStringAsFixed(2)} ${settings.currency}";
      highlightColor = Colors.green;
    } else { // Despesas
      totalValueStr = "${state.totalAnnualExpenses.toStringAsFixed(2)} ${settings.currency}";
      averageValueStr = "${state.averageExpenses.toStringAsFixed(2)} ${settings.currency}";
      highlightColor = Colors.red;
    }

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
                      
                      // Toggle: Horas | Ganhos | Despesas
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(value: 0, label: Text("Horas"), icon: Icon(Icons.access_time)),
                            ButtonSegment(value: 1, label: Text("Ganhos"), icon: Icon(Icons.attach_money)),
                            ButtonSegment(value: 2, label: Text("Despesas"), icon: Icon(Icons.money_off)),
                          ],
                          selected: {_selectedMode},
                          onSelectionChanged: (Set<int> newSelection) {
                            setState(() => _selectedMode = newSelection.first);
                          },
                        ),
                      )
                    ],
                  ),
                ),

                // Gráfico
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 24, 16),
                    child: _buildChart(state, theme, settings.currency, highlightColor),
                  ),
                ),

                const SizedBox(height: 24),

                // Resumo
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
                            value: totalValueStr,
                            color: highlightColor,
                          ),
                        ),
                        Container(width: 1, height: 40, color: Colors.grey.withValues(alpha: 0.3)),
                        Expanded(
                          child: _SummaryItem(
                            label: "MÉDIA MENSAL",
                            value: averageValueStr,
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

  Widget _buildChart(StatsState state, ThemeData theme, String currency, Color barColor) {
    double maxY = 0;
    for (var m in state.monthlyData) {
      double val = 0;
      if (_selectedMode == 0) {val = m.hours;}
      else if (_selectedMode == 1) {val = m.earnings;}
      else {val = m.expenses;}
      
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
              final suffix = _selectedMode == 0 ? 'h' : currency;
              return BarTooltipItem(
                "${rod.toY.toStringAsFixed(1)} $suffix",
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
          double value = 0;
          if (_selectedMode == 0) {value = data.hours;}
          else if (_selectedMode == 1) {value = data.earnings;}
          else {value = data.expenses;}
          
          return BarChartGroupData(
            x: data.month,
            barRods: [
              BarChartRodData(
                toY: value,
                color: barColor,
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