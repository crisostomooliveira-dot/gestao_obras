import 'package:gestao_obras/features/construction/construction_page.dart';
import 'package:gestao_obras/features/cost_center/cost_center_page.dart';
import 'package:gestao_obras/features/equipment/equipment_page.dart'; // Importa a nova página
import 'package:gestao_obras/features/product/product_page.dart';
import 'package:gestao_obras/features/supplier/supplier_page.dart';
import 'package:flutter/material.dart';

class RegistrationsTab extends StatelessWidget {
  const RegistrationsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5, // Aumenta o número de abas
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Obras'),
              Tab(text: 'Fornecedores'),
              Tab(text: 'Produtos'),
              Tab(text: 'Centros de Custo'),
              Tab(text: 'Equipamentos'), // Nova aba
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                ConstructionPage(),
                SupplierPage(),
                ProductPage(),
                CostCenterPage(),
                EquipmentPage(), // Nova página na visão de abas
              ],
            ),
          ),
        ],
      ),
    );
  }
}
