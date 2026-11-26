import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF131A22),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  // Render the animated splash immediately without waiting for async I/O
  runApp(const ExpenseTrackerApp());
}
