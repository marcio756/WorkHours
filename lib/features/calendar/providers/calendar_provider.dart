// lib/features/calendar/providers/calendar_provider.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:work_hours_tracker/data/local/database.dart';
import 'package:work_hours_tracker/core/utils/date_utils_helper.dart';
import 'package:work_hours_tracker/data/providers/database_provider.dart';
import 'package:work_hours_tracker/features/settings/providers/settings_provider.dart';

// --- DATA CLASS REFATORIZADA ---
class MonthlySummary {
  final double physicalHours; // Horas reais (relógio)
  final double billableHours; // Horas a pagar (com multiplicadores)
  final double earnings;

  MonthlySummary({
    this.physicalHours = 0.0,
    this.billableHours = 0.0,
    this.earnings = 0.0,
  });
}

// --- PROVIDER QUE CALCULA OS TOTAIS ---
final monthlySummaryProvider = Provider.autoDispose<MonthlySummary>((ref) {
  final calendarState = ref.watch(calendarViewModelProvider);
  final settings = ref.watch(settingsViewModelProvider);

  if (settings.isLoading) return MonthlySummary();

  double physicalHours = 0.0;
  double billableHours = 0.0;

  for (var entry in calendarState.entries.values) {
    if (entry.hours > 0) {
      final multiplier = entry.isHoliday ? settings.holidayMultiplier : 1.0;
      
      // 1. Soma horas de relógio (ex: 3h)
      physicalHours += entry.hours;
      
      // 2. Soma horas faturáveis (ex: 3h * 2 = 6h)
      billableHours += (entry.hours * multiplier);
    }
  }

  // O valor ganho é sempre sobre as horas faturáveis
  final totalEarnings = billableHours * settings.hourlyRate;

  return MonthlySummary(
    physicalHours: physicalHours,
    billableHours: billableHours, // <--- O valor que tu queres ver (51.5)
    earnings: totalEarnings,
  );
});

// ... (O resto do ficheiro CalendarState e CalendarViewModel mantém-se igual)
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

class CalendarViewModel extends StateNotifier<CalendarState> {
  final AppDatabase _db;
  StreamSubscription<List<WorkEntry>>? _entriesSubscription;

  CalendarViewModel(this._db) : super(CalendarState(currentMonth: DateTime.now())) {
    _loadEntries();
  }

  @override
  void dispose() {
    _entriesSubscription?.cancel();
    super.dispose();
  }

  void _loadEntries() {
    _entriesSubscription?.cancel();

    final start = DateTime(state.currentMonth.year, state.currentMonth.month, 1);
    final end = DateTime(state.currentMonth.year, state.currentMonth.month + 1, 0);

    _entriesSubscription = _db.watchEntriesBetween(
      DateUtilsHelper.toIsoDate(start),
      DateUtilsHelper.toIsoDate(end),
    ).listen((entriesList) {
      final entriesMap = {
        for (var e in entriesList) DateTime.parse(e.date): e
      };
      if (mounted) {
        state = state.copyWith(entries: entriesMap);
      }
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