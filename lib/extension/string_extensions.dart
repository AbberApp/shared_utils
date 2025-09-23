extension StringExtension on String {
  bool get allDigits {
    for (int i = 0; i < length; i++) {
      if (!this[i].contains(RegExp(r'^[0-9]$'))) {
        return false;
      }
    }
    return true;
  }

  bool get containsOnlyDigitsAndDecimal {
    bool hasDecimal = false;
    for (int i = 0; i < length; i++) {
      if (!this[i].contains(RegExp(r'^[0-9.]$'))) {
        return false;
      }
      if (this[i] == '.') {
        if (hasDecimal) {
          return false; // يحتوي على أكثر من علامة عشرية واحدة
        }
        hasDecimal = true;
      }
    }
    return true;
  }

  String get removedBracketsFromList => substring(1, length - 1);
}


