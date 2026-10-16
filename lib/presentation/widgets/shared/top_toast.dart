import 'dart:async';

import 'package:flutter/material.dart';

/// Aviso pequeño que baja desde arriba y desaparece solo, sin tapar la
/// descripción de los videos (que está abajo, donde salen los SnackBar).
///
/// Usa el Overlay raíz, así que se puede llamar justo antes de cerrar una
/// pantalla con Navigator.pop y el aviso se sigue viendo en la siguiente.
void showTopToast(
  BuildContext context,
  String message, {
  IconData icon = Icons.check_circle,
  Color? iconColor,
  bool isError = false,
  Duration duration = const Duration(milliseconds: 2200),
}) {
  showTopToastIn(
    Overlay.of(context, rootOverlay: true),
    message,
    icon: icon,
    iconColor: iconColor,
    isError: isError,
    duration: duration,
  );
}

/// Igual que [showTopToast], pero con el Overlay ya obtenido. Sirve cuando
/// el widget que lanza el aviso puede desaparecer antes de mostrarlo (por
/// ejemplo, el botón de borrar de un post que se acaba de eliminar):
/// se toma el Overlay ANTES del await y se usa después.
void showTopToastIn(
  OverlayState overlay,
  String message, {
  IconData icon = Icons.check_circle,
  Color? iconColor,
  bool isError = false,
  Duration duration = const Duration(milliseconds: 2200),
}) {
  if (!overlay.mounted) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _TopToast(
      message: message,
      icon: isError ? Icons.error_outline : icon,
      iconColor: iconColor,
      isError: isError,
      duration: duration,
      onDone: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  overlay.insert(entry);
}

class _TopToast extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color? iconColor;
  final bool isError;
  final Duration duration;
  final VoidCallback onDone;

  const _TopToast({
    required this.message,
    required this.icon,
    this.iconColor,
    required this.isError,
    required this.duration,
    required this.onDone,
  });

  @override
  State<_TopToast> createState() => _TopToastState();
}

class _TopToastState extends State<_TopToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );
  late final Animation<Offset> _slide = Tween(
    begin: const Offset(0, -1.5),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _timer = Timer(widget.duration, _hide);
  }

  Future<void> _hide() async {
    _timer?.cancel();
    if (!mounted) return;
    await _controller.reverse();
    widget.onDone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.iconColor ??
        (widget.isError ? Colors.redAccent : Colors.greenAccent);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SlideTransition(
            position: _slide,
            child: FadeTransition(
              opacity: _controller,
              child: GestureDetector(
                onTap: _hide, // tocarlo lo cierra antes
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    margin: const EdgeInsets.only(top: 8, left: 24, right: 24),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xEE1E1E1E),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(color: Colors.black38, blurRadius: 12),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(widget.icon, color: color, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            widget.message,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
