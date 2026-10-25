import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class DevicePreset {
  final String name;
  final Size size;
  final EdgeInsets safePadding;
  final double pixelRatio;

  const DevicePreset({
    required this.name,
    required this.size,
    required this.safePadding,
    this.pixelRatio = 2.625,
  });
}

class AndroidFrameWrapper extends StatefulWidget {
  final Widget child;
  final ValueChanged<ThemeMode>? onThemeModeChanged;

  const AndroidFrameWrapper({
    super.key,
    required this.child,
    this.onThemeModeChanged,
  });

  @override
  State<AndroidFrameWrapper> createState() => _AndroidFrameWrapperState();
}

class _AndroidFrameWrapperState extends State<AndroidFrameWrapper> {
  static const List<DevicePreset> _presets = [
    DevicePreset(
      name: 'Android Standard (412×915)',
      size: Size(412, 915),
      safePadding: EdgeInsets.only(top: 36, bottom: 24),
    ),
    DevicePreset(
      name: 'Compact Android (360×800)',
      size: Size(360, 800),
      safePadding: EdgeInsets.only(top: 28, bottom: 20),
    ),
    DevicePreset(
      name: 'Large Pro / Ultra (448×998)',
      size: Size(448, 998),
      safePadding: EdgeInsets.only(top: 40, bottom: 24),
    ),
  ];

  int _presetIndex = 0;
  bool _enabled = true;
  bool _showBezel = true;
  bool _isLandscape = false;
  bool _simulateSafeArea = true;
  final bool _showToolbar = true;

  bool get _isDesktopDebug =>
      kDebugMode &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows);

  @override
  Widget build(BuildContext context) {
    if (!_isDesktopDebug) {
      return widget.child;
    }

    if (!_enabled) {
      return Stack(
        children: [
          Positioned.fill(child: widget.child),
          Positioned(
            right: 12,
            bottom: 12,
            child: _FloatingRestoreButton(
              onTap: () => setState(() => _enabled = true),
            ),
          ),
        ],
      );
    }

    final preset = _presets[_presetIndex];
    final effectiveSize = _isLandscape
        ? Size(preset.size.height, preset.size.width)
        : preset.size;

    final effectivePadding = _simulateSafeArea
        ? (_isLandscape
              ? const EdgeInsets.only(top: 24, bottom: 16, left: 36, right: 36)
              : preset.safePadding)
        : EdgeInsets.zero;

    final parentMediaQuery = MediaQuery.of(context);

    return Material(
      color: const Color(0xFF0F1117),
      child: Column(
        children: [
          if (_showToolbar) _buildDebugBar(preset, effectiveSize),
          Expanded(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(_showBezel ? 16.0 : 0.0),
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    width: effectiveSize.width + (_showBezel ? 24 : 0),
                    height: effectiveSize.height + (_showBezel ? 24 : 0),
                    padding: EdgeInsets.all(_showBezel ? 12 : 0),
                    decoration: _showBezel
                        ? BoxDecoration(
                            color: const Color(0xFF1E222D),
                            borderRadius: BorderRadius.circular(44),
                            border: Border.all(
                              color: const Color(0xFF383E4E),
                              width: 2.5,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black87,
                                blurRadius: 32,
                                offset: Offset(0, 14),
                              ),
                            ],
                          )
                        : null,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(_showBezel ? 34 : 0),
                      child: SizedBox(
                        width: effectiveSize.width,
                        height: effectiveSize.height,
                        child: MediaQuery(
                          data: parentMediaQuery.copyWith(
                            size: effectiveSize,
                            devicePixelRatio: preset.pixelRatio,
                            padding: effectivePadding,
                            viewPadding: effectivePadding,
                          ),
                          child: Stack(
                            children: [
                              widget.child,
                              if (_simulateSafeArea)
                                _SimulatedSystemBars(
                                  isLandscape: _isLandscape,
                                  topHeight: effectivePadding.top,
                                  bottomHeight: effectivePadding.bottom,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebugBar(DevicePreset preset, Size effectiveSize) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF181B24),
        border: Border(bottom: BorderSide(color: Color(0xFF2A2F3D))),
      ),
      child: Row(
        children: [
          const Icon(Icons.phone_android, size: 16, color: Colors.tealAccent),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _presetIndex,
              dropdownColor: const Color(0xFF1E222D),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              items: List.generate(
                _presets.length,
                (i) =>
                    DropdownMenuItem(value: i, child: Text(_presets[i].name)),
              ),
              onChanged: (val) {
                if (val != null) setState(() => _presetIndex = val);
              },
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${effectiveSize.width.toInt()}×${effectiveSize.height.toInt()} px',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const Spacer(),
          _BarToggle(
            icon: Icons.stay_current_portrait,
            label: _isLandscape ? 'Land' : 'Port',
            active: _isLandscape,
            onTap: () => setState(() => _isLandscape = !_isLandscape),
          ),
          _BarToggle(
            icon: Icons.crop_free,
            label: 'Bezel',
            active: _showBezel,
            onTap: () => setState(() => _showBezel = !_showBezel),
          ),
          _BarToggle(
            icon: Icons.security_update_good,
            label: 'SafeArea',
            active: _simulateSafeArea,
            onTap: () => setState(() => _simulateSafeArea = !_simulateSafeArea),
          ),
          _BarToggle(
            icon: Icons.fullscreen,
            label: 'Native',
            active: false,
            onTap: () => setState(() => _enabled = false),
          ),
        ],
      ),
    );
  }
}

class _BarToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _BarToggle({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: active
                ? Colors.tealAccent.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: active ? Colors.tealAccent : Colors.white24,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: active ? Colors.tealAccent : Colors.white70,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.tealAccent : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SimulatedSystemBars extends StatelessWidget {
  final bool isLandscape;
  final double topHeight;
  final double bottomHeight;

  const _SimulatedSystemBars({
    required this.isLandscape,
    required this.topHeight,
    required this.bottomHeight,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            height: topHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '9:41',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                    ),
                  ),
                  if (!isLandscape)
                    Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                    ),
                  const Row(
                    children: [
                      Icon(
                        Icons.signal_cellular_4_bar,
                        size: 13,
                        color: Colors.white70,
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.wifi, size: 13, color: Colors.white70),
                      SizedBox(width: 4),
                      Icon(Icons.battery_full, size: 13, color: Colors.white70),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: bottomHeight,
            child: Center(
              child: Container(
                width: 110,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white54,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingRestoreButton extends StatelessWidget {
  final VoidCallback onTap;

  const _FloatingRestoreButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black87,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.phone_android, size: 15, color: Colors.tealAccent),
              SizedBox(width: 6),
              Text(
                '412×915 Frame',
                style: TextStyle(color: Colors.white, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
