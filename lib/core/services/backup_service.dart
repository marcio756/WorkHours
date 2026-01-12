// lib/core/services/backup_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:work_hours_tracker/data/local/database.dart';
import 'package:intl/intl.dart';

class BackupService {
  
  /// Gera um ficheiro JSON com os dados e abre o menu de partilha/guardar.
  Future<void> exportData(List<WorkEntry> entries) async {
    // 1. Converter Entradas para JSON
    final List<Map<String, dynamic>> jsonList = entries.map((e) {
      return {
        "date": e.date,
        "hours": e.hours,
        "isHoliday": e.isHoliday,
        "description": e.description,
      };
    }).toList();

    final jsonString = jsonEncode(jsonList);

    // 2. Criar ficheiro temporário
    final directory = await getApplicationDocumentsDirectory();
    final dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
    final fileName = "backup_horas_$dateStr.json";
    final file = File('${directory.path}/$fileName');

    await file.writeAsString(jsonString);

    // 3. Partilhar o ficheiro (permite guardar no Drive/Downloads)
    await Share.shareXFiles([XFile(file.path)], text: 'Backup Work Hours Tracker');
  }

  /// Abre o explorador de ficheiros e devolve a lista de entradas lida.
  Future<List<WorkEntry>> pickAndParseBackup() async {
    try {
      // 1. Escolher ficheiro
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        
        // 2. Parse JSON
        final List<dynamic> jsonList = jsonDecode(content);
        
        // 3. Converter para objetos WorkEntry
        return jsonList.map((item) {
          return WorkEntry(
            // Assume formato ISO YYYY-MM-DD do teu ficheiro antigo
            date: item['date'], 
            // Trata int ou double (o teu json tem "3" e "3.5")
            hours: (item['hours'] as num).toDouble(), 
            isHoliday: item['isHoliday'] ?? false,
            description: item['description'],
          );
        }).toList();
      }
    } catch (e) {
      throw Exception("Erro ao ler ficheiro: $e");
    }
    return [];
  }
}