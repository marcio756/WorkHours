// lib/data/local/database.dart

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

/// Tabela de Entradas de Trabalho
class WorkEntries extends Table {
  TextColumn get date => text()(); // ISO8601 String YYYY-MM-DD
  RealColumn get hours => real().withDefault(const Constant(0.0))();
  BoolColumn get isHoliday => boolean().withDefault(const Constant(false))();
  TextColumn get description => text().nullable()();

  @override
  Set<Column> get primaryKey => {date};
}

/// Tabela de Produtos (Template)
class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  RealColumn get defaultPrice => real()();
  IntColumn get defaultQuantity => integer().withDefault(const Constant(1))();
}

/// Tabela de Despesas Reais
class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get date => text()(); // ISO8601 String
  IntColumn get productId => integer().nullable().references(Products, #id)();
  TextColumn get name => text()();
  RealColumn get price => real()();
  IntColumn get quantity => integer()();
}

@DriftDatabase(tables: [WorkEntries, Products, Expenses])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // --- Work Entry Queries ---

  Future<List<WorkEntry>> getAllEntries() => select(workEntries).get();

  Stream<List<WorkEntry>> watchEntriesBetween(String start, String end) {
    return (select(workEntries)
          ..where((t) => t.date.isBetweenValues(start, end)))
        .watch();
  }

  Future<void> saveWorkEntry(WorkEntry entry) {
    return into(workEntries).insertOnConflictUpdate(entry);
  }

  Future<void> deleteEntry(String date) {
    return (delete(workEntries)..where((t) => t.date.equals(date))).go();
  }

  // --- NOVO: Batch Insert para Importação ---
  Future<void> insertBatchWorkEntries(List<WorkEntry> entries) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(workEntries, entries);
    });
  }

  // --- Expense Queries ---

  Stream<List<Expense>> watchExpensesBetween(String start, String end) {
    return (select(expenses)..where((t) => t.date.isBetweenValues(start, end)))
        .watch();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'work_hours.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}