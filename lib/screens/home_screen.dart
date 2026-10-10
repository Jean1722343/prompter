import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../app.dart';
import '../models/script.dart';
import '../services/overlay_bridge.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/glass.dart';
import 'editor_screen.dart';
import 'launch_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  final _collapsed = ValueNotifier(false);
  String _query = '';
  bool _overlayActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(() => _collapsed.value = _scroll.offset > 90);
    _refreshOverlay();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _search.dispose();
    _scroll.dispose();
    _collapsed.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshOverlay();
  }

  Future<void> _refreshOverlay() async {
    final active = await OverlayBridge.isActive();
    if (mounted && active != _overlayActive) setState(() => _overlayActive = active);
  }

  void _openEditor([Script? script]) {
    Navigator.of(
      context,
    ).push(CupertinoPageRoute(builder: (_) => EditorScreen(scriptId: script?.id))).then((_) => _refreshOverlay());
  }

  void _openLauncher(Script script) => showLaunchSheet(context, script).then((_) => _refreshOverlay());

  Future<void> _delete(Script script) async {
    final store = ScriptScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    await store.delete(script.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('"${script.displayTitle}" eliminado'),
          action: SnackBarAction(label: 'Deshacer', onPressed: () => store.upsert(script)),
        ),
      );
  }

  void _showOptions(Script script) {
    showGlassSheet<void>(
      context,
      builder: (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 14),
              child: Text(
                script.displayTitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.footnote,
              ),
            ),
            _ActionRow(
              icon: CupertinoIcons.play_fill,
              label: 'Leer',
              onTap: () {
                Navigator.pop(sheet);
                _openLauncher(script);
              },
            ),
            _ActionRow(
              icon: CupertinoIcons.pencil,
              label: 'Editar',
              onTap: () {
                Navigator.pop(sheet);
                _openEditor(script);
              },
            ),
            _ActionRow(
              icon: CupertinoIcons.doc_on_doc,
              label: 'Duplicar',
              onTap: () {
                Navigator.pop(sheet);
                ScriptScope.read(context).duplicate(script);
              },
            ),
            _ActionRow(
              icon: CupertinoIcons.trash,
              label: 'Eliminar',
              destructive: true,
              onTap: () {
                Navigator.pop(sheet);
                _delete(script);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = ScriptScope.of(context);
    final all = store.scripts;
    final q = _query.trim().toLowerCase();
    final scripts = q.isEmpty
        ? all
        : all.where((s) => s.title.toLowerCase().contains(q) || s.content.toLowerCase().contains(q)).toList();
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AmbientBackground(
        child: Stack(
          children: [
            CustomScrollView(
              controller: _scroll,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Brand(),
                        const SizedBox(height: 30),
                        Text('Guiones', style: AppText.largeTitle),
                        const SizedBox(height: 6),
                        Text(
                          all.isEmpty
                              ? 'Escribe lo que vas a decir y léelo mientras grabas.'
                              : all.length == 1
                              ? '1 guion · listo para grabar'
                              : '${all.length} guiones · listos para grabar',
                          style: AppText.body.copyWith(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_overlayActive)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: _ActiveOverlayBanner(
                        onClose: () async {
                          await OverlayBridge.close();
                          _refreshOverlay();
                        },
                      ),
                    ),
                  ),
                if (all.length > 2)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: _SearchField(controller: _search, onChanged: (v) => setState(() => _query = v)),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 18)),
                if (store.loaded && all.isEmpty)
                  SliverFillRemaining(hasScrollBody: false, child: _EmptyState(onCreate: () => _openEditor()))
                else if (scripts.isEmpty && q.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text('Nada coincide con "$_query"', textAlign: TextAlign.center, style: AppText.body),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 120 + bottomInset),
                    sliver: SliverList.separated(
                      itemCount: scripts.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final s = scripts[i];
                        return Dismissible(
                          key: ValueKey(s.id),
                          direction: DismissDirection.endToStart,
                          background: const _DeleteBackground(),
                          onDismissed: (_) => _delete(s),
                          child: ScriptCard(
                            script: s,
                            onTap: () => _openEditor(s),
                            onLongPress: () => _showOptions(s),
                            onPlay: () => _openLauncher(s),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
            // Barra compacta de cristal que aparece al hacer scroll (como en iOS).
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ValueListenableBuilder(
                valueListenable: _collapsed,
                builder: (context, collapsed, _) => IgnorePointer(
                  ignoring: !collapsed,
                  child: AnimatedOpacity(
                    opacity: collapsed ? 1 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: BackdropGroup(child: _CompactHeader(topInset: topInset)),
                  ),
                ),
              ),
            ),
            // Barra flotante inferior.
            Positioned(
              left: 0,
              right: 0,
              bottom: 16 + bottomInset,
              child: Center(
                child: GlassPill(
                  tinted: true,
                  icon: CupertinoIcons.add,
                  label: 'Nuevo guion',
                  height: 56,
                  onTap: () => _openEditor(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactHeader extends StatelessWidget {
  const _CompactHeader({required this.topInset});

  final double topInset;

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 0,
      blur: 30,
      tint: AppColors.background,
      tintOpacity: 0.35,
      strength: 0.6,
      child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: SizedBox(
          height: 48,
          child: Center(child: Text('Guiones', style: AppText.headline)),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: ShapeDecoration(
            gradient: AppColors.accentGradient,
            shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(11)),
          ),
          child: const Icon(CupertinoIcons.text_alignleft, color: Colors.white, size: 19),
        ),
        const SizedBox(width: 10),
        Text('Prompter', style: AppText.headline.copyWith(fontSize: 18, fontWeight: FontWeight.w700)),
        const Spacer(),
        GlassIconButton(
          icon: switch (AppearanceScope.of(context).appearance) {
            Appearance.system => CupertinoIcons.circle_lefthalf_fill,
            Appearance.light => CupertinoIcons.sun_max_fill,
            Appearance.dark => CupertinoIcons.moon_fill,
          },
          size: 36,
          semanticLabel: 'Apariencia',
          onTap: () => _showAppearanceSheet(context),
        ),
        const SizedBox(width: 8),
        Glass(
          radius: 16,
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RecDot(),
              SizedBox(width: 7),
              Text(
                'REC',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.6, color: AppColors.label),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Hoja para elegir modo claro, oscuro o automático.
void _showAppearanceSheet(BuildContext context) {
  final scope = AppearanceScope.of(context);
  showGlassSheet<void>(
    context,
    builder: (sheet) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text('Apariencia', textAlign: TextAlign.center, style: AppText.title),
          ),
          for (final a in Appearance.values)
            _ActionRow(
              icon: switch (a) {
                Appearance.system => CupertinoIcons.circle_lefthalf_fill,
                Appearance.light => CupertinoIcons.sun_max_fill,
                Appearance.dark => CupertinoIcons.moon_fill,
              },
              label: a == Appearance.system ? 'Automático (como el sistema)' : a.label,
              selected: a == scope.appearance,
              onTap: () {
                Navigator.pop(sheet);
                scope.onChanged(a);
              },
            ),
        ],
      ),
    ),
  );
}

/// Punto rojo que late, como el de una cámara grabando.
class RecDot extends StatefulWidget {
  const RecDot({super.key, this.size = 8});

  final double size;

  @override
  State<RecDot> createState() => _RecDotState();
}

class _RecDotState extends State<RecDot> with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _anim, curve: Curves.easeInOut)),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: AppColors.red,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: AppColors.red.withValues(alpha: 0.8), blurRadius: 8)],
        ),
      ),
    );
  }
}

class ScriptCard extends StatelessWidget {
  const ScriptCard({
    super.key,
    required this.script,
    required this.onTap,
    required this.onPlay,
    required this.onLongPress,
  });

  final Script script;
  final VoidCallback onTap;
  final VoidCallback onPlay;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final preview = script.content.trim().replaceAll(RegExp(r'\s+'), ' ');
    final canPlay = script.content.trim().isNotEmpty;

    return Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      scale: 0.97,
      haptic: false,
      child: Glass(
        radius: 30,
        padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    script.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.headline.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    preview.isEmpty ? 'Guion vacío' : preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _Meta(icon: CupertinoIcons.text_alignleft, label: pluralWords(script.wordCount)),
                      _Meta(icon: CupertinoIcons.timer, label: '≈ ${formatDuration(script.readingTime)}'),
                      _Meta(icon: CupertinoIcons.clock, label: formatRelative(script.updatedAt)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Pressable(
              onTap: canPlay ? onPlay : null,
              scale: 0.88,
              semanticLabel: 'Leer guion',
              child: const AccentOrb(
                size: 54,
                child: Padding(
                  padding: EdgeInsets.only(left: 3),
                  child: Icon(CupertinoIcons.play_fill, color: Colors.white, size: 24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.tertiaryLabel),
        const SizedBox(width: 4),
        Text(label, style: AppText.caption.copyWith(color: AppColors.secondaryLabel)),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 22,
      height: 46,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textAlignVertical: TextAlignVertical.center,
        style: AppText.headline.copyWith(fontWeight: FontWeight.w400, fontSize: 16),
        decoration: InputDecoration(
          prefixIcon: Icon(CupertinoIcons.search, color: AppColors.secondaryLabel, size: 20),
          hintText: 'Buscar',
          contentPadding: EdgeInsets.zero,
          suffixIcon: ValueListenableBuilder(
            valueListenable: controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : GestureDetector(
                    onTap: () {
                      controller.clear();
                      onChanged('');
                    },
                    child: Icon(CupertinoIcons.xmark_circle_fill, size: 18, color: AppColors.tertiaryLabel),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ActiveOverlayBanner extends StatelessWidget {
  const _ActiveOverlayBanner({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 24,
      tint: AppColors.accent,
      tintOpacity: 0.18,
      padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
      child: Row(
        children: [
          const RecDot(size: 9),
          const SizedBox(width: 12),
          Expanded(child: Text('Teleprompter flotante activo', style: AppText.headline)),
          GlassPill(label: 'Cerrar', height: 38, fontSize: 14, onTap: onClose),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.red : AppColors.label;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Pressable(
        onTap: onTap,
        scale: 0.97,
        child: Glass(
          radius: 20,
          height: 56,
          strength: 0.8,
          blurBackground: false,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              Icon(icon, color: color, size: 21),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: AppText.headline.copyWith(color: color))),
              if (selected) Icon(CupertinoIcons.checkmark_alt, color: AppColors.accent, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 30),
      decoration: ShapeDecoration(
        color: AppColors.red.withValues(alpha: 0.85),
        shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(30)),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.trash_fill, color: Colors.white, size: 24),
          SizedBox(height: 4),
          Text(
            'Eliminar',
            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 140),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Glass(
            radius: 34,
            width: 104,
            height: 104,
            child: Icon(CupertinoIcons.doc_text, size: 46, color: AppColors.accent),
          ),
          const SizedBox(height: 26),
          Text('Tu primer guion te espera', style: AppText.title, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Ponle un título, escribe o pega el texto y léelo flotando sobre tu cámara.',
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(fontSize: 16),
          ),
        ],
      ),
    );
  }
}
