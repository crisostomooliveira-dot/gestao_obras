import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:controle_compras/common/widgets/state_dropdown.dart';
import 'package:controle_compras/features/construction/construction_model.dart';
import 'package:flutter/material.dart';

class ConstructionPage extends StatefulWidget {
  const ConstructionPage({super.key});

  @override
  State<ConstructionPage> createState() => _ConstructionPageState();
}

class _ConstructionPageState extends State<ConstructionPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  String? _selectedState;
  String? _selectedStatus;

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
                  SizedBox(width: 250, child: TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nome da Obra'), validator: (v) => (v == null || v.isEmpty) ? 'Insira o nome' : null)),
                  SizedBox(width: 200, child: TextFormField(controller: _cityController, decoration: const InputDecoration(labelText: 'Cidade'), validator: (v) => (v == null || v.isEmpty) ? 'Insira a cidade' : null)),
                  SizedBox(width: 120, child: StateDropdown(selectedState: _selectedState, onChanged: (v) => setState(() => _selectedState = v))),
                  SizedBox(width: 150, child: DropdownButtonFormField<String>(decoration: const InputDecoration(labelText: 'Status'), value: _selectedStatus, items: ['Ativa', 'Finalizada', 'Paralisada'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setState(() => _selectedStatus = v), validator: (v) => v == null ? 'Selecione' : null)),
                  ElevatedButton(onPressed: _saveConstruction, child: const Text('Salvar Obra')),
                ],
              ),
            ),
            const Divider(height: 40),

            // --- Tabela ---
            const Text('Obras Cadastradas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('constructions').orderBy('name').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return const Text('Ocorreu um erro');
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                  final constructions = snapshot.data!.docs.map((doc) => Construction.fromFirestore(doc)).toList();

                  return SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SizedBox(
                      width: double.infinity,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Obra')),
                          DataColumn(label: Text('Localização')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Ações')),
                        ],
                        rows: constructions.map((c) {
                          return DataRow(
                            cells: [
                              DataCell(Text(c.name)),
                              DataCell(Text('${c.city} - ${c.state}')),
                              DataCell(Chip(label: Text(c.status ?? 'N/A', style: const TextStyle(color: Colors.white)), backgroundColor: _getStatusColor(c.status))),
                              DataCell(
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteConstruction(c.id),
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

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'Ativa': return Colors.green;
      case 'Finalizada': return Colors.blue;
      case 'Paralisada': return Colors.red;
      default: return Colors.grey;
    }
  }

  void _saveConstruction() {
    if (_formKey.currentState!.validate()) {
      FirebaseFirestore.instance.collection('constructions').add({
        'name': _nameController.text,
        'city': _cityController.text,
        'state': _selectedState,
        'status': _selectedStatus,
      });

      _formKey.currentState?.reset();
      _nameController.clear(); _cityController.clear();
      setState(() { _selectedState = null; _selectedStatus = null; });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Obra salva com sucesso!')));
    }
  }

  void _deleteConstruction(String id) {
    FirebaseFirestore.instance.collection('constructions').doc(id).delete();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Obra excluída com sucesso!')));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    super.dispose();
  }
}
