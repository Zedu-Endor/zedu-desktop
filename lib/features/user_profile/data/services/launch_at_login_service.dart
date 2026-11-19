import 'dart:io';

import 'package:launch_at_startup/launch_at_startup.dart';

/// Turns "start Zedu when I log in" on or off for this computer.
abstract class LaunchAtLoginService {
  /// Only macOS and Windows have a login item to manage.
  bool get isSupported;

  Future<bool> isEnabled();

  Future<void> setEnabled(bool enabled);
}

/// The macOS login item API (SMAppService) needs macOS 13 or later.
/// [osVersion] looks like "Version 14.5 (Build 23F79)".
bool macOsSupportsLoginItem(String osVersion) {
  final major = int.tryParse(
    RegExp(r'Version (\d+)').firstMatch(osVersion)?.group(1) ?? '',
  );
  return major != null && major >= 13;
}

/// The Store/MSIX identity of the package this executable is installed in, or
/// `null` when the app is not running from a packaged install.
///
/// A packaged executable lives in
/// `C:\Program Files\WindowsApps\<Identity>_<version>_<arch>__<hash>\zedu.exe`,
/// so the identity is the install folder up to its first `_`. Deriving it keeps
/// the check correct for any Partner Center identity without hardcoding one.
///
/// Without this, [launchAtStartup] would register `Platform.resolvedExecutable`
/// under the Run key, and in a Store build that path sits in the protected
/// WindowsApps folder, so Windows cannot start it at login.
String? msixPackageNameOf(String executablePath) {
  if (!executablePath.contains('WindowsApps')) return null;

  final separator = executablePath.lastIndexOf(RegExp(r'[\\/]'));
  if (separator < 0) return null;

  final folder = executablePath.substring(0, separator);
  final folderSeparator = folder.lastIndexOf(RegExp(r'[\\/]'));
  final installFolder = folder.substring(folderSeparator + 1);

  final identity = installFolder.split('_').first;
  return identity.isEmpty ? null : identity;
}

/// Uses the operating system's own login item, so the choice is kept between
/// launches without the app saving anything itself.
class PlatformLaunchAtLoginService implements LaunchAtLoginService {
  PlatformLaunchAtLoginService() {
    if (isSupported) {
      launchAtStartup.setup(
        appName: 'Zedu',
        appPath: Platform.resolvedExecutable,
        packageName: msixPackageNameOf(Platform.resolvedExecutable),
      );
    }
  }

  @override
  bool get isSupported =>
      Platform.isWindows ||
      (Platform.isMacOS &&
          macOsSupportsLoginItem(Platform.operatingSystemVersion));

  @override
  Future<bool> isEnabled() => launchAtStartup.isEnabled();

  @override
  Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      await launchAtStartup.enable();
    } else {
      await launchAtStartup.disable();
    }
  }
}
