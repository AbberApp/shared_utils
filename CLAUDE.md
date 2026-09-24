# CLAUDE.md - shared_utils

مكتبة مشتركة بين جميع مشاريع المجموعة (azbah, azbahadmin, abber_admin, azbah_admin).
**أولوية قصوى** — تحقق منها قبل كتابة أي أداة أو widget أو service.

---

## ما توفره المكتبة — الدليل الكامل

### Network

```dart
import 'package:shared_utils/shared_utils.dart';

// ApiConsumer — مستهلك API (Dio wrapper)
final ApiConsumer _apiConsumer; // حقله في DataSource
final Response response = await _apiConsumer.get(url, queryParameters: filters);
final Response response = await _apiConsumer.post(url, body: data);
final Response response = await _apiConsumer.patch(url, body: data);
final Response response = await _apiConsumer.delete(url);

// handleJsonResponse — كائن JSON مضمون (استخدمه مع fromJson)
return Model.fromJson(handleJsonResponse(response));

// handleResponse — الجسم كما وصل: نصّ أو قائمة أو خريطة
final String report = handleResponse(response); // تقرير، رسالة، CSV، رمز تحقّق
final List<dynamic> items = handleResponse(response); // قائمة JSON في الجذر
// ❌ ممنوع: Model.fromJson(handleResponse(r)) — نصّ الخادم يصل fromJson
//    فينفجر بـ«String is not a subtype of Map» بلا دلالة على السبب

// ConnectionStatus — فحص الاتصال
final ConnectionStatus _connectionStatus;
if (await _connectionStatus.isNotConnected) {
  return Left(ErrorType.noInternetConnection.toFailure());
}

// ErrorHandler — معالج الأخطاء
on Exception catch (e) {
  return Left(ErrorHandler.handle(e).failure);
}

// Failure — نموذج الخطأ
state.failure.message        // رسالة الخطأ
state.failure.displayMessage // رسالة قابلة للعرض
state.failure.fields         // أخطاء الحقول (validation)
```

### Data

```dart
// BaseEntity<T> — أساس كل نموذج مُرقَّم
abstract class BaseFeatureModel extends BaseEntity<FeatureModel> { ... }

// Getters المتاحة على BaseEntity
base.count       // إجمالي العناصر
base.next        // رابط الصفحة التالية
base.results     // قائمة العناصر
base.hasNext     // هل يوجد صفحة تالية
base.canLoadMore // هل يمكن تحميل المزيد
base.isEmpty     // هل القائمة فارغة
base.isNotEmpty  // هل القائمة تحتوي بيانات
base.length      // عدد العناصر
base.nextOffset  // offset الصفحة التالية

// Methods
base.addAll(newData)               // إضافة البيانات مع تحديث pagination
base.merge(newData, (i) => i.id)  // دمج مع تجنب التكرار
```

### Widgets

```dart
// SkeletonizerWidget — تأثير Skeleton أثناء التحميل
SkeletonizerWidget(
  isLoading: isLoading,
  shimmerBaseColor: AppColors.of(context).muted,
  // containersColor لا أثر له إلا مع ignoreContainers: true
  ignoreContainers: true,
  containersColor: AppColors.of(context).background,
  child: YourWidget(),
)
// ❌ ممنوع: CircularProgressIndicator

// LoadMoreWidget — في نهاية كل قائمة مُرقَّمة
ListView.separated(
  itemCount: items.length + 1,
  itemBuilder: (_, index) {
    if (index == items.length) {
      return LoadMoreWidget(isLoadMore: state is LoadMoreLoadingState);
    }
    return ItemWidget(item: items[index]);
  },
)

// LoadMoreWidget.onScroll — ربط مع ScrollController
ScrollController()..addListener(() {
  LoadMoreWidget.onScroll(
    controller: _scrollController,
    base: _bloc.items,
    // إلزاميّ في التوقيع الحالي لكنّه لا يُقرأ: القرار مبنيّ على base وموضع
    // التمرير وحدهما. لا تتوقّع أن تُراعى فلاترُك هنا — رشّحها في الـ Bloc.
    filters: _bloc.filters,
    isLoadMore: _bloc.state is LoadMoreLoadingState,
    onLoadMore: () => _bloc.add(const LoadMoreEvent()),
  );
});

// PaginatedListView — قائمة جاهزة تدير كل شيء تلقائياً
// استخدمها عندما: itemBuilder بسيط، لا separatorBuilder مخصص، لا ScrollController خاص
PaginatedListView<FeatureModel>(
  items: _bloc.items.results,
  isLoading: state is FetchLoadingState,
  isLoadMore: state is LoadMoreLoadingState,
  canLoadMore: _bloc.items.canLoadMore,
  onLoadMore: () => _bloc.add(const LoadMoreEvent()),
  onRefresh: () async => _bloc.add(const FetchEvent()),
  shimmerBaseColor: AppColors.of(context).muted,
  shimmerContainersColor: AppColors.of(context).background,
  itemBuilder: (context, item) => FeatureCard(item: item),
)

// LoadMoreWidget + SkeletonizerWidget — عندما تحتاج تحكم كامل:
// separatorBuilder مخصص، ScrollController خاص، buildWhen/listenWhen معقد
SkeletonizerWidget(
  isLoading: isLoading,
  shimmerBaseColor: AppColors.of(context).muted,
  // containersColor لا أثر له إلا مع ignoreContainers: true
  ignoreContainers: true,
  containersColor: AppColors.of(context).background,
  child: RefreshIndicator(
    onRefresh: () async => _bloc.add(const FetchEvent()),
    child: ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppDecorationStyles.padding),
      itemCount: items.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == items.length) {
          return LoadMoreWidget(isLoadMore: state is LoadMoreLoadingState);
        }
        return FeatureCard(item: items[index]);
      },
    ),
  ),
)

// showToast — إشعارات للمستخدم
showToast('تم الحفظ بنجاح');
showToast('حدث خطأ', backgroundColor: AppColors.error);
// ❌ ممنوع: ScaffoldMessenger.showSnackBar()
```

### Extensions

```dart
// String Extensions
'user@email.com'.isValidEmail   // bool
'12345'.isAllDigits             // bool
'3.14'.isValidDecimal           // bool
'hello'.capitalized             // 'Hello'
'[a,b]'.withoutBrackets         // 'a,b'

// DateTime Extensions
DateTime.now().toDateString       // 'yyyy-MM-dd'
DateTime.now().toFullDateTime     // 'MMMM d, yyyy, h:mm a' بالعربي
DateTime.now().toDayMonth         // 'd MMMM' بالعربي
DateTime.now().toChatHeaderDate   // 'd MMMM yyyy' بالعربي

// double/int Extensions
12345.67.toCurrency           // '12,345.67'
12345.67.toCurrencyNoDecimals // '12,345'
12345.toCurrency              // '12,345'
```

### Formatters

```dart
// IbanFormatter — للـ TextFormField
CustomTextFormField(
  inputFormatters: [IbanFormatter()],
)

// IbanUtils — التحقق وتنسيق IBAN
IbanUtils.isValid('SA44 2000 0001 2345 6789 1234') // bool
IbanUtils.format('SA44200000012345...')             // مع مسافات
IbanUtils.strip('SA44 2000...')                     // بدون مسافات
// ❌ ممنوع: IBAN validation مخصص

// NumberFormatter, CardFormatter, TextFormatter, PhoneFormatter
// استخدمها بدل أي formatter مخصص
```

### Pickers

```dart
// ImagePickerManager — اختيار صور
final File? image = await ImagePickerManager.pickImage(
  ImagePickerSource.gallery,
  useCrop: true,
  imageQuality: 35,
);
// ❌ ممنوع: image_picker مباشرة

// FilePickerManager — اختيار ملفات
final File? file = await FilePickerManager.pickFile();
```

### Realtime

```dart
// SocketManager — WebSocket
SocketManager(
  url,
  headersBuilder: () => {'Authorization': 'Token ${token}'},
)
// ❌ ممنوع: WebSocket مخصص

// SseManager — Server-Sent Events
SseManager(
  url,
  headersBuilder: () => {'Authorization': 'Token ${token}'},
  queryParametersBuilder: () => {'last_event_id': lastId},
  // يُستدعى عند 401 — أعِد true إن نجح تجديد التوكن فيُعاد الاتصال تلقائياً،
  // أو false فيقطع SseManager بدل حلقة إعادة اتصالٍ مرفوضة.
  onUnauthorized: () async => await refreshToken(),
)
// ❌ ممنوع: SSE implementation مخصص
```

### Utils

```dart
// dismissKeyboard
dismissKeyboard(context);
// ❌ ممنوع: FocusScope.of(context).unfocus()

// getFirstName
getFirstName('محمد أحمد'); // 'محمد'

// DelayHandler — Debounce
final _delay = DelayHandler(defaultDelayMs: 800);
_delay.run(() => _bloc.add(SearchEvent(query)));
// dispose في dispose()

// AppUpdateChecker
await AppUpdateChecker.instance.checkForUpdate(
  appStoreId: '123456789',
  onUpdateAvailable: (bool isMandatory, [AppReleaseInfo? info]) {
    // isMandatory: true عند تغيّر major/minor، false عند patch
  },
  onError: (error) {},
);

// DeviceInfoManager
DeviceInfoManager deviceInfo;
```

---

## قواعد الاستخدام

1. **import واحد يكفي:**
   ```dart
   import 'package:shared_utils/shared_utils.dart';
   ```

2. **قبل كتابة أي أداة** — تحقق من المكتبة أولاً
3. **قبل استخدام أي package خارجي** — تحقق إذا كانت shared_utils تغطيه
4. **`PaginatedListView`** بدل بناء `ListView` + `LoadMoreWidget` + `SkeletonizerWidget` يدوياً إذا كان الـ layout بسيطاً

## الفرع الوحيد: `stable`

لا فرع في هذا المستودع غير `stable` — ولا وسوم. ممنوع إنشاء فرعٍ باسمٍ
آخر مهما كان الغرض؛ وما وُجد منها يُدمج في `stable` ثمّ يُحذف نهائياً.

**والعمل نفسه محصورٌ في `stable`:** اكتب والتزم وادفع عليه مباشرةً. لا فرع
ميزةٍ ولا إصلاح، ولا طلب دمج (PR) — ولا حتّى «مؤقّتاً حتّى أُجرّب».

**لماذا هنا بالذات؟** لأنّ هذه مكتبةٌ تستهلكها ثمانية تطبيقات عبر
`ref: stable`. فأيّ عملٍ يجلس على فرعٍ جانبيّ لا يصل أيّاً منها، مهما بدا
مكتملاً. الدليل من 2026-09-24: إصلاحُ تجمّد شاشة الإقلاع كان جاهزاً في
المكتبة، بينما ثلاثةٌ من التطبيقات ما زالت تحلّ إصداراً أقدم — والإصلاح
لا يتحرّك حتّى يصل `stable`.

**وما كان أخطر من أن يجلس على `stable`** يوضع خلف عَلَمٍ أو إعدادٍ يُطفأ،
لا خلف فرعٍ ينتظر. ومع كلّ تغييرٍ: ارفع `version` في `pubspec.yaml` قبل
الدفع، وإلّا لم تلتقطه التطبيقات.
