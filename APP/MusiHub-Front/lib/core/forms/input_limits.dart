import 'package:flutter/services.dart';

abstract final class InputLimits {
  static const email = 254;
  static const password = 128;
  static const fullName = 80;
  static const shortText = 80;
  static const profileBio = 500;
  static const bandBio = 600;
  static const opportunityTitle = 90;
  static const opportunityDescription = 800;
  static const url = 500;
  static const phone = 20;
  static const contactValue = 120;
  static const date = 10;
  static const price = 10;
  static const numericId = 10;

  static List<TextInputFormatter> get phoneFormatters {
    return [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]'))];
  }

  static List<TextInputFormatter> get digitsOnlyFormatters {
    return [FilteringTextInputFormatter.digitsOnly];
  }

  static List<TextInputFormatter> get dateFormatters {
    return [FilteringTextInputFormatter.allow(RegExp(r'[0-9-]'))];
  }

  static List<TextInputFormatter> get priceFormatters {
    return [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))];
  }
}
