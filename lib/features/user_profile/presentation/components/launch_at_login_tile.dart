import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// "Launch Zedu at login" switch. Shows nothing on platforms without a login
/// item.
class LaunchAtLoginTile extends StatefulWidget {
  const LaunchAtLoginTile({super.key, this.service});

  /// Overridden in tests; the real operating system login item by default.
  final LaunchAtLoginService? service;

  @override
  State<LaunchAtLoginTile> createState() => _LaunchAtLoginTileState();
}

class _LaunchAtLoginTileState extends State<LaunchAtLoginTile> {
  late final LaunchAtLoginService _service =
      widget.service ?? PlatformLaunchAtLoginService();
  bool _enabled = false;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_service.isSupported) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    try {
      final enabled = await _service.isEnabled();
      if (mounted) setState(() => _enabled = enabled);
    } catch (e) {
      debugPrint('LaunchAtLoginTile._load: $e');
      // Leave the switch off if the login item can't be read.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggle(bool value) async {
    setState(() {
      _enabled = value;
      _busy = true;
    });
    try {
      await _service.setEnabled(value);
    } catch (_) {
      if (!mounted) return;
      setState(() => _enabled = !value);
      AppToastService.show(
        context,
        type: AppToastType.error,
        message: 'Could not change the launch at login setting.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_service.isSupported) return const SizedBox.shrink();

    // One semantics node, so a screen reader reads the label with the switch.
    return MergeSemantics(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Launch Zedu at login',
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Start Zedu automatically when you log in to this computer.',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colors.textHint,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: _enabled, onChanged: _busy ? null : _toggle),
        ],
      ),
    );
  }
}
