// lib/features/stats/providers/stats_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:work_hours_tracker/data/local/database.dart';
import 'package:work_hours_tracker/features/settings/providers/settings_provider.dart';
import 'package:work_hours_tracker/data/providers/database_provider.dart';

class MonthlyStats {
  final int month;      
  final double hours;   
  final double earnings; 
  final double expenses; // NOVO CAMPO

  MonthlyStats({
    required this.month, 
    required this.hours, 
    required this.earnings,
    required this.expenses,
  });
}

class StatsState {
  final int year;
  final bool isLoading;
  final List<MonthlyStats> monthlyData;
  final double totalAnnualHours;
  final double totalAnnualEarnings;
  final double totalAnnualExpenses; // NOVO CAMPO

  StatsState({
    required this.year,
    this.isLoading = false,
    this.monthlyData = const [],
    this.totalAnnualHours = 0,
    this.totalAnnualEarnings = 0,
    this.totalAnnualExpenses = 0,
  });

  // Médias (Evita divisão por zero)
  double get averageHours {
    final count = monthlyData.where((e) => e.hours > 0).length;
    return count == 0 ? 0 : totalAnnualHours / count;
  }

  double get averageEarnings {
    final count = monthlyData.where((e) => e.earnings > 0).length;
    return count == 0 ? 0 : totalAnnualEarnings / count;
  }

  double get averageExpenses {
    final count = monthlyData.where((e) => e.expenses > 0).length;
    return count == 0 ? 0 : totalAnnualExpenses / count;
  }
}

class StatsViewModel extends StateNotifier<StatsState> {
  final AppDatabase _db;
  final double _hourlyRate;
  final double _holidayMultiplier;

  StatsViewModel(this._db, this._hourlyRate, this._holidayMultiplier) 
      : super(StatsState(year: DateTime.now().year, isLoading: true)) {
    loadStats(DateTime.now().year);
  }

  Future<void> loadStats(int year) async {
    state = StatsState(year: year, isLoading: true);

    // 1. Buscar dados
    final allEntries = await _db.getAllEntries();
    final allExpenses = await _db.select(_db.expenses).get(); // Buscar despesas
    
    // 2. Filtrar pelo ano selecionado
    final yearlyEntries = allEntries.where((e) => DateTime.parse(e.date).year == year);
    final yearlyExpenses = allExpenses.where((e) => DateTime.parse(e.date).year == year);

    // 3. Inicializar Maps
    final Map<int, double> hoursMap = {for (var i = 1; i <= 12; i++) i: 0.0};
    final Map<int, double> earningsMap = {for (var i = 1; i <= 12; i++) i: 0.0};
    final Map<int, double> expensesMap = {for (var i = 1; i <= 12; i++) i: 0.0};

    // 4. Calcular Horas e Ganhos
    for (var entry in yearlyEntries) {
      final date = DateTime.parse(entry.date);
      final multiplier = entry.isHoliday ? _holidayMultiplier : 1.0;
      final earnings = entry.hours * multiplier * _hourlyRate;

      hoursMap[date.month] = (hoursMap[date.month] ?? 0) + entry.hours;
      earningsMap[date.month] = (earningsMap[date.month] ?? 0) + earnings;
    }

    // 5. Calcular Despesas
    for (var expense in yearlyExpenses) {
      final date = DateTime.parse(expense.date);
      final totalCost = expense.price * expense.quantity;
      expensesMap[date.month] = (expensesMap[date.month] ?? 0) + totalCost;
    }

    // 6. Consolidar Resultados
    final List<MonthlyStats> resultList = [];
    double totalH = 0;
    double totalE = 0;
    double totalExp = 0;

    for (var i = 1; i <= 12; i++) {
      final h = hoursMap[i]!;
      final e = earningsMap[i]!;
      final exp = expensesMap[i]!;
      
      resultList.add(MonthlyStats(month: i, hours: h, earnings: e, expenses: exp));
      
      totalH += h;
      totalE += e;
      totalExp += exp;
    }

    state = StatsState(
      year: year,
      isLoading: false,
      monthlyData: resultList,
      totalAnnualHours: totalH,
      totalAnnualEarnings: totalE,
      totalAnnualExpenses: totalExp,
    );
  }

  void changeYear(int increment) {
    loadStats(state.year + increment);
  }
}

final statsProvider = StateNotifierProvider.autoDispose<StatsViewModel, StatsState>((ref) {
  final db = ref.watch(databaseProvider);
  final settings = ref.watch(settingsViewModelProvider);
  return StatsViewModel(db, settings.hourlyRate, settings.holidayMultiplier);
});