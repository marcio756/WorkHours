// lib/features/expenses/expenses_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:work_hours_tracker/data/local/database.dart';
import 'package:work_hours_tracker/features/expenses/providers/expenses_provider.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(expensesProvider);
    final viewModel = ref.read(expensesProvider.notifier);
    final theme = Theme.of(context);

    // Formatar Título do Mês
    final dateStr = DateFormat('MMMM yyyy', 'pt_PT').format(state.currentMonth);
    final capitalizedTitle = dateStr.replaceFirst(dateStr[0], dateStr[0].toUpperCase());

    return Scaffold(
      appBar: AppBar(title: const Text("Gestão de Despesas")),
      body: Column(
        children: [
          // Seletor de Mês
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.colorScheme.surfaceContainerLow,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton.filledTonal(
                  onPressed: () => viewModel.changeMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  capitalizedTitle,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton.filledTonal(
                  onPressed: () => viewModel.changeMonth(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),

          TabBar(
            controller: _tabController,
            tabs: const [Tab(text: "Despesas"), Tab(text: "Produtos")],
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildExpensesList(state, viewModel, theme),
                _buildProductsList(state, viewModel, theme),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_tabController.index == 1) {
             _showProductDialog(context, viewModel, null);
          } else {
             _tabController.animateTo(1);
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text("Selecione um produto para comprar.")),
             );
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildExpensesList(ExpensesState state, ExpensesViewModel viewModel, ThemeData theme) {
    if (state.expenses.isEmpty) {
      return const Center(child: Text("Sem despesas neste mês.", style: TextStyle(color: Colors.grey)));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("TOTAL GASTO: ", style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onPrimaryContainer)),
                Text("${state.totalSpent.toStringAsFixed(2)} €", style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onPrimaryContainer)),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: state.expenses.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final expense = state.expenses[index];
              return Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainer,
                child: ListTile(
                  title: Text(expense.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${expense.quantity} x ${expense.price.toStringAsFixed(2)} €"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("${(expense.price * expense.quantity).toStringAsFixed(2)} €", style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontSize: 16)),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                        onPressed: () => viewModel.deleteExpense(expense),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductsList(ExpensesState state, ExpensesViewModel viewModel, ThemeData theme) {
    if (state.products.isEmpty) {
      return const Center(child: Text("Crie produtos para começar.", style: TextStyle(color: Colors.grey)));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: state.products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final product = state.products[index];
        return Card(
          elevation: 2,
          child: ListTile(
            title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text("Padrão: ${product.defaultPrice.toStringAsFixed(2)} €"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.filled(
                  icon: const Icon(Icons.shopping_cart),
                  onPressed: () => _showBuyDialog(context, viewModel, product),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showProductDialog(context, viewModel, product),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => viewModel.deleteProduct(product),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showProductDialog(BuildContext context, ExpensesViewModel viewModel, Product? product) {
    final nameCtrl = TextEditingController(text: product?.name ?? "");
    final priceCtrl = TextEditingController(text: product?.defaultPrice.toString() ?? "");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(product != null ? "Editar Produto" : "Novo Produto"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Nome", border: OutlineInputBorder()), textCapitalization: TextCapitalization.sentences),
            const SizedBox(height: 16),
            TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: "Preço Padrão (€)", border: OutlineInputBorder()), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              final price = double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0.0;
              if (nameCtrl.text.isNotEmpty && price > 0) {
                viewModel.saveProduct(name: nameCtrl.text, price: price, id: product?.id);
                Navigator.pop(ctx);
              }
            },
            child: const Text("Guardar"),
          )
        ],
      ),
    );
  }

  // --- LÓGICA DE ARREDONDAMENTO ROBUSTA ---
  double _calculateRoundedPrice(double rawPrice, bool enabled) {
    if (!enabled) return rawPrice;
    
    // Arredonda para o 0.5 mais próximo
    double rounded = (rawPrice * 2).round() / 2.0;
    
    // PROTEÇÃO: Se arredondar para 0.0 (ex: 0.12), IGNORA O ARREDONDAMENTO e devolve o original
    if (rounded == 0.0) return rawPrice;
    
    return rounded;
  }

  void _showBuyDialog(BuildContext context, ExpensesViewModel viewModel, Product product) {
    final qtyCtrl = TextEditingController(text: "1");
    final priceCtrl = TextEditingController(text: product.defaultPrice.toString());
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final rawPrice = double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0.0;
          
          // Switch para o utilizador decidir se quer arredondar
          // Por defeito LIGADO se o preço for > 0.25€ (para evitar o caso dos pães de 0.12)
          bool useRounding = rawPrice > 0.25;

          final finalPrice = _calculateRoundedPrice(rawPrice, useRounding);

          return AlertDialog(
            title: Text("Comprar: ${product.name}"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: qtyCtrl, 
                  decoration: const InputDecoration(labelText: "Quantidade", prefixIcon: Icon(Icons.numbers)), 
                  keyboardType: TextInputType.number
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceCtrl, 
                  decoration: const InputDecoration(labelText: "Preço Unitário (€)", prefixIcon: Icon(Icons.euro)), 
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}) // Atualizar preview ao digitar
                ),
                const SizedBox(height: 12),
                
                // PREVIEW DO PREÇO FINAL
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    // CORREÇÃO DO LINTER: withValues
                    color: rawPrice != finalPrice ? Colors.amber.withValues(alpha: 0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8)
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Preço Final:", style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        "${finalPrice.toStringAsFixed(2)} €",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                
                // Explicação apenas se houver arredondamento
                if (rawPrice != finalPrice)
                  // CORREÇÃO DO LINTER: const Constructor
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      "(Arredondado para 0.50€ mais próximo)", 
                      style: TextStyle(fontSize: 10, color: Colors.grey)
                    ),
                  )
                else if (rawPrice > 0 && rawPrice < 0.25)
                   const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      "(Valor muito baixo, arredondamento desligado)", 
                      style: TextStyle(fontSize: 10, color: Colors.blue)
                    ),
                  )
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
              FilledButton(
                onPressed: () {
                  final qty = int.tryParse(qtyCtrl.text) ?? 1;
                  viewModel.addExpense(product, qty, finalPrice);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Adicionado!")));
                },
                child: const Text("Adicionar"),
              )
            ],
          );
        }
      ),
    );
  }
}