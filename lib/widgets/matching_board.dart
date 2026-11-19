import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../logic/matching.dart';
import '../theme/app_colors.dart';
import 'question_image.dart';

/// Colores de las líneas mientras se responde: uno por elemento, para saber
/// qué línea sale de cada uno.
const _pairColors = [
  AppColors.primary,
  Color(0xFFFF8A00),
  Color(0xFF1E88E5),
  Color(0xFF43A047),
  Color(0xFFD81B60),
  Color(0xFF6D4C41),
];

/// Tablero de una pregunta de relacionar: elementos a la izquierda, imágenes
/// mezcladas a la derecha y líneas que se trazan arrastrando (con el dedo o
/// con el mouse) o tocando un elemento y después una imagen.
class MatchingBoard extends StatefulWidget {
  final List<String> leftItems;

  /// imageRefs[i] es la imagen correcta de leftItems[i].
  final List<String> imageRefs;

  /// order[fila] = índice (en imageRefs) de la imagen que se muestra en esa fila.
  final List<int> order;

  /// Se llama al confirmar, con el resultado de cada elemento.
  final ValueChanged<List<bool>> onConfirmed;

  const MatchingBoard({
    super.key,
    required this.leftItems,
    required this.imageRefs,
    required this.order,
    required this.onConfirmed,
  });

  @override
  State<MatchingBoard> createState() => MatchingBoardState();
}

class MatchingBoardState extends State<MatchingBoard> {
  late MatchingAnswer _answer;

  /// Fila en la que se muestra cada imagen (la inversa de order).
  late List<int> _slotOfImage;

  /// Elemento elegido con un toque, esperando que se toque una imagen.
  int? _selectedLeft;

  // Arrastre en curso.
  int? _dragPointer;
  int? _dragLeft;
  Offset? _dragStart;
  Offset? _dragPoint; // null hasta que el puntero se mueve lo suficiente

  /// Resultado por elemento después de confirmar; con valor, el tablero queda bloqueado.
  List<bool>? _results;

  _BoardGeometry? _geometry;

  /// Los elementos de la izquierda reclaman el gesto apenas se los toca. Si no,
  /// dentro de un scroll vertical el arrastre de la página gana a los 18 px
  /// (un pan necesita 36) y la línea nunca se llega a trazar.
  static final _claimGesture = <Type, GestureRecognizerFactory>{
    EagerGestureRecognizer: GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
      EagerGestureRecognizer.new,
      (_) {},
    ),
  };

  @visibleForTesting
  Map<int, int> get connections => _answer.connections;

  bool get _locked => _results != null;
  int get _count => widget.leftItems.length;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(MatchingBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.order, widget.order) || !listEquals(oldWidget.leftItems, widget.leftItems)) {
      _reset();
    }
  }

  void _reset() {
    assert(widget.imageRefs.length == _count && widget.order.length == _count,
        'Cada elemento necesita su imagen y su lugar en el orden.');
    _answer = MatchingAnswer(_count);
    _slotOfImage = List.filled(_count, 0);
    for (var row = 0; row < _count; row++) {
      _slotOfImage[widget.order[row]] = row;
    }
    _selectedLeft = null;
    _results = null;
    _clearDrag();
  }

  void _clearDrag() {
    _dragPointer = null;
    _dragLeft = null;
    _dragStart = null;
    _dragPoint = null;
  }

  Color _colorFor(int left) {
    final results = _results;
    if (results != null) return results[left] ? AppColors.teal : AppColors.pink;
    return _pairColors[left % _pairColors.length];
  }

  // ---------------------------------------------------------------------------
  // Gestos
  // ---------------------------------------------------------------------------

  void _onPointerDown(PointerDownEvent event) {
    if (_locked || _dragPointer != null) return;
    final left = _geometry?.leftAt(event.localPosition);
    if (left == null) return;
    _dragPointer = event.pointer;
    _dragLeft = left;
    _dragStart = event.localPosition;
    _dragPoint = null;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _dragPointer) return;
    // Con el mouse alcanza un movimiento chico; con el dedo, el umbral normal
    // para no confundir un toque con un arrastre.
    final slop = event.kind == PointerDeviceKind.mouse ? 6.0 : kTouchSlop;
    if (_dragPoint == null && (event.localPosition - _dragStart!).distance < slop) return;
    setState(() {
      _dragPoint = event.localPosition;
      _selectedLeft = null;
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _dragPointer) return;
    final left = _dragLeft!;
    final dragged = _dragPoint != null;
    final geometry = _geometry!;
    setState(() {
      if (!dragged) {
        // Un toque: elige el elemento (o lo suelta si ya estaba elegido).
        _selectedLeft = _selectedLeft == left ? null : left;
      } else {
        final slot = geometry.slotAt(event.localPosition);
        if (slot != null) {
          _answer.connect(left, widget.order[slot]);
        } else if (!geometry.isOverLeftColumn(event.localPosition)) {
          // Soltar la línea en el hueco o fuera del tablero la saca.
          _answer.disconnect(left);
        }
      }
      _clearDrag();
    });
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer == _dragPointer) setState(_clearDrag);
  }

  void _onImageTap(int slot) {
    final image = widget.order[slot];
    if (_locked) {
      _showImage(image);
      return;
    }
    setState(() {
      final selected = _selectedLeft;
      if (selected != null) {
        _answer.connect(selected, image);
        _selectedLeft = null;
      } else {
        // Sin un elemento elegido, tocar una imagen unida suelta su línea.
        _answer.disconnectImage(image);
      }
    });
  }

  void _confirm() {
    final results = _answer.grade();
    setState(() {
      _results = results;
      _selectedLeft = null;
    });
    widget.onConfirmed(results);
  }

  void _showImage(int image) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            InteractiveViewer(
              maxScale: 4,
              child: QuestionImage(imageRef: widget.imageRefs[image], width: double.infinity, fit: BoxFit.contain),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton.filledTonal(
                tooltip: 'Cerrar',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dibujo
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_locked)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Arrastrá desde cada elemento hasta su imagen, o tocá el elemento y después la imagen. '
              'Mantené apretada una imagen para verla más grande.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final g = _geometry = _BoardGeometry(width: constraints.maxWidth, count: _count);
            return Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerCancel,
              child: SizedBox(
                width: g.width,
                height: g.height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var i = 0; i < _count; i++)
                      Positioned(
                        left: 0,
                        top: g.rowTop(i),
                        width: g.leftWidth,
                        height: g.rowHeight,
                        child: _buildLeft(i),
                      ),
                    for (var slot = 0; slot < _count; slot++)
                      Positioned(
                        left: g.imageLeft,
                        top: g.rowTop(slot),
                        width: g.rowHeight,
                        height: g.rowHeight,
                        child: _buildImage(slot, g),
                      ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _LinesPainter(
                            geometry: g,
                            connections: _answer.connections,
                            slotOfImage: _slotOfImage,
                            colorFor: _colorFor,
                            dragLeft: _dragPoint == null ? null : _dragLeft,
                            dragPoint: _dragPoint,
                            results: _results,
                            idleColor: Colors.grey.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        if (_locked) _buildSummary() else _buildButtons(),
      ],
    );
  }

  Widget _buildLeft(int i) {
    final image = _answer.imageFor(i);
    final selected = _selectedLeft == i || (_dragLeft == i && _dragPoint != null);
    final color = _colorFor(i);
    final result = _results?[i];
    final highlighted = selected || image != null || result != null;

    Widget cell = AnimatedContainer(
      key: ValueKey('matching-left-$i'),
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.15) : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlighted ? color : Colors.grey.withValues(alpha: 0.3),
          width: selected ? 3 : 2,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          if (result != null) ...[
            Icon(result ? Icons.check_circle : Icons.cancel, color: color, size: 20),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              widget.leftItems[i],
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
        ],
      ),
    );

    final connectedTo = image == null ? '' : ', unido a la imagen ${_slotOfImage[image] + 1}';
    final outcome = result == null ? '' : (result ? ', correcto' : ', incorrecto');
    cell = Semantics(
      label: '${widget.leftItems[i]}$connectedTo$outcome',
      button: !_locked,
      selected: selected,
      child: cell,
    );

    if (_locked) return cell;
    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: _claimGesture,
        child: cell,
      ),
    );
  }

  Widget _buildImage(int slot, _BoardGeometry g) {
    final image = widget.order[slot];
    final left = _answer.leftFor(image);
    final dragPoint = _dragPoint;
    final hovered = dragPoint != null && g.slotAt(dragPoint) == slot;
    final borderColor = hovered
        ? AppColors.primary
        : left != null
            ? _colorFor(left)
            : Colors.grey.withValues(alpha: 0.3);

    return Semantics(
      label: 'Imagen ${slot + 1}${left == null ? '' : ', unida a ${widget.leftItems[left]}'}',
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          key: ValueKey('matching-slot-$slot'),
          onTap: () => _onImageTap(slot),
          onLongPress: () => _showImage(image),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: hovered || left != null ? 3 : 2),
            ),
            child: QuestionImage(
              imageRef: widget.imageRefs[image],
              width: g.rowHeight,
              height: g.rowHeight,
              borderRadius: BorderRadius.circular(11),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            key: const ValueKey('matching-reset'),
            onPressed: _answer.isEmpty
                ? null
                : () => setState(() {
                      _answer.clear();
                      _selectedLeft = null;
                    }),
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reiniciar'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            key: const ValueKey('matching-confirm'),
            onPressed: _answer.isComplete ? _confirm : null,
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            icon: const Icon(Icons.check),
            label: const Text('Confirmar'),
          ),
        ),
      ],
    );
  }

  Widget _buildSummary() {
    final correct = _results!.where((r) => r).length;
    return Column(
      children: [
        Text(
          '$correct de $_count ${_count == 1 ? 'correcta' : 'correctas'}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        if (correct < _count)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'La línea punteada verde muestra la pareja correcta.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
      ],
    );
  }
}

/// Medidas del tablero. Todo sale de cuentas (no de GlobalKeys): así se sabe
/// dónde empieza y termina cada línea y sobre qué celda está el puntero.
class _BoardGeometry {
  final double width;
  final int count;
  static const spacing = 12.0;

  late final double leftWidth = width * 0.38;
  late final double gap = max(56.0, width * 0.2);
  late final double rowHeight = min(
    max(width - leftWidth - gap, 56.0),
    switch (count) { <= 3 => 130.0, 4 => 110.0, 5 => 96.0, _ => 84.0 },
  );

  _BoardGeometry({required this.width, required this.count});

  double get imageLeft => leftWidth + gap;
  double get height => count * rowHeight + (count - 1) * spacing;
  double rowTop(int row) => row * (rowHeight + spacing);

  Offset leftAnchor(int row) => Offset(leftWidth, rowTop(row) + rowHeight / 2);
  Offset rightAnchor(int row) => Offset(imageLeft, rowTop(row) + rowHeight / 2);

  bool isOverLeftColumn(Offset p) => p.dx >= 0 && p.dx <= leftWidth && p.dy >= 0 && p.dy <= height;

  /// Elemento de la izquierda bajo el punto (sin contar el espacio entre filas).
  int? leftAt(Offset p) {
    if (p.dx < 0 || p.dx > leftWidth) return null;
    for (var row = 0; row < count; row++) {
      final top = rowTop(row);
      if (p.dy >= top && p.dy <= top + rowHeight) return row;
    }
    return null;
  }

  /// Fila de imagen donde se suelta una línea. Es generoso a propósito: cuenta
  /// la mitad derecha del hueco y el espacio entre filas.
  int? slotAt(Offset p) {
    if (p.dx < leftWidth + gap / 2 || p.dx > width) return null;
    if (p.dy < -spacing || p.dy > height + spacing) return null;
    final row = (p.dy / (rowHeight + spacing)).floor();
    return row.clamp(0, count - 1);
  }
}

class _LinesPainter extends CustomPainter {
  final _BoardGeometry geometry;
  final Map<int, int> connections;
  final List<int> slotOfImage;
  final Color Function(int left) colorFor;
  final int? dragLeft;
  final Offset? dragPoint;
  final List<bool>? results;
  final Color idleColor;

  _LinesPainter({
    required this.geometry,
    required this.connections,
    required this.slotOfImage,
    required this.colorFor,
    required this.dragLeft,
    required this.dragPoint,
    required this.results,
    required this.idleColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final g = geometry;

    // Pareja correcta, punteada, para las que quedaron mal.
    final results = this.results;
    if (results != null) {
      for (var left = 0; left < results.length; left++) {
        if (!results[left]) {
          _dashed(canvas, g.leftAnchor(left), g.rightAnchor(slotOfImage[left]), AppColors.teal);
        }
      }
    }

    for (final entry in connections.entries) {
      _arrow(canvas, g.leftAnchor(entry.key), g.rightAnchor(slotOfImage[entry.value]), colorFor(entry.key));
    }

    final dragLeft = this.dragLeft;
    final dragPoint = this.dragPoint;
    if (dragLeft != null && dragPoint != null) {
      _arrow(canvas, g.leftAnchor(dragLeft), dragPoint, colorFor(dragLeft));
    }

    // Puntos de donde salen y adonde llegan las líneas.
    final connectedImages = {for (final e in connections.entries) e.value: e.key};
    for (var row = 0; row < g.count; row++) {
      final leftConnected = connections.containsKey(row) || dragLeft == row;
      _dot(canvas, g.leftAnchor(row), leftConnected ? colorFor(row) : idleColor);
    }
    for (var image = 0; image < slotOfImage.length; image++) {
      final left = connectedImages[image];
      _dot(canvas, g.rightAnchor(slotOfImage[image]), left == null ? idleColor : colorFor(left));
    }
  }

  void _arrow(Canvas canvas, Offset from, Offset to, Color color) {
    final direction = to - from;
    final length = direction.distance;
    if (length < 1) return;
    final unit = direction / length;
    const headLength = 12.0;
    final base = to - unit * headLength;
    final normal = Offset(-unit.dy, unit.dx);

    canvas.drawLine(
      from,
      base,
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    final head = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(base.dx + normal.dx * 6, base.dy + normal.dy * 6)
      ..lineTo(base.dx - normal.dx * 6, base.dy - normal.dy * 6)
      ..close();
    canvas.drawPath(head, Paint()..color = color);
  }

  void _dashed(Canvas canvas, Offset from, Offset to, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final direction = to - from;
    final length = direction.distance;
    if (length < 1) return;
    final unit = direction / length;
    const dash = 8.0;
    const space = 6.0;
    for (var d = 0.0; d < length; d += dash + space) {
      canvas.drawLine(from + unit * d, from + unit * min(d + dash, length), paint);
    }
  }

  void _dot(Canvas canvas, Offset center, Color color) {
    canvas.drawCircle(center, 6, Paint()..color = color);
    canvas.drawCircle(center, 2.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
