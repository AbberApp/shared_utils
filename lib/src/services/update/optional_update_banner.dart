import 'package:flutter/material.dart';

/// شريط «تحديث اختياريّ» دائم — كالتوست لكنّه يبقى ظاهرًا حتّى يضغط المستخدم
/// «تحديث» أو يغلقه. يُعرض فوق التطبيق كلّه عبر [Overlay] و idempotent (لا يتكرّر).
///
/// theme-agnostic: التطبيق يمرّر ألوانه (مثل [showToast]) فلا يعتمد على ثيم بعينه.
class OptionalUpdateBanner {
  OptionalUpdateBanner._();

  static OverlayEntry? _entry;

  static bool get isShowing => _entry != null;

  static void show(
    BuildContext context, {
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
    required Color backgroundColor,
    required Color foregroundColor,
    required Color actionColor,
    IconData icon = Icons.system_update_alt_rounded,
    OverlayState? overlayState,
    bool showCloseButton = true,
  }) {
    // Prefer an explicit OverlayState (e.g. navigatorKey.currentState.overlay):
    // a bare navigatorKey.currentContext has NO Overlay ancestor, so
    // Overlay.maybeOf(context) returns null and the banner never shows.
    final OverlayState? overlay =
        overlayState ?? Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null || _entry != null) return; // معروض أصلًا → لا تكرار

    _entry = OverlayEntry(
      builder: (_) => _OptionalUpdateBannerView(
        message: message,
        actionLabel: actionLabel,
        icon: icon,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        actionColor: actionColor,
        onAction: onAction,
        onClose: hide,
        showCloseButton: showCloseButton,
      ),
    );
    overlay.insert(_entry!);
  }

  static void hide() {
    _entry?.remove();
    _entry = null;
  }
}

class _OptionalUpdateBannerView extends StatelessWidget {
  const _OptionalUpdateBannerView({
    required this.message,
    required this.actionLabel,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.actionColor,
    required this.onAction,
    required this.onClose,
    required this.showCloseButton,
  });

  final String message;
  final String actionLabel;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color actionColor;
  final VoidCallback onAction;
  final VoidCallback onClose;
  final bool showCloseButton;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 12.0,
      right: 12.0,
      bottom: 12.0,
      child: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(14.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 12.0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                spacing: 10.0,
                children: [
                  Icon(icon, color: foregroundColor, size: 22.0),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(color: foregroundColor, fontSize: 13.0, height: 1.3),
                    ),
                  ),
                  TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      foregroundColor: actionColor,
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      minimumSize: const Size(0, 36.0),
                    ),
                    child: Text(
                      actionLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.0),
                    ),
                  ),
                  if (showCloseButton)
                    InkWell(
                      onTap: onClose,
                      borderRadius: BorderRadius.circular(20.0),
                      child: Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: Icon(Icons.close_rounded, color: foregroundColor, size: 18.0),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
