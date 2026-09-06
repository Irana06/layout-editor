import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shiclash/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Every screen except the landscape editor is laid out for a portrait phone.
  // Locking here rather than on the way out of landscape keeps the behaviour the
  // same from a cold start; LandscapeEditorScreen lifts the lock for its route
  // and restores it when popped.
  SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const ShiclashApp());
}
