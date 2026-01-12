// lib/features/settings/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:work_hours_tracker/features/settings/providers/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _rateCtrl;
  late TextEditingController _currencyCtrl;
  late TextEditingController _multiplierCtrl;
  late TextEditingController _phoneCtrl; // Novo controlador

  @override
  void initState() {
    super.initState();
    _rateCtrl = TextEditingController();
    _currencyCtrl = TextEditingController();
    _multiplierCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _rateCtrl.dispose();
    _currencyCtrl.dispose();
    _multiplierCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsViewModelProvider);
    final viewModel = ref.read(settingsViewModelProvider.notifier);

    // Sincronização segura
    if (!_rateCtrl.selection.isValid) _rateCtrl.text = state.hourlyRate.toString();
    if (!_currencyCtrl.selection.isValid) _currencyCtrl.text = state.currency;
    if (!_multiplierCtrl.selection.isValid) _multiplierCtrl.text = state.holidayMultiplier.toString();
    if (!_phoneCtrl.selection.isValid) _phoneCtrl.text = state.reportPhone; // Sincroniza telefone

    if (state.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Definições")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle(context, "Valores"),
          const SizedBox(height: 8),
          
          TextField(
            controller: _rateCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: "Taxa Horária", border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_money)),
            onChanged: (val) {
              final d = double.tryParse(val.replaceAll(',', '.'));
              if (d != null) viewModel.updateHourlyRate(d);
            },
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: _currencyCtrl,
            decoration: const InputDecoration(labelText: "Símbolo da Moeda", border: OutlineInputBorder(), prefixIcon: Icon(Icons.currency_exchange)),
            onChanged: (val) => viewModel.updateCurrency(val),
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: _multiplierCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: "Multiplicador de Feriado", border: OutlineInputBorder(), hintText: "Ex: 1.5", prefixIcon: Icon(Icons.percent)),
            onChanged: (val) {
               final d = double.tryParse(val.replaceAll(',', '.'));
               if (d != null) viewModel.updateHolidayMultiplier(d);
            },
          ),
          
          const Divider(height: 40),
          _buildSectionTitle(context, "Aparência"),
          const SizedBox(height: 8),
          
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text("Auto"), icon: Icon(Icons.brightness_auto)),
              ButtonSegment(value: 1, label: Text("Claro"), icon: Icon(Icons.wb_sunny)),
              ButtonSegment(value: 2, label: Text("Escuro"), icon: Icon(Icons.nightlight_round)),
            ],
            selected: {state.appTheme},
            onSelectionChanged: (Set<int> newSelection) => viewModel.updateAppTheme(newSelection.first),
          ),

          const Divider(height: 40),
          _buildSectionTitle(context, "Notificações"),
          const SizedBox(height: 8),

          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.notifications_active, color: Theme.of(context).colorScheme.primary),
            title: const Text("Lembrete Diário"),
            subtitle: Text(state.notificationTime != null ? "Agendado para ${state.notificationTime!.format(context)}" : "Desativado"),
            trailing: Switch(
              value: state.notificationTime != null, 
              onChanged: (value) async {
                if (value) {
                  final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 18, minute: 0));
                  if (time != null) viewModel.updateNotificationTime(time);
                } else {
                  viewModel.updateNotificationTime(null);
                }
              }
            ),
          ),

          // --- NOVA SECÇÃO: RELATÓRIO AUTOMÁTICO ---
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.send_time_extension, color: Theme.of(context).colorScheme.tertiary),
            title: const Text("Relatório Automático"),
            subtitle: const Text("Notificação mensal para enviar horas"),
            trailing: Switch(
              value: state.reportAutoEnabled,
              onChanged: (val) {
                // Atualiza com os valores atuais dos outros campos
                viewModel.updateReportSettings(
                  enabled: val,
                  day: state.reportDay,
                  phone: _phoneCtrl.text,
                );
              },
            ),
          ),
          
          if (state.reportAutoEnabled) ...[
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(child: Text("Dia do mês para envio:")),
                      DropdownButton<int>(
                        value: state.reportDay,
                        items: List.generate(28, (index) => index + 1).map((day) {
                          return DropdownMenuItem(value: day, child: Text("Dia $day"));
                        }).toList(),
                        onChanged: (newDay) {
                          if (newDay != null) {
                            viewModel.updateReportSettings(
                              enabled: true,
                              day: newDay,
                              phone: _phoneCtrl.text,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: "Número de Destino (Automático)",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                      hintText: "912345678"
                    ),
                    onSubmitted: (val) {
                      viewModel.updateReportSettings(
                        enabled: true,
                        day: state.reportDay,
                        phone: val,
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Nota: Devido a restrições do sistema, receberás uma notificação no dia escolhido. Ao clicar, o SMS será preparado automaticamente.",
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
          // ---------------------------------------------

          const Divider(height: 40),
          _buildSectionTitle(context, "Dias de Descanso"),
          const SizedBox(height: 8),
          
          Wrap(
            spacing: 8,
            children: List.generate(7, (index) {
              final dayValue = index + 1;
              final isSelected = state.restDays.contains(dayValue);
              final dayName = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'][index];
              return FilterChip(
                label: Text(dayName),
                selected: isSelected,
                onSelected: (_) => viewModel.toggleRestDay(dayValue),
              );
            }),
          ),
          
          const Divider(height: 40),
          _buildSectionTitle(context, "Dados"),
          const SizedBox(height: 8),
          
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async => await viewModel.createBackup(),
                  icon: const Icon(Icons.download),
                  label: const Text("Exportar"),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      final count = await viewModel.restoreBackup();
                      if (context.mounted && count > 0) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$count dias importados!"), backgroundColor: Colors.green));
                      }
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro ao importar."), backgroundColor: Colors.red));
                    }
                  },
                  icon: const Icon(Icons.upload_file),
                  label: const Text("Importar"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}