import 'package:intl/intl.dart';

String _intlLocale(String code) => code == 'tr' ? 'tr_TR' : 'en_US';

/// 1234.5 -> "₺1,234.50" (en) / "₺1.234,50" (tr)
String formatPrice(double? value, [String languageCode = 'en']) {
  if (value == null) return '-';
  final money = NumberFormat('#,##0.00', _intlLocale(languageCode));
  return '₺${money.format(value)}';
}

/// "Saturday, October 18" (en) / "18 Ekim Cumartesi" (tr)
String formatDateLong(DateTime date, [String languageCode = 'en']) =>
    DateFormat(
      languageCode == 'tr' ? 'd MMMM EEEE' : 'EEEE, MMMM d',
      _intlLocale(languageCode),
    ).format(date);

/// "Oct 18" (en) / "18 Eki" (tr)
String formatDateShort(DateTime date, [String languageCode = 'en']) =>
    DateFormat(
      languageCode == 'tr' ? 'd MMM' : 'MMM d',
      _intlLocale(languageCode),
    ).format(date);

/// "October 18, 2026" (en) / "18 Ekim 2026" (tr)
String formatMonthDayYear(DateTime date, [String languageCode = 'en']) =>
    DateFormat(
      languageCode == 'tr' ? 'd MMMM y' : 'MMMM d, y',
      _intlLocale(languageCode),
    ).format(date);

/// "14:30"
String formatTime(DateTime date) => DateFormat('HH:mm').format(date);
