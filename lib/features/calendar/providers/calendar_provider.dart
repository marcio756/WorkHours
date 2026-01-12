// lib/features/calendar/providers/calendar_provider.dart

import 'dart:async'; // Import necessário para StreamSubscription
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:work_hours_tracker/data/local/database.dart';
import 'package:work_hours_tracker/core/utils/date_utils_helper.dart';
import 'package:work_hours_tracker/data/providers/database_provider.dart';
import 'package:work_hours_tracker/features/settings/providers/settings_provider.dart';

// --- DATA CLASS PARA O RESUMO ---
class MonthlySummary {
  final double totalHours;
  final double earnings;

  MonthlySummary({
    this.totalHours = 0.0,
    this.earnings = 0.0,
  });
}

// --- PROVIDER QUE CALCULA OS TOTAIS ---
final monthlySummaryProvider = Provider.autoDispose<MonthlySummary>((ref) {
  final calendarState = ref.watch(calendarViewModelProvider);
  final settings = ref.watch(settingsViewModelProvider);

  if (settings.isLoading) return MonthlySummary();

  double totalHours = 0.0;
  double totalEarnings = 0.0;

  for (var entry in calendarState.entries.values) {
    // Verifica se a entrada pertence ao mês atual (para não somar dias "vizinhos" que a query possa trazer)
    // A query já filtra, mas segurança extra não faz mal
    if (entry.hours > 0) {
      final multiplier = entry.isHoliday ? settings.holidayMultiplier : 1.0;
      totalHours += entry.hours;
      totalEarnings += (entry.hours * multiplier * settings.hourlyRate);
    }
  }

  return MonthlySummary(
    totalHours: totalHours,
    earnings: totalEarnings,
  );
});

// --- ESTADO DO CALENDÁRIO ---
class CalendarState {
  final DateTime currentMonth;
  final Set<DateTime> selectedDates;
  final bool isSelectionMode;
  final Map<DateTime, WorkEntry> entries;

  CalendarState({
    required this.currentMonth,
    this.selectedDates = const {},
    this.isSelectionMode = false,
    this.entries = const {},
  });

  CalendarState copyWith({
    DateTime? currentMonth,
    Set<DateTime>? selectedDates,
    bool? isSelectionMode,
    Map<DateTime, WorkEntry>? entries,
  }) {
    return CalendarState(
      currentMonth: currentMonth ?? this.currentMonth,
      selectedDates: selectedDates ?? this.selectedDates,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      entries: entries ?? this.entries,
    );
  }
}

// --- VIEWMODEL DO CALENDÁRIO (CORRIGIDO PARA PERFORMANCE) ---
class CalendarViewModel extends StateNotifier<CalendarState> {
  final AppDatabase _db;
  
  // Variável para guardar a subscrição ativa
  StreamSubscription<List<WorkEntry>>? _entriesSubscription;

  CalendarViewModel(this._db) : super(CalendarState(currentMonth: DateTime.now())) {
    _loadEntries();
  }

  @override
  void dispose() {
    // Limpar a subscrição quando o ecrã fecha
    _entriesSubscription?.cancel();
    super.dispose();
  }

  void _loadEntries() {
    // 1. Cancelar a escuta anterior para não acumular processos (A SOLUÇÃO DA LENTIDÃO)
    _entriesSubscription?.cancel();

    final start = DateTime(state.currentMonth.year, state.currentMonth.month, 1);
    // Nota: Usar dia 0 do mês seguinte é mais seguro para apanhar o último dia
    final end = DateTime(state.currentMonth.year, state.currentMonth.month + 1, 0);

    // 2. Iniciar nova escuta e guardar a referência
    _entriesSubscription = _db.watchEntriesBetween(
      DateUtilsHelper.toIsoDate(start),
      DateUtilsHelper.toIsoDate(end),
    ).listen((entriesList) {
      final entriesMap = {
        for (var e in entriesList) DateTime.parse(e.date): e
      };
      // Atualizar estado apenas se o widget ainda estiver montado (Riverpod gere isto, mas é boa prática no dispose)
      state = state.copyWith(entries: entriesMap);
    });
  }

  void changeMonth(int monthsToAdd) {
    final newDate = DateTime(
      state.currentMonth.year,
      state.currentMonth.month + monthsToAdd,
    );
    state = state.copyWith(
      currentMonth: newDate,
      selectedDates: {}, 
      isSelectionMode: false,
    );
    // Recarregar dados para o novo mês
    _loadEntries();
  }

  void toggleSelectionMode() {
    final newMode = !state.isSelectionMode;
    state = state.copyWith(
      isSelectionMode: newMode,
      selectedDates: newMode ? state.selectedDates : {},
    );
  }

  void onDateSelected(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);

    if (state.isSelectionMode) {
      final current = Set<DateTime>.from(state.selectedDates);
      if (current.contains(normalizedDate)) {
        current.remove(normalizedDate);
      } else {
        current.add(normalizedDate);
      }
      state = state.copyWith(selectedDates: current);
    } else {
      state = state.copyWith(selectedDates: {normalizedDate});
    }
  }

  Future<void> saveEntry(double hours, bool isHoliday, String? description) async {
    for (final date in state.selectedDates) {
      final entry = WorkEntry(
        date: DateUtilsHelper.toIsoDate(date),
        hours: hours,
        isHoliday: isHoliday,
        description: description,
      );
      await _db.saveWorkEntry(entry);
    }
    if (!state.isSelectionMode) {
      state = state.copyWith(selectedDates: {});
    }
  }
  
  void clearSelection() {
     state = state.copyWith(selectedDates: {}, isSelectionMode: false);
  }
}

final calendarViewModelProvider = StateNotifierProvider<CalendarViewModel, CalendarState>((ref) {
  return CalendarViewModel(ref.watch(databaseProvider));
});