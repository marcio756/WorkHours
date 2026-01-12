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

    final dateStr = DateFormat('MMMM yyyy', 'pt_PT').format(state.currentMonth);
    final capitalizedTitle = dateStr.replaceFirst(dateStr[0], dateStr[0].toUpperCase());

    return Scaffold(
      appBar: AppBar(title: const Text("Gestão de Despesas")),
      body: Column(
        children: [
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

  // --- LÓGICA DE ARREDONDAMENTO NO TOTAL ---
  
  // Arredonda para o 0.50 mais próximo (ex: 11.92 -> 12.0, 0.96 -> 1.0)
  // Se for muito baixo (ex: 0.12), mantém original
  double _roundValue(double value) {
    double rounded = (value * 2).round() / 2.0;
    if (rounded == 0.0) return value;
    return rounded;
  }

  void _showBuyDialog(BuildContext context, ExpensesViewModel viewModel, Product product) {
    final qtyCtrl = TextEditingController(text: "1");
    final priceCtrl = TextEditingController(text: product.defaultPrice.toString());
    
    // Variável para o Switch
    bool useRounding = true; 

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final qty = int.tryParse(qtyCtrl.text) ?? 1;
          final rawUnitPrice = double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0.0;
          
          // Cálculo: Preço Bruto = Unitário * Quantidade
          final rawTotal = rawUnitPrice * qty;
          
          // Cálculo: Preço Final (Arredondado ou não)
          final finalTotal = useRounding ? _roundValue(rawTotal) : rawTotal;

          return AlertDialog(
            title: Text("Comprar: ${product.name}"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: qtyCtrl, 
                  decoration: const InputDecoration(labelText: "Quantidade", prefixIcon: Icon(Icons.numbers)), 
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}) // Atualizar cálculos
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceCtrl, 
                  decoration: const InputDecoration(labelText: "Preço Unitário (€)", prefixIcon: Icon(Icons.euro)), 
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}) // Atualizar cálculos
                ),
                const SizedBox(height: 16),
                
                // Switch de Arredondamento
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Arredondar Total?", style: TextStyle(fontWeight: FontWeight.bold)),
                    Switch(
                      value: useRounding,
                      onChanged: (val) => setState(() => useRounding = val)
                    )
                  ],
                ),
                
                // PREVIEW DO TOTAL
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: rawTotal != finalTotal ? Colors.amber.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Total Bruto:"),
                          Text("${rawTotal.toStringAsFixed(2)} €", style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Total Final:", style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            "${finalTotal.toStringAsFixed(2)} €",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: rawTotal != finalTotal ? Colors.amber[800] : Colors.green[800],
                              fontSize: 18
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (rawTotal != finalTotal)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text("(Arredondado para o 0.50€ mais próximo)", style: TextStyle(fontSize: 10, color: Colors.grey)),
                  )
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
              FilledButton(
                onPressed: () {
                  // Para que o Total bata certo na base de dados, recalculamos o preço unitário
                  // Novo Unitário = Total Final / Quantidade
                  final effectiveUnitPrice = qty > 0 ? (finalTotal / qty) : 0.0;

                  viewModel.addExpense(product, qty, effectiveUnitPrice);
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