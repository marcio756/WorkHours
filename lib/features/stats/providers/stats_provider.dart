// lib/features/stats/providers/stats_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:work_hours_tracker/data/local/database.dart';
import 'package:work_hours_tracker/features/settings/providers/settings_provider.dart';
import 'package:work_hours_tracker/data/providers/database_provider.dart';

// Modelo de dados simples para o gráfico
class MonthlyStats {
  final int month;      // 1 a 12
  final double hours;   // Total de horas
  final double earnings; // Total ganho (considerando feriados)

  MonthlyStats({required this.month, required this.hours, required this.earnings});
}

class StatsState {
  final int year;
  final bool isLoading;
  final List<MonthlyStats> monthlyData; // Dados prontos para o gráfico (12 meses)
  final double totalAnnualHours;
  final double totalAnnualEarnings;

  StatsState({
    required this.year,
    this.isLoading = false,
    this.monthlyData = const [],
    this.totalAnnualHours = 0,
    this.totalAnnualEarnings = 0,
  });

  // Média mensal (excluindo meses futuros/vazios se quisermos ser rigorosos, 
  // mas aqui fazemos divisão simples pelos meses com dados ou 12)
  double get averageHours => totalAnnualHours / (monthlyData.where((e) => e.hours > 0).length.clamp(1, 12));
  double get averageEarnings => totalAnnualEarnings / (monthlyData.where((e) => e.earnings > 0).length.clamp(1, 12));
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

    // 1. Buscar todos os registos
    final allEntries = await _db.getAllEntries();
    
    // 2. Filtrar pelo ano selecionado
    final yearlyEntries = allEntries.where((e) => DateTime.parse(e.date).year == year);

    // 3. Inicializar os 12 meses a zero
    final Map<int, double> hoursMap = {for (var i = 1; i <= 12; i++) i: 0.0};
    final Map<int, double> earningsMap = {for (var i = 1; i <= 12; i++) i: 0.0};

    // 4. Calcular somas
    for (var entry in yearlyEntries) {
      final date = DateTime.parse(entry.date);
      final month = date.month;
      
      // Cálculo de Ganhos: Se for feriado aplica o multiplicador
      final multiplier = entry.isHoliday ? _holidayMultiplier : 1.0;
      final earnings = entry.hours * multiplier * _hourlyRate;

      hoursMap[month] = (hoursMap[month] ?? 0) + entry.hours;
      earningsMap[month] = (earningsMap[month] ?? 0) + earnings;
    }

    // 5. Converter para Lista
    final List<MonthlyStats> resultList = [];
    double totalH = 0;
    double totalE = 0;

    for (var i = 1; i <= 12; i++) {
      final h = hoursMap[i]!;
      final e = earningsMap[i]!;
      resultList.add(MonthlyStats(month: i, hours: h, earnings: e));
      totalH += h;
      totalE += e;
    }

    state = StatsState(
      year: year,
      isLoading: false,
      monthlyData: resultList,
      totalAnnualHours: totalH,
      totalAnnualEarnings: totalE,
    );
  }

  void changeYear(int increment) {
    loadStats(state.year + increment);
  }
}

// O Provider principal
final statsProvider = StateNotifierProvider.autoDispose<StatsViewModel, StatsState>((ref) {
  final db = ref.watch(databaseProvider);
  // Observa as definições para recarregar se a taxa mudar
  final settings = ref.watch(settingsViewModelProvider);
  
  return StatsViewModel(db, settings.hourlyRate, settings.holidayMultiplier);
});