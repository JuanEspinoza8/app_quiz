import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_daily/screens/settings_screen.dart';

void main() {
  /// Abre el selector de hora en modo teclado, como en un teléfono en
  /// español configurado en formato de 12 h, escribe 04:12 y devuelve lo
  /// que eligió el usuario.
  Future<TimeOfDay?> typeTime(WidgetTester tester, {TransitionBuilder? builder}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    // La fuente de los tests es más alta que la real y el selector en modo
    // teclado desborda 4 px; en el teléfono entra bien. Se ignora solo ese
    // aviso.
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      previousOnError?.call(details);
    };

    TimeOfDay? result;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery(
        // El teléfono configurado en formato de 12 h.
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showTimePicker(
            context: context,
            initialTime: const TimeOfDay(hour: 18, minute: 0),
            initialEntryMode: TimePickerEntryMode.input,
            builder: builder,
          ),
          child: const Text('abrir'),
        ),
      ),
    ));

    await tester.tap(find.text('abrir'));
    // Con un campo de texto enfocado el cursor parpadea sin parar: acá no se
    // usa pumpAndSettle porque nunca terminaría.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), '04');
    await tester.enterText(fields.at(1), '12');
    await tester.pump();
    await tester.tap(find.text('ACEPTAR'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    FlutterError.onError = previousOnError;
    return result;
  }

  testWidgets('sin el ajuste, Flutter lee "04" como 16 en un teléfono de 12 h (el bug)', (tester) async {
    expect(await typeTime(tester), const TimeOfDay(hour: 16, minute: 12));
  });

  testWidgets('con reminderTimePickerBuilder, "04" se guarda como 04', (tester) async {
    expect(await typeTime(tester, builder: reminderTimePickerBuilder), const TimeOfDay(hour: 4, minute: 12));
  });
}
