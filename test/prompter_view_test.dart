import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prompter/widgets/prompter_view.dart';

Widget _host(Size size, PrompterController controller) => MaterialApp(
  home: Center(
    child: SizedBox.fromSize(
      size: size,
      child: PrompterView(text: List.filled(200, 'palabra').join(' '), controller: controller, fontSize: 26, speed: 5),
    ),
  ),
);

void main() {
  testWidgets('aguanta un primer frame de tamaño 0 (ventana flotante)', (tester) async {
    final controller = PrompterController();
    await tester.pumpWidget(_host(Size.zero, controller));
    controller.restart();
    await tester.pumpWidget(_host(const Size(360, 240), controller));
    await tester.pump();
    expect(tester.takeException(), isNull);
    controller.dispose();
  });

  testWidgets('cuenta atrás y luego avanza solo hasta pausar', (tester) async {
    final controller = PrompterController();
    await tester.pumpWidget(_host(const Size(360, 240), controller));

    controller.play();
    expect(controller.countdown, 3);
    await tester.pump(const Duration(milliseconds: 2600));
    expect(controller.countdown, isNull);
    expect(controller.playing, isTrue);

    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(controller.progress, greaterThan(0));

    controller.pause();
    final progress = controller.progress;
    await tester.pump(const Duration(seconds: 1));
    expect(controller.progress, progress);

    controller.restart();
    await tester.pump();
    expect(controller.progress, 0);
    controller.dispose();
  });
}
