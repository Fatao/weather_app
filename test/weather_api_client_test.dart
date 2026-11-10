import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:weather_app/weather.dart';
import 'package:weather_app/weather_api_client.dart';

const geocodingBody = '''
{"results":[{"id":524901,"name":"Москва","latitude":55.75222,"longitude":37.61556,
 "country":"Россия"}]}
''';

const forecastBody = '''
{"latitude":55.75,"longitude":37.62,
 "current":{"time":"2026-11-09T15:30","interval":900,"temperature_2m":18.4,
  "apparent_temperature":16.2,"relative_humidity_2m":62,"surface_pressure":1013.2,
  "wind_speed_10m":3.1,"weather_code":3},
 "daily":{"time":["2026-11-09","2026-11-10","2026-11-11"],
  "weather_code":[3,0,1],
  "temperature_2m_max":[18.4,20.1,21.0],
  "temperature_2m_min":[10.2,12.0,13.3]}}
''';

http.Response jsonResponse(String body, [int status = 200]) {
  return http.Response(
    body,
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

WeatherApiClient clientWith(MockClientHandler handler) {
  return WeatherApiClient(client: MockClient(handler));
}

const city = City(name: 'Москва', latitude: 55.75, longitude: 37.62);

void main() {
  group('поиск города', () {
    test('находит город и берёт координаты', () async {
      final api = clientWith((_) async => jsonResponse(geocodingBody));

      final found = await api.findCity('Москва');

      expect(found, isNotNull);
      expect(found!.name, 'Москва');
      expect(found.latitude, 55.75222);
    });

    test('в запрос попадает название города', () async {
      Uri? sent;
      final api = clientWith((request) async {
        sent = request.url;
        return jsonResponse(geocodingBody);
      });

      await api.findCity('Санкт-Петербург');

      expect(sent!.host, 'geocoding-api.open-meteo.com');
      expect(sent!.queryParameters['name'], 'Санкт-Петербург');
    });

    test('если results нет в ответе — города нет', () async {
      final api = clientWith((_) async => jsonResponse('{"generationtime_ms":0.5}'));

      expect(await api.findCity('Абракадабра'), isNull);
    });

    test('пустой results — тоже города нет', () async {
      final api = clientWith((_) async => jsonResponse('{"results":[]}'));

      expect(await api.findCity('Абракадабра'), isNull);
    });
  });

  group('загрузка погоды', () {
    test('разбирает текущую погоду и прогноз', () async {
      final api = clientWith((_) async => jsonResponse(forecastBody));

      final weather = await api.loadWeather(city);

      expect(weather.cityName, 'Москва');
      expect(weather.temperature, 18.4);
      expect(weather.feelsLike, 16.2);
      expect(weather.humidity, 62);
      expect(weather.windSpeed, 3.1);
      expect(weather.pressureHpa, 1013.2);
      expect(weather.weatherCode, 3);
      expect(weather.days.length, 3);
      expect(weather.days[1].maxTemp, 20.1);
      expect(weather.days[2].date, DateTime(2026, 11, 11));
    });

    test('давление может не прийти', () async {
      final body = forecastBody.replaceAll('"surface_pressure":1013.2,', '');
      final api = clientWith((_) async => jsonResponse(body));

      final weather = await api.loadWeather(city);

      expect(weather.pressureHpa, isNull);
    });

    test('в запросе м/с и 5 дней', () async {
      Uri? sent;
      final api = clientWith((request) async {
        sent = request.url;
        return jsonResponse(forecastBody);
      });

      await api.loadWeather(city);

      expect(sent!.host, 'api.open-meteo.com');
      expect(sent!.queryParameters['wind_speed_unit'], 'ms');
      expect(sent!.queryParameters['forecast_days'], '5');
    });

    test('нет нужных полей — некорректный ответ', () async {
      final api = clientWith((_) async => jsonResponse('{"current":{}}'));

      expect(
        api.loadWeather(city),
        throwsA(isA<WeatherException>()
            .having((e) => e.type, 'type', WeatherErrorType.badResponse)),
      );
    });
  });

  group('ошибки сети и HTTP', () {
    test('404', () async {
      final api = clientWith((_) async => jsonResponse('', 404));

      expect(
        api.findCity('Москва'),
        throwsA(isA<WeatherException>()
            .having((e) => e.type, 'type', WeatherErrorType.notFound)),
      );
    });

    test('500', () async {
      final api = clientWith((_) async => jsonResponse('oops', 500));

      expect(
        api.findCity('Москва'),
        throwsA(isA<WeatherException>()
            .having((e) => e.type, 'type', WeatherErrorType.server)
            .having((e) => e.message, 'message', contains('500'))),
      );
    });

    test('429', () async {
      final api = clientWith((_) async => jsonResponse('', 429));

      expect(
        api.findCity('Москва'),
        throwsA(isA<WeatherException>()
            .having((e) => e.type, 'type', WeatherErrorType.rateLimited)),
      );
    });

    test('в ответе не JSON', () async {
      final api = clientWith((_) async => jsonResponse('<html>'));

      expect(
        api.findCity('Москва'),
        throwsA(isA<WeatherException>()
            .having((e) => e.type, 'type', WeatherErrorType.badResponse)),
      );
    });

    test('нет интернета', () async {
      final api = clientWith((_) async => throw http.ClientException('offline'));

      expect(
        api.findCity('Москва'),
        throwsA(isA<WeatherException>()
            .having((e) => e.type, 'type', WeatherErrorType.noConnection)),
      );
    });
  });

  group('модель', () {
    test('погода сохраняется в JSON и читается обратно', () {
      final api = clientWith((_) async => jsonResponse(forecastBody));

      return api.loadWeather(city).then((weather) {
        final restored = Weather.fromJson(weather.toJson());

        expect(restored.cityName, weather.cityName);
        expect(restored.temperature, weather.temperature);
        expect(restored.days.length, 3);
        expect(restored.pressureHpa, weather.pressureHpa);
      });
    });
  });
}
