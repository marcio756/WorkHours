// lib/data/providers/database_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:work_hours_tracker/data/local/database.dart';

// Este provider agora é global e acessível por todas as features (Calendário, Stats, Settings)
final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());