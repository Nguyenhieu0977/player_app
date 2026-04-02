import 'package:window_manager/window_manager.dart';

class WindowService {
  Future<void> applyKioskMode({
    required bool fullscreen,
    required bool alwaysOnTop,
  }) async {
    await windowManager.setAlwaysOnTop(alwaysOnTop);
    if (fullscreen) {
      await windowManager.setFullScreen(true);
    }
  }

  Future<void> exitKioskMode() async {
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setFullScreen(false);
  }
}
