import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Step3PaymentWidget extends StatefulWidget {
  final String purchaseRequestId;
  final Map<String, dynamic> requestData;

  const Step3PaymentWidget({super.key, required this.purchaseRequestId, required this.requestData});

  @override
  State<Step3PaymentWidget> createState() => _Step3PaymentWidgetState();
}

class _Step3PaymentWidgetState extends State<Step3PaymentWidget> {
  final _formKey = GlobalKey<FormState>();
  final _nfController = TextEditingController();
  final _trackingCodeController = TextEditingController(); // Novo controller
  String? _paymentStatus;
  String? _deliveryStatus;
  DateTime? _expectedDeliveryDate;

  @override
  void initState() {
    super.initState();
    _nfController.text = widget.requestData['invoiceNumber'] ?? '';
    _trackingCodeController.text = widget.requestData['trackingCode'] ?? ''; // Preenche o novo campo
    _paymentStatus = widget.requestData['paymentStatus'];
    _deliveryStatus = widget.requestData['deliveryStatus'];
    _expectedDeliveryDate = (widget.requestData['expectedDeliveryDate'] as Timestamp?)?.toDate();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text('Etapa 3: Pagamento e Acompanhamento', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          _buildOrderSummary(),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          TextFormField(controller: _nfController, decoration: const InputDecoration(labelText: 'Número da Nota Fiscal (NF)')),
          const SizedBox(height: 16),
          TextFormField(controller: _trackingCodeController, decoration: const InputDecoration(labelText: 'Código de Rastreio')), // Novo campo
          const SizedBox(height: 16),
          _buildExpectedDeliveryDateField(context),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(value: _paymentStatus, decoration: const InputDecoration(labelText: 'Status do Pagamento'), items: ['Pendente', 'Pago', 'Atrasado'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setState(() => _paymentStatus = v)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(value: _deliveryStatus, decoration: const InputDecoration(labelText: 'Status da Entrega'), items: ['Aguardando Entrega', 'Entregue', 'Em Trânsito'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setState(() => _deliveryStatus = v)),
          const SizedBox(height: 32),
          ElevatedButton(onPressed: _updateStatus, child: const Text('Atualizar Status')),
        ],
      ),
    );
  }

  Widget _buildOrderSummary() {
    // ... (sem alterações aqui)
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Resumo do Pedido', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Fornecedor: ${widget.requestData['selectedSupplierName'] ?? 'N/A'}'),
            const SizedBox(height: 4),
            Text('Valor Total: R\$ ${(widget.requestData['totalPrice'] as num?)?.toStringAsFixed(2) ?? '0.00'}'),
          ],
        ),
      ),
    );
  }

  Widget _buildExpectedDeliveryDateField(BuildContext context) {
    // ... (sem alterações aqui)
    return TextFormField(
      readOnly: true,
      decoration: InputDecoration(
        labelText: 'Data de Entrega Prevista',
        suffixIcon: const Icon(Icons.calendar_today),
      ),
      controller: TextEditingController(
        text: _expectedDeliveryDate == null ? '' : DateFormat('dd/MM/yyyy').format(_expectedDeliveryDate!),
      ),
      onTap: () async {
        final pickedDate = await showDatePicker(context: context, initialDate: _expectedDeliveryDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
        if (pickedDate != null) setState(() => _expectedDeliveryDate = pickedDate);
      },
    );
  }

  void _updateStatus() {
    if (_formKey.currentState!.validate()) {
      FirebaseFirestore.instance.collection('purchase_requests').doc(widget.purchaseRequestId).update({
        'invoiceNumber': _nfController.text,
        'trackingCode': _trackingCodeController.text, // Salva o novo campo
        'paymentStatus': _paymentStatus,
        'deliveryStatus': _deliveryStatus,
        'expectedDeliveryDate': _expectedDeliveryDate != null ? Timestamp.fromDate(_expectedDeliveryDate!) : null,
        'status': 'Finalizado',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informações da compra atualizadas!')),
      );
    }
  }

  @override
  void dispose() {
    _nfController.dispose();
    _trackingCodeController.dispose(); // Dispose do novo controller
    super.dispose();
  }
}
