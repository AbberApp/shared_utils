## 3.3.0

* feat(ShareService + ShareOrigin): ورقة المشاركة والحافظة في المكتبة، ومعها
  مصدر الورقة على iPad.

  كان كلّ مشروعٍ يكتب `SharePlus.instance.share(...)` بيده، ويعيد معها سطرَي
  `findRenderObject()` و`localToGlobal(Offset.zero) & box.size` — تسعة مواضع في
  «عبر» و«منام» ولوحة الإدارة و«وصال». ومن نسي `sharePositionOrigin` رأى ورقة
  المشاركة تخرج من زاوية الشاشة على iPad، لأنّها هناك popover يطلب مستطيلاً
  يخرج منه.

  `ShareService`: `copy` و`shareText` و`shareBytes` (يكتب البايتات في المجلّد
  المؤقّت ويحفظ الاسم بـ`fileNameOverrides`) و`shareFiles`. وكلّها تقبل
  `origin`.

  `ShareOrigin`: إضافةٌ على `BuildContext` تعطي `context.shareOrigin` —
  مستطيل العنصر المضغوط بإحداثيات الشاشة، و`null` حين لا حجم له بعد. تُقرأ من
  سياق العنصر لا من سياق الصفحة، وإلّا خرجت الورقة من مكانٍ لا علاقة له بالزرّ.

## 3.2.0

* feat(DioConsumer): `allowBadCertificates` — مفتاحٌ على تحقّق شهادات TLS.

  كان العميل يقبل كلّ شهادةٍ بلا تحقّق في كلّ البيئات، بلا سبيلٍ إلى غير ذلك:
  كلّ مشروعٍ يبني `DioConsumer` يرث تعطيلَ حمايةِ MITM. ومشروعٌ يحمل رموزَ
  دخولٍ أو وثائقَ خاصّة يحتاج التحقّق، فمن يتحكّم بالشبكة يستطيع دونه أن
  يقدّم شهادةً من صنعه فيقرأ ما يمرّ ويعدّله.

  الافتراض `true` — سلوك المشاريع القائمة لا يتغيّر حرفاً، وقرارُ إبقائه
  للمالك. ومن مرّر `false` لم يُمَسّ محوِّله أصلاً، فيبقى تحقّق dart:io
  الافتراضيّ: تُرفَض الشهادة المزوّرة أو المنتهية أو التي لاسمِ نطاقٍ آخر.
  وفائدةٌ ثانيةٌ لمن اختار `false`: التحويل إلى `IOHttpClientAdapter` — وهو
  يرمي على الويب — لم يعد يقع عليه.

  `test/dio_consumer_tls_test.dart` يثبّت الحالتين، فلا ينقلب الافتراض سهواً.

## 3.1.0

* fix(SentryBootstrap): مهلةٌ على التهيئة، فلا تحجز إقلاع التطبيق.

  `SentryFlutter.init` يُشغّل تكاملاته كلّها **قبل** `appRunner`، ومنها ما
  ينادي الطبقة الأصليّة. والحارس القائم كان ضدّ الرمي وحده: نداءٌ أصليّ لا
  يردّ يوقف الدالّة فلا يصل السطر الذي يُشغّل التطبيق — ولأنّ
  `FlutterNativeSplash.preserve` يحجز أوّل إطار، تبقى شاشة الإقلاع ساكنةً
  إلى الأبد بلا انهيارٍ ولا بلاغ (Sentry نفسه لم يُهيَّأ بعد).

  صار `await SentryFlutter.init(...)` محدوداً بعشر ثوانٍ؛ و`TimeoutException`
  من `Exception` فيلتقطها الحارس القائم ويُقلع التطبيق بلا مراقبة — وهو
  أهون من ألّا يُقلع. و`guardedRunner` صار idempotent وسطرُ الاحتياط يمرّ
  عبره، وإلّا لو اكتملت التهيئة بعد انقضاء المهلة لشُغّل التطبيق مرّتين.

## 3.0.0

مراجعةٌ شاملة للمكتبة: جردٌ بتدقيقٍ خصوميّ ثلاثيّ العدسات أنتج 334 ادعاءً، نجا منها
219 وسقط 115. نُفِّذ منها 224 إصلاحاً، وكُتب 1011 اختباراً جديداً (961 ← 2042 اختباراً،
بلا موقوفٍ واحد).

### ⚠️ BREAKING

خمسة تغييراتٍ في السطح العام. قِيست مواضع النداء فعليّاً في المشاريع الثمانية
المستهلِكة قبل تنفيذ كلٍّ منها، فكانت **صفراً** في الثلاثة الأولى — الكسر على الورق
وحده، والترحيل لا يكلّف المشاريع سطراً.

| قديم | جديد |
|---|---|
| `DeviceInfoModel` | `SharedDeviceInfo` |
| `AppInfo` | `SharedAppInfo` |
| `DeviceDetails` | `SharedDeviceDetails` |
| `SystemInfo` | `SharedSystemInfo` |
| `ScreenInfo` | `SharedScreenInfo` |
| `DeviceDetails.androidId` | `SharedDeviceDetails.buildId` |
| مفتاح `android_id` في `toJson()` | `build_id` |
| `ApiConsumer.get(..., useToken:)` | حُذف الوسيط |
| `ResponseCode.unknown = 301` | `= -19` |

* **`ResponseCode.unknown` ← ‎-19.** كانت 301 وهو كود HTTP قائم (Moved Permanently)،
  فـ`Failure(code: 301)` لا يُميَّز أهو خطؤنا أم إعادة توجيهٍ من الخادم. وسائر الأكواد
  المخصّصة خارج مجال HTTP (‎≤ 0) فصار النمط متّسقاً. من يقارن `failure.code` بالرقم
  حرفيّاً يحتاج مواءمة؛ ومن يقارنه بـ`ResponseCode.unknown` لا يتغيّر عنده شيء.

* **تسمية نماذج الجهاز ببادئة `Shared`.** الأسماء الخمسة كانت عامّةً جدّاً وتُصدَّر بلا
  نطاق، فوقع الاصطدام فعلاً: `abber_admin` يعرّف `class DeviceInfoModel` خاصّاً به
  فحجب صنف المكتبة **صامتاً بلا خطأ ترجمة**. ولم تُستعمل `show`/`hide` في البرميل —
  تلك تُخفي الأسماء عن كلّ مستورد وهي الكاسر حقّاً — ولا أُبقي `typedef` بالاسم
  القديم، لأنّ الاسم القديم نفسه هو مصدر الاصطدام. الوصول في المشاريع كلّه
  بالاستدلال (`DeviceInfoManager.instance.info.persistentId`) فلا موضع ترحيل.

* **`androidId` ← `buildId`.** القيمة `Build.ID` — رقم بناء النظام، يتكرّر على كلّ
  جهازٍ يعمل بالبناء نفسه — والاسم القديم يوحي بـ SSAID أو معرّف جهاز: فخٌّ حيّ لأوّل
  من يكتب `device.androidId` ظانّاً أنّه يميّز جهازاً. لتمييز جهازٍ بعينه: `id`
  (المعرّف الثابت). `toFlatMap()` لم يكن يُصدِّر الحقل أصلاً فلم تتأثّر؛ أمّا `toJson()`
  فمفتاحه تغيّر — وهذا يحتاج مواءمة الخادم إن كان يقرأ `device.android_id`.

* **حذف الوسيط `useToken` من `ApiConsumer.get` و`DioConsumer.get`.** كان كذبةً صامتة:
  من يكتب `useToken: false` يظنّ أنّه منع ترويسة المصادقة، والطلب يُرسَل بالتوكن.
  348 استدعاءً لـ `.get(` في المشاريع الثمانية ولا واحدٌ يمرّره. ترويسة المصادقة شأن
  `appInterceptors` وحده.

### إصلاحات — انهيارات

* **`SentryBootstrap.run`** — نداء إضافات المنصّة كان أوّل سطرٍ في `optionsConfiguration`
  وبلا حارس. فشلُ قناةٍ أصليّة يجعل Sentry يبتلع الخطأ ثمّ يرمي `ArgumentError('DSN is
  required.')` لأنّ `options.dsn` لم يُسنَد بعد — فلا يُستدعى `runApp` قطّ: **شاشةٌ
  بيضاء دائمة بلا أيّ بلاغ، لأنّ Sentry نفسه لم يُهيَّأ**. صارت الإعدادات المضمونة
  أوّلاً، والنداء الهشّ داخل `try/catch` بإصدارٍ احتياطيّ، والتهيئة كلّها ملفوفة مع علم
  `appStarted` يضمن إقلاع التطبيق ويمنع تشغيله مرّتين.

* **`IbanUtils.isValid`** — `int.parse` داخل MOD‑97 بلا حماية. الدالّة تفحص رمز الدولة
  والطول فقط، فأيّ نصٍّ بطولٍ معياريّ فيه واصلة أو رقمٌ عربيّ‑هنديّ يصل إلى `int.parse`
  فيرمي `FormatException`. وهي تُستعمل داخل `TextFormField.validator`، فالاستثناء يصعد
  عبر `FormState.validate()` بلا التقاط ← شاشةٌ حمراء فور ضغط «حفظ». المسار الواقعيّ:
  لصق IBAN من كشف حسابٍ بنكيّ. صار حارس طقم محارف + `int.tryParse`.

### إصلاحات — العربية تحديداً

* **`SseManager`** — `utf8.decode` لكلّ chunk كان يرمي `FormatException` على تتابع
  البايتات المقسّم بين chunkين، وهو ما يحدث مع الحروف العربية. صار `utf8.decoder.bind`
  وهو مفكّكٌ ذو حالة.
* **`IbanFormatter`** — وحده بين منسّقات المكتبة لا يوحّد الأرقام العربية‑الهندية، فكان
  يُرجع `oldValue` صامتاً على «SA٤٤» ويُجمّد الحقل.
* **`TextFormatter`** — `composing` قديم بعد تقصير النصّ؛ والحقل هو تحديداً المعرَّض
  للوحة مفاتيح عربية.

### إصلاحات — تغييرات سلوكية مرئية

* **`DateTime` extensions** — `_localDateTime` كان يضيف الإزاحة إلى تاريخٍ محلّيّ أصلاً
  فيُزيحه مرّتين: `DateTime.now()` في الرياض تُعرض ‎+3 ساعات. و`inHours` يبتر الأنصاف
  فتخطئ الهند ‎+5:30 وإيران ‎+3:30. صار `isUtc ? toLocal() : this`. **يؤثّر في 15 موضع
  تنسيق.**
* **`BaseEntity.canLoadMore`** — كان `hasNext && count > 0` فيبقى `true` بعد نفاد
  العناصر: عاصفة طلباتٍ في نهاية كلّ قائمة. صار `count > length`.
* **`CardFormatter` و`IbanFormatter`** — المؤشّر كان يُقذف إلى نهاية النصّ بعد كلّ ضغطة،
  فالتصحيح من المنتصف مستحيل. وحذف شهر انتهاء البطاقة كان يعيد بناء `/` بلا نهاية.

### جديد

* **`handleJsonResponse(Response)`** — رفيقةٌ صارمة لـ`handleResponse` تُعيد
  `Map<String, dynamic>` وترمي `DioException` واضحة على غير ذلك. `handleResponse` لم
  يتغيّر فيها حرف — عقدُها (إعادة النصّ الخام عند فشل الفكّ) معتمَدٌ في 794 موضعاً
  لنقاط نهايةٍ تردّ نصّاً عادياً. استعمل الجديدة حيث تُمرَّر النتيجة إلى `Model.fromJson`
  لتحصل على خطأٍ مفهوم بدل `TypeError: String is not a subtype of Map` عند المستهلك.

### تغييرات سلوكية إضافية (بلا تغيير تواقيع)

* **`convertArabicToEnglishNumbers`** — كانت تستبدل الفاصلة `,` بنقطةٍ عشرية، فـ«1,234»
  تصير «1.234»: **خطأ بمعامل ألف في مبلغٍ ماليّ**. صارت `,` و`٬` (U+066C) تُحذفان
  بوصفهما فاصلتَي آلاف، و`٫` (U+066B) وحدها تصير نقطةً عشرية. المبرَّر من مخرجات
  المكتبة نفسها: `toCurrency` تستعمل `NumberFormat('#,##0.00','en_US')` فالفاصلة
  اللاتينية فيها فاصلة آلافٍ لا غير.
* **`ResponseCode.isBadHtmlResponse`** — كانت تطابق قالباً حرفيّاً واحداً، فمسافةٌ واحدة
  أو غياب DOCTYPE يكسر الكشف بكامله: صفحة nginx 502 بكود 200 كانت تعبر إلى
  `Model.fromJson` فتنفجر هناك بـ«String is not a subtype of Map» بلا دلالةٍ على
  السبب. صارت تقبل بادئتَي `<!doctype html` و`<html` بعد التشذيب وبلا حساسيةٍ لحالة
  الأحرف.
* **أقاليم رمز الاتصال «1»** — كندا وبورتوريكو والدومينيكان كانت تُنسب كلّها إلى `US`.
  صار الحسم برمز المنطقة (NPA) عبر libphonenumber، مع السقوط إلى `US` عند تعذّر
  التحليل. ودوالّ الاستخراج صارت تطبّع المُدخل: مسافةٌ بادئة من لصق جهات الاتصال،
  وأرقامٌ عربية‑هندية، وبادئة الخروج الدوليّ `00`.
* **`parseToMap`** — `None` في قاموس Python كانت تصير نصّ «None» (قيمةٌ غير‑null تنجو
  من كلّ فحوص `??`)، والمفاتيح العربية غير المقتبسة كانت تُسقط الحمولة كلّها إلى `{}`.
* **`toCurrency`** — الإشارة لم تكن تُمحى بعد التقريب إلى صفر فيُعرض «‎-0.00»؛ والأعداد
  فوق حدّ int64 كانت تُقصّ صامتاً (‎1e19 تخرج «9,223,372,036,854,775,807.00»).
* **`isValidEmail`** كانت تقبل نطاقاً يبدأ أو ينتهي بشرطة؛ و**`withoutBrackets`** كانت
  تقصّ محرفين من أيّ نصّ ولو لم يكونا قوسين متقابلين؛ و**`DelayHandler.run`** بعد
  `dispose()` صارت عمليةً لاغية بدل جدولة مؤقّتٍ جديد.

### إضافات

* `int.toCurrencyNoDecimals` — كانت على `double` وحدها.
* `String.toLatinDigits` — الاتجاه العكسي لـ`toArabicDigits`، كان مفقوداً.

### اختبارات

961 ← **2042 اختباراً، وصفر موقوف.** كُتب 1011 اختباراً جديداً وثّقت 68 عيباً بـ`skip`
بدل أن تباركها، ثمّ أُصلحت العيوب كلّها ورُفع الإيقاف. وأربعةٌ منها تبيّن أنّ **الاختبار**
هو المخطئ لا الكود — منها واحدٌ كان سبب إيقافه باطلاً من أصله — فصُحّحت الاختبارات. تغطيةٌ جديدة
لـ`handleResponse` و`ErrorHandler` و`Failure` و`parseToMap` و`BaseEntity` و`SafeBloc`
و`DelayHandler` و`FieldErrors` وخوارزمية IBAN MOD‑97، وأوّل `testWidgets` في المستودع.
و`mocktail` أُضيفت إلى `dev_dependencies`.

### تبعيات وتوثيق

* `sentry_flutter` ← ‎9.30.1. وكلّ التبعيات المباشرة على أحدث إصدارٍ منشور.
* 18 تصحيحاً في `README.md` و`CLAUDE.md`: أمثلةٌ لا تُصرَّف (`previous` المحذوف،
  `merge(key:)`، `saveAndGetFile` يعيد `File` لا `String?`)، و`ref: main` وهو فرعٌ لا
  وجود له، و`updateRequired` وهو رمزٌ غير موجود. وأُضيف `ignoreContainers: true` إلى
  مثال `SkeletonizerWidget` — بدونه كان `containersColor` يُهمَل صامتاً.
* حُذفت ثلاثة براميل داخلية ميّتة لا يستوردها أحد: `network.dart` و`services.dart`
  و`utils.dart`.

### ملاحظة على TLS

`DioConsumer` يقبل كلّ شهادات TLS بلا تحقّق، في كلّ البيئات بما فيها الإنتاج. أُبقي
بقرارٍ صريحٍ من مالك المكتبة ووُثّق في موضعه بتعليقٍ يمنع إعادة فتحه مراجعةً بعد مراجعة.

## 2.18.1

* chore(deps): ترقية الاعتماديات — `sentry_flutter` ‎9.30، `dio` ‎5.11.1،
  `file_picker` ‎13، `skeletonizer` ‎3، `phone_numbers_parser` ‎9.0.26.
  لا تغيير في واجهة المكتبة.

## 2.18.0

* feat: تصدير سبع حزمٍ للمنصّة من `shared_utils.dart` — `dio` · `connectivity_plus`
  · `skeletonizer` · `json_annotation` · `url_launcher` · `share_plus` ·
  `open_file`. الغرض توحيد الإصدار: ترقيةٌ واحدة هنا تسري على المشاريع الثمانية
  بدل ثمانية `pubspec` يتخلّف بعضها عن بعض — كان `share_plus` موزّعًا على
  13.0.0 و13.1.0 و13.3.0 في وقتٍ واحد. و`open_file` لا `open_filex`: الثانية بلا
  `Package.swift` فتُبقي CocoaPods حيّةً وتمنع الانتقال إلى SPM.

## 2.17.0

* feat(forms): `FieldErrors.apply` / `FieldErrors.clear` — تربط أخطاء الحقول
  القادمة من الخادم (`Failure.fields`) بحقول `Form` مباشرةً. الأوّليّات كانت
  موجودة (`hasFields` و`fieldError`) والربط متروكاً لكلّ تطبيق، فكُتب في كلٍّ
  منها بيدٍ مختلفة أو لم يُكتب: فيُعرض خطأ الحقل حواراً عامّاً والمستخدم لا
  يعرف أيّ حقلٍ يصلح.

## 2.16.0

* feat(SentryBootstrap): `identify` — هويّة المستخدم بخريطة حرّة، و`forget()`
  لمسحها عند الخروج. كان كل تطبيق يكتب `setUserDataToSentry` بنفسه: منطقٌ واحد
  يختلف في حقوله وحدها. والخريطة حرّة عمداً — لكل تطبيق حقوله (مشترٍ/معبّر،
  تاجر، مسؤول…) والمكتبة لا تعرف نماذجه. و`forget()` كانت ناقصة في التطبيقات
  كلّها فتبقى هويّة المستخدم السابق على أحداث من بعده. وكلتاهما تفشل صامتةً:
  هويّة في التتبّع لا تستحقّ إسقاط تسجيل الدخول.

## 2.15.0

* feat(SentryBootstrap): تهيئة موحّدة لتتبّع الأخطاء. كان كل تطبيق يكتب إعداده
  بنفسه فتتفرّق القرارات: أحدهم بلا مرشّح ضجيج، وآخر بعيّنة تتبّع ١٠٠٪ — وغرقت
  لوحة «عبر» بـ٦٥٪ ضجيجَ شبكة أخفى أعطاباً حقيقية شهوراً. المعيار الآن في
  المكتبة والتطبيق يمرّر ما يخصّه وحده: المفتاح واسم المشروع، والإصدار يُبنى
  تلقائياً من نسخة التطبيق ورقم بنائه فيطابق ما في المتجر.
* feat(SentryNoiseFilter): انتقل مع التهيئة — يُسقط ما لا نملك إصلاحه (انقطاع
  الشبكة، أخطاء خوادم الأطراف الثالثة، محتوىً ذهب) بقائمةٍ صريحة لا مرشّح عامّ
  يبتلع. وكل خطأ في كودنا يمرّ كما هو.

## 2.14.0

* feat(FileCacheManager): `FileNoLongerAvailableException` — تمييز الملفّ المفقود
  عن عطب الشبكة. مُخزّن الوسائط يردّ 403 على ملفٍّ غير موجود لا 404: S3 يُخفي
  وجود المفاتيح، فمن لا يملك `s3:ListBucket` يرى AccessDenied بدل NoSuchKey.
  الأثر عملياً: مرفقات ما قبل ترحيل التخزين فُقدت مع الخوادم فتفشل مشاركتها
  باستثناءٍ غامض يصل تتبّع الأخطاء — ٢٩١ حدثاً لدى ٤٢ مستخدماً في «عبر». النوع
  الجديد لا يُصلَح بإعادة المحاولة، فيعرض المستدعي «لم يعد متاحاً» ولا يُرسله
  إلى Sentry.

## 2.13.0

* feat(AudioSessionConfig): ضبط جلسة الصوت. التطبيقات كانت تتّكل على افتراض
  `just_audio` (فئة playback بوصولٍ حصريّ)، ومتى أمسك الصوتَ طرفٌ آخر — بثّ،
  تسجيل، مكالمة — رفض النظام التفعيل بالخطأ 560557684 فتفشل رسالة صوتية بلا
  سبب ظاهر (٢٦٨ حدثاً لدى ٦٥ مستخدماً في «عبر»). الآن `mixWithOthers` على iOS
  و`gainTransientMayDuck` على أندرويد: صوتٌ قصير لا يطلب إسكات غيره فلا يُرفض.
  ميزة تكميلية تفشل صامتةً ولا تُعطّل الإقلاع.

## 2.12.1

* revert: `previous` خارج معيار `BaseEntity`. أُضيف في نسخةٍ حملت الرقم 2.13.0
  ثمّ سُحب فوراً وعاد الرقم إلى 2.12.1 — و2.13.0 أُعيد استعماله لاحقاً
  لـ`AudioSessionConfig`. المكتبة تضع المعيار والمشاريع تلتزم به لا العكس:
  الحقل أُضيف لأجل تطبيقٍ واحد يحمله في نماذجه، والصحيح أن يُزال من التطبيق لا
  أن يُوسَّع به المعيار المشترك. **من أضافه إلى نماذجه فليُزله** — `BaseEntity`
  لا يعرّفه.

## 2.12.0

* feat(state): `SafeBloc` و`SafeCubit` — حرّاس دورة حياة البلوك. نمطٌ واحد ينهار
  في كل تطبيقات المجموعة: طلبٌ شبكيّ يبدأ، يغادر المستخدم الشاشة، ثمّ يُستدعى
  `emit` على بلوكٍ أُغلق ← Bad state. رصده Sentry في «عبر» بآلاف الأحداث، ومسحُ
  التطبيقات الثمانية أظهر ١٤٤ صنفاً معرَّضاً له. حراسة كل كتلة على حدة تعالج
  الماضي وتترك المستقبل، فالحارس في الأساس يرثه الصنف بكلمة واحدة. مزيجان لا
  واحد لحدٍّ لغويّ: `emit` في `BlocBase` تراها الكيوبتات والبلوكات، و`add` في
  `Bloc` وحده. التبعيّة `bloc` وحدها (النواة) لا `flutter_bloc`.

## 2.11.0

* fix(FilePickerManager): مواءمة `file_picker` 12 — غيّرت الحزمة واجهتها
  (`pickFiles` صار يُعيد `List<PlatformFile>` بلا `.files`، و`PlatformFile` فقد
  `extension`)، فتوقّفت المكتبة عن التصريف كلّياً وما عاد أيّ تطبيق يستوردها
  يُبنى. أُعيدت كتابته على `pickFile` المفردة والامتداد يُشتقّ من الاسم.
* chore(deps): ترقية الاعتماديات، وخروج `file_picker` من قيد beta، وإعلان `meta`
  الذي كان مستورداً بلا إعلان.
* refactor: كل `catch` مجرّد (23) صار صريحاً — `on Exception` حيث المتوقّع
  استثناء، و`on Object` حيث يمكن أن يُرمى `Error`؛ فالمجرّد كان يبتلع `Error`
  ويُخفي أخطاءً برمجية حقيقية.

## 2.10.0

* **BREAKING** refactor(AppUpdateChecker): `onUpdateAvailable` تحمل تفاصيل
  الإصدار، و`onReleaseInfo` حُذفت. الاستجابة نفسها التي نقارن بها الإصدار هي
  التي تحمل `releaseNotes`، فالبيانات كانت في اليد لحظة إطلاق `onUpdateAvailable`
  وردٌّ ثانٍ لها تزيّد. التوقيع الآن:

  ```dart
  onUpdateAvailable: (bool isMandatory, [AppReleaseInfo? info])
  ```

  الوسيط الثاني اختياريّ موضعيّ، و`info` تكون `null` إن فشل جلبها من المتجر.
  المستهلكون الذين يمرّرون دالّة بوسيطٍ واحد يجب أن يقبلوا الوسيط الثاني —
  ودالّةٌ بلا وسائط لا تُسنَد أصلاً لأنّ `isMandatory` موضعيّ إلزاميّ.

## 2.9.1

* fix(AppReleaseInfo): `noteLines` تأخذ الأسطر المعلَّمة برمز نقطة فقط. نصّ
  المتجر ليس نقاطاً خالصة: يفتح بعنوانٍ ترويجيّ ويغلق بدعوةٍ للتحديث، وكلاهما
  ليس ميزة — فصارت بطاقة الثلاث نقاط ثماني صفوف. وترجع إلى كل الأسطر غير
  الفارغة حين يخلو النصّ من الرموز، بسقفٍ ستّ نقاط كي لا يُدفع زرّ التحديث
  خارج الشاشة.

## 2.9.0

* feat(AppUpdateChecker): `AppReleaseInfo` و`fetchReleaseInfo(appStoreId)` —
  ملاحظات «ما الجديد» من المتجر. كانت شاشة التحديث تقرأها من إعداد الخادم وهو
  مصفوفة فارغة في الإنتاج، فلا تظهر البطاقة أبداً رغم أنّ المتجر يحمل النصّ
  كاملاً. المصدر iTunes Lookup: طلبة `GET` واحدة بلا مصادقة — وPlay بلا مكافئ
  عامّ (يتطلّب Play Developer API بحساب خدمة موقَّع أو كشطاً)، فنقرأها من آبل
  ونعرضها على المنصّتين إذ النصّ واحد عملياً. تفشل صامتةً ولا تُعطّل التحديث.

## 2.8.21

* feat(phone): `validatePhone` now uses `phone_numbers_parser` (Google
  libphonenumber patterns, not length alone), so it parses the full +E164 and
  NANP dial-code-folded regions (JM = 1876) validate correctly; it falls back to
  length when metadata is missing.
* feat(phone): add `isPlausiblePhone` (length-only, lenient) as the UI's
  fail-open gate — a valid number is always plausible, so no valid user is ever
  blocked and the OTP send stays the final arbiter. 949 per-country tests pass.
* chore(deps): `fluttertoast` 10 + `in_app_update` 5 (moves to the Kotlin bundled
  with Flutter); `persistent_device_id` 2.0.

## 2.8.20

* fix(phone): build `kPhonePossibleLengths` from libphonenumber MOBILE metadata
  only. The `general_desc` lengths (SA = [9, 10]) inflated `getExactLength` to
  10, so the app's completion check (`length == maxLength`) never fired for
  9-digit Saudi mobiles. SA is now [9]; multi-length countries (DE 10/11) still
  accept every valid length.

## 2.8.19

* fix(phone): replace the hand-maintained min/max table with the generated
  `kPhonePossibleLengths` (Google libphonenumber, model-adjusted for NANP dial
  codes) and validate by length membership, including non-contiguous sets
  (BJ = [8, 10]).
* fix(phone): `validatePhone` / `getExactLength` take an optional country, so
  they honor the picker's choice and disambiguate shared dial codes (44 → GB,
  not Guernsey), with a `kMainRegionForDialCode` fallback.
* fix(phone): correct corrupt rows — IT dial code 41 → 39 (it was Switzerland),
  KY 345 → 1345, PR 1939 → 1, VA 379 → 39; drop the duplicate Bahrain row.
* chore(phone): add the reproducible generator `tool/gen_phone_lengths.py` plus
  an exhaustive test over all 236 countries using real libphonenumber example
  numbers (488 tests pass).

## 2.8.18

* fix(SocketManager): reset the reconnect-attempt counter on app resume before
  rescheduling. Without it, once the 10 attempts were exhausted during a long
  foreground outage the counter stayed full, so `resumed` → `_scheduleReconnect`
  gave up permanently and the socket never recovered for the rest of the session
  (presence sockets connect once at a root screen). Now every foreground return
  gets a fresh reconnect budget — self-healing as intended.

## 2.8.2

* chore(SocketManager): remove the temporary `query keys: ...` diagnostic log
  added in 2.8.1 (was only needed to confirm the auth-query work; auth is now
  header-only).

## 2.8.1

* chore(SocketManager): log the resolved query-parameter keys (keys only,
  no values — never leaks the token) on each connect, to confirm the auth
  query is attached in the running build.

## 2.8.0

* **BREAKING** refactor(SocketManager): drop the static `queryParameters`
  field — query parameters are now provided exclusively through the
  `queryBuilder` callback (built fresh on every (re)connect, like
  `headersBuilder`). Callers that passed static `queryParameters` should
  move those entries into `queryBuilder`. This keeps the auth token (and
  any other query) always fresh and avoids a stale snapshot captured at
  construction time. Aligns with `SseManager`'s `queryParametersBuilder`.

## 2.7.0

* feat(SocketManager): add optional `queryBuilder` callback — builds fresh
  query parameters on every (re)connect (mirrors `headersBuilder`). Lets a
  caller pass the auth token inside the WS URL itself as a reliable fallback
  to the `Authorization` header, which `dart:io` does not consistently send
  on reconnect. Eliminates the repeated 4001 reject/reconnect flapping seen
  on mobile after backgrounding. `headersBuilder` is untouched; the static
  `queryParameters` still works and is merged under the dynamic builder.

## 2.6.0

* deps: bump `file_picker` to `^12.0.0-beta.2` to drop the legacy
  `DKImagePickerController` chain (resolves SPM conflict with
  `image_cropper`'s `TOCropViewController 3.x`)
* deps: bump `package_info_plus` to `^10.1.0` and `device_info_plus`
  to `^13.1.0` to satisfy `win32 ^6.x` required by the new `file_picker`

## 0.0.1

* TODO: Describe initial release.
