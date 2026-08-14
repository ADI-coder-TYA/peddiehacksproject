import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String format(num? amount, {String currency = 'INR', int decimalDigits = 0}) {
    if (amount == null) {
      final symbol = getSymbol(currency);
      return '$symbol 0';
    }
    
    final symbol = getSymbol(currency);
    final formatter = NumberFormat.currency(
      symbol: symbol,
      decimalDigits: decimalDigits,
    );
    return formatter.format(amount);
  }

  static String getSymbol(String currency) {
    final symbolMap = {
      'INR': '₹',
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
    };
    return symbolMap[currency.toUpperCase()] ?? (currency.toUpperCase() == 'INR' ? '₹' : '\$');
  }
}
