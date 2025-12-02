import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<Map<String, dynamic>> _dashboardData;

  @override
  void initState() {
    super.initState();
    _dashboardData = _fetchDashboardData();
  }

  Future<Map<String, dynamic>> _fetchDashboardData() async {
    final constructionsFuture = FirebaseFirestore.instance.collection('constructions').get();
    final requestsFuture = FirebaseFirestore.instance.collection('purchase_requests').get();

    final results = await Future.wait([constructionsFuture, requestsFuture]);

    final constructions = (results[0] as QuerySnapshot).docs;
    final requests = (results[1] as QuerySnapshot).docs;

    final Map<String, List<DocumentSnapshot>> requestsByConstructionId = {};
    for (var req in requests) {
      // Correção: Garantir que data() é um Map
      final data = req.data() as Map<String, dynamic>; 
      final constructionId = data['constructionId'];
      if (constructionId != null) {
        (requestsByConstructionId[constructionId] ??= []).add(req);
      }
    }

    return {
      'constructions': constructions,
      'requestsByConstructionId': requestsByConstructionId,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dashboardData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro ao carregar dados: ${snapshot.error}'));
          }
          if (!snapshot.hasData || (snapshot.data!['constructions'] as List).isEmpty) {
            return const Center(child: Text('Nenhuma obra cadastrada para exibir o dashboard.'));
          }

          final constructions = snapshot.data!['constructions'] as List<DocumentSnapshot>;
          final requestsByConstructionId = snapshot.data!['requestsByConstructionId'] as Map<String, List<DocumentSnapshot>>;

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _dashboardData = _fetchDashboardData();
              });
            },
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildLegend(),
                const SizedBox(height: 24),
                ...constructions.map((constructionDoc) {
                  final constructionId = constructionDoc.id;
                  final requestsForConstruction = requestsByConstructionId[constructionId] ?? [];
                  return _buildConstructionStatusCard(constructionDoc, requestsForConstruction);
                }).toList(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _buildLegendItem(Colors.amber, 'Solicitado'),
        _buildLegendItem(Colors.blue, 'Pedido Criado'),
        _buildLegendItem(Colors.green, 'Finalizado'),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [Container(width: 16, height: 16, color: color), const SizedBox(width: 8), Text(label)],
    );
  }

  Widget _buildConstructionStatusCard(DocumentSnapshot constructionDoc, List<DocumentSnapshot> requests) {
    final constructionData = constructionDoc.data()! as Map<String, dynamic>;

    int solicitados = 0, pedidosCriados = 0, finalizados = 0;
    for (var req in requests) {
      // Correção: Garantir que data() é um Map
      final data = req.data() as Map<String, dynamic>;
      switch (data['status']) {
        case 'Solicitado': solicitados++; break;
        case 'Pedido Criado': pedidosCriados++; break;
        case 'Finalizado': finalizados++; break;
      }
    }
    final total = solicitados + pedidosCriados + finalizados;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(constructionData['name'] ?? 'Obra sem nome', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (total == 0)
              const Text('Nenhum pedido de compra para esta obra.')
            else
              Column(
                children: [
                  Text('$total pedidos no total'),
                  const SizedBox(height: 8),
                  _buildStatusBar(solicitados, pedidosCriados, finalizados, total),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar(int solicitados, int pedidosCriados, int finalizados, int total) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          if (solicitados > 0) Expanded(flex: solicitados, child: Container(height: 20, color: Colors.amber, child: Center(child: Text(solicitados.toString(), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))))),
          if (pedidosCriados > 0) Expanded(flex: pedidosCriados, child: Container(height: 20, color: Colors.blue, child: Center(child: Text(pedidosCriados.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))),
          if (finalizados > 0) Expanded(flex: finalizados, child: Container(height: 20, color: Colors.green, child: Center(child: Text(finalizados.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))),
        ],
      ),
    );
  }
}
