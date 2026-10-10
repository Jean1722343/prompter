import 'dart:io';

import 'package:flutter/services.dart';

import '../data/storage.dart';
import '../models/script.dart';

/// Lado de la app: abrir/cerrar la ventana flotante y gestionar el permiso.
class OverlayBridge {
  OverlayBridge._();

  static const _channel = MethodChannel('prompter/overlay');

  /// La ventana encima de otras apps solo existe en Android.
  static bool get isSupported => Platform.isAndroid;

  static Future<bool> hasPermission() async =>
      isSupported && (await _channel.invokeMethod<bool>('hasPermission') ?? false);

  static Future<void> requestPermission() => _channel.invokeMethod('requestPermission');

  static Future<bool> isActive() async => isSupported && (await _channel.invokeMethod<bool>('isActive') ?? false);

  static Future<void> show(Script script) async {
    await Storage.setOverlayScript(script);
    await _channel.invokeMethod('show');
  }

  static Future<void> close() => _channel.invokeMethod('close');

  /// Abre la cámara en modo vídeo (frontal si el fabricante lo permite).
  static Future<bool> openCamera() async => await _channel.invokeMethod<bool>('openCamera') ?? false;

  /// Manda la app al fondo para dejar ver lo que hay detrás.
  static Future<void> minimizeApp() => _channel.invokeMethod('minimize');
}

/// Lado de la ventana flotante: mover, redimensionar, cerrar.
class OverlayWindow {
  OverlayWindow._();

  static const _channel = MethodChannel('prompter/overlay_window');

  static void setReloadHandler(Future<void> Function() onReload) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'reload') await onReload();
    });
  }

  /// A partir de aquí, Android mueve la ventana siguiendo al dedo hasta soltar.
  static Future<void> beginMove() => _channel.invokeMethod('beginMove');

  /// Cambia el tamaño. Con [shift] la ventana se desplaza si no cabe en
  /// pantalla; sin él, crece desde la esquina superior izquierda.
  static Future<OverlayGeometry?> resize(Size size, {bool persist = false, bool shift = false}) async {
    final map = await _channel.invokeMapMethod<String, double>('resize', {
      'width': size.width,
      'height': size.height,
      'persist': persist,
      'shift': shift,
    });
    return map == null ? null : OverlayGeometry.fromMap(map);
  }

  static Future<OverlayGeometry?> geometry() async {
    final map = await _channel.invokeMapMethod<String, double>('geometry');
    return map == null ? null : OverlayGeometry.fromMap(map);
  }

  static Future<void> openApp() => _channel.invokeMethod('openApp');

  static Future<void> close() => _channel.invokeMethod('close');
}

class OverlayGeometry {
  const OverlayGeometry({required this.size, required this.offset, required this.screen});

  factory OverlayGeometry.fromMap(Map<String, double> m) => OverlayGeometry(
    size: Size(m['width']!, m['height']!),
    offset: Offset(m['x']!, m['y']!),
    screen: Size(m['screenWidth']!, m['screenHeight']!),
  );

  final Size size;
  final Offset offset;
  final Size screen;
}
