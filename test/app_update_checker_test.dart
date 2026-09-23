import 'dart:io';

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

  // ─────────────────────────────────────────────────────────────────────────
  // مقارنة الإصدارات — الخانة الرابعة، ولاحقة البناء، والوسم، وتفاوت الأطوال
  // ─────────────────────────────────────────────────────────────────────────

  group('الخانة الرابعة (App Store يقبل أربع خانات)', () {
    test('تغيّر الخانة الرابعة وحدها → اختياريّ (10.8.6.1 ← 10.8.6.2)', () {
      // إصلاحٌ عاجل في الخانة الرابعة ليس قفزةً كبرى ولا وسطى.
      expect(checker.isMandatoryUpdate('10.8.6.1', '10.8.6.2'), isFalse);
    });

    test('إضافة خانة رابعة بلا تغيير سواها → اختياريّ (10.8.6 ← 10.8.6.1)', () {
      expect(checker.isMandatoryUpdate('10.8.6', '10.8.6.1'), isFalse);
    });

    test('خانة رابعة مع قفزة وسطى → إجباريّ (10.8.6.1 ← 10.9.0.0)', () {
      expect(checker.isMandatoryUpdate('10.8.6.1', '10.9.0.0'), isTrue);
    });

    test('خانة رابعة أصغر لا تقلب الحكم (10.8.6.9 ← 10.8.6.1)', () {
      expect(checker.isMandatoryUpdate('10.8.6.9', '10.8.6.1'), isFalse);
    });

    test('عشر خانات لا تربك التفكيك — الوسطى وحدها تحكم', () {
      expect(
        checker.isMandatoryUpdate('1.2.3.4.5.6.7.8.9.10', '1.3.0.0.0.0.0.0.0.0'),
        isTrue,
      );
    });
  });

  group('لاحقة البناء (+N) والوسم (-label)', () {
    test('وسم -beta على المتجر يُتجاهل — وسطى → إجباريّ (1.2.0 ← 1.3.0-beta)',
        () {
      expect(checker.isMandatoryUpdate('1.2.0', '1.3.0-beta'), isTrue);
    });

    test('وسم -beta على المحلّي يُتجاهل — صغرى → اختياريّ (1.2.0-beta ← 1.2.1)',
        () {
      expect(checker.isMandatoryUpdate('1.2.0-beta', '1.2.1'), isFalse);
    });

    test('اللاحقتان معاً (-rc و +build) — وسطى → إجباريّ', () {
      expect(
        checker.isMandatoryUpdate('1.2.3-rc.1+45', '1.3.0-rc.2+46'),
        isTrue,
      );
    });

    test('رقم البناء وحده يقفز → اختياريّ (1.2.3+999 ← 1.2.3+1000)', () {
      expect(checker.isMandatoryUpdate('1.2.3+999', '1.2.3+1000'), isFalse);
    });

    test('الوسم يُقتطع مع ما بعده من نقاط (1.2.3 ← 1.2-beta.9) → اختياريّ', () {
      // "1.2-beta.9" يُقرأ "1.2" لا "1.2" ثمّ "9": القطع عند الشرطة يسبق
      // التقسيم بالنقاط، فالكبرى والوسطى متطابقتان → لا إجبار.
      expect(checker.isMandatoryUpdate('1.2.3', '1.2-beta.9'), isFalse);
    });

    test('وسم عربيّ يُتجاهل (1.2.3-تجريبي ← 1.3.0-تجريبي) → إجباريّ', () {
      expect(
        checker.isMandatoryUpdate('1.2.3-تجريبي', '1.3.0-تجريبي'),
        isTrue,
      );
    });

    test('وسم طويل جدّاً (٥٠٠ حرف عربيّ) لا يؤثّر في الحكم', () {
      final String longLabel = 'ب' * 500;
      expect(
        checker.isMandatoryUpdate('1.2.3-$longLabel', '1.3.0-$longLabel'),
        isTrue,
      );
    });
  });

  group('خانات غير متساوية الطول', () {
    test('متجر بخانة واحدة أكبر → إجباريّ (1.2.3 ← 2)', () {
      expect(checker.isMandatoryUpdate('1.2.3', '2'), isTrue);
    });

    test('متجر بخانة واحدة مساوية للكبرى → اختياريّ (1.0.0 ← 1)', () {
      expect(checker.isMandatoryUpdate('1.0.0', '1'), isFalse);
    });

    test('متجر بخانة واحدة والمحلّي له وسطى أعلى → لا إجبار (1.2.0 ← 1)', () {
      // الخانات الناقصة تُقرأ أصفاراً: 1 ← 1.0.0، وهو تراجعٌ عن 1.2.0.
      expect(checker.isMandatoryUpdate('1.2.0', '1'), isFalse);
    });

    test('محلّي بخانتين ومتجر بأربع، الصغرى فقط → اختياريّ (1.2 ← 1.2.0.5)', () {
      expect(checker.isMandatoryUpdate('1.2', '1.2.0.5'), isFalse);
    });

    test('محلّي بأربع ومتجر بثلاث بوسطى أعلى → إجباريّ (1.2.3.4 ← 1.3.0)', () {
      expect(checker.isMandatoryUpdate('1.2.3.4', '1.3.0'), isTrue);
    });

    test('نقطة زائدة في الذيل لا تُحدث خانةً وهميّة (1.2.3. ← 1.2.4.)', () {
      expect(checker.isMandatoryUpdate('1.2.3.', '1.2.4.'), isFalse);
    });
  });

  group('نسخة المتجر أقدم من المحلّي — لا إجبار على التراجع', () {
    test('كبرى أقدم (3.0.0 ← 2.9.9) → لا إجبار', () {
      expect(checker.isMandatoryUpdate('3.0.0', '2.9.9'), isFalse);
    });

    test('وسطى أقدم (1.5.0 ← 1.4.9) → لا إجبار', () {
      expect(checker.isMandatoryUpdate('1.5.0', '1.4.9'), isFalse);
    });

    test('صغرى أقدم (1.2.9 ← 1.2.1) → لا إجبار', () {
      expect(checker.isMandatoryUpdate('1.2.9', '1.2.1'), isFalse);
    });

    test('تراجع كبير (10.0.0 ← 9.99.99) → لا إجبار', () {
      expect(checker.isMandatoryUpdate('10.0.0', '9.99.99'), isFalse);
    });

    test('المقارنة عدديّة لا نصّيّة (1.9.0 ← 1.10.0) → إجباريّ', () {
      // نصّياً "10" < "9"، وعدديّاً 10 > 9 — الثانية هي الصحيحة.
      expect(checker.isMandatoryUpdate('1.9.0', '1.10.0'), isTrue);
    });

    test('المقارنة عدديّة لا نصّيّة (1.10.0 ← 1.9.0) → لا إجبار', () {
      expect(checker.isMandatoryUpdate('1.10.0', '1.9.0'), isFalse);
    });
  });

  group('مدخلات حدّية ومشوّهة', () {
    test('الطرفان فارغان → لا إجبار', () {
      expect(checker.isMandatoryUpdate('', ''), isFalse);
    });

    test('إصدار المتجر فارغ → لا إجبار', () {
      // نصٌّ فارغ لا يُفهم منه إصدار، فلا يُبنى عليه حجبُ التطبيق.
      expect(checker.isMandatoryUpdate('1.2.3', ''), isFalse);
    });

    test('الإصدار المحلّي فارغ → يُقرأ 0.0.0 فيصير أيّ إصدار متجرٍ إجبارياً', () {
      // سلوكٌ مقصود في التفكيك الدفاعيّ؛ لا يقع عملياً لأنّ PackageInfo
      // لا يُرجع نصّاً فارغاً.
      expect(checker.isMandatoryUpdate('', '2.0.0'), isTrue);
    });

    test('إصدار متجر غير رقميّ بالكامل (abc) → لا إجبار', () {
      expect(checker.isMandatoryUpdate('1.2.3', 'abc'), isFalse);
    });

    test('خانة وسطى غير رقميّة تُقرأ صفراً فلا تُجبر (1.2.3 ← 1.x.0)', () {
      expect(checker.isMandatoryUpdate('1.2.3', '1.x.0'), isFalse);
    });

    test('إشارة سالبة تُقتطع كوسم فيصير الإصدار صفراً (1.2.3 ← -1.0.0)', () {
      expect(checker.isMandatoryUpdate('1.2.3', '-1.0.0'), isFalse);
    });

    test('أرقام عربيّة-هنديّة لا تُفكَّك → لا إجبار (1.0.0 ← ٢.٠.٠)', () {
      // int.tryParse لا يقرأ '٢'، والخانة غير المفهومة تُقرأ صفراً.
      expect(checker.isMandatoryUpdate('1.0.0', '٢.٠.٠'), isFalse);
    });

    test('مسافات داخل الخانات مقبولة (1.2.3 ← 1. 3.0) → إجباريّ', () {
      expect(checker.isMandatoryUpdate('1.2.3', '1. 3.0'), isTrue);
    });

    test('من الصفر إلى وسطى أولى (0.0.0 ← 0.1.0) → إجباريّ', () {
      expect(checker.isMandatoryUpdate('0.0.0', '0.1.0'), isTrue);
    });

    test('من الصفر إلى صغرى أولى (0.0.0 ← 0.0.1) → اختياريّ', () {
      expect(checker.isMandatoryUpdate('0.0.0', '0.0.1'), isFalse);
    });

    test('خانة كبرى أطول من سعة int (٢٠ رقماً) → إجباريّ', () {
      // 99999999999999999999 يفوق 2^63-1، وكان int.tryParse يردّه null
      // فتُقرأ الخانة صفراً ويُحكم على إصدارٍ أحدث بكثير بأنّه ليس إجبارياً،
      // بل لا يُعدّ تحديثاً أصلاً. صار التفكيك بـBigInt فلا فيضان.
      expect(
        checker.isMandatoryUpdate('1.0.0', '99999999999999999999.0.0'),
        isTrue,
      );
    });

    test('خانة كبرى عملاقة أقدم من المحلّي → لا إجبار على التراجع', () {
      // الاتّجاه المعاكس يثبّت أنّ المقارنة عدديّة لا مجرّد «الأطول أكبر».
      expect(
        checker.isMandatoryUpdate('99999999999999999999.0.0', '1.0.0'),
        isFalse,
      );
    });
  });

  group('حراسة المنصّة (على مضيف سطح المكتب في الاختبار)', () {
    test('performImmediateUpdate خارج أندرويد يُرجع false بلا نداء القناة', () async {
      expect(Platform.isAndroid, isFalse, reason: 'مضيف الاختبار سطح مكتب');
      expect(await checker.performImmediateUpdate(), isFalse);
    });

    test('checkForUpdate على منصّة غير مدعومة لا ينادي أيّ callback', () async {
      bool notified = false;
      Object? failure;

      await checker.checkForUpdate(
        appStoreId: '000000000',
        onUpdateAvailable: (bool isMandatory, [AppReleaseInfo? info]) {
          notified = true;
        },
        onError: (Object e) => failure = e,
      );

      // لا أندرويد ولا iOS → لا فحص ولا شبكة ولا نداء لأيّ من الاثنين.
      expect(notified, isFalse);
      expect(failure, isNull);
    });

    test(
      'checkIOSUpdate يبلّغ onError بوسيطٍ واحد ولا يرمي حين يفشل الفحص',
      () async {
        // تراجع (regression): كان هذا المسار يبتلع الخطأ بلا تسجيلٍ لأثر
        // المكدّس، فيصل Sentry بلا موضع. صار يسجّله داخلياً ويبقى `onError`
        // على وسيطه الواحد — هذا الاختبار يثبّت التوقيع كما يستهلكه التطبيقات.
        //
        // في بيئة الاختبار تفشل PackageInfo.fromPlatform قبل أيّ طلبة شبكة،
        // فالمسار مغلقٌ على الجهاز بلا إنترنت.
        Object? failure;
        bool notified = false;

        await checker.checkIOSUpdate(
          '000000000',
          (bool isMandatory, [AppReleaseInfo? info]) => notified = true,
          (Object e) => failure = e,
        );

        expect(failure, isNotNull, reason: 'الخطأ يُبلَّغ لا يُبتلع');
        expect(notified, isFalse, reason: 'لا إشعار تحديث عند فشل الفحص');
      },
    );
  });
}
