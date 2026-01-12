// lib/core/utils/date_utils_helper.dart

import 'package:intl/intl.dart';

class DateUtilsHelper {
  
  static String toIsoDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  static String? getPortugueseHolidayName(DateTime date) {
    final day = date.day;
    final month = date.month;

    // Feriados Fixos
    if (day == 1 && month == 1) return "Ano Novo";
    if (day == 25 && month == 4) return "Dia da Liberdade";
    if (day == 1 && month == 5) return "Dia do Trabalhador";
    if (day == 10 && month == 6) return "Dia de Portugal";
    if (day == 15 && month == 8) return "Assunção de Nossa Senhora";
    if (day == 5 && month == 10) return "Implantação da República";
    if (day == 1 && month == 11) return "Dia de Todos os Santos";
    if (day == 1 && month == 12) return "Restauração da Independência";
    if (day == 8 && month == 12) return "Imaculada Conceição";
    if (day == 25 && month == 12) return "Natal";

    // Feriados Móveis
    final easter = calculateEaster(date.year);
    final dateOnly = DateTime(date.year, date.month, date.day);
    
    if (isSameDay(dateOnly, easter.subtract(const Duration(days: 2)))) return "Sexta-feira Santa";
    if (isSameDay(dateOnly, easter)) return "Páscoa";
    if (isSameDay(dateOnly, easter.add(const Duration(days: 60)))) return "Corpo de Deus";
    if (isSameDay(dateOnly, easter.subtract(const Duration(days: 47)))) return "Carnaval"; // Opcional

    return null;
  }

  static DateTime calculateEaster(int year) {
    final a = year % 19;
    final b = year ~/ 100;
    final c = year % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final month = (h + l - 7 * m + 114) ~/ 31;
    final day = ((h + l - 7 * m + 114) % 31) + 1;

    return DateTime(year, month, day);
  }
  
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // --- NOVA FUNÇÃO: Contar dias úteis no mês ---
  static int countBusinessDays(int year, int month, List<int> restDays) {
    int count = 0;
    // Dia 0 do mês seguinte é o último dia do mês atual
    final daysInMonth = DateTime(year, month + 1, 0).day;

    for (int i = 1; i <= daysInMonth; i++) {
      final date = DateTime(year, month, i);
      // Se não for dia de descanso E não for feriado, conta como dia útil
      if (!restDays.contains(date.weekday) && getPortugueseHolidayName(date) == null) {
        count++;
      }
    }
    return count;
  }
}