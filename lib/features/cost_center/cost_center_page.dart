import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gestao_obras/features/cost_center/cost_center_model.dart';
import 'package:flutter/material.dart';

class CostCenterPage extends StatefulWidget {
  const CostCenterPage({super.key});

  @override
  State<CostCenterPage> createState() => _CostCenterPageState();
}

class _CostCenterPageState extends State<CostCenterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _selectedCategory;
  final List<String> _categories = ['Engenharia', 'Administrativo', 'Assistência Técnica', 'Montagem', 'Gotejo'];

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
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  SizedBox(width: 250, child: TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nome do Centro de Custo'), validator: (v) => (v == null || v.isEmpty) ? 'Insira o nome' : null)),
                  SizedBox(width: 250, child: DropdownButtonFormField<String>(decoration: const InputDecoration(labelText: 'Categoria'), value: _selectedCategory, items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(), onChanged: (v) => setState(() => _selectedCategory = v), validator: (v) => v == null ? 'Selecione' : null)),
                  ElevatedButton(onPressed: _saveCostCenter, child: const Text('Salvar Centro de Custo')),
                ],
              ),
            ),
            const Divider(height: 40),

            // --- Tabela ---
            const Text('Centros de Custo Cadastrados', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('cost_centers').orderBy('name').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return const Text('Ocorreu um erro');
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                  final costCenters = snapshot.data!.docs.map((doc) => CostCenter.fromFirestore(doc)).toList();

                  return SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SizedBox(
                      width: double.infinity,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Nome')),
                          DataColumn(label: Text('Categoria')),
                          DataColumn(label: Text('Ações')),
                        ],
                        rows: costCenters.map((cc) {
                          return DataRow(
                            cells: [
                              DataCell(Text(cc.name)),
                              DataCell(Text(cc.category ?? '')),
                              DataCell(
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteCostCenter(cc.id),
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

  void _saveCostCenter() {
    if (_formKey.currentState!.validate()) {
      FirebaseFirestore.instance.collection('cost_centers').add({
        'name': _nameController.text,
        'category': _selectedCategory,
      });

      _formKey.currentState?.reset();
      _nameController.clear();
      setState(() => _selectedCategory = null);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Centro de Custo salvo!')));
    }
  }

  void _deleteCostCenter(String id) {
    FirebaseFirestore.instance.collection('cost_centers').doc(id).delete();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Centro de Custo excluído!')));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
