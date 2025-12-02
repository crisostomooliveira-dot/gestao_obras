import 'package:cloud_firestore/cloud_firestore.dart';

class Supplier {
  final String id;
  final String name;
  final String? cnpj;
  final String? city;
  final String? state;
  final String? sellerName;
  final String? phone;
  final String? email;

  Supplier({
    required this.id,
    required this.name,
    this.cnpj,
    this.city,
    this.state,
    this.sellerName,
    this.phone,
    this.email,
  });

  factory Supplier.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Supplier(
      id: doc.id,
      name: data['name'] ?? 'N/A',
      cnpj: data['cnpj'] ?? '',
      city: data['city'] ?? '',
      state: data['state'] ?? '',
      sellerName: data['sellerName'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
    );
  }
}
