import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gestao_obras/features/product/product_model.dart';
import 'package:flutter/material.dart';

class ProductPage extends StatefulWidget {
  const ProductPage({super.key});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _otherUnitController = TextEditingController();
  String? _selectedUnit;
  String? _selectedUsageCategory;
  bool _showOtherUnitField = false;

  final List<String> _standardUnits = ['Kg', 'Litros', 'Metros', 'Barra', 'Peças', 'Outro'];
  final List<String> _usageCategories = ['Obra', 'Alojamento', 'Aluguel', 'Equipamentos'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Formulário de Cadastro ---
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: 'Descrição do Produto'),
                    validator: (value) => (value == null || value.isEmpty) ? 'Insira a descrição' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'Unidade Padrão'),
                          value: _selectedUnit,
                          items: _standardUnits.map((unit) => DropdownMenuItem(value: unit, child: Text(unit))).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedUnit = value;
                              _showOtherUnitField = (value == 'Outro');
                            });
                          },
                          validator: (value) => value == null ? 'Selecione uma unidade' : null,
                        ),
                      ),
                      if (_showOtherUnitField)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 12.0),
                            child: TextFormField(
                              controller: _otherUnitController,
                              decoration: const InputDecoration(labelText: 'Especifique a Unidade'),
                              validator: (value) => (value == null || value.isEmpty) ? 'Especifique a unidade' : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Categoria de Uso'),
                    value: _selectedUsageCategory,
                    items: _usageCategories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                    onChanged: (value) => setState(() => _selectedUsageCategory = value),
                    validator: (value) => value == null ? 'Selecione uma categoria' : null,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _saveProduct,
                    child: const Text('Salvar Produto'),
                  ),
                ],
              ),
            ),
            const Divider(height: 40),
            
            // --- Tabela de Produtos ---
            const Text('Produtos Cadastrados', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('products').orderBy('description').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return const Text('Ocorreu um erro');
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                  final products = snapshot.data!.docs.map((doc) => Product.fromFirestore(doc)).toList();

                  return SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SizedBox(
                      width: double.infinity,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Descrição')),
                          DataColumn(label: Text('Unidade')),
                          DataColumn(label: Text('Categoria de Uso')),
                          DataColumn(label: Text('Ações')),
                        ],
                        rows: products.map((product) {
                          return DataRow(
                            cells: [
                              DataCell(Text(product.description)),
                              DataCell(Text(product.unit)),
                              DataCell(Text(product.usageCategory)),
                              DataCell(
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteProduct(product.id),
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

  void _saveProduct() {
    if (_formKey.currentState!.validate()) {
      String finalUnit = (_selectedUnit == 'Outro') ? _otherUnitController.text : _selectedUnit!;

      FirebaseFirestore.instance.collection('products').add({
        'description': _descriptionController.text,
        'unit': finalUnit,
        'usageCategory': _selectedUsageCategory,
      });

      _formKey.currentState?.reset();
      _descriptionController.clear();
      _otherUnitController.clear();
      setState(() {
        _selectedUnit = null;
        _selectedUsageCategory = null;
        _showOtherUnitField = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produto salvo com sucesso!')),
      );
    }
  }

  void _deleteProduct(String productId) {
    FirebaseFirestore.instance.collection('products').doc(productId).delete();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Produto excluído com sucesso!')),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _otherUnitController.dispose();
    super.dispose();
  }
}
