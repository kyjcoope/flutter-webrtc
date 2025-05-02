import 'dart:math';
import 'package:flutter/services.dart';

class PhoneNumberFormatter extends TextInputFormatter {
  final int countryCode;

  PhoneNumberFormatter(this.countryCode);

  String get _prefix => '+$countryCode ';
  static const int _max = 10;
  final _digit = RegExp(r'\d');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    String digits = text.replaceAll(RegExp(r'\D'), '');
    final String ccString = countryCode.toString();
    final int ccLength = ccString.length;

    if ((text.startsWith('+$ccString') || text.startsWith(_prefix)) &&
        digits.startsWith(ccString)) {
      if (digits.length > ccLength) {
        digits = digits.substring(ccLength);
      } else {
        digits = '';
      }
    }

    if (digits.length > _max) digits = digits.substring(0, _max);

    final buf = StringBuffer(_prefix);
    for (int i = 0; i < digits.length; i++) {
      if (i == 0) buf.write('(');
      if (i == 3) buf.write(') ');
      if (i == 6) buf.write(' ');
      buf.write(digits[i]);
    }
    final formatted = buf.toString();

    int count = 0;
    int digitsSeenSoFar = 0;
    bool startsWithPrefix =
        text.startsWith('+$ccString') || text.startsWith(_prefix);

    for (int i = 0; i < newValue.selection.baseOffset; i++) {
      String ch = newValue.text[i];
      if (_digit.hasMatch(ch)) {
        digitsSeenSoFar++;
        if (!(startsWithPrefix && digitsSeenSoFar <= ccLength)) {
          count++;
        }
      }
    }

    count = min(count, digits.length);

    int offset = _prefix.length;
    int seen = 0;

    for (int i = _prefix.length; i < formatted.length; i++) {
      offset++;
      if (_digit.hasMatch(formatted[i])) {
        seen++;
      }
      if (seen >= count) break;
    }
    offset = min(offset, formatted.length);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
