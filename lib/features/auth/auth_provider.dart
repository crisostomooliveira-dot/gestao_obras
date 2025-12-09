import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gestao_obras/features/auth/user_model.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _userModel;
  UserModel? get user => _userModel;

  bool get isLoggedIn => _userModel != null;

  AuthProvider() {
    FirebaseAuth.instance.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _userModel = null;
    } else {
      await _loadUserModel(firebaseUser.uid);
    }
    notifyListeners();
  }

  Future<void> _loadUserModel(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        final permissions = Map<String, bool>.from(data['permissions'] ?? {});
        _userModel = UserModel(
          id: doc.id,
          username: data['username'] ?? '', 
          isMaster: data['isMaster'] ?? false,
          permissions: permissions,
        );
      } else {
        _userModel = null; 
      }
    } catch (e) {
      _userModel = null;
    }
  }

  Future<String?> login(String email, String password) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      return null; // Sucesso
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return 'E-mail ou senha inválidos.';
      } else {
        // Retorna o erro real do Firebase para diagnóstico
        return 'Erro: ${e.message} (código: ${e.code})';
      }
    }
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
  }

  bool hasPermission(String menuKey) {
    if (_userModel == null) return false;
    if (_userModel!.isMaster) return true;
    return _userModel!.permissions[menuKey] ?? false;
  }
}
