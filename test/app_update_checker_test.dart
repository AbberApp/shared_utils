import 'package:flutter_test/flutter_test.dart';
import 'package:shared_utils/shared_utils.dart';

void main() {
  final checker = AppUpdateChecker.instance;

  group('isMandatoryUpdate (iOS rule: major/minor → mandatory, patch → optional)', () {
    test('patch bump → optional (1.1.1 → 1.1.2)', () {
      expect(checker.isMandatoryUpdate('1.1.1', '1.1.2'), isFalse);
    });

    test('minor bump → mandatory (1.1.1 → 1.2.1)', () {
      expect(checker.isMandatoryUpdate('1.1.1', '1.2.1'), isTrue);
    });

    test('major bump → mandatory (1.1.1 → 2.0.0)', () {
      expect(checker.isMandatoryUpdate('1.1.1', '2.0.0'), isTrue);
    });

    test('minor bump even if patch drops → mandatory (1.1.5 → 1.2.0)', () {
      expect(checker.isMandatoryUpdate('1.1.5', '1.2.0'), isTrue);
    });

    test('same version → not mandatory (1.1.1 → 1.1.1)', () {
      expect(checker.isMandatoryUpdate('1.1.1', '1.1.1'), isFalse);
    });

    test('several patch bumps → still optional (1.0.0 → 1.0.9)', () {
      expect(checker.isMandatoryUpdate('1.0.0', '1.0.9'), isFalse);
    });

    test('build suffix (+N) is ignored — patch → optional', () {
      expect(checker.isMandatoryUpdate('1.1.1+20', '1.1.2+21'), isFalse);
    });

    test('build suffix (+N) is ignored — minor → mandatory', () {
      expect(checker.isMandatoryUpdate('1.1.1+20', '1.2.0+30'), isTrue);
    });

    test('missing patch segment — minor → mandatory (1.1 → 1.2)', () {
      expect(checker.isMandatoryUpdate('1.1', '1.2'), isTrue);
    });

    test('missing patch segment — added patch → optional (1.1 → 1.1.1)', () {
      expect(checker.isMandatoryUpdate('1.1', '1.1.1'), isFalse);
    });

    test('whitespace tolerated', () {
      expect(checker.isMandatoryUpdate(' 1.1.1 ', ' 1.2.0 '), isTrue);
    });
  });
}
