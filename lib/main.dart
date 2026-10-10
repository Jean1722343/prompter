import 'package:flutter/material.dart';

import 'app.dart';
import 'overlay/overlay_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PrompterApp());
}

/// Punto de entrada de la ventana flotante. Lo arranca `OverlayService` en Android.
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OverlayApp());
}
