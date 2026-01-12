// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:work_hours_tracker/core/services/notification_service.dart';
import 'package:work_hours_tracker/features/calendar/calendar_screen.dart';
import 'package:work_hours_tracker/features/settings/providers/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Inicializar Notificações
  await NotificationService().init();
  
  // 2. Inicializar Locale
  await initializeDateFormatting('pt_PT', null);

  runApp(
    const ProviderScope(
      child: WorkHoursApp(),
    ),
  );
}

class WorkHoursApp extends ConsumerWidget {
  const WorkHoursApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 3. Ouvir as definições para o Tema Dinâmico
    final settingsState = ref.watch(settingsViewModelProvider);

    // Lógica do Tema: 0=System, 1=Light, 2=Dark
    final ThemeMode mode = switch (settingsState.appTheme) {
      1 => ThemeMode.light,
      2 => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    return MaterialApp(
      title: 'Work Hours Tracker',
      debugShowCheckedModeBanner: false,
      themeMode: mode, // Usa o modo selecionado
      
      // Tema Claro
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1976D2),
          brightness: Brightness.light,
          secondary: const Color(0xFF009688),
          tertiary: const Color(0xFFED6C02),
        ),
      ),
      
      // Tema Escuro
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1976D2),
          brightness: Brightness.dark,
          secondary: const Color(0xFF009688),
          tertiary: const Color(0xFFED6C02),
        ),
      ),
      
      home: const CalendarScreen(),
    );
  }
}