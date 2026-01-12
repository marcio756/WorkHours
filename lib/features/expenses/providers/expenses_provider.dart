// lib/features/expenses/providers/expenses_provider.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:work_hours_tracker/data/local/database.dart';
import 'package:work_hours_tracker/core/utils/date_utils_helper.dart';
import 'package:work_hours_tracker/data/providers/database_provider.dart';
import 'package:drift/drift.dart' as drift;

class ExpensesState {
  final DateTime currentMonth;
  final List<Expense> expenses;
  final List<Product> products;
  final double totalSpent;

  ExpensesState({
    required this.currentMonth,
    this.expenses = const [],
    this.products = const [],
    this.totalSpent = 0.0,
  });

  ExpensesState copyWith({
    DateTime? currentMonth,
    List<Expense>? expenses,
    List<Product>? products,
    double? totalSpent,
  }) {
    return ExpensesState(
      currentMonth: currentMonth ?? this.currentMonth,
      expenses: expenses ?? this.expenses,
      products: products ?? this.products,
      totalSpent: totalSpent ?? this.totalSpent,
    );
  }
}

class ExpensesViewModel extends StateNotifier<ExpensesState> {
  final AppDatabase _db;
  
  StreamSubscription<List<Expense>>? _expensesSubscription;
  StreamSubscription<List<Product>>? _productsSubscription;

  ExpensesViewModel(this._db) : super(ExpensesState(currentMonth: DateTime.now())) {
    _initStreams();
  }

  @override
  void dispose() {
    _expensesSubscription?.cancel();
    _productsSubscription?.cancel();
    super.dispose();
  }

  void _initStreams() {
    // 1. Produtos
    _productsSubscription?.cancel();
    _productsSubscription = _db.select(_db.products).watch().listen((productsList) {
      // Ordenar e criar NOVA lista para garantir que o StateNotifier deteta a mudança
      final sorted = List<Product>.of(productsList)..sort((a, b) => a.name.compareTo(b.name));
      
      state = state.copyWith(products: sorted);
    });

    // 2. Despesas
    _updateExpensesStream();
  }

  void _updateExpensesStream() {
    _expensesSubscription?.cancel();

    final start = DateTime(state.currentMonth.year, state.currentMonth.month, 1);
    final end = DateTime(state.currentMonth.year, state.currentMonth.month + 1, 0);

    _expensesSubscription = _db.watchExpensesBetween(
      DateUtilsHelper.toIsoDate(start),
      DateUtilsHelper.toIsoDate(end),
    ).listen((expensesList) {
      final total = expensesList.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
      
      // Criar nova lista explicitamente
      state = state.copyWith(
        expenses: List.of(expensesList), 
        totalSpent: total,
      );
    });
  }

  void changeMonth(int monthsToAdd) {
    final newDate = DateTime(
      state.currentMonth.year,
      state.currentMonth.month + monthsToAdd,
    );
    // Atualiza se o mês mudar
    if (newDate.year != state.currentMonth.year || newDate.month != state.currentMonth.month) {
      state = state.copyWith(currentMonth: newDate);
      _updateExpensesStream();
    }
  }

  // --- CRUD ---

  Future<void> saveProduct({required String name, required double price, int? id}) async {
    final companion = ProductsCompanion(
      id: id != null ? drift.Value(id) : const drift.Value.absent(),
      name: drift.Value(name),
      defaultPrice: drift.Value(price),
    );
    await _db.into(_db.products).insertOnConflictUpdate(companion);
  }

  Future<void> deleteProduct(Product product) async {
    await _db.delete(_db.products).delete(product);
  }

  Future<void> addExpense(Product product, int quantity, double price) async {
    final now = DateTime.now();
    // Se estiver no mês atual, usa hoje. Se não, usa dia 1 do mês visualizado.
    final isViewingCurrentMonth = now.year == state.currentMonth.year && now.month == state.currentMonth.month;
    final dateToSave = isViewingCurrentMonth ? now : DateTime(state.currentMonth.year, state.currentMonth.month, 1);

    final expense = ExpensesCompanion.insert(
      date: DateUtilsHelper.toIsoDate(dateToSave),
      productId: drift.Value(product.id),
      name: product.name,
      price: price,
      quantity: quantity,
    );
    await _db.into(_db.expenses).insert(expense);
  }

  Future<void> deleteExpense(Expense expense) async {
    await _db.delete(_db.expenses).delete(expense);
  }
}

final expensesProvider = StateNotifierProvider<ExpensesViewModel, ExpensesState>((ref) {
  return ExpensesViewModel(ref.watch(databaseProvider));
});