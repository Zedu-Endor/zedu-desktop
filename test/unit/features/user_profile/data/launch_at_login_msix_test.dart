import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

void main() {
  group('msixPackageNameOf', () {
    test('reads the identity out of a packaged install path', () {
      expect(
        msixPackageNameOf(
          r'C:\Program Files\WindowsApps\Emerjent.Zedu_1.4.0.0_x64__8wekyb3d8bbwe\zedu.exe',
        ),
        'Emerjent.Zedu',
      );
      expect(
        msixPackageNameOf(
          r'C:\Program Files\WindowsApps\Zedu.Desktop_0.1.0.0_x64__abc123\zedu.exe',
        ),
        'Zedu.Desktop',
      );
    });

    test('is null for an unpackaged install', () {
      expect(msixPackageNameOf(r'C:\Program Files\Zedu\zedu.exe'), isNull);
      expect(
        msixPackageNameOf(
          r'C:\src\zedu\build\windows\x64\runner\Release\zedu.exe',
        ),
        isNull,
      );
    });
  });
}
