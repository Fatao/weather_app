import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_app/main.dart';
import 'package:weather_app/weather_api_client.dart';
import 'package:weather_app/weather_cache.dart';
import 'package:weather_app/weather_repository.dart';
import 'package:weather_app/weather_state.dart';

import 'fakes.dart';

void main() {
  late FakeWeatherApi api;
  late WeatherState state;

  setUp(() {
    api = FakeWeatherApi();
    state = WeatherState(
      WeatherRepository(api: api, cache: MemoryWeatherCache()),
    );
  });

  Future<void> openApp(WidgetTester tester) async {
    // размер как у телефона
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WeatherApp(weatherState: state));
    await tester.pumpAndSettle();
  }

  // Текущая температура. Искать по тексту нельзя: такие же числа есть в прогнозе.
  String currentTemperature(WidgetTester tester) {
    final text = tester.widget<Text>(find.byKey(const ValueKey('temperature_text')));
    return text.data!;
  }

  Future<void> searchFor(WidgetTester tester, String city) async {
    await tester.enterText(find.byKey(const ValueKey('city_field')), city);
    await tester.tap(find.byKey(const ValueKey('search_button')));
    await tester.pumpAndSettle();
  }

  testWidgets('при открытии показывает погоду по умолчанию', (tester) async {
    await openApp(tester);

    expect(currentTemperature(tester), '+18°');
    expect(find.text('Пасмурно'), findsOneWidget);
    expect(find.text('Ощущается как +16°'), findsOneWidget);
    expect(find.text('62%'), findsOneWidget);
    expect(find.text('3 м/с'), findsOneWidget);
    expect(find.text('760 мм'), findsOneWidget);
  });

  testWidgets('показывает прогноз на 5 дней', (tester) async {
    await openApp(tester);

    expect(find.text('Прогноз на 5 дней'), findsOneWidget);
    expect(find.text('Сегодня'), findsOneWidget);
    expect(find.text('Вт'), findsOneWidget);
    expect(find.text('Пт'), findsOneWidget);
  });

  testWidgets('поиск другого города', (tester) async {
    await openApp(tester);

    await searchFor(tester, 'Казань');

    expect(find.text('Казань'), findsWidgets);
    expect(api.requestedCities.last, 'Казань');
  });

  testWidgets('во время загрузки виден индикатор', (tester) async {
    api.gate = Completer<void>();

    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(WeatherApp(weatherState: state));
    await tester.pump();

    expect(find.byKey(const ValueKey('loading')), findsOneWidget);

    api.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('loading')), findsNothing);
    expect(currentTemperature(tester), '+18°');
  });

  testWidgets('несуществующий город: сообщение «не найден»', (tester) async {
    await openApp(tester);
    api.cityExists = false;

    await searchFor(tester, 'Абракадабра');

    expect(find.byKey(const ValueKey('not_found')), findsOneWidget);
    expect(find.textContaining('Город не найден'), findsOneWidget);
    expect(find.byKey(const ValueKey('forecast_card')), findsNothing);
  });

  testWidgets('пустой запрос: ошибка под полем', (tester) async {
    await openApp(tester);

    await searchFor(tester, '');

    expect(find.text('Введите название города'), findsOneWidget);
    // прежняя погода остаётся на экране
    expect(currentTemperature(tester), '+18°');
  });

  testWidgets('ошибка сети: сообщение и кнопка «Повторить»', (tester) async {
    await openApp(tester);
    api.error = const WeatherException(
      WeatherErrorType.noConnection,
      'Нет подключения к интернету.',
    );

    await searchFor(tester, 'Новосибирск');

    expect(find.text('Нет подключения к интернету.'), findsOneWidget);
    expect(find.byKey(const ValueKey('retry_button')), findsOneWidget);

    // интернет появился — нажимаем «Повторить»
    api.error = null;
    await tester.tap(find.byKey(const ValueKey('retry_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('retry_button')), findsNothing);
    expect(currentTemperature(tester), '+18°');
  });

  testWidgets('ошибка сервера показывает код', (tester) async {
    await openApp(tester);
    api.error = const WeatherException(
      WeatherErrorType.server,
      'Ошибка сервера (код 500). Попробуйте позже.',
    );

    await searchFor(tester, 'Омск');

    expect(find.textContaining('500'), findsOneWidget);
  });

  testWidgets('без интернета показываются сохранённые данные', (tester) async {
    await openApp(tester);

    api.error = const WeatherException(
      WeatherErrorType.noConnection,
      'Нет подключения к интернету.',
    );
    await searchFor(tester, 'Москва');

    expect(find.byKey(const ValueKey('cache_note')), findsOneWidget);
    expect(currentTemperature(tester), '+18°');
  });
}
