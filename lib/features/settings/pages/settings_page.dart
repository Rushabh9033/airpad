import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsStore {
  static const String _kSensitivity = 'airpad.sensitivity';
  static const String _kScrollSpeed = 'airpad.scrollSpeed';
  static const String _kDebugOverlay = 'airpad.debugOverlay';

  static const double defaultSensitivity = 1.0;
  static const double defaultScrollSpeed = 1.0;
  static const bool defaultDebugOverlay = false;

  double sensitivity = defaultSensitivity;
  double scrollSpeed = defaultScrollSpeed;
  bool debugOverlay = defaultDebugOverlay;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    sensitivity = p.getDouble(_kSensitivity) ?? defaultSensitivity;
    scrollSpeed = p.getDouble(_kScrollSpeed) ?? defaultScrollSpeed;
    debugOverlay = p.getBool(_kDebugOverlay) ?? defaultDebugOverlay;
  }

  Future<void> setSensitivity(double v) async {
    sensitivity = v;
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_kSensitivity, v);
  }

  Future<void> setScrollSpeed(double v) async {
    scrollSpeed = v;
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_kScrollSpeed, v);
  }

  Future<void> setDebugOverlay(bool v) async {
    debugOverlay = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kDebugOverlay, v);
  }
}

class SettingsPage extends StatefulWidget {
  final SettingsStore store;
  const SettingsPage({super.key, required this.store});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late double _sensitivity = widget.store.sensitivity;
  late double _scrollSpeed = widget.store.scrollSpeed;
  late bool _debugOverlay = widget.store.debugOverlay;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141418),
        elevation: 0,
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            const _SectionHeader('Tracking'),
            _SliderRow(
              label: 'Sensitivity',
              hint: 'How fast the cursor moves for a given finger travel',
              value: _sensitivity,
              min: 0.5,
              max: 3.0,
              divisions: 25,
              onChanged: (v) {
                setState(() => _sensitivity = v);
                widget.store.setSensitivity(v);
              },
            ),
            _SliderRow(
              label: 'Scroll speed',
              hint: 'Multiplier for two-finger scroll deltas',
              value: _scrollSpeed,
              min: 0.5,
              max: 3.0,
              divisions: 25,
              onChanged: (v) {
                setState(() => _scrollSpeed = v);
                widget.store.setScrollSpeed(v);
              },
            ),
            const SizedBox(height: 24),
            const _SectionHeader('Diagnostics'),
            SwitchListTile(
              value: _debugOverlay,
              onChanged: (v) {
                setState(() => _debugOverlay = v);
                widget.store.setDebugOverlay(v);
              },
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Debug overlay',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                'Show pointer stats on the trackpad surface',
                style:
                    TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              ),
              activeThumbColor: const Color(0xFF3D7CFF),
            ),
            const SizedBox(height: 24),
            Text(
              'Airpad Phase 1',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final String hint;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.hint,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500)),
              Text(
                value.toStringAsFixed(2),
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                    fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(hint,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF3D7CFF),
              inactiveTrackColor: const Color(0xFF2A2A30),
              thumbColor: Colors.white,
              overlayColor: const Color(0xFF3D7CFF).withValues(alpha: 0.2),
              trackHeight: 3,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
