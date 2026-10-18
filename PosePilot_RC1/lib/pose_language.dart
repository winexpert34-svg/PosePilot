import 'dart:ui' as ui;

class PoseLanguage {
  static bool get russian =>
      ui.PlatformDispatcher.instance.locale.languageCode.toLowerCase() == 'ru';

  static String text(String english, String russianText) =>
      russian ? russianText : english;

  static const Map<String, String> _translations = {
    'Relaxed Stand': 'Свободная стойка',
    'One Leg Forward': 'Одна нога впереди',
    'Weight Shift': 'Перенос веса',
    '¾ Stand': 'Стойка три четверти',
    'Over Shoulder': 'Взгляд через плечо',
    'Walking': 'В движении',
    'Hands at Waist': 'Руки на талии',
    'Relaxed Hands': 'Расслабленные руки',
    'Chair Relaxed': 'Свободно на стуле',
    'Chair ¾': 'На стуле вполоборота',
    'Edge Sitting': 'На краю сиденья',
    'Crossed Legs': 'Скрещённые ноги',
    'One Leg Extended': 'Вытянутая нога',
    'Relaxed Lounge': 'Расслабленная поза',
    'Shoulder Lean': 'Наклон плеча',
    'Back Lean': 'Наклон назад',
    'One Foot Wall': 'Нога у стены',
    'Side Lean': 'Наклон в сторону',
    'Facing Window': 'Лицом к окну',
    'Step into frame': 'Встаньте в кадр',
    'Perfect ✨ Hold still': 'Отлично ✨ Не двигайтесь',
    'Move back so I can see you': 'Отойдите немного назад',
    'Relax your shoulders': 'Расслабьте плечи',
    'Shift your hips slightly': 'Слегка сместите бёдра',
    'Open your arms a little': 'Немного разведите руки',
    'Bring your arms in slightly': 'Немного приблизьте руки к телу',
    'Widen your stance slightly': 'Поставьте ноги чуть шире',
    'Bring your feet a little closer': 'Поставьте ноги чуть ближе',
    'Almost — hold that': 'Почти получилось — замрите',
    'Perfect ✨': 'Отлично ✨',
  };

  static String translate(String value) =>
      russian ? (_translations[value] ?? value) : value;
}
