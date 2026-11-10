// Модели: город, прогноз на один день и сама погода.

class City {
  const City({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final double latitude;
  final double longitude;
}

class DayForecast {
  const DayForecast({
    required this.date,
    required this.weatherCode,
    required this.maxTemp,
    required this.minTemp,
  });

  final DateTime date;
  final int weatherCode;
  final double maxTemp;
  final double minTemp;

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'weatherCode': weatherCode,
      'maxTemp': maxTemp,
      'minTemp': minTemp,
    };
  }

  factory DayForecast.fromJson(Map<String, dynamic> json) {
    return DayForecast(
      date: DateTime.parse(json['date'] as String),
      weatherCode: json['weatherCode'] as int,
      maxTemp: (json['maxTemp'] as num).toDouble(),
      minTemp: (json['minTemp'] as num).toDouble(),
    );
  }
}

class Weather {
  const Weather({
    required this.cityName,
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.weatherCode,
    required this.days,
    required this.loadedAt,
    this.pressureHpa,
    this.fromCache = false,
  });

  final String cityName;
  final double temperature;
  final double feelsLike;
  final int humidity; // проценты
  final double windSpeed; // м/с
  final double? pressureHpa; // может не прийти
  final int weatherCode;
  final List<DayForecast> days;
  final DateTime loadedAt;
  final bool fromCache; // true, если данные взяты из сохранённых

  // Разбираем ответ Open-Meteo. Если в JSON нет нужного поля или оно другого
  // типа, тут вылетит ошибка — её ловит ApiClient и показывает «некорректный ответ».
  factory Weather.fromApiJson(String cityName, Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>;
    final daily = json['daily'] as Map<String, dynamic>;

    final dates = daily['time'] as List;
    final codes = daily['weather_code'] as List;
    final maxTemps = daily['temperature_2m_max'] as List;
    final minTemps = daily['temperature_2m_min'] as List;

    final days = <DayForecast>[];
    for (var i = 0; i < dates.length; i++) {
      days.add(DayForecast(
        date: DateTime.parse(dates[i] as String),
        weatherCode: (codes[i] as num).toInt(),
        maxTemp: (maxTemps[i] as num).toDouble(),
        minTemp: (minTemps[i] as num).toDouble(),
      ));
    }
    if (days.isEmpty) {
      throw const FormatException('Пустой прогноз');
    }

    return Weather(
      cityName: cityName,
      temperature: (current['temperature_2m'] as num).toDouble(),
      feelsLike: (current['apparent_temperature'] as num).toDouble(),
      humidity: (current['relative_humidity_2m'] as num).round(),
      windSpeed: (current['wind_speed_10m'] as num).toDouble(),
      pressureHpa: (current['surface_pressure'] as num?)?.toDouble(),
      weatherCode: (current['weather_code'] as num).toInt(),
      days: days,
      loadedAt: DateTime.now(),
    );
  }

  Weather copyWith({bool? fromCache}) {
    return Weather(
      cityName: cityName,
      temperature: temperature,
      feelsLike: feelsLike,
      humidity: humidity,
      windSpeed: windSpeed,
      pressureHpa: pressureHpa,
      weatherCode: weatherCode,
      days: days,
      loadedAt: loadedAt,
      fromCache: fromCache ?? this.fromCache,
    );
  }

  // Для кэша
  Map<String, dynamic> toJson() {
    return {
      'cityName': cityName,
      'temperature': temperature,
      'feelsLike': feelsLike,
      'humidity': humidity,
      'windSpeed': windSpeed,
      'pressureHpa': pressureHpa,
      'weatherCode': weatherCode,
      'days': days.map((day) => day.toJson()).toList(),
      'loadedAt': loadedAt.toIso8601String(),
    };
  }

  factory Weather.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days'] as List;
    return Weather(
      cityName: json['cityName'] as String,
      temperature: (json['temperature'] as num).toDouble(),
      feelsLike: (json['feelsLike'] as num).toDouble(),
      humidity: json['humidity'] as int,
      windSpeed: (json['windSpeed'] as num).toDouble(),
      pressureHpa: (json['pressureHpa'] as num?)?.toDouble(),
      weatherCode: json['weatherCode'] as int,
      days: rawDays
          .map((day) => DayForecast.fromJson(day as Map<String, dynamic>))
          .toList(),
      loadedAt: DateTime.parse(json['loadedAt'] as String),
    );
  }
}
