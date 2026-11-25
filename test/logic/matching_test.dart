import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_daily/logic/matching.dart';

void main() {
  group('shuffledOrder', () {
    test('es una permutación y nunca deja el orden original', () {
      for (var n = 2; n <= 6; n++) {
        for (var seed = 0; seed < 200; seed++) {
          final order = shuffledOrder(n, Random(seed));
          expect(order.toSet(), {for (var i = 0; i < n; i++) i}, reason: 'n=$n seed=$seed');
          expect(order, isNot(List.generate(n, (i) => i)), reason: 'n=$n seed=$seed');
        }
      }
    });

    test('con una sola pareja no hay nada que mezclar', () {
      expect(shuffledOrder(1, Random(1)), [0]);
      expect(shuffledOrder(0, Random(1)), isEmpty);
    });
  });

  group('MatchingAnswer', () {
    test('conectar todas las parejas bien da todo correcto', () {
      final answer = MatchingAnswer(3)
        ..connect(0, 0)
        ..connect(1, 1)
        ..connect(2, 2);

      expect(answer.isComplete, isTrue);
      expect(answer.grade(), [true, true, true]);
      expect(answer.allCorrect, isTrue);
    });

    test('volver a conectar un elemento reemplaza su línea', () {
      final answer = MatchingAnswer(3)
        ..connect(0, 1)
        ..connect(0, 2);

      expect(answer.connections, {0: 2});
      expect(answer.leftFor(1), isNull);
    });

    test('una imagen no recibe dos líneas: la nueva le saca la imagen al otro elemento', () {
      final answer = MatchingAnswer(3)
        ..connect(0, 1)
        ..connect(2, 1);

      expect(answer.connections, {2: 1});
      expect(answer.imageFor(0), isNull);
      expect(answer.leftFor(1), 2);
    });

    test('desconectar por elemento o por imagen', () {
      final answer = MatchingAnswer(3)
        ..connect(0, 1)
        ..connect(1, 0);

      answer.disconnect(0);
      expect(answer.connections, {1: 0});

      answer.disconnectImage(0);
      expect(answer.isEmpty, isTrue);
    });

    test('grade marca cuáles están bien y cuáles mal, y las que faltan como mal', () {
      final answer = MatchingAnswer(3)
        ..connect(0, 0)
        ..connect(1, 2);

      expect(answer.isComplete, isFalse);
      expect(answer.grade(), [true, false, false]);
      expect(answer.allCorrect, isFalse);
    });

    test('clear borra todas las conexiones', () {
      final answer = MatchingAnswer(2)
        ..connect(0, 1)
        ..connect(1, 0)
        ..clear();

      expect(answer.isEmpty, isTrue);
    });
  });
}
