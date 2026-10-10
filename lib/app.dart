import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/script_store.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

class PrompterApp extends StatefulWidget {
  const PrompterApp({super.key});

  @override
  State<PrompterApp> createState() => _PrompterAppState();
}

class _PrompterAppState extends State<PrompterApp> {
  final _store = ScriptStore()..load();

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScriptScope(
      store: _store,
      child: MaterialApp(
        title: 'Prompter',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        // Todos los cristales comparten una sola captura del fondo.
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
          ),
          child: BackdropGroup(child: child!),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

/// Da acceso a la lista de guiones desde cualquier pantalla.
class ScriptScope extends InheritedNotifier<ScriptStore> {
  const ScriptScope({super.key, required ScriptStore store, required super.child}) : super(notifier: store);

  static ScriptStore of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ScriptScope>()!.notifier!;

  static ScriptStore read(BuildContext context) => context.getInheritedWidgetOfExactType<ScriptScope>()!.notifier!;
}
