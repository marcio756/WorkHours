// lib/features/reports/report_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:work_hours_tracker/core/services/notification_service.dart';
import 'package:work_hours_tracker/core/utils/date_utils_helper.dart';
import 'package:work_hours_tracker/data/providers/database_provider.dart';
import 'package:work_hours_tracker/features/settings/providers/settings_provider.dart';
import 'package:drift/drift.dart' as drift;

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  DateTime _selectedMonth = DateTime.now();
  final TextEditingController _phoneCtrl = TextEditingController();
  bool _isShortReport = true; 
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsViewModelProvider);
    if (settings.reportPhone.isNotEmpty) {
      _phoneCtrl.text = settings.reportPhone;
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _changeMonth(int monthsToAdd) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + monthsToAdd,
      );
    });
  }

  // --- ARREDONDAMENTO (Múltiplos de 5) ---
  double _roundToNearestFive(double value) {
    if (value == 0) return 0;
    return (value / 5).round() * 5.0;
  }

  Future<void> _generateAndSendReport({
    required DateTime targetMonth, 
    required String phone,
    bool isShort = true,
  }) async {
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Insira um número de telefone.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final db = ref.read(databaseProvider);
      final settings = ref.read(settingsViewModelProvider);

      final start = DateTime(targetMonth.year, targetMonth.month, 1);
      final end = DateTime(targetMonth.year, targetMonth.month + 1, 0);

      // 1. Obter Horas
      final entries = await (db.select(db.workEntries)
        ..where((t) => t.date.isBetween(
            drift.Variable(DateUtilsHelper.toIsoDate(start)), 
            drift.Variable(DateUtilsHelper.toIsoDate(end))
        ))).get();

      // 2. Obter Despesas
      final expenses = await (db.select(db.expenses)
        ..where((t) => t.date.isBetween(
            drift.Variable(DateUtilsHelper.toIsoDate(start)), 
            drift.Variable(DateUtilsHelper.toIsoDate(end))
        ))).get();

      // 3. Calcular Totais
      double totalHours = 0.0;
      double totalEarningsWork = 0.0; // Valor EXATO
      
      entries.sort((a, b) => a.date.compareTo(b.date));
      for (var entry in entries) {
        if (entry.hours > 0) {
          final multiplier = entry.isHoliday ? settings.holidayMultiplier : 1.0;
          totalHours += entry.hours;
          totalEarningsWork += (entry.hours * multiplier * settings.hourlyRate);
        }
      }

      double totalExpenses = 0.0;
      for (var exp in expenses) {
        totalExpenses += (exp.price * exp.quantity);
      }

      // 4. Calcular Líquido e Arredondar
      final rawNetReceivable = totalEarningsWork - totalExpenses;
      
      // APLICAÇÃO DA REGRA: Arredondar APENAS o total final c/ despesas
      final roundedNetReceivable = _roundToNearestFive(rawNetReceivable);

      // 5. Construir Mensagem
      final monthName = DateFormat('MMMM yyyy', 'pt_PT').format(targetMonth).toUpperCase();
      final sb = StringBuffer();

      sb.writeln("RELATÓRIO DE HORAS - $monthName");
      sb.writeln("--------------------------------");
      sb.writeln("Taxa: ${settings.hourlyRate.toStringAsFixed(2)} ${settings.currency}/h");
      sb.writeln("Total Horas: ${totalHours.toStringAsFixed(1)} h");
      sb.writeln("Total Despesas: ${totalExpenses.toStringAsFixed(2)} ${settings.currency}");
      
      // Total a Receber (Bruto) -> AGORA MOSTRA O VALOR EXATO
      sb.writeln("Total a Receber: ${totalEarningsWork.toStringAsFixed(2)} ${settings.currency}"); 
      
      // Total a Receber c/ Despesas -> MOSTRA O VALOR ARREDONDADO AO 5
      sb.writeln("Total a Receber c/ Despesas: ${roundedNetReceivable.toStringAsFixed(2)} ${settings.currency}");

      if (!isShort) {
        sb.writeln("\nDETALHES:");
        if (entries.isEmpty && expenses.isEmpty) {
          sb.writeln("(Sem registos)");
        } else {
          if (entries.isNotEmpty) {
            sb.writeln("\n--- TRABALHO ---");
            for (var entry in entries) {
              final date = DateTime.parse(entry.date);
              final dayStr = DateFormat('dd/MM', 'pt_PT').format(date);
              final extraInfo = entry.isHoliday ? " (Feriado/Extra)" : "";
              final desc = entry.description != null && entry.description!.isNotEmpty 
                  ? " - ${entry.description}" 
                  : "";
              sb.writeln("$dayStr: ${entry.hours}h$extraInfo$desc");
            }
          }
          if (expenses.isNotEmpty) {
            sb.writeln("\n--- DESPESAS ---");
            for (var exp in expenses) {
              final date = DateTime.parse(exp.date);
              final dayStr = DateFormat('dd/MM', 'pt_PT').format(date);
              final totalExp = exp.price * exp.quantity;
              sb.writeln("$dayStr: ${exp.name} (${exp.quantity}x) = ${totalExp.toStringAsFixed(2)}");
            }
          }
        }
      }

      final messageBody = sb.toString();
      final Uri smsUri = Uri(
        scheme: 'sms',
        path: phone,
        queryParameters: <String, String>{
          'body': messageBody,
        },
      );

      if (!mounted) return;

      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Não foi possível abrir a app de mensagens.")),
          );
        }
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- MÉTODOS DE TESTE ---

  void _testAutoSendLastMonth() {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1);
    final settings = ref.read(settingsViewModelProvider);
    final phoneToUse = settings.reportPhone.isNotEmpty ? settings.reportPhone : _phoneCtrl.text;

    _generateAndSendReport(
      targetMonth: lastMonth, 
      phone: phoneToUse,
      isShort: true 
    );
  }

  Future<void> _testNotificationTrigger() async {
    final bool granted = await NotificationService().requestPermissions();
    
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Permissão NEGADA! Ativa nas Definições do telemóvel."),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    await NotificationService().showTestNotification(
      title: "Teste de Relatório",
      body: "Se estás a ler isto, as notificações funcionam!",
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Agendado para 5s! Sai da app para ver.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('MMMM yyyy', 'pt_PT').format(_selectedMonth);
    final capitalizedDate = dateStr.replaceFirst(dateStr[0], dateStr[0].toUpperCase());

    return Scaffold(
      appBar: AppBar(title: const Text("Enviar Relatório")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Seletor de Mês
            Text("MÊS DE REFERÊNCIA", style: theme.textTheme.labelSmall),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => _changeMonth(-1), 
                    icon: const Icon(Icons.chevron_left)
                  ),
                  Text(
                    capitalizedDate,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => _changeMonth(1), 
                    icon: const Icon(Icons.chevron_right)
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Telefone
            Text("DESTINATÁRIO", style: theme.textTheme.labelSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: "999999999",
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 32),

            // Tipo
            Text("TIPO DE RELATÓRIO", style: theme.textTheme.labelSmall),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text("Curto"), icon: Icon(Icons.short_text)),
                ButtonSegment(value: false, label: Text("Detalhado"), icon: Icon(Icons.receipt_long)),
              ],
              selected: {_isShortReport},
              onSelectionChanged: (Set<bool> newSelection) {
                setState(() => _isShortReport = newSelection.first);
              },
            ),
            
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3))
              ),
              child: Text(
                _isShortReport 
                    ? "Envia apenas os totais (Horas, Taxa e Valor a Receber)."
                    : "Envia os totais e uma lista detalhada de horas e despesas.",
                style: theme.textTheme.bodySmall,
              ),
            ),

            const SizedBox(height: 32),

            // Botão Manual
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : () => _generateAndSendReport(
                  targetMonth: _selectedMonth,
                  phone: _phoneCtrl.text,
                  isShort: _isShortReport
                ),
                icon: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send),
                label: Text(_isLoading ? "A GERAR..." : "ENVIAR AGORA"),
              ),
            ),

            const Divider(height: 60),

            // Testes
            Text("ZONA DE TESTES AUTOMÁTICOS", style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.tertiary)),
            const SizedBox(height: 16),
            
            OutlinedButton.icon(
              onPressed: _testAutoSendLastMonth,
              icon: const Icon(Icons.autorenew),
              label: const Text("Simular Envio (Mês Passado)"),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 45),
                foregroundColor: theme.colorScheme.tertiary
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _testNotificationTrigger,
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text("Testar Notificação (5s)"),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}