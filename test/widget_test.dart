import 'package:flutter_test/flutter_test.dart';
import 'package:prompter/models/prompter_settings.dart';
import 'package:prompter/models/script.dart';
import 'package:prompter/utils/format.dart';

void main() {
  group('Script', () {
    test('cuenta palabras y estima el tiempo de lectura', () {
      final script = Script.create(title: 'Hola', content: List.filled(300, 'palabra').join(' '));
      expect(script.wordCount, 300);
      expect(script.readingTime, const Duration(minutes: 2));
    });

    test('un guion sin texto está vacío y muestra "Sin título"', () {
      final script = Script.create(title: '  ', content: '\n');
      expect(script.isEmpty, isTrue);
      expect(script.wordCount, 0);
      expect(script.displayTitle, 'Sin título');
    });

    test('se serializa y deserializa sin perder datos', () {
      final script = Script.create(title: 'Intro', content: 'Bienvenidos al canal');
      final copy = Script.fromJson(script.toJson());
      expect(copy.id, script.id);
      expect(copy.title, script.title);
      expect(copy.content, script.content);
      expect(copy.updatedAt.millisecondsSinceEpoch, script.updatedAt.millisecondsSinceEpoch);
    });
  });

  group('PrompterSettings', () {
    test('limita los valores a rangos válidos', () {
      final s = PrompterSettings.overlay.copyWith(opacity: 3, speed: -1, fontSize: 500);
      expect(s.opacity, 1);
      expect(s.speed, PrompterSettings.minSpeed);
      expect(s.fontSize, PrompterSettings.maxFont);
    });
  });

  group('format', () {
    test('duraciones legibles', () {
      expect(formatDuration(const Duration(seconds: 40)), '40 s');
      expect(formatDuration(const Duration(minutes: 2, seconds: 30)), '2 min 30 s');
      expect(formatDuration(const Duration(minutes: 12, seconds: 40)), '13 min');
    });

    test('fechas relativas', () {
      final now = DateTime(2026, 10, 10, 12);
      expect(formatRelative(now.subtract(const Duration(seconds: 10)), now: now), 'ahora mismo');
      expect(formatRelative(now.subtract(const Duration(minutes: 5)), now: now), 'hace 5 min');
      expect(formatRelative(DateTime(2026, 10, 9, 20), now: now), 'ayer');
      expect(formatRelative(DateTime(2026, 3, 12), now: now), '12 mar');
    });
  });
}
