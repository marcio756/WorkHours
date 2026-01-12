// test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:work_hours_tracker/main.dart'; // Import correto

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Inicializar dependências necessárias para o teste
    await initializeDateFormatting('pt_PT', null);

    // Build our app and trigger a frame.
    // É necessário envolver em ProviderScope tal como no main.dart
    await tester.pumpWidget(
      const ProviderScope(
        child: WorkHoursApp(),
      ),
    );

    // O teste padrão procura contadores, mas a nossa app mostra um Calendário.
    // Vamos apenas verificar se a app arranca sem erros (smoke test básico).
    expect(find.byType(WorkHoursApp), findsOneWidget);
  });
}