import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:gestao_obras/features/auth/user_editor_page.dart';

class UserManagementPage extends StatelessWidget {
  const UserManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Usuários'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Erro ao carregar usuários.'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final users = snapshot.data!.docs;

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final userDoc = users[index];
              final userData = userDoc.data() as Map<String, dynamic>;
              final bool isMaster = userData['isMaster'] ?? false;

              return ListTile(
                title: Text(userData['username'] ?? 'Usuário sem nome'),
                subtitle: Text(isMaster ? 'Administrador' : 'Usuário Padrão'),
                trailing: isMaster ? const Icon(Icons.vpn_key, color: Colors.amber) : null,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => UserEditorPage(userId: userDoc.id)),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const UserEditorPage()),
        ),
        child: const Icon(Icons.add),
        tooltip: 'Adicionar Usuário',
      ),
    );
  }
}
