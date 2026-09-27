import 'package:flutter/material.dart';

class LocaleController {
  static final ValueNotifier<Locale> locale = ValueNotifier<Locale>(
    const Locale('ar'),
  );

  static void setLocale(Locale newLocale) {
    locale.value = newLocale;
  }
}
