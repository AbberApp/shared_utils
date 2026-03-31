# shared_utils

مكتبة أدوات مشتركة لمشاريع Flutter. تحتوي على الـ utilities والـ helpers المستخدمة في جميع المشاريع لتجنب تكرار الكود.

## التثبيت

```yaml
dependencies:
  shared_utils:
    git:
      url: https://github.com/AbberApp/shared_utils.git
      ref: main
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
    required super.previous,
    required super.results,
  });

  factory BaseOrderModel.fromJson(Map<String, dynamic> json) =>
      _$BaseOrderModelFromJson(json);

  factory BaseOrderModel.empty() =>
      BaseOrderModel(count: 0, next: '', previous: '', results: []);
}

// استخدام في الـ Bloc
BaseOrderModel orders = BaseOrderModel.empty();

// إضافة بيانات جديدة عند load more
orders.addAll(newData);

// التحقق من إمكانية التحميل
if (orders.canLoadMore) {
  // fetch next page
}

// دمج بدون تكرار
orders.merge(newData, key: (order) => order.id);
```

**Properties:**
| Property | النوع | الوصف |
|----------|-------|-------|
| `count` | `int` | إجمالي العناصر |
| `next` | `String` | رابط الصفحة التالية |
| `results` | `List<T>` | العناصر المحملة |
| `hasNext` | `bool` | هل توجد صفحة تالية |
| `canLoadMore` | `bool` | هل يمكن التحميل |
| `isEmpty` | `bool` | هل القائمة فارغة |
| `nextOffset` | `int` | الـ offset التالي |

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

date.toWhatsAppStyle      // "اليوم" | "أمس" | "الاثنين" | "١٢ مارس ٢٠٢٦"
date.toChatMessageTime    // "٩:٣٠ م"
date.toChatHeaderDate     // "١٢ مارس ٢٠٢٦"
date.toFullDateTime       // "مارس ١٢، ٢٠٢٦، ٩:٣٠ م"
date.toDateString         // "2026-03-12"
date.toDayMonth           // "١٢ مارس"
date.toTimeAgo            // "منذ دقيقتين" | "منذ ساعة واحدة" | "منذ ٣ أيام"
date.toAge                // 25
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
// → {app_name: ..., app_version: ..., device_model: ..., os_name: ...}
```

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

// استخدام — يحمّل ويخزن تلقائياً
final String? filePath = await FileCacheManager.instance.saveAndGetFile(url);

// حذف من الـ cache
FileCacheManager.deleteFileCache(url);

// نوع الـ MIME
FileCacheManager.getFileMimeType('file.pdf'); // 'application/pdf'
```

### AppUpdateChecker

```dart
// في شاشة الـ Splash
await AppUpdateChecker.instance.checkForUpdate(
  appStoreId: '123456789', // App Store ID للـ iOS
  onUpdateAvailable: () {
    showUpdateDialog(context);
  },
  onError: (error) {
    debugPrint('Update check failed: $error');
  },
);

// تنفيذ التحديث الفوري (Android فقط)
await AppUpdateChecker.instance.performImmediateUpdate();
```

---

## Widgets

> تُستورد من `package:shared_utils/widgets.dart` (ملف barrel منفصل لتجنب تعارض الأسماء).
>
> ```dart
> import 'package:shared_utils/widgets.dart';
> ```

---

### SkeletonizerWidget

Widget يعرض تأثير shimmer أثناء التحميل، يلتف حول أي widget ويحوّله إلى skeleton.

```dart
SkeletonizerWidget(
  isLoading: isLoading,
  shimmerBaseColor: AppColors.of(context).muted,       // لون shimmer
  containersColor: AppColors.of(context).background,    // لون خلفية الـ containers
  child: YourWidget(),
)
```

**مع `ignoreContainers`** — يُظهر الـ containers بلونها الأصلي بدلاً من shimmer:

```dart
SkeletonizerWidget(
  isLoading: isLoading,
  ignoreContainers: true,
  shimmerBaseColor: AppColors.of(context).muted,
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
| `containersColor` | `Color?` | `colorScheme.surface` | لون خلفية الـ containers عند `ignoreContainers: true` |

---

### PaginatedListView

قائمة جاهزة تدير الـ pagination تلقائياً، تعرض skeleton أثناء التحميل الأولي ومؤشر تحميل في الأسفل عند Load More.

**الاستيراد:**

```dart
import 'package:shared_utils/widgets.dart';
```

**الاستخدام الأساسي:**

```dart
BlocBuilder<MyBloc, MyState>(
  buildWhen: (previous, current) =>
      current is MyLoadingState ||
      current is MySuccessState ||
      current is MyFailureState ||
      current is MyLoadMoreLoadingState ||   // مهم: لتحديث isLoadMore
      current is MyLoadMoreSuccessState,
  builder: (context, state) {
    final bool isLoading  = state is MyLoadingState;
    final bool isLoadMore = state is MyLoadMoreLoadingState;

    // عناصر skeleton أثناء التحميل الأولي
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

**مع Pull-to-Refresh:**

```dart
PaginatedListView<MyModel>(
  items: items,
  isLoading: isLoading,
  isLoadMore: isLoadMore,
  canLoadMore: bloc.items.next.isNotEmpty,
  onLoadMore: () => bloc.add(const MyLoadMoreEvent()),
  onRefresh: () async {
    bloc.add(const MyFetchEvent());
    await Future.delayed(const Duration(seconds: 1));
  },
  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 32.0),
  shimmerBaseColor: AppColors.of(context).muted,
  shimmerContainersColor: AppColors.of(context).background,
  loadMoreIndicatorColor: AppColors.of(context).primary,
  loadMoreBackgroundColor: AppColors.of(context).secondary,
  itemBuilder: (context, item) => MyItemWidget(item: item),
)
```

**مع ScrollController خارجي** (عند الحاجة للتحكم بالـ scroll من الخارج):

```dart
PaginatedListView<MyModel>(
  scrollController: _myScrollController,
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
)
```

**Parameters:**

| Parameter | النوع | الافتراضي | الوصف |
|-----------|-------|-----------|-------|
| `items` | `List<T>` | مطلوب | قائمة العناصر (تمرير عناصر `.empty()` عند `isLoading`) |
| `isLoading` | `bool` | مطلوب | التحميل الأولي — يُظهر الـ skeleton |
| `isLoadMore` | `bool` | مطلوب | تحميل صفحة إضافية — يُظهر مؤشر في الأسفل |
| `canLoadMore` | `bool` | مطلوب | هل توجد صفحات إضافية (`base.next.isNotEmpty`) |
| `onLoadMore` | `VoidCallback` | مطلوب | يُستدعى عند الوصول لنهاية القائمة |
| `itemBuilder` | `Widget Function(BuildContext, T)` | مطلوب | بناء كل عنصر |
| `onRefresh` | `Future<void> Function()?` | `null` | يُفعّل الـ RefreshIndicator عند تمريره |
| `padding` | `EdgeInsets?` | `symmetric(h:20, v:32)` | padding القائمة |
| `scrollController` | `ScrollController?` | داخلي | تمرير controller خارجي عند الحاجة |
| `shimmerBaseColor` | `Color?` | `colorScheme.surfaceTint` | لون shimmer الـ skeleton |
| `shimmerContainersColor` | `Color?` | `colorScheme.surface` | لون خلفية containers الـ skeleton |
| `loadMoreIndicatorColor` | `Color?` | `colorScheme.primary` | لون مؤشر تحميل المزيد |
| `loadMoreBackgroundColor` | `Color?` | `colorScheme.secondary` | لون خلفية مؤشر تحميل المزيد |

> **ملاحظة:** `PaginatedListView` يدير الـ `ScrollController` داخلياً ويستدعي `onLoadMore` تلقائياً عند الاقتراب من نهاية القائمة بـ 200px. لا حاجة لـ `ScrollController` أو `_scrollListener` في الـ widget الأب.

---

### showToast

```dart
// رسالة بسيطة
showToast('تم الحفظ بنجاح');

// مع لون خلفية
showToast('حدث خطأ', backgroundColor: AppColors.error);
showToast('تم التطبيق', backgroundColor: AppColors.success);

// طويلة
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
  expandedSize: 24.0,       // عرض النقطة النشطة
  fillPreviousDots: true,   // تلوين النقاط السابقة
  onDotClicked: () => _pageController.animateToPage(index, ...),
)
```

### ResponsiveGridView

```dart
// يحسب عدد الأعمدة تلقائياً حسب عرض الشاشة
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
// في الـ State
final _searchDelay = DelayHandler(defaultDelayMs: 500);

// في onChanged
onChanged: (query) {
  _searchDelay.run(() => bloc.add(SearchEvent(query)));
}

// في dispose
@override
void dispose() {
  _searchDelay.dispose();
  super.dispose();
}
```

---

## Utils

### launchWhatsApp

```dart
// يفتح واتساب مع رسالة تحتوي معلومات الجهاز تلقائياً
await launchWhatsApp(
  phoneNumber: '+966500000000',
  userId: '12345',
  message: 'مرحباً، أحتاج مساعدة',
);
```

### Helpers

```dart
// إخفاء لوحة المفاتيح
dismissKeyboard(context);

// استخراج الاسم الأول
getFirstName('محمد عبدالله الغامدي'); // "محمد"

// تحويل الأرقام العربية إلى إنجليزية
convertArabicNumbers('١٢٣٤'); // "1234"
```

---

## الإصدار الحالي

**v2.2.4** — متوافق مع Dart SDK ^3.9.2 و Flutter >=1.17.0
