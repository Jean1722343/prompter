import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/script_store.dart';
import 'data/storage.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

class PrompterApp extends StatefulWidget {
  const PrompterApp({super.key});

  @override
  State<PrompterApp> createState() => _PrompterAppState();
}

class _PrompterAppState extends State<PrompterApp> with WidgetsBindingObserver {
  final _store = ScriptStore()..load();
  Appearance _appearance = Appearance.system;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Storage.appearance().then((a) {
      if (mounted) setState(() => _appearance = a);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _store.dispose();
    super.dispose();
  }

  // En modo automático, sigue al sistema en cuanto cambia.
  @override
  void didChangePlatformBrightness() {
    if (_appearance == Appearance.system) setState(() {});
  }

  void _setAppearance(Appearance a) {
    setState(() => _appearance = a);
    Storage.saveAppearance(a);
  }

  @override
  Widget build(BuildContext context) {
    final platform = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final dark = _appearance.resolve(platform);
    AppColors.dark = dark;

    return AppearanceScope(
      appearance: _appearance,
      onChanged: _setAppearance,
      child: ScriptScope(
        store: _store,
        child: MaterialApp(
          title: 'Prompter',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          themeAnimationDuration: Duration.zero,
          // Todos los cristales comparten una sola captura del fondo.
          builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: AppColors.systemOverlay,
            // La clave obliga a repintar todo con la nueva paleta.
            child: KeyedSubtree(key: ValueKey(dark), child: BackdropGroup(child: child!)),
          ),
          home: const HomeScreen(),
        ),
      ),
    );
  }
}

/// Apariencia actual y forma de cambiarla.
class AppearanceScope extends InheritedWidget {
  const AppearanceScope({super.key, required this.appearance, required this.onChanged, required super.child});

  final Appearance appearance;
  final ValueChanged<Appearance> onChanged;

  static AppearanceScope of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppearanceScope>()!;

  @override
  bool updateShouldNotify(AppearanceScope old) => old.appearance != appearance;
}

/// Da acceso a la lista de guiones desde cualquier pantalla.
class ScriptScope extends InheritedNotifier<ScriptStore> {
  const ScriptScope({super.key, required ScriptStore store, required super.child}) : super(notifier: store);

  static ScriptStore of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ScriptScope>()!.notifier!;

  static ScriptStore read(BuildContext context) => context.getInheritedWidgetOfExactType<ScriptScope>()!.notifier!;
}
