import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quiz_daily/services/image_store.dart';
import 'package:quiz_daily/widgets/matching_board.dart';

import '../helpers/widget_test_helper.dart';

void main() {
  // El ejemplo del cliente: a la izquierda 1, 2 y 3; a la derecha, de arriba
  // hacia abajo, la imagen del 2, la del 1 y la del 3.
  const left = ['1', '2', '3'];
  const images = ['img_1.png', 'img_2.png', 'img_3.png'];
  const clientOrder = [1, 0, 2];

  late List<List<bool>> confirmed;
  late ScrollController scroll;

  Future<void> pumpBoard(WidgetTester tester, {List<int> order = clientOrder}) async {
    confirmed = [];
    scroll = ScrollController();
    final store = FakeImageStore();
    images.forEach(store.add);
    await tester.pumpWidget(Provider<ImageStore>.value(
      value: store,
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            controller: scroll,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MatchingBoard(leftItems: left, imageRefs: images, order: order, onConfirmed: confirmed.add),
                // Contenido extra para que la página se pueda desplazar.
                const SizedBox(height: 1500),
              ],
            ),
          ),
        ),
      ),
    ));
  }

  Finder leftCell(int i) => find.byKey(ValueKey('matching-left-$i'));
  Finder imageSlot(int slot) => find.byKey(ValueKey('matching-slot-$slot'));
  Map<int, int> connections(WidgetTester tester) =>
      tester.state<MatchingBoardState>(find.byType(MatchingBoard)).connections;
  ButtonStyleButton confirmButton(WidgetTester tester) =>
      tester.widget<ButtonStyleButton>(find.byKey(const ValueKey('matching-confirm')));

  /// Arrastra desde el elemento [from] hasta [to], en varios pasos.
  Future<void> drag(WidgetTester tester, int from, Offset to, {PointerDeviceKind kind = PointerDeviceKind.touch}) async {
    final start = tester.getCenter(leftCell(from));
    final gesture = await tester.startGesture(start, kind: kind);
    for (var step = 1; step <= 5; step++) {
      await gesture.moveTo(Offset.lerp(start, to, step / 5)!);
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();
  }

  Future<void> dragToSlot(WidgetTester tester, int from, int slot, {PointerDeviceKind kind = PointerDeviceKind.touch}) =>
      drag(tester, from, tester.getCenter(imageSlot(slot)), kind: kind);

  testWidgets('arrastrar con el dedo une el elemento con la imagen', (tester) async {
    await pumpBoard(tester);

    await dragToSlot(tester, 0, 1);

    // La fila 1 muestra la imagen 0 (la del "1"): la conexión guarda la imagen, no la fila.
    expect(connections(tester), {0: 0});
  });

  testWidgets('arrastrar con el mouse también une', (tester) async {
    await pumpBoard(tester);

    await dragToSlot(tester, 1, 0, kind: PointerDeviceKind.mouse);

    expect(connections(tester), {1: 1});
  });

  testWidgets('dentro de una página con scroll, el arrastre traza la línea y no desplaza la página', (tester) async {
    await pumpBoard(tester);
    final start = tester.getCenter(leftCell(2));
    final target = tester.getCenter(imageSlot(0));

    // Primero sube en línea recta (si el scroll se quedara con el gesto, la
    // página bajaría) y después va hacia la imagen de arriba.
    final gesture = await tester.startGesture(start);
    for (var dy = 20.0; dy <= start.dy - target.dy; dy += 20) {
      await gesture.moveTo(start - Offset(0, dy));
      await tester.pump();
    }
    await gesture.moveTo(target);
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(scroll.offset, 0);
    expect(connections(tester), {2: 1});
  });

  testWidgets('tocar un elemento y después una imagen también une', (tester) async {
    await pumpBoard(tester);

    await tester.tap(leftCell(2));
    await tester.pump();
    await tester.tap(imageSlot(2));
    await tester.pump();

    expect(connections(tester), {2: 2});
  });

  testWidgets('volver a unir un elemento reemplaza su línea', (tester) async {
    await pumpBoard(tester);

    await dragToSlot(tester, 0, 0);
    await dragToSlot(tester, 0, 2);

    expect(connections(tester), {0: 2});
  });

  testWidgets('una imagen no puede recibir dos líneas', (tester) async {
    await pumpBoard(tester);

    await dragToSlot(tester, 0, 1);
    await dragToSlot(tester, 2, 1);

    expect(connections(tester), {2: 0});
  });

  testWidgets('soltar la línea en el hueco la saca; tocar una imagen unida también', (tester) async {
    await pumpBoard(tester);
    await dragToSlot(tester, 0, 1);
    await dragToSlot(tester, 1, 0);

    // Soltar entre las dos columnas.
    final leftEdge = tester.getTopRight(leftCell(0));
    final imageEdge = tester.getTopLeft(imageSlot(0));
    await drag(tester, 0, Offset((leftEdge.dx + imageEdge.dx) / 2 - 10, leftEdge.dy + 200));
    expect(connections(tester), {1: 1});

    await tester.tap(imageSlot(0));
    await tester.pump();
    expect(connections(tester), isEmpty);
  });

  testWidgets('"Confirmar" se habilita recién con todas las parejas unidas', (tester) async {
    await pumpBoard(tester);
    expect(confirmButton(tester).onPressed, isNull);

    await dragToSlot(tester, 0, 1);
    await dragToSlot(tester, 1, 0);
    expect(confirmButton(tester).onPressed, isNull);

    await dragToSlot(tester, 2, 2);
    expect(confirmButton(tester).onPressed, isNotNull);
  });

  testWidgets('ejemplo del cliente: 1 → medio, 2 → arriba y 3 → abajo da todo correcto', (tester) async {
    await pumpBoard(tester);

    await dragToSlot(tester, 0, 1); // 1 → imagen del medio
    await dragToSlot(tester, 1, 0); // 2 → imagen de arriba
    await dragToSlot(tester, 2, 2); // 3 → imagen de abajo
    await tester.tap(find.text('Confirmar'));
    await tester.pump();

    expect(confirmed, [
      [true, true, true],
    ]);
    expect(find.byIcon(Icons.check_circle), findsNWidgets(3));
    expect(find.text('3 de 3 correctas'), findsOneWidget);
    expect(find.text('Confirmar'), findsNothing);
  });

  testWidgets('al confirmar marca cuáles están bien y cuáles mal, y bloquea el tablero', (tester) async {
    await pumpBoard(tester);

    await dragToSlot(tester, 0, 0); // 1 → imagen del 2: mal
    await dragToSlot(tester, 1, 1); // 2 → imagen del 1: mal
    await dragToSlot(tester, 2, 2); // 3 → imagen del 3: bien
    await tester.tap(find.text('Confirmar'));
    await tester.pump();

    expect(confirmed.single, [false, false, true]);
    expect(find.byIcon(Icons.cancel), findsNWidgets(2));
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.text('1 de 3 correctas'), findsOneWidget);
    expect(find.textContaining('línea punteada'), findsOneWidget);

    // Ya no se puede cambiar.
    await dragToSlot(tester, 2, 0);
    expect(connections(tester), {0: 1, 1: 0, 2: 2});
  });

  testWidgets('"Reiniciar" borra todas las líneas', (tester) async {
    await pumpBoard(tester);
    await dragToSlot(tester, 0, 1);
    await dragToSlot(tester, 1, 0);

    await tester.tap(find.text('Reiniciar'));
    await tester.pump();

    expect(connections(tester), isEmpty);
  });

  testWidgets('mantener apretada una imagen la muestra grande', (tester) async {
    await pumpBoard(tester);

    await tester.longPress(imageSlot(0));
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
  });

  testWidgets('con 6 parejas en un teléfono angosto, todo entra en el ancho', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = FakeImageStore();
    await tester.pumpWidget(Provider<ImageStore>.value(
      value: store,
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: MatchingBoard(
              leftItems: const ['Uno', 'Dos', 'Tres', 'Cuatro', 'Cinco', 'Un concepto bastante largo'],
              imageRefs: const ['a', 'b', 'c', 'd', 'e', 'f'],
              order: const [5, 4, 3, 2, 1, 0],
              onConfirmed: (_) {},
            ),
          ),
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    final right = tester.getTopRight(imageSlot(0)).dx;
    expect(right, lessThanOrEqualTo(300));
  });
}
