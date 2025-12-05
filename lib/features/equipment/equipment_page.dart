import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EquipmentPage extends StatefulWidget {
  const EquipmentPage({super.key});

  @override
  State<EquipmentPage> createState() => _EquipmentPageState();
}

class _EquipmentPageState extends State<EquipmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  // Variável para guardar a categoria selecionada
  String? _selectedCategory;
  final List<String> _categories = ['Ferramentas', 'Equipamentos', 'Implementos'];

  void _saveEquipment() {
    if (_formKey.currentState!.validate()) {
      FirebaseFirestore.instance.collection('equipments').add({
        'description': _descriptionController.text,
        'category': _selectedCategory,
      });
      _formKey.currentState!.reset();
      _descriptionController.clear();
      setState(() {
        _selectedCategory = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Equipamento salvo com sucesso!')),
      );
    }
  }

  void _deleteEquipment(String docId) {
    FirebaseFirestore.instance.collection('equipments').doc(docId).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Form(
              key: _formKey,
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  SizedBox(width: 300, child: TextFormField(controller: _descriptionController, decoration: const InputDecoration(labelText: 'Descrição do Equipamento'), validator: (v) => v!.isEmpty ? 'Obrigatório' : null)),
                  // Campo de texto substituído por Dropdown
                  SizedBox(
                    width: 200,
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Categoria'),
                      value: _selectedCategory,
                      items: _categories.map((String category) {
                        return DropdownMenuItem<String>(value: category, child: Text(category));
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          _selectedCategory = newValue;
                        });
                      },
                      validator: (value) => value == null ? 'Selecione' : null,
                    ),
                  ),
                  ElevatedButton(onPressed: _saveEquipment, child: const Text('Salvar Equipamento')),
                ],
              ),
            ),
            const Divider(height: 40),
            const Text('Equipamentos Cadastrados', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('equipments').orderBy('description').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return const Text('Erro ao carregar equipamentos.');
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  return SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Descrição')),
                        DataColumn(label: Text('Categoria')),
                        DataColumn(label: Text('Ações')),
                      ],
                      rows: snapshot.data!.docs.map((doc) {
                        final data = doc.data()! as Map<String, dynamic>;
                        return DataRow(
                          cells: [
                            DataCell(Text(data['description'] ?? '')),
                            DataCell(Text(data['category'] ?? '')),
                            DataCell(IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteEquipment(doc.id))),
                          ],
                        );
                      }).toList(),
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
}
