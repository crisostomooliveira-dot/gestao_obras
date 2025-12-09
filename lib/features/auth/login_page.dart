import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:gestao_obras/features/auth/auth_provider.dart';
import 'package:gestao_obras/features/auth/user_editor_page.dart';
import 'package:provider/provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final String? error = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Card(
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Gestão de Obras', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'E-mail'),
                      validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(labelText: 'Senha'),
                      obscureText: true,
                      validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                    ),
                    const SizedBox(height: 24),
                    if (_isLoading)
                      const CircularProgressIndicator()
                    else
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _login,
                          child: const Text('Entrar'),
                        ),
                      ),
                    const SizedBox(height: 16),
                    _buildFirstUserButton(), // Botão para criar o primeiro usuário
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFirstUserButton() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').limit(1).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink(); // Não mostra nada enquanto carrega
        }
        if (snapshot.hasData && snapshot.data!.docs.isEmpty) {
          // Só mostra o botão se a coleção 'users' estiver vazia
          return TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const UserEditorPage(isCreatingFirstUser: true)),
            ),
            child: const Text('Criar primeiro usuário administrador'),
          );
        }
        return const SizedBox.shrink(); // Não mostra o botão se já existem usuários
      },
    );
  }
}
