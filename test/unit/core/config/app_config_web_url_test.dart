import 'package:zedu/core/core.dart';

import '../../../helpers/helpers.dart';

void main() {
  AppConfig config(String api, {String web = ''}) =>
      AppConfig(apiBaseUrl: api, usesMockData: false, webAppUrl: web);

  test('the web address is the API host without api.', () {
    expect(
      config('https://api.zedu.chat/api/v1/').webBaseUrl,
      'https://zedu.chat',
    );
    expect(
      config('https://api.staging.zedu.chat/api/v1/').webBaseUrl,
      'https://staging.zedu.chat',
    );
  });

  test('keeps a host without api. and its port', () {
    expect(
      config('http://localhost:8080/api/v1/').webBaseUrl,
      'http://localhost:8080',
    );
  });

  test('WEB_APP_URL wins, without a trailing slash', () {
    expect(
      config(
        'https://api.zedu.chat/api/v1/',
        web: 'https://web.team.test/',
      ).webBaseUrl,
      'https://web.team.test',
    );
  });
}
