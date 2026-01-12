// lib/features/calendar/widgets/day_cell.dart

import 'package:flutter/material.dart';

class DayCell extends StatelessWidget {
  final DateTime date;
  final double? hours;
  final bool isHoliday;
  final bool isSelected;
  final bool isToday;
  final bool isRestDay;

  const DayCell({
    super.key,
    required this.date,
    this.hours,
    this.isHoliday = false,
    this.isSelected = false,
    this.isToday = false,
    this.isRestDay = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Cores de Fundo
    Color backgroundColor;
    if (isSelected) {
      backgroundColor = theme.colorScheme.primary;
    } else if (isRestDay) {
      backgroundColor = Colors.transparent; // Dias de descanso transparentes para limpar visual
    } else {
      backgroundColor = theme.colorScheme.surfaceContainerLow; // Ligeiro cinza nos dias normais
    }

    // Cor do Texto
    Color contentColor;
    if (isSelected) {
      contentColor = theme.colorScheme.onPrimary;
    } else if (isRestDay) {
      contentColor = theme.colorScheme.onSurface.withValues(alpha: 0.3);
    } else if (isToday) {
      contentColor = theme.colorScheme.primary; // Hoje tem texto colorido
    } else {
      contentColor = theme.colorScheme.onSurface;
    }

    final holidayColor = theme.colorScheme.tertiary;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16), // Mais arredondado
        border: isToday && !isSelected
            ? Border.all(color: theme.colorScheme.primary, width: 2)
            : null,
      ),
      child: Stack(
        children: [
          // Número do Dia
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${date.day}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: (isToday || isSelected) ? FontWeight.w900 : FontWeight.w500,
                  color: contentColor,
                ),
              ),
            ),
          ),
          
          // Indicador de Feriado (Ponto) - Apenas se não houver horas
          if (isHoliday && hours == null)
            Align(
              alignment: Alignment.center,
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: holidayColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),

          // Badge de Horas (Pílula)
          if (hours != null && hours! > 0)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.only(bottom: 4, left: 4, right: 4),
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? theme.colorScheme.onPrimary.withValues(alpha: 0.2) 
                      : theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  hours!.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), ''),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isSelected 
                        ? theme.colorScheme.onPrimary 
                        : theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 10
                  ),
                  overflow: TextOverflow.clip,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}