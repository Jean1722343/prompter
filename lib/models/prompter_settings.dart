/// Ajustes de lectura. Se guardan por separado para la pantalla completa y
/// para la ventana flotante, porque una ventana pequeña necesita otra letra.
class PrompterSettings {
  const PrompterSettings({
    required this.fontSize,
    required this.speed,
    required this.opacity,
    this.mirror = false,
    this.dark = false,
  });

  factory PrompterSettings.fromJson(Map<String, dynamic> json, PrompterSettings fallback) {
    double read(String key, double def) => (json[key] as num?)?.toDouble() ?? def;
    return PrompterSettings(
      fontSize: read('fontSize', fallback.fontSize).clamp(minFont, maxFont),
      speed: read('speed', fallback.speed).clamp(minSpeed, maxSpeed),
      opacity: read('opacity', fallback.opacity).clamp(0.0, 1.0),
      mirror: json['mirror'] as bool? ?? fallback.mirror,
      dark: json['dark'] as bool? ?? fallback.dark,
    );
  }

  static const reader = PrompterSettings(fontSize: 42, speed: 3, opacity: 1);
  static const overlay = PrompterSettings(fontSize: 26, speed: 3, opacity: 0.55);

  static const minFont = 14.0;
  static const maxFont = 96.0;
  static const minSpeed = 0.5;
  static const maxSpeed = 10.0;

  final double fontSize;

  /// Velocidad de 0.5 a 10. Se traduce a líneas por segundo en el lector.
  final double speed;

  /// Opacidad del fondo (0 = totalmente transparente, 1 = sólido).
  final double opacity;

  /// Texto en espejo, para teleprompters con cristal.
  final bool mirror;

  /// Fondo negro y letra blanca (lector a pantalla completa).
  final bool dark;

  PrompterSettings copyWith({double? fontSize, double? speed, double? opacity, bool? mirror, bool? dark}) =>
      PrompterSettings(
        fontSize: (fontSize ?? this.fontSize).clamp(minFont, maxFont),
        speed: (speed ?? this.speed).clamp(minSpeed, maxSpeed),
        opacity: (opacity ?? this.opacity).clamp(0.0, 1.0),
        mirror: mirror ?? this.mirror,
        dark: dark ?? this.dark,
      );

  Map<String, dynamic> toJson() => {
    'fontSize': fontSize,
    'speed': speed,
    'opacity': opacity,
    'mirror': mirror,
    'dark': dark,
  };
}
