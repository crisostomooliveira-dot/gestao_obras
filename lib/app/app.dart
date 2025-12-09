import 'package:flutter/material.dart';
import 'package:gestao_obras/app/main_layout.dart';
import 'package:gestao_obras/features/auth/auth_provider.dart';
import 'package:gestao_obras/features/auth/login_page.dart';
import 'package:provider/provider.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestão de Obras',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false,
      home: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          if (authProvider.isLoggedIn) {
            return const MainLayout();
          } else {
            return const LoginPage();
          }
        },
      ),
    );
  }
}
