# shared_utils

مكتبة أدوات مشتركة لمشاريع Flutter. تحتوي على الـ utilities والـ helpers المستخدمة في جميع المشاريع لتجنب تكرار الكود.

## التثبيت

```yaml
dependencies:
  shared_utils:
    git:
      url: https://github.com/AbberApp/shared_utils.git
      ref: stable
```

> `stable` هو الفرع **الوحيد** في المستودع ولا وسوم فيه. أيّ `ref` آخر —
> و`main` أوّلها — يفشل عند `flutter pub get` برسالةٍ غامضة تُضيّع وقتاً قبل
> أن تُفهم. القاعدة مذكورة في [`CLAUDE.md`](CLAUDE.md).

## الاستيراد

```dart
// ملف واحد لكل شيء
import 'package:shared_utils/shared_utils.dart';
```

---

## هيكل المكتبة

```
lib/src/
├── network/            # الشبكة والـ API
│   ├── api/            # ApiConsumer, DioConsumer
│   │   ├── handlers/   # ErrorHandler, ResponseHandler
│   │   └── models/     # Failure, ResponseCode, ResponseMessage
│   └── connectivity/   # ConnectionStatus
├── realtime/           # الاتصال الفوري
│   ├── socket/         # SocketManager, SocketRegistry
│   └── sse/            # SseManager, SseRegistry
├── state/              # SafeBloc, SafeCubit — حرّاس دورة حياة البلوك
├── ui/                 # واجهة المستخدم
│   ├── widgets/        # Toast, PageIndicator, ResponsiveGridView, Skeletonizer, LoadMore, PaginatedListView
│   ├── formatters/     # NumberFormatter, CardFormatter, TextFormatter, PhoneFormatter, IbanFormatter
│   └── forms/          # FieldErrors
├── utils/              # أدوات مساعدة
│   ├── extensions/     # DateFormatExtension, StringExtension, CurrencyExtension, ArabicDigitsExtension
│   ├── phone/          # IntlPhoneUtils
│   ├── helpers.dart
│   ├── delay_handler.dart
│   └── parse_to_map.dart
├── services/           # الخدمات
│   ├── cache/          # FileCacheManager, FileNoLongerAvailableException
│   ├── update/         # AppUpdateChecker, AppReleaseInfo, OptionalUpdateBanner, GuardedNavigator
│   ├── monitoring/     # SentryBootstrap, SentryNoiseFilter
│   ├── audio/          # AudioSessionConfig
│   └── pickers/        # FilePickerManager, ImagePickerManager
├── device/             # معلومات الجهاز — DeviceInfoManager, SharedDeviceInfo
└── data/               # base_entity.dart — BaseEntity
```

---

## المحتويات

- [BaseEntity](#baseentity--pagination)
- [Network](#network)
- [Extensions](#extensions)
- [Formatters](#formatters)
- [Pickers](#pickers)
- [DeviceInfoManager](#deviceinfomanager)
- [IntlPhoneUtils](#intlphoneutils)
- [Services](#services)
- [Widgets](#widgets)
  - [showToast](#showtoast)
  - [SkeletonizerWidget](#skeletonizerwidget)
  - [PaginatedListView](#paginatedlistview)
  - [PageIndicator](#pageindicator)
  - [ResponsiveGridView](#responsivegridview)
  - [DelayHandler](#delayhandler--debounce)
- [Utils](#utils)

---

## BaseEntity — Pagination

الـ base class لكل قائمة مرتبطة بـ API مع pagination.

```dart
// تعريف الـ Model
class BaseOrderModel extends BaseEntity<OrderModel> {
  BaseOrderModel({
    required super.count,
    required super.next,
    required super.results,
  });

  factory BaseOrderModel.fromJson(Map<String, dynamic> json) =>
      _$BaseOrderModelFromJson(json);

  factory BaseOrderModel.empty() =>
      BaseOrderModel(count: 0, next: '', results: []);
}

// استخدام في الـ Bloc
BaseOrderModel orders = BaseOrderModel.empty();

// إضافة بيانات جديدة عند load more
orders.addAll(newData);

// التحقق من إمكانية التحميل
if (orders.canLoadMore) {
  // fetch next page
}

// دمج بدون تكرار — الوسيط الثاني موضعيّ لا مُسمّى
orders.merge(newData, (order) => order.id);
```

> لا تُضف `previous` إلى نماذجك: أُضيف مرّةً إلى `BaseEntity` ثمّ سُحب عمداً
> (راجع 2.12.1 في [`CHANGELOG.md`](CHANGELOG.md)) — المكتبة تضع المعيار
> والمشاريع تلتزم به، والحقل لم يكن يخدم إلّا تطبيقاً واحداً.

**Properties:**
| Property | النوع | الوصف |
|----------|-------|-------|
| `count` | `int` | إجمالي العناصر |
| `next` | `String` | رابط الصفحة التالية |
| `results` | `List<T>` | العناصر المحملة |
| `hasNext` | `bool` | هل توجد صفحة تالية |
| `canLoadMore` | `bool` | هل يمكن التحميل |
| `isEmpty` | `bool` | هل القائمة فارغة |
| `isNotEmpty` | `bool` | هل القائمة تحتوي بيانات |
| `length` | `int` | عدد العناصر المحملة |
| `nextOffset` | `int?` | الـ offset التالي |

> `nextOffset` يُعيد `null` في ثلاث حالات: لا صفحة تالية (`hasNext == false`)،
> أو `next` بلا معامل `offset`، أو تعذّر تحليل الرابط. فلا تكتب
> `orders.nextOffset!` — آخر صفحة تُسقط التطبيق.

---

## Network

### ConnectionStatus

```dart
// في الـ Repository
final ConnectionStatus _connectionStatus;

Future<Either<Failure, Data>> fetchData() async {
  if (await _connectionStatus.isNotConnected) {
    return Left(ErrorType.noInternetConnection.toFailure());
  }
  // ...
}

// مراقبة الحالة لحظة بلحظة
_connectionStatus.connectionStream.listen((state) {
  if (state == InternetConnectionState.disconnected) {
    showToast('لا يوجد اتصال بالإنترنت');
  }
});
```

### handleResponse و handleJsonResponse

معالجا الاستجابة: كلاهما يفحص كود الحالة، ويرفض صفحات HTML، ويحوّل الجسم
الفارغ إلى `{}`، ويرمي `DioException` يقرؤها `ErrorHandler`. الفرق في
المُخرَج وحده.

```dart
// نقطة نهاية عقدُها كائن JSON — استخدم الصارمة
final Response response = await _apiConsumer.get(EndPoints.order);
return OrderModel.fromJson(handleJsonResponse(response)); // Map<String, dynamic>

// جسمٌ نصّيٌّ مقصود (تقرير، رسالة، CSV، رمز تحقّق) — استخدم العامّة
final String code = handleResponse(await _apiConsumer.post(EndPoints.otp));

// قائمة JSON في الجذر (بلا غلاف pagination) — العامّة كذلك
final List<dynamic> raw = handleResponse(response);
return raw.map((e) => TagModel.fromJson(e)).toList();
```

| | `handleJsonResponse` | `handleResponse` |
|---|---|---|
| المُخرَج | `Map<String, dynamic>` | `dynamic` — خريطة أو قائمة أو نصّ خام |
| جسمٌ ليس كائن JSON | `DioException` بمسار الطلب ومقتطفٍ من الجسم | يُعاد خاماً كما وصل |
| 204 والجسم الفارغ | `{}` | `{}` — و204 رسالة حذفٍ عربية للعرض |
| متى | كلّ `Model.fromJson` | النصّ الخام، أو قائمة في الجذر |

> `handleResponse` يُعيد النصّ الخام حين يفشل فكّ JSON — وهذا عقدٌ مقصود
> تعتمد عليه نقاط النهاية النصّية. لكنّه حين يُمرَّر إلى `Model.fromJson`
> ينفجر بـ`TypeError: String is not a subtype of Map` داخل النموذج، بلا
> ذكرٍ للمسار ولا لما ردّه الخادم. `handleJsonResponse` يوقف ذلك عند حدّ
> الشبكة برسالةٍ تدلّ على السبب.

### ErrorHandler

```dart
// في الـ Repository — معالجة تلقائية لكل أنواع الأخطاء
try {
  final response = await _remoteDataSource.fetchData();
  return Right(response);
} on Exception catch (error) {
  return Left(ErrorHandler.handle(error).failure);
}
```

### Failure

```dart
// يحتوي على رسالة الخطأ الجاهزة للعرض
result.fold(
  (failure) => emit(FailureState(failure)),
  (data) => emit(SuccessState(data)),
);

// في الـ UI
ErrorMessageWidget(text: state.failure.displayMessage)

// أخطاء على مستوى الـ fields
for (final error in failure.fields) {
  print('${error.field}: ${error.message}');
}
```

### ErrorType

```dart
ErrorType.noInternetConnection.toFailure()
ErrorType.unauthorized.toFailure()
ErrorType.notFound.toFailure()
ErrorType.internalServerError.toFailure()
```

---

## Extensions

### DateFormatExtension على DateTime

```dart
final date = DateTime.now();

date.toWhatsAppStyle      // "اليوم" | "أمس" | "الاثنين" | "٢٠٢٦/٠٣/١٢"
date.toChatMessageTime    // "٩:٣٠ م"
date.toChatHeaderDate     // "١٢ مارس ٢٠٢٦"
date.toFullDateTime       // "مارس ١٢، ٢٠٢٦، ٩:٣٠ م"
date.toShortDateTime      // "٩:٣٠" اليوم | "٩:٣٠ ٠٣/١٢" هذه السنة | "٩:٣٠ ٢٠٢٥/٠٣/١٢"
date.toDateString         // "2026-03-12"
date.toDayMonth           // "١٢ مارس"
date.toTimeAgo            // مضغوط: "الآن" | "45 ث" | "12 د" | "3 س و 20 د" | "5 ي و 2 س"
date.toTimeAgoArabic      // كامل: "منذ دقيقتين" | "منذ ساعة" | "منذ ٣ أيام"
date.toAge                // 25
```

> `toTimeAgo` و`toTimeAgoArabic` ليستا مترادفتين: الأولى صيغة مضغوطة بلا كلمة
> «منذ» تصلح لطابع زمنيّ بجانب رسالة، والثانية الصيغة العربية الكاملة. إن طلب
> التصميم «منذ دقيقتين» فالمطلوب `toTimeAgoArabic`.

### DateStringExtension على String

```dart
'25'.ageToBirthDate       // تاريخ ميلادٍ يوافق 25 سنة اليوم، بصيغة "yyyy-MM-dd"
                          // ويُعيد النصّ كما هو إن لم يكن رقماً
```

### CurrencyExtension على double/int

```dart
1234567.89.toCurrency           // "1,234,567.89"
1234567.89.toCurrencyNoDecimals // "1,234,568"
1234567.toCurrency              // "1,234,567"
```

### StringExtension على String

```dart
'test@email.com'.isValidEmail   // true
'12345'.isAllDigits             // true
'12.34'.isValidDecimal          // true
'hello world'.capitalized       // "Hello world"
'[item]'.withoutBrackets        // "item"
```

---

## Formatters

### NumbersOnlyFormatter

```dart
// أرقام فقط — يحوّل الأرقام العربية ٠-٩ تلقائياً
TextField(
  inputFormatters: [NumbersOnlyFormatter()],
)

// مع السماح بالأرقام العشرية
TextField(
  inputFormatters: [NumbersOnlyFormatter(allowDecimal: true)],
)
```

### CardNumberFormatter

```dart
// 4111111111111111 → "4111  1111  1111  1111"
TextField(
  inputFormatters: [CardNumberFormatter()],
  maxLength: 22,
)
```

### CardExpiryFormatter

```dart
// 1226 → "12/26"  |  3 → "03/"  (تكمّل تلقائياً)
TextField(
  inputFormatters: [CardExpiryFormatter()],
  maxLength: 5,
)
```

### PhoneNumberFormatter

```dart
// يزيل 0 الأول، يحوّل 00 إلى +، يكشف الدولة تلقائياً
TextField(
  inputFormatters: [
    PhoneNumberFormatter(
      onCountryChanged: (country) {
        setState(() => _selectedCountry = country);
      },
    ),
  ],
)
```

### NoEnglishLettersFormatter

```dart
// يمنع كتابة الحروف الإنجليزية
TextField(
  inputFormatters: [NoEnglishLettersFormatter.formatter],
)
```

### UpperCaseEnglishFormatter

```dart
// يقبل حروف إنجليزية وأرقام فقط — ويحوّلها لـ uppercase
TextField(
  inputFormatters: [UpperCaseEnglishFormatter()],
)
```

### IbanFormatter و IbanUtils

```dart
// حقل الإدخال — أحرف كبيرة، مسافة كل 4 محارف، وحدٌّ أقصى بحسب رمز الدولة
TextFormField(
  inputFormatters: [IbanFormatter()],
)

// التحقق والتنسيق
IbanUtils.isValid('SA44 2000 0001 2345 6789 1234'); // الطول + MOD 97
IbanUtils.format('SA4420000001234567891234');        // "SA44 2000 0001 ..."
IbanUtils.strip('SA44 2000 0001 ...');               // للإرسال للـ API
IbanUtils.isSupportedCountry('SA');                  // true
IbanUtils.expectedLength('SA');                      // 24 — null إن لم تُدعم
```

> ❌ لا تكتب تحقّق IBAN مخصّصاً. الجدول هنا يغطّي أطوال ISO 13616 لـ 93 دولة
> مع `MOD 97` وفق ISO 7064 — وأي نسخة يدوية ستتخلّف عنه.

---

## Pickers

### ImagePickerManager

```dart
// اختيار صورة من المعرض
final File? image = await ImagePickerManager.pickImage(
  ImagePickerSource.gallery,
);

// اختيار من الكاميرا مع اقتصاص دائري
final File? image = await ImagePickerManager.pickImage(
  ImagePickerSource.camera,
  useCrop: true,
  imageQuality: 80,
);

// اختيار صور متعددة
final List<XFile>? images = await ImagePickerManager.pickMultipleImages();

// اقتصاص صورة موجودة
final XFile? cropped = await ImagePickerManager.cropImage(imagePath);
```

### FilePickerManager

```dart
// أي ملف
final File? file = await FilePickerManager.pickFile();

// ملف صوتي (mp3, wav, m4a, aac, amr, opus, wma, 3gp, ogg)
final File? audio = await FilePickerManager.pickAudio();

// ملف فيديو (mp4, mkv, avi, mov, wmv)
final File? video = await FilePickerManager.pickVideo();

// ملف SVG
final File? svg = await FilePickerManager.pickSvg();
```

---

## DeviceInfoManager

```dart
// في main.dart — تهيئة عند بدء التطبيق
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DeviceInfoManager.instance.initialize();
  runApp(const MyApp());
}

// الوصول للمعلومات
final info = DeviceInfoManager.instance.info;

info.app.name           // "Wisalapp"
info.app.version        // "1.1.2"
info.app.fullVersion    // "1.1.2+45"
info.device.model       // "iPhone 15 Pro"
info.device.brand       // "Apple"
info.device.type        // "phone"
info.system.osName      // "iOS"
info.system.locale      // "ar"
info.screen.width       // 393.0
info.persistentId       // "A1B2C3..." (يبقى ثابتاً حتى بعد إعادة التثبيت)

// إرساله في الـ headers
final headers = info.toFlatMap();
// → persistent_id
//   app_version, app_build, app_full_version, app_package
//   device_id, device_brand, device_model, device_name, device_type,
//   device_is_physical
//   os_name, os_version, platform, locale, timezone
//   screen_width, screen_height, screen_pixel_ratio
```

> `app_name` مستثنى عمداً من الخريطة المسطّحة: اسم التطبيق قد يحمل مسافات أو
> أحرفاً خاصّة لا تصلح في ترويسة HTTP. من احتاجه فليقرأه من `info.app.name`
> أو من `info.toJson()`.

### أسماء النماذج

`info` من نوع `SharedDeviceInfo`، وحقوله من `SharedAppInfo` و`SharedDeviceDetails`
و`SharedSystemInfo` و`SharedScreenInfo`. البادئة `Shared` مقصودة: هذه الأصناف
تُصدَّر بلا نطاق، والأسماء العامّة (`DeviceInfoModel`, `AppInfo`, `DeviceDetails`,
`SystemInfo`, `ScreenInfo`) كانت تصطدم بأصناف المشاريع فتُحجب بلا خطأ ترجمة.

---

## IntlPhoneUtils

قاعدة بيانات كاملة لـ **248+ دولة** مع دعم **21 لغة**.

```dart
// كشف الدولة من رقم الهاتف
final country = IntlPhoneUtils.getCountryByCompletePhoneNumber('+966501234567');
print(country?.name);     // "Saudi Arabia"
print(country?.flag);     // "🇸🇦"
print(country?.dialCode); // "966"

// التحقق من رقم سعودي
IntlPhoneUtils.isSA('+966501234567'); // true

// الحصول على الدولة بالكود
final sa = IntlPhoneUtils.getCountryByCode('SA');

// استخراج معلومات من رقم كامل
IntlPhoneUtils.getCountryFlag('+441234567890');     // 🇬🇧
IntlPhoneUtils.getCountryDialCode('+33123456789');  // '33'
IntlPhoneUtils.getCountryCode('+12025551234');      // 'US'

// إزالة كود الدولة من الرقم
IntlPhoneUtils.getPhoneNumberByCountryDialCode('+966501234567'); // '501234567'
```

---

## Services

### FileCacheManager

```dart
// تهيئة مرة واحدة في main.dart مع الـ DI
FileCacheManager.init(
  download: (url) => dio.get(url, options: Options(responseType: ResponseType.bytes)),
  containsKey: (key) => storage.containsKey(key),
  getFile: (key) => storage.get(key),
  saveFile: (key, value) => storage.save(key, value),
  deleteKey: (key) => storage.delete(key),
);

// استخدام — يحمّل ويخزن تلقائياً (أعضاء نسخة: عبر .instance)
final File file = await FileCacheManager.instance.saveAndGetFile(url);

// دليل فرعيّ آخر داخل مجلّد المستندات (الافتراضي 'audio_cache')
final File doc = await FileCacheManager.instance.saveAndGetFile(
  url,
  fileCache: 'documents_cache',
);

// حذف من الـ cache
FileCacheManager.instance.deleteFileCache(url);

// أعضاء ساكنة — لا تمرّ بـ .instance
FileCacheManager.getFileType('a/b/file.pdf');    // 'pdf'
FileCacheManager.getFileMimeType('file.pdf');    // 'application/pdf'
```

> `saveAndGetFile` **ترمي ولا تُعيد `null`** — فلا معنى لـ `String?` ولا لفحص
> العدم. والتقط `FileNoLongerAvailableException` على حدة: مُخزّن الوسائط يردّ
> 403 أو 404 على محتوىً ذهب، وهو لا يُصلَح بإعادة المحاولة ولا يستحقّ الذهاب
> إلى تتبّع الأخطاء — اعرض «لم يعد متاحاً» بدل خطأٍ عامّ.

```dart
try {
  final File file = await FileCacheManager.instance.saveAndGetFile(url);
  // ...
} on FileNoLongerAvailableException catch (_) {
  showToast('الملف لم يعد متاحاً');
} on Exception catch (e) {
  showToast(ErrorHandler.handle(e).failure.displayMessage);
}
```

### AppUpdateChecker

```dart
// في شاشة الـ Splash
await AppUpdateChecker.instance.checkForUpdate(
  appStoreId: '123456789', // App Store ID للـ iOS
  // isMandatory: true عند تغيّر major/minor، false عند patch.
  // info: تفاصيل الإصدار من المتجر — null إن تعذّر جلبها، فلا تفترض وجودها.
  onUpdateAvailable: (bool isMandatory, [AppReleaseInfo? info]) {
    showUpdateDialog(
      context,
      isMandatory: isMandatory,
      notes: info?.noteLines ?? const <String>[], // «ما الجديد» جاهزة كنقاط
    );
  },
  onError: (error) {
    debugPrint('Update check failed: $error');
  },
);

// جلب تفاصيل الإصدار وحدها — بلا مقارنة ولا شرط تحديث
final AppReleaseInfo? release =
    await AppUpdateChecker.instance.fetchReleaseInfo('123456789');

// تنفيذ التحديث الفوري (Android فقط)
await AppUpdateChecker.instance.performImmediateUpdate();
```

> ملاحظات الإصدار تُقرأ من iTunes Lookup وتُعرض على المنصّتين: Play لا يوفّر
> واجهة عامّة لها. ويفشل جلبها بصمت فلا يعطّل تدفّق التحديث.

---

## Widgets

### SkeletonizerWidget

Widget يعرض تأثير shimmer أثناء التحميل، يلتف حول أي widget ويحوّله إلى skeleton.

```dart
SkeletonizerWidget(
  isLoading: isLoading,
  shimmerBaseColor: AppColors.of(context).muted,
  // containersColor لا أثر له إلا مع ignoreContainers: true
  ignoreContainers: true,
  containersColor: AppColors.of(context).background,
  child: YourWidget(),
)
```

**مثال كامل مع BLoC:**

```dart
BlocBuilder<MyBloc, MyState>(
  builder: (context, state) {
    final bool isLoading = state is MyLoadingState;

    final List<MyModel> items = isLoading
        ? List.generate(6, (_) => MyModel.empty())
        : bloc.items;

    return SkeletonizerWidget(
      isLoading: isLoading,
      shimmerBaseColor: AppColors.of(context).muted,
      containersColor: AppColors.of(context).background,
      child: Column(
        children: items.map((item) => MyItemWidget(item: item)).toList(),
      ),
    );
  },
)
```

**Parameters:**

| Parameter | النوع | الافتراضي | الوصف |
|-----------|-------|-----------|-------|
| `isLoading` | `bool` | مطلوب | تفعيل/إيقاف تأثير الـ skeleton |
| `child` | `Widget` | مطلوب | الـ widget المراد تحويله لـ skeleton |
| `ignoreContainers` | `bool` | `false` | إظهار الـ containers بلونها بدلاً من shimmer |
| `shimmerBaseColor` | `Color?` | `colorScheme.surfaceTint` | لون الـ shimmer |
| `containersColor` | `Color?` | `colorScheme.surface` | لون خلفية الـ containers |

---

### PaginatedListView

قائمة جاهزة تدير الـ pagination تلقائياً، تعرض skeleton أثناء التحميل الأولي ومؤشر تحميل في الأسفل عند Load More.

```dart
BlocBuilder<MyBloc, MyState>(
  buildWhen: (previous, current) =>
      current is MyLoadingState ||
      current is MySuccessState ||
      current is MyFailureState ||
      current is MyLoadMoreLoadingState ||
      current is MyLoadMoreSuccessState,
  builder: (context, state) {
    final bool isLoading  = state is MyLoadingState;
    final bool isLoadMore = state is MyLoadMoreLoadingState;

    final List<MyModel> items = isLoading
        ? List.generate(10, (_) => MyModel.empty())
        : bloc.items.results;

    return PaginatedListView<MyModel>(
      items: items,
      isLoading: isLoading,
      isLoadMore: isLoadMore,
      canLoadMore: bloc.items.next.isNotEmpty,
      onLoadMore: () => bloc.add(const MyLoadMoreEvent()),
      shimmerBaseColor: AppColors.of(context).muted,
      shimmerContainersColor: AppColors.of(context).background,
      loadMoreIndicatorColor: AppColors.of(context).primary,
      loadMoreBackgroundColor: AppColors.of(context).secondary,
      itemBuilder: (context, item) => MyItemWidget(item: item),
    );
  },
)
```

**Parameters:**

| Parameter | النوع | الافتراضي | الوصف |
|-----------|-------|-----------|-------|
| `items` | `List<T>` | مطلوب | قائمة العناصر |
| `isLoading` | `bool` | مطلوب | التحميل الأولي — يُظهر الـ skeleton |
| `isLoadMore` | `bool` | مطلوب | تحميل صفحة إضافية |
| `canLoadMore` | `bool` | مطلوب | هل توجد صفحات إضافية |
| `onLoadMore` | `VoidCallback` | مطلوب | يُستدعى عند نهاية القائمة |
| `itemBuilder` | `Widget Function(BuildContext, T)` | مطلوب | بناء كل عنصر |
| `onRefresh` | `Future<void> Function()?` | `null` | يُفعّل الـ RefreshIndicator |
| `padding` | `EdgeInsets?` | `symmetric(h:20, v:32)` | padding القائمة |
| `scrollController` | `ScrollController?` | داخلي | controller خارجي عند الحاجة |

---

### showToast

```dart
showToast('تم الحفظ بنجاح');
showToast('حدث خطأ', backgroundColor: AppColors.error);
showToast('رسالة طويلة', isLong: true);
```

### PageIndicator

```dart
PageIndicator(
  controller: _pageController,
  count: 3,
  dotColor: Colors.grey,
  activeDotColor: Colors.blue,
  spacing: 8.0,
  dotSize: 8.0,
  expandedSize: 24.0,
  fillPreviousDots: true,
)
```

### ResponsiveGridView

```dart
ResponsiveGridView(
  config: GridConfig(
    itemWidth: 150.0,
    itemHeight: 200.0,
    crossAxisSpacing: 12.0,
    mainAxisSpacing: 12.0,
    minCrossAxisCount: 2,
    maxCrossAxisCount: 4,
  ),
  itemCount: items.length,
  itemBuilder: (context, index) => ItemWidget(item: items[index]),
)
```

### DelayHandler — Debounce

```dart
final _searchDelay = DelayHandler(defaultDelayMs: 500);

onChanged: (query) {
  _searchDelay.run(() => bloc.add(SearchEvent(query)));
}
```

---

## Utils

### launchWhatsApp

```dart
await launchWhatsApp(
  phoneNumber: '+966500000000',
  deviceInfo: DeviceInfoManager.instance,
  userId: '12345',
  message: 'مرحباً، أحتاج مساعدة',
);
```

> يجب أن يكون `DeviceInfoManager.instance.initialize()` قد نُفّذ في `main` قبل
> هذا النداء: الدالّة تقرأ المعلومات عبر `infoOrNull` فلا ترمي إن غابت، لكن
> نصّ الدعم الفنّي يخرج حينها بـ `null` في النظام ونسخة التطبيق — وهي الحقول
> التي كُتبت الرسالة لأجلها.

### Helpers

```dart
dismissKeyboard(context);
getFirstName('محمد عبدالله الغامدي'); // "محمد"
convertArabicNumbers('١٢٣٤'); // "1234"
```

---

## الإصدار الحالي

الإصدار المعتمد هو ما في [`pubspec.yaml`](pubspec.yaml)، وسجلّ التغييرات في
[`CHANGELOG.md`](CHANGELOG.md) — لا رقمٌ مكتوب هنا يدوياً يتخلّف عند كل نشر.

متطلّبات البيئة: Dart SDK ‎^3.9.2‎ و Flutter ‎>=1.17.0‎.
