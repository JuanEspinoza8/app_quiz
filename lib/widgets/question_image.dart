import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/image_store.dart';

/// Muestra una imagen de pregunta a partir de su referencia. Si el archivo
/// no está (por ejemplo, una pregunta importada de otro teléfono), muestra
/// un ícono en lugar de fallar.
class QuestionImage extends StatelessWidget {
  final String? imageRef;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius borderRadius;

  const QuestionImage({
    super.key,
    required this.imageRef,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = BorderRadius.zero,
  });

  @override
  Widget build(BuildContext context) {
    final ref = imageRef;
    final provider = ref == null
        ? null
        : context.watch<ImageStore>().providerFor(ref, cacheWidth: _cacheWidth(context));

    return ClipRRect(
      borderRadius: borderRadius,
      child: provider == null
          ? _placeholder(context)
          : Image(
              image: provider,
              width: width,
              height: height,
              fit: fit,
              gaplessPlayback: true,
              errorBuilder: (context, _, _) => _placeholder(context),
            ),
    );
  }

  /// Se decodifica al tamaño en pantalla (o a 1080 px si no se sabe).
  int _cacheWidth(BuildContext context) {
    final w = width;
    if (w == null || !w.isFinite) return 1080;
    return (w * MediaQuery.devicePixelRatioOf(context)).round();
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.withValues(alpha: 0.15),
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
    );
  }
}
