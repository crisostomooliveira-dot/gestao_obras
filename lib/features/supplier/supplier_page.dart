import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:controle_compras/common/widgets/state_dropdown.dart';
import 'package:controle_compras/features/supplier/supplier_model.dart';
import 'package:flutter/material.dart';

class SupplierPage extends StatefulWidget {
  const SupplierPage({super.key});

  @override
  State<SupplierPage> createState() => _SupplierPageState();
}

class _SupplierPageState extends State<SupplierPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cnpjController = TextEditingController();
  final _cityController = TextEditingController();
  String? _selectedState;
  final _sellerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Formulário ---
            Form(
              key: _formKey,
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(width: 250, child: TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nome do Fornecedor'), validator: (v) => (v == null || v.isEmpty) ? 'Insira o nome' : null)),
                  SizedBox(width: 200, child: TextFormField(controller: _cnpjController, decoration: const InputDecoration(labelText: 'CNPJ'))),
                  SizedBox(width: 200, child: TextFormField(controller: _cityController, decoration: const InputDecoration(labelText: 'Cidade'), validator: (v) => (v == null || v.isEmpty) ? 'Insira a cidade' : null)),
                  SizedBox(width: 120, child: StateDropdown(selectedState: _selectedState, onChanged: (v) => setState(() => _selectedState = v))),
                  SizedBox(width: 250, child: TextFormField(controller: _sellerNameController, decoration: const InputDecoration(labelText: 'Nome do Vendedor'))),
                  SizedBox(width: 150, child: TextFormField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Telefone'))),
                  SizedBox(width: 250, child: TextFormField(controller: _emailController, decoration: const InputDecoration(labelText: 'E-mail'), keyboardType: TextInputType.emailAddress)),
                  ElevatedButton(onPressed: _saveSupplier, child: const Text('Salvar Fornecedor')),
                ],
              ),
            ),
            const Divider(height: 40),

            // --- Tabela ---
            const Text('Fornecedores Cadastrados', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('suppliers').orderBy('name').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return const Text('Ocorreu um erro');
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                  final suppliers = snapshot.data!.docs.map((doc) => Supplier.fromFirestore(doc)).toList();

                  return SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SizedBox(
                      width: double.infinity,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Fornecedor')),
                          DataColumn(label: Text('Localização')),
                          DataColumn(label: Text('Vendedor')),
                          DataColumn(label: Text('Contato')),
                          DataColumn(label: Text('Ações')),
                        ],
                        rows: suppliers.map((supplier) {
                          return DataRow(
                            cells: [
                              DataCell(Text(supplier.name)),
                              DataCell(Text('${supplier.city} - ${supplier.state}')),
                              DataCell(Text(supplier.sellerName ?? '')),
                              DataCell(Text('${supplier.phone}\n${supplier.email}')),
                              DataCell(
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteSupplier(supplier.id),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveSupplier() {
    if (_formKey.currentState!.validate()) {
      FirebaseFirestore.instance.collection('suppliers').add({
        'name': _nameController.text,
        'cnpj': _cnpjController.text,
        'city': _cityController.text,
        'state': _selectedState,
        'sellerName': _sellerNameController.text,
        'phone': _phoneController.text,
        'email': _emailController.text,
      });

      _formKey.currentState?.reset();
      _nameController.clear(); _cnpjController.clear(); _cityController.clear();
      _sellerNameController.clear(); _phoneController.clear(); _emailController.clear();
      setState(() => _selectedState = null);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fornecedor salvo!')));
    }
  }

  void _deleteSupplier(String supplierId) {
    FirebaseFirestore.instance.collection('suppliers').doc(supplierId).delete();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fornecedor excluído!')));
  }

  @override
  void dispose() {
    _nameController.dispose(); _cnpjController.dispose(); _cityController.dispose();
    _sellerNameController.dispose(); _phoneController.dispose(); _emailController.dispose();
    super.dispose();
  }
}
