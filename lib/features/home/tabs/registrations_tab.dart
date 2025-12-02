import 'package:controle_compras/features/construction/construction_page.dart';
import 'package:controle_compras/features/cost_center/cost_center_page.dart';
import 'package:controle_compras/features/product/product_page.dart';
import 'package:controle_compras/features/supplier/supplier_page.dart';
import 'package:flutter/material.dart';

class RegistrationsTab extends StatelessWidget {
  const RegistrationsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 0,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Fornecedor'),
              Tab(text: 'Produtos'),
              Tab(text: 'Obras'),
              Tab(text: 'Centro de Custo'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            SupplierPage(),
            ProductPage(),
            ConstructionPage(),
            CostCenterPage(),
          ],
        ),
      ),
    );
  }
}
