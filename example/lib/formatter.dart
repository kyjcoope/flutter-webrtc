import 'dart:math';
import 'package:flutter/services.dart';

class PhoneNumberFormatter extends TextInputFormatter {
  final int countryCode;

  PhoneNumberFormatter(this.countryCode);

  String get _prefix => '+$countryCode ';
  static const int _max = 10; // Max digits for the national number part
  final _digit = RegExp(r'\d');
  late final String _ccString = countryCode.toString();
  late final int _ccLength = _ccString.length;
  late final String _prefixWithPlus = '+$_ccString'; // e.g. "+1"
  late final String _prefixWithPlusSpace = '+$_ccString '; // e.g. "+1 "

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    String nationalDigits;

    // Extract only the national digits, explicitly handling the prefix
    if (text.startsWith(_prefixWithPlusSpace)) {
      nationalDigits = text
          .substring(_prefixWithPlusSpace.length)
          .replaceAll(RegExp(r'\D'), '');
    } else if (text.startsWith(_prefixWithPlus)) {
      // Handles cases like "+1" before the space and parenthesis are added
      nationalDigits =
          text.substring(_prefixWithPlus.length).replaceAll(RegExp(r'\D'), '');
    } else {
      // If it doesn't start with the country code prefix, treat all digits as national part
      // (This might happen if user deletes the prefix)
      nationalDigits = text.replaceAll(RegExp(r'\D'), '');
    }

    if (nationalDigits.length > _max) {
      nationalDigits = nationalDigits.substring(0, _max);
    }

    final buf = StringBuffer(_prefix); // Start with "+CC "
    for (int i = 0; i < nationalDigits.length; i++) {
      if (i == 0) buf.write('(');
      if (i == 3) buf.write(') ');
      if (i == 6) buf.write(' ');
      buf.write(nationalDigits[i]);
    }
    final formatted = buf.toString();

    // Calculate cursor position based on national digits before the cursor in the *original input*
    int nationalDigitsBeforeCursor = 0;
    int rawDigitsSeen = 0;
    bool startsWithPrefix = text.startsWith(_prefixWithPlus) ||
        text.startsWith(_prefixWithPlusSpace);

    for (int i = 0; i < newValue.selection.baseOffset; i++) {
      String char = text[i];
      if (_digit.hasMatch(char)) {
        rawDigitsSeen++;
        // Only count as a national digit if it's past the country code part (if prefix exists)
        if (!startsWithPrefix || rawDigitsSeen > _ccLength) {
          nationalDigitsBeforeCursor++;
        }
      }
    }
    // Ensure the count doesn't exceed the actual number of national digits we ended up with
    nationalDigitsBeforeCursor = min(
      nationalDigitsBeforeCursor,
      nationalDigits.length,
    );

    // Calculate the actual offset in the *formatted* string
    int offset = _prefixWithPlusSpace.length; // Start after "+CC "
    int nationalDigitsSeenInFormatted = 0;

    for (int i = _prefixWithPlusSpace.length; i < formatted.length; i++) {
      offset++;
      if (_digit.hasMatch(formatted[i])) {
        nationalDigitsSeenInFormatted++;
      }
      if (nationalDigitsSeenInFormatted >= nationalDigitsBeforeCursor) {
        break;
      }
    }
    // Ensure offset doesn't go beyond the formatted text length
    offset = min(offset, formatted.length);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
