import 'dart:async';
import 'dart:ui';

class DelayHandler {
  Timer? _timer;
  final int defaultMilliseconds;

  DelayHandler({this.defaultMilliseconds = 800});

  void run(VoidCallback action, {int? delay}) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: delay ?? defaultMilliseconds), action);
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
