import 'package:flutter/material.dart';

import 'weather.dart';
import 'weather_codes.dart';
import 'weather_format.dart';
import 'weather_state.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({
    super.key,
    required this.weatherState,
    this.initialCity = 'Москва',
  });

  final WeatherState weatherState;
  final String initialCity;

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  late final TextEditingController _cityController;

  @override
  void initState() {
    super.initState();
    _cityController = TextEditingController(text: widget.initialCity);
    // при открытии сразу показываем погоду для города по умолчанию
    widget.weatherState.search(widget.initialCity);
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  void _search() {
    FocusScope.of(context).unfocus();
    widget.weatherState.search(_cityController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF2FB),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: ListenableBuilder(
                listenable: widget.weatherState,
                builder: (context, _) {
                  final state = widget.weatherState;
                  final weather = state.weather;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Синий верх: поиск и текущая погода
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF3F8EF0), Color(0xFF8CC4F5)],
                          ),
                        ),
                        child: Column(
                          children: [
                            _SearchField(
                              controller: _cityController,
                              errorText: state.inputError,
                              onSearch: _search,
                            ),
                            const SizedBox(height: 24),
                            _buildCurrentPart(state),
                          ],
                        ),
                      ),
                      if (state.status == LoadStatus.success && weather != null)
                        _ForecastCard(days: weather.days),
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Weather data by Open-Meteo.com',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Что показывать в синем блоке — зависит от состояния
  Widget _buildCurrentPart(WeatherState state) {
    switch (state.status) {
      case LoadStatus.idle:
        return const _Message(text: 'Введите город и нажмите поиск');

      case LoadStatus.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: CircularProgressIndicator(
            key: ValueKey('loading'),
            color: Colors.white,
          ),
        );

      case LoadStatus.notFound:
        return const _Message(
          key: ValueKey('not_found'),
          icon: Icons.search_off,
          text: 'Город не найден. Проверьте название и попробуйте снова.',
        );

      case LoadStatus.error:
        return _Message(
          key: const ValueKey('error'),
          icon: Icons.error_outline,
          text: state.errorMessage ?? 'Ошибка',
          onRetry: state.retry,
        );

      case LoadStatus.success:
        return _CurrentWeather(weather: state.weather!);
    }
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.errorText,
    required this.onSearch,
  });

  final TextEditingController controller;
  final String? errorText;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const ValueKey('city_field'),
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => onSearch(),
      style: const TextStyle(color: Colors.white, fontSize: 18),
      cursorColor: Colors.white,
      decoration: InputDecoration(
        hintText: 'Город',
        hintStyle: const TextStyle(color: Colors.white70),
        errorText: errorText,
        errorStyle: const TextStyle(color: Colors.amberAccent),
        filled: true,
        fillColor: const Color(0x33FFFFFF),
        prefixIcon: const Icon(Icons.location_on, color: Colors.white),
        suffixIcon: IconButton(
          key: const ValueKey('search_button'),
          tooltip: 'Найти',
          icon: const Icon(Icons.search, color: Colors.white),
          onPressed: onSearch,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

// Сообщение в синем блоке: «не найдено», ошибка и т. п.
class _Message extends StatelessWidget {
  const _Message({super.key, required this.text, this.icon, this.onRetry});

  final String text;
  final IconData? icon;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          if (icon != null) Icon(icon, size: 48, color: Colors.white),
          if (icon != null) const SizedBox(height: 12),
          Text(
            text,
            key: const ValueKey('message_text'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              key: const ValueKey('retry_button'),
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white),
              ),
              child: const Text('Повторить'),
            ),
          ],
        ],
      ),
    );
  }
}

class _CurrentWeather extends StatelessWidget {
  const _CurrentWeather({required this.weather});

  final Weather weather;

  @override
  Widget build(BuildContext context) {
    const white = TextStyle(color: Colors.white);
    final pressure = weather.pressureHpa;

    return Column(
      key: const ValueKey('current_weather'),
      children: [
        Text(
          weather.cityName,
          key: const ValueKey('city_name'),
          style: white.copyWith(fontSize: 18),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(weatherIcon(weather.weatherCode), size: 72, color: Colors.white),
            const SizedBox(width: 16),
            Text(
              formatTemperature(weather.temperature),
              key: const ValueKey('temperature_text'),
              style: white.copyWith(fontSize: 64, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          weatherDescription(weather.weatherCode),
          key: const ValueKey('description_text'),
          textAlign: TextAlign.center,
          style: white.copyWith(fontSize: 26, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          'Ощущается как ${formatTemperature(weather.feelsLike)}',
          style: white.copyWith(fontSize: 14),
        ),
        if (weather.fromCache)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Нет связи с сервером. Показаны сохранённые данные '
              '(${formatClock(weather.loadedAt)}).',
              key: const ValueKey('cache_note'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.amberAccent, fontSize: 13),
            ),
          ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0x33FFFFFF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              _Stat(
                icon: Icons.water_drop_outlined,
                label: 'Влажность',
                value: '${weather.humidity}%',
                valueKey: const ValueKey('humidity_text'),
              ),
              _Stat(
                icon: Icons.air,
                label: 'Ветер',
                value: formatWind(weather.windSpeed),
                valueKey: const ValueKey('wind_text'),
              ),
              _Stat(
                icon: Icons.speed,
                label: 'Давление',
                // давление приходит не всегда
                value: pressure == null ? '—' : '${hpaToMmHg(pressure)} мм',
                valueKey: const ValueKey('pressure_text'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueKey,
  });

  final IconData icon;
  final String label;
  final String value;
  final Key valueKey;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 2),
          Text(
            value,
            key: valueKey,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({required this.days});

  final List<DayForecast> days;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('forecast_card'),
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Прогноз на ${formatDaysCount(days.length)}',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (var i = 0; i < days.length; i++)
                Expanded(child: _ForecastDay(day: days[i], isToday: i == 0)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ForecastDay extends StatelessWidget {
  const _ForecastDay({required this.day, required this.isToday});

  final DayForecast day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    // солнце жёлтое, всё остальное синее
    final iconColor = day.weatherCode <= 1 ? Colors.orange : Colors.blue;

    return Column(
      children: [
        Text(
          formatDayLabel(day.date, isToday: isToday),
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 8),
        Icon(weatherIcon(day.weatherCode), color: iconColor),
        const SizedBox(height: 8),
        Text(
          formatTemperature(day.maxTemp),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(
          formatTemperature(day.minTemp),
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }
}
