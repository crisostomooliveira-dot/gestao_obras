import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:gestao_obras/app/app.dart';
import 'package:gestao_obras/features/auth/auth_provider.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AuthProvider(),
      child: const App(),
    );
  }
}
