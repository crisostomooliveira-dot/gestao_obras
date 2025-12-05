import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gestao_obras/features/purchase/purchase_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:gestao_obras/features/rental/rental_page.dart';
import 'package:intl/intl.dart';

class TrackingTab extends StatefulWidget {
  final String? constructionIdFilter;

  const TrackingTab({super.key, this.constructionIdFilter});

  @override
  State<TrackingTab> createState() => _TrackingTabState();
}

class _TrackingTabState extends State<TrackingTab> {
  final _nfController = TextEditingController();
  String? _generalStatusFilter;
  String? _paymentStatusFilter;
  String? _deliveryStatusFilter;
  late Stream<List<DocumentSnapshot>> _combinedStream;

  @override
  void initState() {
    super.initState();
    _combinedStream = const Stream.empty();
    _nfController.addListener(() => _updateStream());
    _updateStream();
  }

  void _updateStream() {
    // Base queries
    Query purchasesQuery = FirebaseFirestore.instance.collection('purchase_requests');
    Query rentalsQuery = FirebaseFirestore.instance.collection('rental_invoices');

    if (widget.constructionIdFilter != null) {
      purchasesQuery = purchasesQuery.where('constructionId', isEqualTo: widget.constructionIdFilter);
      rentalsQuery = rentalsQuery.where('constructionId', isEqualTo: widget.constructionIdFilter);
    }

    // Filtro unificado para status de pagamento
    if (_paymentStatusFilter != null) {
        purchasesQuery = purchasesQuery.where('paymentStatus', isEqualTo: _paymentStatusFilter);
        rentalsQuery = rentalsQuery.where('paymentStatus', isEqualTo: _paymentStatusFilter);
    }
    
    // Filtro para status de material (apenas aluguéis)
    if (_deliveryStatusFilter != null) {
        rentalsQuery = rentalsQuery.where('materialStatus', isEqualTo: _deliveryStatusFilter);
        // Como compras não têm `materialStatus`, a query de compras não é filtrada aqui.
    }

    // Filtro geral (se aplicável a ambos)
    if (_generalStatusFilter != null) {
        purchasesQuery = purchasesQuery.where('status', isEqualTo: _generalStatusFilter);
        // Se o status geral também se aplica a aluguéis, adicione a linha abaixo
        // rentalsQuery = rentalsQuery.where('status', isEqualTo: _generalStatusFilter);
    }

    // Nota: A combinação de filtros pode exigir índices compostos no Firestore.

    final Stream<List<DocumentSnapshot>> combined = ZippedStream(
      [purchasesQuery.snapshots(), rentalsQuery.snapshots()],
      (snapshots) {
        final allDocs = [...(snapshots[0] as QuerySnapshot).docs, ...(snapshots[1] as QuerySnapshot).docs];
        
        // Aplicar filtros que não podem ser feitos no servidor (se necessário)
        final filteredDocs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          if (_deliveryStatusFilter != null && doc.reference.path.contains('purchase_requests')) {
             // Se um filtro de material for aplicado, esconde as compras, pois elas não têm esse status.
             return false;
          }
          return true;
        }).toList();

        filteredDocs.sort((a, b) {
          final aDate = (a.data() as Map<String, dynamic>).containsKey('requestDate') 
              ? (a['requestDate'] as Timestamp?)?.toDate() 
              : (a['createdAt'] as Timestamp?)?.toDate();
          final bDate = (b.data() as Map<String, dynamic>).containsKey('requestDate') 
              ? (b['requestDate'] as Timestamp?)?.toDate() 
              : (b['createdAt'] as Timestamp?)?.toDate();
          return (bDate ?? DateTime(0)).compareTo(aDate ?? DateTime(0));
        });
        return filteredDocs;
      }
    ).asBroadcastStream();

    setState(() {
      _combinedStream = combined;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (widget.constructionIdFilter == null) _buildFilters(),
          Expanded(
            child: StreamBuilder<List<DocumentSnapshot>>(
              stream: _combinedStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Ocorreu um erro: ${snapshot.error}'));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('Nenhuma despesa encontrada.'));

                return ListView(children: snapshot.data!.map((doc) => _buildTrackingCard(context, doc)).toList());
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingCard(BuildContext context, DocumentSnapshot doc) {
    final isPurchase = doc.reference.path.contains('purchase_requests');
    if (isPurchase) {
      return _buildPurchaseCard(context, doc);
    } else {
      return _buildRentalCard(context, doc);
    }
  }
  
  Widget _buildPurchaseCard(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    final status = data['status'] ?? 'N/A';
    
    String getSupplierDisplayName() {
      final legacySupplierName = data['selectedSupplierName'];
      if (legacySupplierName != null) return legacySupplierName;
      final items = data['finalItems'] as List<dynamic>?;
      if (items == null || items.isEmpty) return 'N/A';
      final supplierNames = items.map((item) => item['supplierName'] as String?).toSet();
      supplierNames.removeWhere((name) => name == null);
      if (supplierNames.isEmpty) return 'N/A';
      if (supplierNames.length == 1) return supplierNames.first!;
      return 'Compra Mista (${supplierNames.length})';
    }

    final supplierName = getSupplierDisplayName();
    
    Widget content;
    if (status == 'Solicitado') {
      final items = (data['items'] as List<dynamic>?) ?? [];
      content = Text('Aguardando cotação de ${items.length} itens.');
    } else {
      final startDate = (data['orderCreationDate'] as Timestamp?)?.toDate();
      final endDate = (data['expectedDeliveryDate'] as Timestamp?)?.toDate();
      double progress = 0.0;
      Color progressColor = Colors.grey;

      if (startDate != null && endDate != null) {
        final totalDuration = endDate.difference(startDate).inDays;
        if (totalDuration > 0) {
          final passedDuration = DateTime.now().difference(startDate).inDays;
          progress = (passedDuration / totalDuration).clamp(0.0, 1.0);
        }
        progressColor = DateTime.now().isAfter(endDate) ? Colors.red : Colors.blue;
      }
      if (data['deliveryStatus'] == 'Entregue') {
        progress = 1.0;
        progressColor = Colors.green;
      }
      
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (endDate != null) ...[
            LinearProgressIndicator(value: progress, backgroundColor: Colors.grey[300], color: progressColor),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(DateFormat('dd/MM/yy').format(startDate!)), Text(DateFormat('dd/MM/yy').format(endDate))]),
          ],
          const SizedBox(height: 8),
          Text('Fornecedor: $supplierName'),
          Text('NF: ${data['invoiceNumber'] ?? '-'}'),
          Text('Pag.: ${data['paymentStatus'] ?? '-'} | Entrega: ${data['deliveryStatus'] ?? '-'}'),
        ],
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => PurchaseDetailPage(purchaseRequestId: doc.id))),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('COMPRA - Status: $status', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              content,
            ],
          ),
        ),
      ),
    );

  }
  
  Widget _buildRentalCard(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    final paymentDueDate = (data['paymentDueDate'] as Timestamp?)?.toDate();
    final isOverdue = paymentDueDate != null && paymentDueDate.isBefore(DateTime.now());

    return Card(
      color: isOverdue ? Colors.red[100] : null,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => showDialog(context: context, barrierDismissible: false, builder: (context) => Dialog.fullscreen(child: RentalInvoiceDialog(doc: doc))),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Text('ALUGUEL - Status: ${data['materialStatus'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
               const SizedBox(height: 8),
               Text('Fornecedor: ${data['supplierName'] ?? 'N/A'}'),
               Text('Fatura: ${data['invoiceNumber'] ?? '-'} | Contrato: ${data['contractNumber'] ?? '-'}'),
               Text('Vencimento: ${paymentDueDate != null ? DateFormat('dd/MM/yyyy').format(paymentDueDate) : '-'}'),
               Text('Pagamento: ${data['paymentStatus'] ?? 'Pendente'}'),
               const SizedBox(height: 8),
               Align(
                 alignment: Alignment.centerRight,
                 child: Text(NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(data['totalValue'] ?? 0.0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
               )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
     return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Removido filtro de status geral para simplificar
          TextField(controller: _nfController, decoration: const InputDecoration(labelText: 'Buscar por Nº da Nota Fiscal')),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: DropdownButtonFormField<String>(decoration: const InputDecoration(labelText: 'Status do Pagamento'), value: _paymentStatusFilter, items: ['Pendente', 'Aguardando Pagamento', 'Pago', 'Atrasado'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setState(() { _paymentStatusFilter = v; _deliveryStatusFilter = null; _updateStream(); }))),
              const SizedBox(width: 12),
              Expanded(child: DropdownButtonFormField<String>(decoration: const InputDecoration(labelText: 'Status do Material'), value: _deliveryStatusFilter, items: ['Mat. em Obra', 'Mat. Devolvido'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setState(() { _deliveryStatusFilter = v; _paymentStatusFilter = null; _updateStream(); }))),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nfController.dispose();
    super.dispose();
  }
}


// Helper class to combine and zip streams
class ZippedStream<T> extends Stream<T> {
  final List<Stream<dynamic>> _streams;
  final T Function(List<dynamic>) _zipper;

  ZippedStream(this._streams, this._zipper);

  @override
  StreamSubscription<T> listen(void Function(T)? onData, {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    final subscriptions = <StreamSubscription>[];
    final values = List<dynamic>.filled(_streams.length, null);
    final active = List<bool>.filled(_streams.length, false);
    int completed = 0;

    final controller = StreamController<T>(onCancel: () {
      for (var sub in subscriptions) {
        sub.cancel();
      }
    });

    void onDataEvent(int index, dynamic data) {
      values[index] = data;
      if (!active[index]) {
          active[index] = true;
      }
      if (active.every((a) => a)) { // Check if all streams have emitted at least once
          controller.add(_zipper(List.from(values)));
      }
    }

    void onDoneEvent() {
      completed++;
      if (completed >= _streams.length && !controller.isClosed) {
        controller.close();
      }
    }

    for (int i = 0; i < _streams.length; i++) {
      subscriptions.add(_streams[i].listen(
        (data) => onDataEvent(i, data),
        onError: controller.addError,
        onDone: onDoneEvent,
      ));
    }

    return controller.stream.listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }
}
