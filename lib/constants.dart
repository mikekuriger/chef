// constants.dart
import 'package:flutter/material.dart';

final ValueNotifier<bool> recipeDataChanged = ValueNotifier(false);

// temporary page refreshing to test
final ValueNotifier<int> journalRefreshTrigger = ValueNotifier(0);
final ValueNotifier<int> galleryRefreshTrigger = ValueNotifier(0);
final ValueNotifier<int> profileRefreshTrigger = ValueNotifier(0);
final ValueNotifier<int> recipeEntryRefreshTrigger = ValueNotifier(0);
final ValueNotifier<int> editorRefreshTrigger = ValueNotifier(0);

const kWebClientId = '846080686597-61d3v0687vomt4g4tl7rueu7rv9qrari.apps.googleusercontent.com';

class AppConfig {
  static const String baseUrl = 'https://chef-us-west-01.zentha.me';
}
