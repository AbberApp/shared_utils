/// علامة البطاقة — فيزا أو ماستركارد — من بادئة رقمها. **لا يرمي أبداً.**
///
/// بديلٌ محلّيّ لحزمة `credit_card_type_detector` 3.0.0: قيدُها
/// `sdk: '>=2.12.0 <3.0.0'` يستثني Dart 3 على الورق فلا تعمل إلّا بتسامح
/// `pub` مع الحزم القديمة، وآخرُ إصدارٍ لها في 2023-03-28.
///
/// **يقتصر على فيزا وماستركارد عمداً:** هما وحدهما ما تستعمله التطبيقات، في
/// `payment_helper.dart` بعد أن تفحص «مدى» بخدمتها الخاصّة. وكثيرٌ من بادئات
/// مدى يقع داخل مدى فيزا وماستركارد، فلا بدّ أن يسبق فحصُها هذا الكشف:
///
/// ```dart
/// if (MadaBinsService.instance.isMada(sanitizedNumber)) return 'MADA';
///
/// final List<CreditCardType> types = detectCCType(sanitizedNumber);
/// if (types.contains(CreditCardType.visa())) return 'VISA';
/// if (types.contains(CreditCardType.mastercard())) return 'MASTER';
/// ```
///
/// **والأسماء والتواقيع المستعمَلة مطابقةٌ للحزمة** — [detectCCType] بنوع
/// إرجاعها، و[CreditCardType.visa] و[CreditCardType.mastercard] — فلا يُمسّ
/// سطرٌ في التطبيقات. ومدى ماستركارد هو مدى الحزمة نفسه (51–55 و2221–2720،
/// وكانت تكتبه ستّة أجزاء)، وحكمُه على البادئة القصيرة حكمُها: «23» ماستركارد،
/// و«22» لم تُحسم بعد.
///
/// وسقط ما لم يُستعمل: العلامات التسع الأخرى في مجموعتها الافتراضية (Amex
/// وDiscover وDiners وJCB وUnionPay وMaestro وElo وHiper وHipercard — وMir لم
/// تكن فيها أصلاً)، وسجلُّ العلامات القابل للتعديل (`addCardType` وأخواتها)،
/// و`prettyType` و`lengths` و`patterns` و`securityCode`، و`SecurityCode`
/// و`CardCollection` و`Pattern` — وهذا الأخير كان يحجب `Pattern` من `dart:core`
/// في كلّ ملفٍّ يستورد البرميل.
///
/// **والفوارق مقصودة، ولا يبلغ أيٌّ منها التطبيقات** — فهي تنظّف الرقم بنفسها
/// ولا تستدعي الكشف قبل ستّ خانات:
///
/// * نصٌّ فارغ ← قائمةٌ فارغة. كانت الحزمة تُرجع علاماتها الإحدى عشرة كلّها
///   («كلّها محتمل»)، فيُصنَّف الحقلُ الفارغ فيزا.
/// * المسافات كلّها والشَّرطات تُحذف. كانت الشرطة تُسقط الرقم كلّه
///   (`4111-1111-…` ← `[]`)، وتعبيرُها للمسافات يُفلت بعضها (مسافتان في الآخر).
/// * القائمة عنصرٌ واحدٌ على الأكثر، فالمديان لا يتقاطعان. وكانت الحزمة تُقدّم
///   علامةً أخصّ إن وُجدت: `401178…` كانت `[elo, visa]`.
/// * المساواة بالقيمة على [CreditCardType.type]. كانت الحزمة تقارن قوائمها
///   بالهويّة، فلا تصحّ `contains` إلّا لأنّ كلّ مُنشئٍ يعيد القوائمَ العامّة
///   نفسها في كلّ استدعاء.
List<CreditCardType> detectCCType(String ccNumStr) {
  final String digits = ccNumStr.replaceAll(_separators, '');
  // يردّ الفارغَ أيضاً: `+` تشترط خانةً واحدةً على الأقلّ.
  if (!_digitsOnly.hasMatch(digits)) return <CreditCardType>[];
  return <CreditCardType>[
    for (final _Brand brand in _brands)
      if (brand.ranges.any((_PrefixRange r) => _startsWithin(digits, r)))
        brand.type,
  ];
}

/// علامة بطاقةٍ يعرفها [detectCCType]: [CreditCardType.visa] أو
/// [CreditCardType.mastercard].
///
/// لا مُنشئ عامّاً سواهما: العلامة لا تُصنع من خارج المكتبة، فلا يُكتب نوعٌ
/// لا يعرف الكشفُ مداه.
///
/// **والمُنشئان العامّان غير `const` — كما كانا في الحزمة — عمداً.** التطبيقات
/// تفعّل `prefer_const_constructors` وتكتب `CreditCardType.visa()` بلا `const`،
/// فلو صارا `const` لظهرت لكلٍّ منها ملاحظتان جديدتان دون أن يتغيّر فيها سطر.
/// فهما `factory`، والإنشاء الثابت داخليّ: كلُّ استدعاءٍ يعيد النسخةَ الثابتة
/// نفسها.
final class CreditCardType {
  const CreditCardType._(this.type);

  static const CreditCardType _visa = CreditCardType._('visa');
  static const CreditCardType _mastercard = CreditCardType._('mastercard');

  /// فيزا: كلُّ رقمٍ يبدأ بـ4.
  factory CreditCardType.visa() => _visa;

  /// ماستركارد: يبدأ بـ51–55 أو بـ2221–2720.
  factory CreditCardType.mastercard() => _mastercard;

  /// المعرّف الآليّ بقيمة الحزمة نفسها: `visa` أو `mastercard`.
  final String type;

  /// بالقيمة على [type] وحده، فلا تتوقّف صحّةُ
  /// `types.contains(CreditCardType.visa())` على هويّة النسخة.
  @override
  bool operator ==(Object other) =>
      other is CreditCardType && other.type == type;

  @override
  int get hashCode => type.hashCode;

  /// إضافةٌ على الحزمة — لم يكن لها `toString` — كي تُقرأ رسائلُ فشل
  /// الاختبارات: `[CreditCardType.visa()]` لا `[Instance of 'CreditCardType']`.
  @override
  String toString() => 'CreditCardType.$type()';
}

/// مدى بادئاتٍ متساوية الطول، شاملٌ طرفيه: `(from: '51', to: '55')`.
typedef _PrefixRange = ({String from, String to});

typedef _Brand = ({CreditCardType type, List<_PrefixRange> ranges});

/// المديان لا يتقاطعان (4 وحدها لفيزا)، فلا يُطابق رقمٌ علامتين.
const List<_Brand> _brands = <_Brand>[
  (
    type: CreditCardType._visa,
    ranges: <_PrefixRange>[(from: '4', to: '4')],
  ),
  (
    type: CreditCardType._mastercard,
    ranges: <_PrefixRange>[
      (from: '51', to: '55'),
      (from: '2221', to: '2720'),
    ],
  ),
];

/// كلُّ مسافةٍ — ومنها غير الفاصلة — وكلُّ شرطة.
final RegExp _separators = RegExp(r'[\s-]');

/// خاناتٌ لاتينيّة وحدها، كما في الحزمة: «٤١١١» ليست رقم بطاقة هنا.
final RegExp _digitsOnly = RegExp(r'^[0-9]+$');

/// هل تحسم خاناتُ [digits] الأولى أنّ الرقم داخل [range]، أيّاً كان ما يليها؟
///
/// بادئةٌ أقصر من طرفَي المدى تُطابق إن وقع **كلُّ** إكمالٍ لها داخله: «23»
/// تُطابق 2221–2720 لأنّ 2300–2399 كلّها فيه، و«22» لا تُطابق لأنّ 2220 خارجه.
///
/// والمقارنة نصّيّة لا عدديّة: الطرفان متساويا الطول فيتّفق ترتيبُ النصّ
/// وترتيبُ العدد، ولا `int.parse` يُخشى منه على رقمٍ طويل.
bool _startsWithin(String digits, _PrefixRange range) {
  final int width = range.from.length;
  final bool complete = digits.length >= width;
  final String lowest = complete
      ? digits.substring(0, width)
      : digits.padRight(width, '0');
  final String highest = complete
      ? digits.substring(0, width)
      : digits.padRight(width, '9');
  return lowest.compareTo(range.from) >= 0 && highest.compareTo(range.to) <= 0;
}
