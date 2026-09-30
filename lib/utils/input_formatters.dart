import 'package:flutter/services.dart';

/// Restringe o campo a números decimais (aceita vírgula ou ponto).
final List<TextInputFormatter> decimalInputFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
];

/// Restringe o campo a números inteiros.
final List<TextInputFormatter> integerInputFormatters = [
  FilteringTextInputFormatter.digitsOnly,
];
