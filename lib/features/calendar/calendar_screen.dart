// lib/features/calendar/calendar_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:work_hours_tracker/core/utils/date_utils_helper.dart';
import 'package:work_hours_tracker/features/calendar/providers/calendar_provider.dart';
import 'package:work_hours_tracker/features/calendar/widgets/day_cell.dart';
import 'package:work_hours_tracker/features/settings/settings_screen.dart';
import 'package:work_hours_tracker/features/settings/providers/settings_provider.dart';
import 'package:work_hours_tracker/features/stats/stats_screen.dart';
import 'package:work_hours_tracker/features/expenses/expenses_screen.dart';
import 'package:work_hours_tracker/features/reports/report_screen.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calendarViewModelProvider);
    final viewModel = ref.read(calendarViewModelProvider.notifier);
    final settingsState = ref.watch(settingsViewModelProvider);
    final summary = ref.watch(monthlySummaryProvider);
    
    final theme = Theme.of(context);

    // Capitalizar título
    final dateStr = DateFormat('MMMM yyyy', 'pt_PT').format(state.currentMonth);
    final capitalizedTitle = dateStr.replaceFirst(dateStr[0], dateStr[0].toUpperCase());

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainer, 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_bag_outlined),
            tooltip: "Despesas",
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExpensesScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: "Estatísticas",
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StatsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.message_outlined),
            tooltip: "Enviar Relatório",
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReportScreen())),
          ),
          IconButton(
            icon: Icon(
              state.isSelectionMode ? Icons.check_circle : Icons.check_circle_outline,
              color: state.isSelectionMode ? theme.colorScheme.primary : null,
            ),
            onPressed: viewModel.toggleSelectionMode,
            tooltip: "Modo de Seleção",
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          )
        ],
      ),
      body: Column(
        children: [
          // 1. Cabeçalho de Mês
          _buildCustomHeader(theme, capitalizedTitle, viewModel),

          // 2. O Calendário e Resumo
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildCalendarCard(state, viewModel, settingsState.restDays, theme),
                  const SizedBox(height: 16),
                  _buildSummaryCard(summary, settingsState.currency, theme),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: state.isSelectionMode && state.selectedDates.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _showEntryDialog(context, viewModel, state),
              icon: const Icon(Icons.edit),
              label: Text("Editar (${state.selectedDates.length})"),
            )
          : null,
    );
  }

  Widget _buildCustomHeader(ThemeData theme, String title, CalendarViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton.filledTonal(
            onPressed: () => viewModel.changeMonth(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          IconButton.filledTonal(
            onPressed: () => viewModel.changeMonth(1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCard(CalendarState state, CalendarViewModel viewModel, List<int> restDays, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
      child: Column(
        children: [
          // INSERIR CABEÇALHO PERSONALIZADO AQUI
          // Removemos o do TableCalendar e usamos o nosso para garantir tamanho uniforme
          _buildDaysOfWeekHeader(theme),
          const SizedBox(height: 8),

          TableCalendar(
            locale: 'pt_PT',
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: state.currentMonth,
            headerVisible: false,
            daysOfWeekVisible: false, // DESLIGAR O ORIGINAL
            startingDayOfWeek: StartingDayOfWeek.monday,
            
            rowHeight: 52,
            
            enabledDayPredicate: (date) => !restDays.contains(date.weekday),
            
            onDaySelected: (selectedDay, focusedDay) {
              if (state.isSelectionMode) {
                viewModel.onDateSelected(selectedDay);
              } else {
                viewModel.onDateSelected(selectedDay);
                final tempState = state.copyWith(selectedDates: {selectedDay});
                _showEntryDialog(context, viewModel, tempState);
              }
            },
            onDayLongPressed: (selectedDay, focusedDay) {
              if (!state.isSelectionMode) {
                viewModel.toggleSelectionMode();
                viewModel.onDateSelected(selectedDay);
              }
            },
            onPageChanged: (focusedDay) {
              final diff = focusedDay.month - state.currentMonth.month + 
                           12 * (focusedDay.year - state.currentMonth.year);
              viewModel.changeMonth(diff);
            },
            
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) => _buildCustomDay(day, state, restDays),
              selectedBuilder: (context, day, focusedDay) => _buildCustomDay(day, state, restDays),
              todayBuilder: (context, day, focusedDay) => _buildCustomDay(day, state, restDays),
              outsideBuilder: (context, day, focusedDay) => const SizedBox.shrink(),
              disabledBuilder: (context, day, focusedDay) => _buildCustomDay(day, state, restDays),
            ),
          ),
        ],
      ),
    );
  }

  // --- NOVO: Cabeçalho de Dias da Semana Uniforme ---
  Widget _buildDaysOfWeekHeader(ThemeData theme) {
    // Lista fixa para garantir tamanho curto
    const days = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calcular tamanho da fonte dinâmico: largura / 7 dias / fator de escala
        // Garante que TODOS diminuem se o ecrã for pequeno
        final dynamicFontSize = (constraints.maxWidth / 7) * 0.35;
        
        // Limitar tamanho máximo para não ficar gigante em tablets
        final fontSize = dynamicFontSize.clamp(10.0, 14.0);

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: days.asMap().entries.map((entry) {
            final idx = entry.key;
            final label = entry.value;
            // Sábado (5) e Domingo (6) a vermelho
            final isWeekend = idx >= 5; 
            
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2), // Pequeno espaço entre nomes
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge!.copyWith(
                    fontSize: fontSize, // Tamanho UNIFORME calculado acima
                    fontWeight: FontWeight.w800,
                    color: isWeekend 
                        ? theme.colorScheme.error.withValues(alpha: 0.7) 
                        : theme.colorScheme.secondary,
                  ),
                  maxLines: 1, // Garante 1 linha
                ),
              ),
            );
          }).toList(),
        );
      }
    );
  }

  Widget _buildCustomDay(DateTime day, CalendarState state, List<int> restDays) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final entry = state.entries[normalizedDay];
    final holidayName = DateUtilsHelper.getPortugueseHolidayName(day);
    
    final isHoliday = (entry?.isHoliday ?? false) || holidayName != null;
    final isRestDay = restDays.contains(day.weekday);

    return Padding(
      padding: const EdgeInsets.all(3.0),
      child: DayCell(
        date: day,
        hours: entry?.hours,
        isHoliday: isHoliday,
        isToday: DateUtilsHelper.isSameDay(day, DateTime.now()),
        isSelected: state.selectedDates.any((d) => DateUtilsHelper.isSameDay(d, day)),
        isRestDay: isRestDay,
      ),
    );
  }

  Widget _buildSummaryCard(MonthlySummary summary, String currency, ThemeData theme) {
     final totalHours = summary.totalHours.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
     final earnings = summary.earnings.toStringAsFixed(2);

     return Container(
       margin: const EdgeInsets.symmetric(horizontal: 16),
       padding: const EdgeInsets.all(20),
       decoration: BoxDecoration(
         color: theme.colorScheme.primaryContainer,
         borderRadius: BorderRadius.circular(24),
       ),
       child: Row(
         mainAxisAlignment: MainAxisAlignment.spaceAround,
         children: [
           _StatItem(
             label: "TOTAL HORAS", 
             value: "$totalHours h", 
             color: theme.colorScheme.onPrimaryContainer
           ),
           Container(width: 1, height: 40, color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.2)),
           _StatItem(
             label: "GANHOS EST.", 
             value: "$earnings $currency",
             color: theme.colorScheme.onPrimaryContainer
           ),
         ],
       ),
     );
  }

  void _showEntryDialog(BuildContext context, CalendarViewModel viewModel, CalendarState state) {
    final dates = state.selectedDates;
    if (dates.isEmpty) return;

    final TextEditingController hoursCtrl = TextEditingController();
    final TextEditingController descCtrl = TextEditingController();
    bool isHoliday = false;

    if (dates.length == 1) {
       final dateKey = DateTime(dates.first.year, dates.first.month, dates.first.day);
       final entry = state.entries[dateKey];
       if (entry != null) {
         hoursCtrl.text = entry.hours > 0 ? entry.hours.toString() : "";
         descCtrl.text = entry.description ?? "";
         isHoliday = entry.isHoliday;
       }
       if (entry == null && DateUtilsHelper.getPortugueseHolidayName(dates.first) != null) {
         isHoliday = true;
       }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(dates.length == 1 
              ? "Registar: ${DateFormat('dd/MM', 'pt_PT').format(dates.first)}" 
              : "Editar ${dates.length} Dias"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: hoursCtrl,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: "Horas Trabalhadas",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.access_time),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: "Nota / Projeto",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description),
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => setState(() => isHoliday = !isHoliday),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isHoliday, 
                          onChanged: (v) => setState(() => isHoliday = v ?? false)
                        ),
                        const Expanded(child: Text("Feriado / Hora Extra")),
                      ],
                    ),
                  )
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
              FilledButton(
                onPressed: () {
                  final hours = double.tryParse(hoursCtrl.text.replaceAll(',', '.')) ?? 0.0;
                  viewModel.saveEntry(hours, isHoliday, descCtrl.text);
                  Navigator.pop(ctx);
                }, 
                child: const Text("Guardar")
              ),
            ],
          );
        }
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color.withValues(alpha: 0.7), letterSpacing: 1.0)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }
}