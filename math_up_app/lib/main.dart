import 'package:flutter/material.dart';

import 'app.dart';
import 'core/application/db_initializer.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final dbInitController = DbInitController();
  dbInitController.run();
  runApp(MathUpApp(dbInitController: dbInitController));
}
