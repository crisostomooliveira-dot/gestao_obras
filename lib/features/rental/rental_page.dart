import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RentalPage extends StatefulWidget {
  const RentalPage({super.key});

  @override
  State<RentalPage> createState() => _RentalPageState();
}

class _RentalPageState extends State<RentalPage> {

  void _showDeleteConfirmationDialog(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: const Text('Tem certeza que deseja excluir esta fatura de aluguel?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteInvoice(doc.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteInvoice(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('rental_invoices').doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fatura de aluguel excluída com sucesso!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir fatura: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('rental_invoices').orderBy('paymentDueDate', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Ocorreu um erro.'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) return const Center(child: Text('Nenhuma fatura de aluguel lançada.'));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: snapshot.data!.docs.map((doc) => _buildInvoiceCard(doc)).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showInvoiceDialog(),
        tooltip: 'Lançar Fatura de Aluguel',
        child: const Icon(Icons.post_add_outlined),
      ),
    );
  }

  Widget _buildInvoiceCard(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    final paymentDueDate = (data['paymentDueDate'] as Timestamp?)?.toDate();
    final isOverdue = paymentDueDate != null && paymentDueDate.isBefore(DateTime.now());

    return Card(
      color: isOverdue ? Colors.red[50] : null,
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showInvoiceDialog(doc: doc),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fornecedor: ${data['supplierName'] ?? 'N/A'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Obra: ${data['constructionName'] ?? '-'}', style: const TextStyle(color: Colors.grey)),
                    Text('Fatura: ${data['invoiceNumber'] ?? '-'} | Contrato: ${data['contractNumber'] ?? '-'}', style: const TextStyle(color: Colors.grey)),
                    Text('Vencimento: ${paymentDueDate != null ? DateFormat('dd/MM/yyyy').format(paymentDueDate) : '-'}', style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(data['totalValue'] ?? 0.0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Chip(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    label: Text(
                      data['approvalStatus'] ?? 'Pendente',
                      style: const TextStyle(fontSize: 11),
                    ),
                    backgroundColor: Colors.orange[100],
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                   IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: () => _showDeleteConfirmationDialog(doc),
                    tooltip: 'Excluir Fatura',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInvoiceDialog({DocumentSnapshot? doc}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog.fullscreen(child: RentalInvoiceDialog(doc: doc)),
    ).then((_) => setState(() {}));
  }
}

class RentalInvoiceDialog extends StatefulWidget {
  final DocumentSnapshot? doc;
  const RentalInvoiceDialog({super.key, this.doc});

  @override
  State<RentalInvoiceDialog> createState() => _RentalInvoiceDialogState();
}

class _RentalInvoiceDialogState extends State<RentalInvoiceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _invoiceNumberController = TextEditingController();
  final _contractNumberController = TextEditingController();
  
  String? _selectedSupplierId, _selectedSupplierName;
  String? _selectedConstructionId, _selectedConstructionName;
  DateTime? _periodStartDate, _periodEndDate, _paymentDueDate;
  String? _paymentStatus;
  String? _materialStatus;
  String _processStatus = 'Aberto';

  List<Map<String, dynamic>> _items = [];
  double _totalValue = 0.0;

  @override
  void initState() {
    super.initState();
    if (widget.doc != null) {
      final data = widget.doc!.data() as Map<String, dynamic>;
      _invoiceNumberController.text = data['invoiceNumber'] ?? '';
      _contractNumberController.text = data['contractNumber'] ?? '';
      _selectedSupplierId = data['supplierId'];
      _selectedSupplierName = data['supplierName'];
      _selectedConstructionId = data['constructionId'];
      _selectedConstructionName = data['constructionName'];
      _periodStartDate = (data['periodStartDate'] as Timestamp?)?.toDate();
      _periodEndDate = (data['periodEndDate'] as Timestamp?)?.toDate();
      _paymentDueDate = (data['paymentDueDate'] as Timestamp?)?.toDate();
      _paymentStatus = data['paymentStatus'] ?? data['status'] ?? 'Pendente';
      _materialStatus = data['materialStatus'] ?? 'Mat. em Obra';
      _processStatus = data['processStatus'] ?? 'Aberto';
      _items = List<Map<String, dynamic>>.from(data['items'] ?? []);
      _calculateTotal();
    } else {
      _paymentStatus = 'Pendente';
      _materialStatus = 'Mat. em Obra';
      _processStatus = 'Aberto';
    }
  }

  void _calculateTotal() {
    double total = 0.0;
    for (var item in _items) {
      total += (item['value'] as num?) ?? 0.0;
    }
    setState(() => _totalValue = total);
  }

  void _addItem() {
    String? selectedProductId;
    String? selectedProductDescription;
    String? selectedFrequency;
    final valueController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Adicionar Equipamento/Item'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Autocomplete<DocumentSnapshot>(
                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                        return TextFormField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          decoration: const InputDecoration(labelText: 'Descrição do Item (digite 3+ letras)'),
                           onFieldSubmitted: (value) => onFieldSubmitted(),
                        );
                    },
                    optionsBuilder: (TextEditingValue textEditingValue) async {
                      final String query = textEditingValue.text.toLowerCase();
                      if (query.length < 3) {
                        return const Iterable<DocumentSnapshot>.empty();
                      }
                      
                      try {
                        final response = await FirebaseFirestore.instance
                            .collection('products')
                            .where('usageCategory', isEqualTo: 'Aluguel')
                            .get();

                        if (response.docs.isEmpty) {
                            return const Iterable<DocumentSnapshot>.empty();
                        }

                        final results = response.docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final String description = (data['description'] ?? '').toLowerCase();
                            return description.startsWith(query);
                        });

                        return results;
                      } catch (e) {
                        debugPrint('Ocorreu um erro ao buscar produtos: $e');
                        return const Iterable<DocumentSnapshot>.empty();
                      }
                    },
                    displayStringForOption: (DocumentSnapshot option) => (option.data() as Map<String, dynamic>)['description'],
                    onSelected: (DocumentSnapshot selection) {
                      final data = selection.data() as Map<String, dynamic>;
                      setDialogState(() {
                        selectedProductId = selection.id;
                        selectedProductDescription = data['description'];
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedFrequency,
                    decoration: const InputDecoration(labelText: 'Frequência'),
                    items: ['Diário', 'Semanal', 'Quinzenal', 'Mensal']
                        .map((label) => DropdownMenuItem(value: label, child: Text(label)))
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedFrequency = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(controller: valueController, decoration: const InputDecoration(labelText: 'Valor (R\$)'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
                ElevatedButton(onPressed: () {
                  if (selectedProductId != null && selectedFrequency != null && valueController.text.isNotEmpty) {
                    setState(() {
                      _items.add({
                        'productId': selectedProductId,
                        'description': selectedProductDescription,
                        'frequency': selectedFrequency,
                        'value': double.tryParse(valueController.text.replaceAll(',', '.')) ?? 0.0,
                      });
                      _calculateTotal();
                    });
                    Navigator.of(ctx).pop();
                  }
                }, child: const Text('Adicionar')),
              ],
            );
          },
        );
      },
    );
  }
  
  Future<void> _saveInvoice() async {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'supplierId': _selectedSupplierId,
      'supplierName': _selectedSupplierName,
      'constructionId': _selectedConstructionId,
      'constructionName': _selectedConstructionName,
      'invoiceNumber': _invoiceNumberController.text,
      'contractNumber': _contractNumberController.text,
      'periodStartDate': _periodStartDate != null ? Timestamp.fromDate(_periodStartDate!) : null,
      'periodEndDate': _periodEndDate != null ? Timestamp.fromDate(_periodEndDate!) : null,
      'paymentDueDate': _paymentDueDate != null ? Timestamp.fromDate(_paymentDueDate!) : null,
      'totalValue': _totalValue,
      'items': _items,
      'paymentStatus': _paymentStatus,
      'materialStatus': _materialStatus,
      'processStatus': _processStatus,
      'approvalStatus': widget.doc?.data() != null ? (widget.doc!.data() as Map<String, dynamic>)['approvalStatus'] ?? 'Aguardando Aprovação' : 'Aguardando Aprovação', 
      'createdAt': widget.doc == null ? FieldValue.serverTimestamp() : (widget.doc!.data() as Map<String, dynamic>)['createdAt'],
    };

    if (widget.doc == null) {
      await FirebaseFirestore.instance.collection('rental_invoices').add(data);
    } else {
      await FirebaseFirestore.instance.collection('rental_invoices').doc(widget.doc!.id).update(data);
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.doc == null ? 'Lançar Fatura de Aluguel' : 'Editar Fatura'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
        actions: [
          ElevatedButton(onPressed: _saveInvoice, child: const Text('SALVAR'))
        ],
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(children: [
                Expanded(child: _buildDropdown('suppliers', 'Fornecedor', _selectedSupplierId, (id, name) => setState(() { _selectedSupplierId = id; _selectedSupplierName = name; }))),
                const SizedBox(width: 16),
                Expanded(child: _buildDropdown('constructions', 'Obra', _selectedConstructionId, (id, name) => setState(() { _selectedConstructionId = id; _selectedConstructionName = name; }))),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: TextFormField(controller: _invoiceNumberController, decoration: const InputDecoration(labelText: 'Nº da Fatura do Fornecedor'))),
                const SizedBox(width: 16),
                Expanded(child: TextFormField(controller: _contractNumberController, decoration: const InputDecoration(labelText: 'Nº do Contrato'))),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _buildDateField(context, 'Início do Período', _periodStartDate, (date) => setState(() => _periodStartDate = date))),
                const SizedBox(width: 16),
                Expanded(child: _buildDateField(context, 'Fim do Período', _periodEndDate, (date) => setState(() => _periodEndDate = date))),
                const SizedBox(width: 16),
                Expanded(child: _buildDateField(context, 'Vencimento Pagamento', _paymentDueDate, (date) => setState(() => _paymentDueDate = date))),
              ]),
              const SizedBox(height: 16),
              Row( 
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _paymentStatus,
                      decoration: const InputDecoration(labelText: 'Status do Pagamento'),
                      items: ['Pendente', 'Aguardando Pagamento', 'Pago']
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (val) => setState(() => _paymentStatus = val),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _materialStatus,
                      decoration: const InputDecoration(labelText: 'Status do Material'),
                      items: ['Mat. em Obra', 'Mat. Devolvido']
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (val) => setState(() => _materialStatus = val),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
               DropdownButtonFormField<String>(
                  value: _processStatus,
                  decoration: const InputDecoration(labelText: 'Status do Processo'),
                  items: ['Aberto', 'Em processo', 'Finalizada']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (val) => setState(() => _processStatus = val!),
                ),
              const Divider(height: 32),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Itens da Fatura', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), IconButton.filled(onPressed: _addItem, icon: const Icon(Icons.add))]),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: DataTable(
                    columns: const [DataColumn(label: Text('Descrição')), DataColumn(label: Text('Frequência')), DataColumn(label: Text('Valor')), DataColumn(label: Text('Ações'))],
                    rows: [
                      ..._items.map((item) => DataRow(cells: [
                        DataCell(Text(item['description'].toString())),
                        DataCell(Text(item['frequency'].toString())),
                        DataCell(Text(NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(item['value'] ?? 0.0))),
                        DataCell(IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() { _items.remove(item); _calculateTotal(); }))),
                      ])),
                      DataRow(
                        cells: [
                          const DataCell(Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold))),
                          const DataCell(SizedBox.shrink()), 
                          DataCell(Text(NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(_totalValue), style: const TextStyle(fontWeight: FontWeight.bold))),
                          const DataCell(SizedBox.shrink()), 
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildDropdown(String collection, String label, String? value, Function(String, String) onChanged) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(collection).orderBy('name').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: LinearProgressIndicator());
        return DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(labelText: label),
          items: snapshot.data!.docs.map((doc) => DropdownMenuItem(value: doc.id, child: Text((doc.data() as Map<String, dynamic>)['name'] ?? 'N/A'))).toList(),
          onChanged: (val) {
            if (val == null) return;
            final selectedDoc = snapshot.data!.docs.firstWhere((d) => d.id == val);
            final selectedName = (selectedDoc.data() as Map<String, dynamic>)['name'] ?? 'N/A';
            onChanged(val, selectedName);
          },
          validator: (v) => v == null ? 'Obrigatório' : null,
        );
      },
    );
  }

  Widget _buildDateField(BuildContext context, String label, DateTime? date, ValueChanged<DateTime?> onDateChanged) {
    return TextFormField(
      readOnly: true,
      decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.calendar_today)),
      controller: TextEditingController(text: date == null ? '' : DateFormat('dd/MM/yyyy').format(date)),
      onTap: () async {
        final picked = await showDatePicker(context: context, initialDate: date ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
        onDateChanged(picked);
      },
    );
  }

  @override
  void dispose() {
    _invoiceNumberController.dispose();
    _contractNumberController.dispose();
    super.dispose();
  }
}
