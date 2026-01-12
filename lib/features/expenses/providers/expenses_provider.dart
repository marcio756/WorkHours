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
    // 1. Produtos (Stream Automático)
    _productsSubscription?.cancel();
    _productsSubscription = _db.select(_db.products).watch().listen((productsList) {
      final sorted = List<Product>.of(productsList)..sort((a, b) => a.name.compareTo(b.name));
      state = state.copyWith(products: sorted);
    });

    // 2. Despesas (Stream Automático)
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
      state = state.copyWith(
        expenses: List.of(expensesList), 
        totalSpent: total,
      );
    });
  }

  // --- REFRESH MANUAL (A Solução para o Bug) ---
  
  Future<void> _refreshProducts() async {
    final productsList = await _db.select(_db.products).get();
    final sorted = List<Product>.of(productsList)..sort((a, b) => a.name.compareTo(b.name));
    state = state.copyWith(products: sorted);
  }

  Future<void> _refreshExpenses() async {
    final start = DateTime(state.currentMonth.year, state.currentMonth.month, 1);
    final end = DateTime(state.currentMonth.year, state.currentMonth.month + 1, 0);
    
    // Usamos o método do DAO ou construímos a query aqui se o DAO não tiver um método 'get' direto exposto desta forma
    // Como o watchExpensesBetween é uma query customizada, a melhor forma é forçar o stream a emitir ou fazer um get manual similar
    final expensesList = await (_db.select(_db.expenses)
      ..where((t) => t.date.isBetweenValues(
          DateUtilsHelper.toIsoDate(start), 
          DateUtilsHelper.toIsoDate(end)
      ))).get();

    final total = expensesList.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
    state = state.copyWith(
      expenses: List.of(expensesList),
      totalSpent: total
    );
  }

  void changeMonth(int monthsToAdd) {
    final newDate = DateTime(
      state.currentMonth.year,
      state.currentMonth.month + monthsToAdd,
    );
    if (newDate.year != state.currentMonth.year || newDate.month != state.currentMonth.month) {
      state = state.copyWith(currentMonth: newDate);
      _updateExpensesStream();
    }
  }

  // --- CRUD (Com Refresh Forçado) ---

  Future<void> saveProduct({required String name, required double price, int? id}) async {
    final companion = ProductsCompanion(
      id: id != null ? drift.Value(id) : const drift.Value.absent(),
      name: drift.Value(name),
      defaultPrice: drift.Value(price),
    );
    await _db.into(_db.products).insertOnConflictUpdate(companion);
    await _refreshProducts(); // Força atualização visual
  }

  Future<void> deleteProduct(Product product) async {
    await _db.delete(_db.products).delete(product);
    await _refreshProducts(); // Força atualização visual
  }

  Future<void> addExpense(Product product, int quantity, double price) async {
    final now = DateTime.now();
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
    await _refreshExpenses(); // Força atualização visual
  }

  Future<void> deleteExpense(Expense expense) async {
    await _db.delete(_db.expenses).delete(expense);
    await _refreshExpenses(); // Força atualização visual
  }
}

final expensesProvider = StateNotifierProvider<ExpensesViewModel, ExpensesState>((ref) {
  return ExpensesViewModel(ref.watch(databaseProvider));
});