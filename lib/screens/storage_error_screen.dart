import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/storage_service.dart';

/// App mínima que se muestra cuando Hive no pudo abrir alguna caja.
class StorageErrorApp extends StatelessWidget {
  final Map<String, Object> failures;
  final Future<void> Function() onRetry;

  const StorageErrorApp({super.key, required this.failures, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Quiz Daily',
      theme: ThemeData(useMaterial3: true, textTheme: GoogleFonts.poppinsTextTheme()),
      home: StorageErrorScreen(failures: failures, onRetry: onRetry),
    );
  }
}

class StorageErrorScreen extends StatefulWidget {
  final Map<String, Object> failures;
  final Future<void> Function() onRetry;

  const StorageErrorScreen({super.key, required this.failures, required this.onRetry});

  @override
  State<StorageErrorScreen> createState() => _StorageErrorScreenState();
}

class _StorageErrorScreenState extends State<StorageErrorScreen> {
  static const _labels = {
    HiveBoxes.questions: 'Preguntas',
    HiveBoxes.progress: 'Progreso y configuración',
    HiveBoxes.stats: 'Estadísticas',
  };

  bool _busy = false;

  Future<void> _retry() async {
    setState(() => _busy = true);
    await widget.onRetry();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _resetDamaged() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Restablecer los datos dañados?'),
        content: Text(
          'Se van a borrar: ${widget.failures.keys.map((k) => _labels[k] ?? k).join(', ')}.\n\n'
          'Antes se guarda una copia de los archivos en el almacenamiento de la app.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restablecer')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final backupPath = await StorageService.backupAndDelete(widget.failures.keys);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Copia guardada'),
          content: Text('Los archivos originales quedaron en:\n$backupPath'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Continuar'))],
        ),
      );
      await widget.onRetry();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo restablecer: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 24),
            const Icon(Icons.storage_rounded, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              'No pudimos abrir tus datos',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'No se borró nada. Si el problema fue temporal, reintentá. '
              'Si se repite, podés restablecer solo las partes que fallaron.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            for (final entry in widget.failures.entries)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.error_outline, color: Colors.redAccent),
                  title: Text(_labels[entry.key] ?? entry.key),
                  subtitle: Text('${entry.value}', maxLines: 4, overflow: TextOverflow.ellipsis),
                ),
              ),
            const SizedBox(height: 24),
            if (_busy)
              const Center(child: CircularProgressIndicator())
            else ...[
              FilledButton.icon(onPressed: _retry, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _resetDamaged,
                icon: const Icon(Icons.restore),
                label: const Text('Restablecer datos dañados'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
