import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gestao_obras/features/approvals/approval_detail_page.dart';
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
  String? _processStatusFilter;
  String? _paymentStatusFilter;
  String? _deliveryStatusFilter;
  String? _constructionFilter;
  String? _approvalStatusFilter; // Novo filtro
  late Stream<List<DocumentSnapshot>> _combinedStream;

  @override
  void initState() {
    super.initState();
    _constructionFilter = widget.constructionIdFilter;
    _combinedStream = const Stream.empty();
    _updateStream();
  }

  void _updateStream() {
    Query purchasesQuery = FirebaseFirestore.instance.collection('purchase_requests');
    Query rentalsQuery = FirebaseFirestore.instance.collection('rental_invoices');

    if (_constructionFilter != null) {
      purchasesQuery = purchasesQuery.where('constructionId', isEqualTo: _constructionFilter);
      rentalsQuery = rentalsQuery.where('constructionId', isEqualTo: _constructionFilter);
    }
    
    if (_approvalStatusFilter != null) {
      purchasesQuery = purchasesQuery.where('approvalStatus', isEqualTo: _approvalStatusFilter);
      rentalsQuery = rentalsQuery.where('approvalStatus', isEqualTo: _approvalStatusFilter);
    }

    if (_processStatusFilter != null && _processStatusFilter != 'Em atraso') {
      purchasesQuery = purchasesQuery.where('processStatus', isEqualTo: _processStatusFilter);
      rentalsQuery = rentalsQuery.where('processStatus', isEqualTo: _processStatusFilter);
    }

    if (_paymentStatusFilter != null) {
      purchasesQuery = purchasesQuery.where('paymentStatus', isEqualTo: _paymentStatusFilter);
      rentalsQuery = rentalsQuery.where('paymentStatus', isEqualTo: _paymentStatusFilter);
    }
    
    if (_deliveryStatusFilter != null) {
      purchasesQuery = purchasesQuery.where('deliveryStatus', isEqualTo: _deliveryStatusFilter);
      rentalsQuery = rentalsQuery.where('materialStatus', isEqualTo: _deliveryStatusFilter);
    }

    final Stream<List<DocumentSnapshot>> combined = ZippedStream(
      [purchasesQuery.snapshots(), rentalsQuery.snapshots()],
      (snapshots) {
        final allDocs = [...(snapshots[0] as QuerySnapshot).docs, ...(snapshots[1] as QuerySnapshot).docs];
        
        List<DocumentSnapshot> filteredDocs = allDocs;

        if (_processStatusFilter == 'Em atraso') {
          filteredDocs = allDocs.where((doc) {
            final data = doc.data()! as Map<String, dynamic>;
            final deadline = (data['deadlineDate'] as Timestamp?)?.toDate();
            final paymentDueDate = (data['paymentDueDate'] as Timestamp?)?.toDate();
            final processStatus = data['processStatus'];
            final paymentStatus = data['paymentStatus'];
            
            bool isOverdue = false;
            if (doc.reference.path.contains('purchase_requests')) {
                isOverdue = deadline != null && DateTime.now().isAfter(deadline) && processStatus != 'Finalizada';
            } else { 
                isOverdue = paymentDueDate != null && DateTime.now().isAfter(paymentDueDate) && paymentStatus != 'Pago';
            }
            return isOverdue;
          }).toList();
        }

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
                if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('Nenhuma despesa encontrada para os filtros selecionados.'));

                return SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Aprovação')),
                        DataColumn(label: Text('Tipo')),
                        DataColumn(label: Text('Fornecedor')),
                        DataColumn(label: Text('Valor')),
                        DataColumn(label: Text('Cond. Pag.')),
                        DataColumn(label: Text('Status Processo')),
                        DataColumn(label: Text('Status Pag.')),
                        DataColumn(label: Text('Status Mat./Entrega')),
                        DataColumn(label: Text('Prazo/Venc.')),
                      ],
                      rows: snapshot.data!.map((doc) => _buildDataRow(context, doc)).toList(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  DataRow _buildDataRow(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    final isPurchase = doc.reference.path.contains('purchase_requests');

    String type = isPurchase ? 'Compra' : 'Aluguel';
    String supplier = data['supplierName'] ?? data['selectedSupplierName'] ?? 'N/A';
    String value = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(data['totalValue'] ?? data['totalPrice'] ?? 0.0);
    
    String paymentConditionString = data['paymentCondition'] ?? '-';
    if(paymentConditionString == 'Boleto') {
      final installments = (data['paymentInstallments'] as List<dynamic>?)?.length ?? 1;
      paymentConditionString = 'Boleto ${installments}x';
    }
    
    final approvalStatus = data['approvalStatus'] ?? 'Aprovado';
    Color approvalColor;
    switch (approvalStatus) {
      case 'Rejeitado':
        approvalColor = Colors.red.shade100;
        break;
      case 'Aguardando Aprovação':
        approvalColor = Colors.amber.shade100;
        break;
      default: // Aprovado
        approvalColor = Colors.green.shade100;
        break;
    }

    String processStatus = data['processStatus'] ?? 'Aberto';
    final deadline = (data['deadlineDate'] as Timestamp?)?.toDate();
    final paymentDueDate = (data['paymentDueDate'] as Timestamp?)?.toDate();
    final paymentStatus = data['paymentStatus'];

    bool isOverdue = false;
    if (isPurchase) {
        isOverdue = deadline != null && DateTime.now().isAfter(deadline) && processStatus != 'Finalizada';
    } else { 
        isOverdue = paymentDueDate != null && DateTime.now().isAfter(paymentDueDate) && paymentStatus != 'Pago';
    }
    if(isOverdue) processStatus = 'Em atraso';

    Color processColor;
    switch (processStatus) {
      case 'Em atraso':
        processColor = Colors.red.shade100;
        break;
      case 'Finalizada':
        processColor = Colors.green.shade100;
        break;
      default:
        processColor = Colors.amber.shade100;
        break;
    }

    String paymentStatusDisplay = data['paymentStatus'] ?? (isPurchase ? '-' : 'Pendente');
    String materialStatus = data['materialStatus'] ?? data['deliveryStatus'] ?? '-';
    DateTime? dueDate = isPurchase ? deadline : paymentDueDate;
    String dueDateString = dueDate != null ? DateFormat('dd/MM/yyyy').format(dueDate) : '-';

    return DataRow(
      color: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
        if (isOverdue) return Colors.red.withOpacity(0.1);
        return null; 
      }),
      cells: [
        DataCell(Chip(label: Text(approvalStatus), backgroundColor: approvalColor, padding: EdgeInsets.zero, visualDensity: VisualDensity.compact)),
        DataCell(Text(type)),
        DataCell(Text(supplier)),
        DataCell(Text(value)),
        DataCell(Text(paymentConditionString)),
        DataCell(Chip(label: Text(processStatus), backgroundColor: processColor, padding: EdgeInsets.zero, visualDensity: VisualDensity.compact)),
        DataCell(Text(paymentStatusDisplay)),
        DataCell(Text(materialStatus)),
        DataCell(Text(dueDateString)),
      ],
      onSelectChanged: (isSelected) {
        if (isSelected ?? false) {
           if (approvalStatus == 'Aguardando Aprovação') {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => ApprovalDetailPage(document: doc)));
           } else if (isPurchase) {
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => PurchaseDetailPage(purchaseRequestId: doc.id)));
          } else {
            showDialog(context: context, barrierDismissible: false, builder: (context) => Dialog.fullscreen(child: RentalInvoiceDialog(doc: doc)));
          }
        }
      },
    );
  }

  Widget _buildFilters() {
     return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('constructions').orderBy('name').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final items = snapshot.data!.docs.map((doc) {
                return DropdownMenuItem<String>(value: doc.id, child: Text((doc.data() as Map<String,dynamic>)['name']));
              }).toList();
              return DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Filtrar por Obra'),
                value: _constructionFilter,
                items: items,
                onChanged: (v) => setState(() { _constructionFilter = v; _updateStream(); }),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: DropdownButtonFormField<String>(decoration: const InputDecoration(labelText: 'Status da Aprovação'), value: _approvalStatusFilter, items: ['Aguardando Aprovação', 'Aprovado', 'Rejeitado'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setState(() { _approvalStatusFilter = v; _updateStream(); }))),
            const SizedBox(width: 12),
            Expanded(child: DropdownButtonFormField<String>(decoration: const InputDecoration(labelText: 'Status do Processo'), value: _processStatusFilter, items: ['Aberto', 'Em processo', 'Finalizada', 'Em atraso'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setState(() { _processStatusFilter = v; _updateStream(); }))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: DropdownButtonFormField<String>(decoration: const InputDecoration(labelText: 'Status do Pagamento'), value: _paymentStatusFilter, items: ['Pendente', 'Aguardando Pagamento', 'Pago', 'Atrasado'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setState(() { _paymentStatusFilter = v; _updateStream(); }))),
            const SizedBox(width: 12),
            Expanded(child: DropdownButtonFormField<String>(decoration: const InputDecoration(labelText: 'Status do Material/Entrega'), value: _deliveryStatusFilter, items: ['Mat. em Obra', 'Mat. Devolvido', 'Aguardando Entrega', 'Entregue', 'Em Trânsito', 'Retirar Material'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setState(() { _deliveryStatusFilter = v; _updateStream(); }))),
          ])
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}


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
      if (active.every((a) => a)) {
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
