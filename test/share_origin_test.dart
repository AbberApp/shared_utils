// مصدر ورقة المشاركة على iPad.
//
// `ShareService` نفسه ينادي قناةً أصليّة، فلا يُختبر بلا جهاز؛ أمّا `shareOrigin` فحسابٌ هندسيّ خالص:
// مستطيل العنصر بإحداثيات الشاشة. وهو الجزء الذي يُخطئ فيه الناس — يمرّرون سياق الصفحة بدل سياق الزرّ،
// أو يقرؤونه قبل أن يأخذ العنصر حجمه.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_utils/shared_utils.dart';

void main() {
  testWidgets('المستطيل هو موضع العنصر وحجمه بإحداثيات الشاشة', (WidgetTester tester) async {
    late BuildContext buttonContext;
    await tester.pumpWidget(MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 30, top: 40),
          child: SizedBox(
            width: 120,
            height: 50,
            child: Builder(builder: (BuildContext context) {
              buttonContext = context;
              return const SizedBox.expand();
            }),
          ),
        ),
      ),
    ));

    expect(buttonContext.shareOrigin, const Rect.fromLTWH(30, 40, 120, 50));
  });

  testWidgets('سياق الصفحة يعطي مستطيل الصفحة لا مستطيل الزرّ', (WidgetTester tester) async {
    late BuildContext pageContext;
    late BuildContext buttonContext;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (BuildContext page) {
        pageContext = page;
        return Center(
          child: SizedBox(
            width: 80,
            height: 20,
            child: Builder(builder: (BuildContext button) {
              buttonContext = button;
              return const SizedBox.expand();
            }),
          ),
        );
      }),
    ));

    expect(buttonContext.shareOrigin!.size, const Size(80, 20));
    // ولهذا يُمرَّر سياق العنصر المضغوط: سياق الصفحة يغطّي الشاشة كلّها
    expect(pageContext.shareOrigin!.size, tester.view.physicalSize / tester.view.devicePixelRatio);
  });
}
