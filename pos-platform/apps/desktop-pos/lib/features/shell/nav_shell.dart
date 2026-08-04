/// Role-aware navigation shell (docs/desktop-architecture.md §4.3, D4),
/// restyled to the Dostop design (docs/desktop-pos-ui-design.md §3): a
/// collapsible grouped sidebar (brand + light/dark switch + nav search) and a
/// global top bar (store selector · global search ⌘K · sync status · theme ·
/// notifications) above every screen.
///
/// The role-gating, single-module fallback, and pending-finalize banner are
/// unchanged — only the chrome is new. [modules] is injectable so tests can
/// pass lightweight modules instead of the network-backed real screens.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/connection_health_provider.dart';
import '../../domain/connection_health.dart';
import '../../ui/tokens.dart';
import '../auth/session_controller.dart';
import '../cart/pending_finalize_controller.dart';
import 'feature_module.dart';
import 'modules.dart';

class NavShell extends ConsumerStatefulWidget {
  NavShell({super.key, List<FeatureModule>? modules})
      : modules = modules ?? kModules;

  final List<FeatureModule> modules;

  @override
  ConsumerState<NavShell> createState() => _NavShellState();
}

class _NavShellState extends ConsumerState<NavShell> {
  int _selected = 0;
  bool _dark = true; // design default is the dark sidebar
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final policy = ref.watch(rolePolicyProvider);
    final mods = visibleModules(widget.modules, policy);
    final session = ref.watch(sessionControllerProvider).valueOrNull;

    if (mods.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No modules available for this role.')),
      );
    }
    final index = _selected.clamp(0, mods.length - 1);
    if (mods.length < 2) return mods.first.builder(context);

    return Scaffold(
      backgroundColor: DostopColors.canvas,
      body: Row(
        children: [
          _Sidebar(
            skin: _Skin.of(_dark),
            collapsed: _collapsed,
            modules: mods,
            selectedIndex: index,
            onSelect: (i) => setState(() => _selected = i),
            onToggleCollapse: () => setState(() => _collapsed = !_collapsed),
            counterId: session?.counterId,
            displayName: session?.displayName ?? '',
            roles: session?.roles ?? const [],
            onLogout: () =>
                ref.read(sessionControllerProvider.notifier).logout(),
          ),
          Expanded(
            child: Column(
              children: [
                _TopBar(
                  storeId: session?.storeId ?? '',
                  counterId: session?.counterId ?? '',
                  dark: _dark,
                  onToggleTheme: () => setState(() => _dark = !_dark),
                ),
                const _PendingSaleBanner(),
                Expanded(child: mods[index].builder(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Top bar
// ===========================================================================

class _TopBar extends ConsumerWidget {
  const _TopBar({
    required this.storeId,
    required this.counterId,
    required this.dark,
    required this.onToggleTheme,
  });

  final String storeId;
  final String counterId;
  final bool dark;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: DostopColors.panel,
        border: Border(bottom: BorderSide(color: DostopColors.hairline)),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          // Global search needs room; drop it on narrow windows (the sidebar
          // and per-screen searches remain).
          final showSearch = c.maxWidth >= 640;
          return Row(
            children: [
              _storeSelector(),
              const SizedBox(width: 14),
              if (showSearch)
                Expanded(child: _search())
              else
                const Spacer(),
              const SizedBox(width: 14),
              const _SyncPill(),
              const SizedBox(width: 8),
              _iconButton(
                icon:
                    dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                tooltip: dark ? 'Light sidebar' : 'Dark sidebar',
                onTap: onToggleTheme,
              ),
              const SizedBox(width: 8),
              _bell(),
            ],
          );
        },
      ),
    );
  }

  Widget _storeSelector() {
    final store = storeId.isEmpty ? 'This store' : storeId;
    final counter =
        counterId.isEmpty ? 'This terminal' : 'Counter $counterId · Open';
    return Container(
      height: 40,
      constraints: const BoxConstraints(maxWidth: 230),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: DostopColors.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DostopColors.slate200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(
              color: DostopColors.brand,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Color(0xFFDCFCE7), spreadRadius: 3),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(store,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: DostopFonts.sans,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                      color: DostopColors.ink,
                    )),
                Text(counter,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: DostopFonts.sans,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: DostopColors.slate400,
                    )),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.keyboard_arrow_down, size: 16, color: DostopColors.slate400),
        ],
      ),
    );
  }

  Widget _search() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: DostopColors.slate50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: DostopColors.slate200),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 17, color: DostopColors.slate400),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Search products, invoices, customers…',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: DostopFonts.sans,
                    fontSize: 13,
                    color: DostopColors.slate400,
                  )),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: DostopColors.hairline,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('Ctrl K',
                  style: TextStyle(
                    fontFamily: DostopFonts.mono,
                    fontSize: 10.5,
                    color: DostopColors.slate400,
                  )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bell() {
    return Stack(
      children: [
        _iconButton(icon: Icons.notifications_none, tooltip: 'Notifications', onTap: () {}),
        Positioned(
          top: 8,
          right: 9,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _iconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: DostopColors.panel,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: DostopColors.slate200),
            ),
            child: Icon(icon, size: 18, color: DostopColors.slate600),
          ),
        ),
      ),
    );
  }
}

/// Live "Synced / Reconnecting / Offline" pill in the top bar.
class _SyncPill extends ConsumerWidget {
  const _SyncPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(connectionHealthControllerProvider);
    final (Color fg, Color bg, Color border, IconData icon, String label) =
        switch (health.state) {
      ServerReachability.reachable => (
          DostopColors.brandDark,
          DostopColors.stockOkBg,
          const Color(0xFFBBF7D0),
          Icons.cloud_done,
          'Synced'
        ),
      ServerReachability.degraded => (
          DostopColors.stockLowFg,
          DostopColors.stockLowBg,
          const Color(0xFFFDE68A),
          Icons.sync,
          'Reconnecting…'
        ),
      ServerReachability.unreachable => (
          DostopColors.danger,
          DostopColors.stockOutBg,
          const Color(0xFFFECACA),
          Icons.cloud_off,
          'Offline'
        ),
    };
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 7),
          Text(label,
              style: TextStyle(
                fontFamily: DostopFonts.sans,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: fg,
              )),
        ],
      ),
    );
  }
}

// ===========================================================================
// Sidebar
// ===========================================================================

/// Light/dark sidebar palette, translated from the prototype's `sb` tokens.
class _Skin {
  const _Skin({
    required this.dark,
    required this.bg,
    required this.border,
    required this.text,
    required this.brand,
    required this.group,
    required this.fieldBg,
    required this.fieldText,
    required this.hover,
    required this.cardBg,
    required this.userName,
    required this.avatarBg,
    required this.avatarFg,
  });

  final bool dark;
  final Color bg, border, text, brand, group, fieldBg, fieldText, hover, cardBg;
  final Color userName, avatarBg, avatarFg;

  factory _Skin.of(bool dark) => dark
      ? const _Skin(
          dark: true,
          bg: DostopColors.sidebarBg,
          border: DostopColors.sidebarBorder,
          text: DostopColors.sidebarText,
          brand: DostopColors.sidebarBrand,
          group: DostopColors.sidebarGroup,
          fieldBg: DostopColors.sidebarBorder,
          fieldText: Color(0xFF9CA3AF),
          hover: DostopColors.sidebarBorder,
          cardBg: DostopColors.sidebarBorder,
          userName: Color(0xFFF3F4F6),
          avatarBg: Color(0xFF064E3B),
          avatarFg: Color(0xFF6EE7B7),
        )
      : const _Skin(
          dark: false,
          bg: Color(0xFFFFFFFF),
          border: Color(0xFFE5E7EB),
          text: Color(0xFF4B5563),
          brand: Color(0xFF111827),
          group: Color(0xFF9CA3AF),
          fieldBg: Color(0xFFF3F4F6),
          fieldText: Color(0xFF6B7280),
          hover: Color(0xFFF3F4F6),
          cardBg: Color(0xFFF9FAFB),
          userName: Color(0xFF111827),
          avatarBg: DostopColors.brandWash,
          avatarFg: DostopColors.brand,
        );
}

class _Sidebar extends StatefulWidget {
  const _Sidebar({
    required this.skin,
    required this.collapsed,
    required this.modules,
    required this.selectedIndex,
    required this.onSelect,
    required this.onToggleCollapse,
    required this.counterId,
    required this.displayName,
    required this.roles,
    required this.onLogout,
  });

  final _Skin skin;
  final bool collapsed;
  final List<FeatureModule> modules;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onToggleCollapse;
  final String? counterId;
  final String displayName;
  final List<String> roles;
  final VoidCallback onLogout;

  @override
  State<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<_Sidebar> {
  String _query = '';

  bool get _collapsed => widget.collapsed;

  @override
  Widget build(BuildContext context) {
    final skin = widget.skin;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: _collapsed ? 76 : 248,
      decoration: BoxDecoration(
        color: skin.bg,
        border: Border(right: BorderSide(color: skin.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(skin),
          if (!_collapsed) _search(skin),
          Expanded(child: _nav(skin)),
          _footer(skin),
        ],
      ),
    );
  }

  Widget _header(_Skin skin) {
    final brandMark = Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: DostopColors.brand,
        borderRadius: BorderRadius.circular(9),
      ),
      child: const Icon(Icons.eco, size: 19, color: Colors.white),
    );
    final collapseBtn = IconButton(
      tooltip: _collapsed ? 'Expand' : 'Collapse',
      onPressed: widget.onToggleCollapse,
      iconSize: 18,
      visualDensity: VisualDensity.compact,
      color: skin.text,
      icon: Icon(_collapsed ? Icons.chevron_right : Icons.chevron_left),
    );

    if (_collapsed) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: skin.border)),
        ),
        child: Column(children: [brandMark, const SizedBox(height: 6), collapseBtn]),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 10, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: skin.border)),
      ),
      child: Row(
        children: [
          brandMark,
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dostop POS',
                    style: TextStyle(
                      fontFamily: DostopFonts.sans,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: skin.brand,
                    )),
                Text('Retail · Colombo',
                    style: TextStyle(
                      fontFamily: DostopFonts.mono,
                      fontSize: 11,
                      color: skin.group,
                    )),
              ],
            ),
          ),
          collapseBtn,
        ],
      ),
    );
  }

  Widget _search(_Skin skin) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: skin.fieldBg,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            const SizedBox(width: 10),
            Icon(Icons.search, size: 16, color: skin.fieldText),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                cursorColor: DostopColors.brand,
                style: TextStyle(
                  fontFamily: DostopFonts.sans,
                  fontSize: 12.5,
                  color: skin.dark ? Colors.white : DostopColors.ink,
                ),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'Search menu…',
                  hintStyle: TextStyle(
                    fontFamily: DostopFonts.sans,
                    fontSize: 12.5,
                    color: skin.fieldText,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _nav(_Skin skin) {
    final q = _collapsed ? '' : _query;
    final visible = q.isEmpty
        ? widget.modules
        : widget.modules
            .where((m) => m.label.toLowerCase().contains(q))
            .toList(growable: false);

    if (visible.isEmpty) {
      return Center(
        child: Text('No matches',
            style: TextStyle(
                fontFamily: DostopFonts.sans, fontSize: 12, color: skin.group)),
      );
    }

    final children = <Widget>[const SizedBox(height: 6)];
    String? lastGroup;
    for (final m in visible) {
      if (!_collapsed && q.isEmpty && m.group != lastGroup && m.group.isNotEmpty) {
        children.add(_groupLabel(skin, m.group));
        lastGroup = m.group;
      } else if (!_collapsed && q.isEmpty && m.group.isEmpty && lastGroup != null) {
        children.add(const SizedBox(height: 8));
        lastGroup = null;
      }
      children.add(_navItem(skin, m));
    }
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: _collapsed ? 12 : 12),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }

  Widget _groupLabel(_Skin skin, String label) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: DostopFonts.sans,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: skin.group,
          ),
        ),
      );

  Widget _navItem(_Skin skin, FeatureModule m) {
    final idx = widget.modules.indexOf(m);
    final active = idx == widget.selectedIndex;
    final content = _collapsed
        ? Center(
            child: Icon(m.icon,
                size: 20, color: active ? DostopColors.brand : skin.text))
        : Row(
            children: [
              Icon(m.icon,
                  size: 19, color: active ? DostopColors.brand : skin.text),
              const SizedBox(width: 11),
              Expanded(
                child: Text(m.label,
                    style: TextStyle(
                      fontFamily: DostopFonts.sans,
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? DostopColors.brand : skin.text,
                    )),
              ),
            ],
          );
    final button = Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: active ? DostopColors.brandWash : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          hoverColor: skin.hover,
          onTap: () => widget.onSelect(idx),
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: 11, vertical: _collapsed ? 11 : 9),
            child: content,
          ),
        ),
      ),
    );
    return _collapsed ? Tooltip(message: m.label, child: button) : button;
  }

  Widget _footer(_Skin skin) {
    final initials = _initials(widget.displayName);
    final avatar = CircleAvatar(
      radius: 16,
      backgroundColor: skin.avatarBg,
      child: Text(initials,
          style: TextStyle(
            fontFamily: DostopFonts.sans,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: skin.avatarFg,
          )),
    );

    if (_collapsed) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: skin.border)),
        ),
        child: Column(
          children: [
            Tooltip(message: widget.displayName, child: avatar),
            const SizedBox(height: 6),
            IconButton(
              tooltip: 'Sign out',
              onPressed: widget.onLogout,
              iconSize: 18,
              color: skin.text,
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
      );
    }

    final role = widget.roles.isNotEmpty ? widget.roles.first : 'cashier';
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: skin.border)),
      ),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: skin.cardBg,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          children: [
            avatar,
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.displayName.isEmpty ? 'Cashier' : widget.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: DostopFonts.sans,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: skin.userName,
                    ),
                  ),
                  Text(
                    role[0].toUpperCase() + role.substring(1),
                    style: TextStyle(
                      fontFamily: DostopFonts.sans,
                      fontSize: 11,
                      color: skin.group,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Sign out',
              onPressed: widget.onLogout,
              iconSize: 18,
              color: skin.text,
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts =
        name.replaceAll(RegExp(r'[^A-Za-z ]'), '').trim().split(RegExp(r'\s+'));
    final letters = parts.where((p) => p.isNotEmpty).take(2).map((p) => p[0]);
    final s = letters.join().toUpperCase();
    return s.isEmpty ? 'C' : s;
  }
}

/// Ambient banner for a pending (lost-reply) Finalize awaiting replay
/// (docs/desktop-local-persistence.md §5.3). Auto-replays on reconnect.
class _PendingSaleBanner extends ConsumerWidget {
  const _PendingSaleBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingFinalizeControllerProvider);
    if (!pending.hasPending) return const SizedBox.shrink();
    return MaterialBanner(
      backgroundColor: DostopColors.stockLowBg,
      leading: const Icon(Icons.sync_problem, color: DostopColors.stockLowFg),
      content: Text(pending.retrying
          ? 'Completing your last sale…'
          : 'A sale is waiting for the store server. It will finish '
              'automatically when the connection returns.'),
      actions: [
        TextButton(
          onPressed: pending.retrying
              ? null
              : () => ref
                  .read(pendingFinalizeControllerProvider.notifier)
                  .retryNow(),
          child: const Text('Retry now'),
        ),
      ],
    );
  }
}
