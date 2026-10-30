import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../data/progress_repository.dart';

/// Cuando la app vuelve del segundo plano, reinicia el progreso diario si
/// cambió el día. Sin esto, una app que quedó abierta de un día para otro
/// seguía mostrando el progreso del día anterior en el inicio.
class DayRolloverOnResume extends StatefulWidget {
  final Widget child;
  const DayRolloverOnResume({super.key, required this.child});

  @override
  State<DayRolloverOnResume> createState() => _DayRolloverOnResumeState();
}

class _DayRolloverOnResumeState extends State<DayRolloverOnResume> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => context.read<ProgressRepository>().rolloverIfNewDay(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
