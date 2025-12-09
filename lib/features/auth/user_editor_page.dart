import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UserEditorPage extends StatefulWidget {
  final String? userId;
  final bool isCreatingFirstUser;

  const UserEditorPage({super.key, this.userId, this.isCreatingFirstUser = false});

  @override
  State<UserEditorPage> createState() => _UserEditorPageState();
}

class _UserEditorPageState extends State<UserEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isMaster = false;
  bool _isApprover = false; // Novo campo
  bool _isLoading = true;

  final Map<String, String> _permissionLabels = {
    'dashboard': 'Dashboard',
    'compras': 'Compras',
    'acompanhamento': 'Acompanhamento',
    'aluguel': 'Aluguel',
    'historico': 'Histórico de Preços',
    'cadastros': 'Cadastros',
    'aprovacoes': 'Aprovações', // Nova permissão
  };

  Map<String, bool> _permissions = {};

  @override
  void initState() {
    super.initState();
    _permissions = { for (var key in _permissionLabels.keys) key : false };
    
    if (widget.isCreatingFirstUser) {
      _isMaster = true;
      _isApprover = true;
      _isLoading = false;
    } else if (widget.userId != null) {
      _loadUserData();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        _usernameController.text = data['username'] ?? '';
        _emailController.text = data['email'] ?? ''; 
        _isMaster = data['isMaster'] ?? false;
        _isApprover = data['isApprover'] ?? false; // Carrega o novo campo
        final loadedPermissions = Map<String, bool>.from(data['permissions'] ?? {});
        for (var key in _permissionLabels.keys) {
          _permissions[key] = loadedPermissions[key] ?? false;
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar usuário: $e')));
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (widget.userId == null) {
        final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        final newUserUid = userCredential.user!.uid;

        await FirebaseFirestore.instance.collection('users').doc(newUserUid).set({
          'username': _usernameController.text.trim(),
          'email': _emailController.text.trim(),
          'isMaster': _isMaster, 
          'isApprover': _isApprover,
          'permissions': _permissions,
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuário criado com sucesso!')));

      } else {
        await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
          'username': _usernameController.text.trim(),
          'isMaster': _isMaster,
          'isApprover': _isApprover,
          'permissions': _permissions,
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuário atualizado com sucesso!')));
      }
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro do Firebase: ${e.message}')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar usuário: $e')));
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.userId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isCreatingFirstUser ? 'Criar Admin Master' : (isEditing ? 'Editar Usuário' : 'Novo Usuário')),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveUser,
            tooltip: 'Salvar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(labelText: 'Nome de Exibição'),
                      validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'E-mail de Acesso'),
                      keyboardType: TextInputType.emailAddress,
                      readOnly: isEditing, 
                      validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                    ),
                    const SizedBox(height: 16),
                    if (!isEditing || widget.isCreatingFirstUser)
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(labelText: 'Senha (mínimo 6 caracteres)'),
                        obscureText: true,
                        validator: (v) => (v != null && v.length < 6) ? 'A senha deve ter no mínimo 6 caracteres' : null,
                      ),
                    const SizedBox(height: 16),
                    if (!widget.isCreatingFirstUser) ...[
                      SwitchListTile(
                        title: const Text('Usuário Master (Administrador)'),
                        subtitle: const Text('Acesso total, incluindo gerenciar usuários.'),
                        value: _isMaster,
                        onChanged: (val) => setState(() => _isMaster = val),
                      ),
                      SwitchListTile(
                        title: const Text('Aprovador'),
                        subtitle: const Text('Pode aprovar ou rejeitar compras e aluguéis.'),
                        value: _isApprover,
                        onChanged: (val) => setState(() => _isApprover = val),
                      ),
                    ],
                    const Divider(height: 32),
                    if (!widget.isCreatingFirstUser) ...[
                      Text('Permissões de Acesso ao Menu', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      if (!_isMaster) ..._permissionLabels.keys.map((key) {
                        return SwitchListTile(
                          title: Text(_permissionLabels[key]!),
                          value: _permissions[key]!,
                          onChanged: (val) => setState(() => _permissions[key] = val),
                        );
                      }).toList(),
                      if (_isMaster)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'Usuários Master têm acesso a todas as áreas por padrão.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
