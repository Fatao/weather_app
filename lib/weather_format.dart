// Превращаем числа и даты в текст для экрана.

const _weekdayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

// 18.4 -> +18°, -3.2 -> -3°, 0.2 -> 0°
String formatTemperature(double value) {
  final rounded = value.round();
  if (rounded > 0) return '+$rounded°';
  return '$rounded°';
}

// Давление приходит в гПа, а в примере из лабы — в мм рт. ст.
int hpaToMmHg(double hpa) => (hpa * 0.750062).round();

// 3.1 -> «3 м/с»
String formatWind(double metersPerSecond) {
  return '${metersPerSecond.round()} м/с';
}

// Первый день списка — сегодня, остальные подписываем днём недели
String formatDayLabel(DateTime date, {required bool isToday}) {
  if (isToday) return 'Сегодня';
  return _weekdayNames[date.weekday - 1];
}

// «5 дней», «3 дня», «1 день»
String formatDaysCount(int count) {
  final lastDigit = count % 10;
  final lastTwoDigits = count % 100;

  String word;
  if (lastTwoDigits >= 11 && lastTwoDigits <= 14) {
    word = 'дней';
  } else if (lastDigit == 1) {
    word = 'день';
  } else if (lastDigit >= 2 && lastDigit <= 4) {
    word = 'дня';
  } else {
    word = 'дней';
  }
  return '$count $word';
}

// 09:05
String formatClock(DateTime time) {
  final hours = time.hour.toString().padLeft(2, '0');
  final minutes = time.minute.toString().padLeft(2, '0');
  return '$hours:$minutes';
}
