// utils/log.dart
import 'package:flutter/foundation.dart'; // kReleaseMode, debugPrint

void logd(Object? msg) {
  if (!kReleaseMode) {
    debugPrint('$msg'); // only prints in debug/profile
  }
}
