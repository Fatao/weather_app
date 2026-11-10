import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:weather_app/weather_api_client.dart';
import 'package:weather_app/weather_cache.dart';
import 'package:weather_app/weather_codes.dart';
import 'package:weather_app/weather_format.dart';
import 'package:weather_app/weather_repository.dart';
import 'package:weather_app/weather_state.dart';

import 'fakes.dart';

void main() {
  late FakeWeatherApi api;
  late MemoryWeatherCache cache;
  late WeatherState state;

  setUp(() {
    api = FakeWeatherApi();
    cache = MemoryWeatherCache();
    state = WeatherState(WeatherRepository(api: api, cache: cache));
  });

  group('сценарии поиска', () {
    test('корректный город: успешная загрузка с прогнозом', () async {
      await state.search('Москва');

      expect(state.status, LoadStatus.success);
      expect(state.weather!.cityName, 'Москва');
      expect(state.weather!.temperature, 18.4);
      expect(state.weather!.days.length, greaterThanOrEqualTo(3));
    });

    test('пробелы вокруг названия убираются', () async {
      await state.search('  Казань  ');

      expect(api.requestedCities, ['Казань']);
    });

    test('несуществующий город: пустой результат', () async {
      api.cityExists = false;

      await state.search('Абракадабра');

      expect(state.status, LoadStatus.notFound);
    });

    test('пустой запрос: ошибка под полем, в сеть не ходим', () async {
      await state.search('');
      expect(state.inputError, 'Введите название города');

      await state.search('   ');
      expect(state.inputError, isNotNull);

      expect(api.requestedCities, isEmpty);
      expect(state.status, LoadStatus.idle);
    });

    test('после правильного запроса ошибка ввода исчезает', () async {
      await state.search('');
      await state.search('Москва');

      expect(state.inputError, isNull);
    });

    test('нет интернета: состояние ошибки', () async {
      api.error = const WeatherException(
        WeatherErrorType.noConnection,
        'Нет подключения к интернету.',
      );

      await state.search('Москва');

      expect(state.status, LoadStatus.error);
      expect(state.errorMessage, 'Нет подключения к интернету.');
    });

    test('ошибка сервера: состояние ошибки с кодом', () async {
      api.error = const WeatherException(
        WeatherErrorType.server,
        'Ошибка сервера (код 500). Попробуйте позже.',
      );

      await state.search('Москва');

      expect(state.status, LoadStatus.error);
      expect(state.errorMessage, contains('500'));
    });

    test('повтор запроса после ошибки', () async {
      api.error = const WeatherException(WeatherErrorType.timeout, 'Таймаут');
      await state.search('Москва');
      expect(state.status, LoadStatus.error);

      api.error = null;
      await state.retry();

      expect(state.status, LoadStatus.success);
      expect(api.requestedCities, ['Москва', 'Москва']);
    });

    test('во время запроса статус loading', () async {
      api.gate = Completer<void>();

      final future = state.search('Москва');
      expect(state.status, LoadStatus.loading);

      api.gate!.complete();
      await future;
      expect(state.status, LoadStatus.success);
    });

    test('устаревший ответ не затирает новый поиск', () async {
      final oldGate = Completer<void>();
      api.gate = oldGate;
      final first = state.search('Первый');

      api.gate = null;
      await state.search('Второй');

      // «Первый» ещё висит, но он уже не нужен
      oldGate.complete();
      await first;
      expect(state.weather!.cityName, 'Второй');
    });
  });

  group('кэш (дополнительное задание)', () {
    test('успешная погода сохраняется', () async {
      await state.search('Москва');

      expect(await cache.load('москва'), isNotNull);
    });

    test('без интернета показываем сохранённую погоду', () async {
      await state.search('Москва');

      api.error = const WeatherException(
        WeatherErrorType.noConnection,
        'Нет подключения к интернету.',
      );
      await state.search('Москва');

      expect(state.status, LoadStatus.success);
      expect(state.weather!.fromCache, isTrue);
      expect(state.weather!.temperature, 18.4);
    });

    test('без интернета и без кэша — ошибка', () async {
      api.error = const WeatherException(
        WeatherErrorType.noConnection,
        'Нет подключения к интернету.',
      );

      await state.search('Новый город');

      expect(state.status, LoadStatus.error);
    });

    test('для несуществующего города кэш не подменяет ответ', () async {
      await state.search('Москва');

      api.cityExists = false;
      await state.search('Москва');

      expect(state.status, LoadStatus.notFound);
    });
  });

  group('форматирование', () {
    test('температура', () {
      expect(formatTemperature(18.4), '+18°');
      expect(formatTemperature(-3.2), '-3°');
      expect(formatTemperature(0.2), '0°');
      expect(formatTemperature(-0.4), '0°');
    });

    test('давление переводится в мм рт. ст.', () {
      expect(hpaToMmHg(1013.25), 760);
    });

    test('ветер', () {
      expect(formatWind(3.1), '3 м/с');
    });

    test('подпись дня', () {
      expect(formatDayLabel(DateTime(2026, 11, 9), isToday: true), 'Сегодня');
      expect(formatDayLabel(DateTime(2026, 11, 10), isToday: false), 'Вт');
    });

    test('склонение слова «день»', () {
      expect(formatDaysCount(1), '1 день');
      expect(formatDaysCount(3), '3 дня');
      expect(formatDaysCount(5), '5 дней');
      expect(formatDaysCount(11), '11 дней');
    });

    test('описание погоды по коду', () {
      expect(weatherDescription(0), 'Ясно');
      expect(weatherDescription(63), 'Дождь');
      expect(weatherDescription(95), 'Гроза');
      expect(weatherDescription(1234), 'Нет данных');
    });
  });
}
