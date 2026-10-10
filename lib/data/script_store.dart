import 'package:flutter/foundation.dart';

import '../models/script.dart';
import 'storage.dart';

/// Lista de guiones en memoria, ordenada por última edición, con guardado a disco.
class ScriptStore extends ChangeNotifier {
  List<Script> _scripts = [];
  bool _loaded = false;

  List<Script> get scripts => List.unmodifiable(_scripts);
  bool get loaded => _loaded;

  Future<void> load() async {
    _scripts = await Storage.loadScripts();
    if (_scripts.isEmpty && !await Storage.isSeeded()) {
      _scripts = [_welcomeScript()];
      await Storage.saveScripts(_scripts);
    }
    await Storage.markSeeded();
    _sort();
    _loaded = true;
    notifyListeners();
  }

  Script? byId(String id) {
    for (final s in _scripts) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<void> upsert(Script script) async {
    final i = _scripts.indexWhere((s) => s.id == script.id);
    if (i == -1) {
      _scripts.add(script);
    } else {
      _scripts[i] = script;
    }
    _sort();
    notifyListeners();
    await Storage.saveScripts(_scripts);
  }

  Future<void> delete(String id) async {
    _scripts.removeWhere((s) => s.id == id);
    notifyListeners();
    await Storage.saveScripts(_scripts);
  }

  Future<Script> duplicate(Script script) async {
    final copy = Script.create(title: '${script.displayTitle} (copia)', content: script.content);
    await upsert(copy);
    return copy;
  }

  void _sort() => _scripts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  static Script _welcomeScript() => Script.create(
    title: 'Bienvenido a Prompter 👋',
    content:
        'Hola. Este es un guion de ejemplo para que veas cómo funciona.\n\n'
        'Toca el botón azul de reproducir y elige "Flotante sobre la cámara". '
        'Se abrirá una ventana encima de tu cámara para que leas mientras grabas.\n\n'
        'Abajo tienes los controles: play y pausa, retroceder, adelantar, '
        'y los botones menos y más para cambiar la velocidad. '
        'Arrastra la barra de progreso para saltar a cualquier parte.\n\n'
        'Arrastra la barra de arriba para mover la ventana. '
        'Pellizca con dos dedos para hacerla más grande o más pequeña, '
        'o arrastra la esquina de abajo a la derecha.\n\n'
        'Con la gota cambias la transparencia y con el botón de letra, el tamaño del texto.\n\n'
        'Consejo: coloca la ventana arriba, cerca de la cámara frontal. '
        'Así parecerá que miras directamente a quien te ve.\n\n'
        'Cuando termines, borra este guion y crea el tuyo. ¡Mucha suerte con tu grabación!',
  );
}
