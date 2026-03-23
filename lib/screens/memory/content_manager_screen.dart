import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../utils/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ContentManagerScreen — Admin CSV import for memory_items
// ─────────────────────────────────────────────────────────────────────────────

class ContentManagerScreen extends StatefulWidget {
  final UserModel user;
  const ContentManagerScreen({super.key, required this.user});

  @override
  State<ContentManagerScreen> createState() => _ContentManagerScreenState();
}

class _ContentManagerScreenState extends State<ContentManagerScreen> {
  final _db = FirebaseFirestore.instance;
  List<_CsvRow> _validRows = [];
  List<String> _errorRows = [];
  bool _parsedCsv = false;
  bool _importing = false;
  int _importedCount = 0;

  // ── CSV Parsing ────────────────────────────────────────────────────────────
  void _parseCsv(String raw) {
    final lines = raw.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final valid = <_CsvRow>[];
    final errors = <String>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final cells = _parseCsvLine(line);

      if (cells.length < 5) {
        errors.add('Row ${i + 1}: Not enough columns');
        continue;
      }

      final cycle = cells[0].trim();
      final subject = cells[1].trim();
      final unitNumber = int.tryParse(cells[2].trim());
      final unitType = cells[3].trim();
      final contentType = cells.length > 4 ? cells[4].trim() : '';
      final questionText = cells.length > 5 ? cells[5].trim() : '';
      final contentText = cells.length > 6 ? cells[6].trim() : '';

      if (unitNumber == null) {
        errors.add('Row ${i + 1}: Invalid unit_number "${cells[2]}"');
        continue;
      }

      // Skip review/break rows (no content needed)
      if (unitType == 'review' || unitType == 'break') {
        // Valid, but no memory_item needed
        continue;
      }

      if (contentType.isEmpty) {
        errors.add('Row ${i + 1}: content_type required for content rows');
        continue;
      }
      if (contentText.isEmpty) {
        errors.add('Row ${i + 1}: content_text required');
        continue;
      }
      if (contentType == 'A' && questionText.isEmpty) {
        errors.add(
            'Row ${i + 1}: question_text required for Type A content rows');
        continue;
      }

      valid.add(_CsvRow(
        cycle: cycle,
        subject: subject,
        unitNumber: unitNumber,
        unitType: unitType,
        contentType: contentType,
        questionText: questionText.isEmpty ? null : questionText,
        contentText: contentText,
        sungFilename: cells.length > 7 ? cells[7].trim() : '',
        spokenFilename: cells.length > 8 ? cells[8].trim() : '',
        pdfFilename: cells.length > 9 ? cells[9].trim() : '',
      ));
    }

    setState(() {
      _validRows = valid;
      _errorRows = errors;
      _parsedCsv = true;
    });
  }

  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    bool inQuotes = false;
    StringBuffer current = StringBuffer();

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(current.toString());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }
    result.add(current.toString());
    return result;
  }

  Future<void> _importRows() async {
    setState(() {
      _importing = true;
      _importedCount = 0;
    });

    int count = 0;

    for (final row in _validRows) {
      final unitId = '${row.cycle}_unit_${row.unitNumber.toString().padLeft(2, '0')}';

      // Upsert unit document
      await _db.collection('units').doc(unitId).set({
        'unit_number': row.unitNumber,
        'unit_type': row.unitType,
        'cycle_id': row.cycle,
        'label': 'Unit ${row.unitNumber}',
      }, SetOptions(merge: true));

      // Upsert memory_item
      final itemId = '${row.cycle}_${row.subject}_unit_${row.unitNumber.toString().padLeft(2, '0')}';
      await _db.collection('memory_items').doc(itemId).set({
        'subject_id': row.subject,
        'unit_id': unitId,
        'cycle_id': row.cycle,
        'question_text': row.questionText,
        'content_text': row.contentText,
        'content_type': row.contentType,
        'sung_audio_url': null, // populated by AudioManager
        'spoken_audio_url': null,
        'timeline_full_song_url': null,
        'cloze_overrides': null,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      count++;
    }

    if (mounted) {
      setState(() {
        _importing = false;
        _importedCount = count;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported $count memory items successfully')),
      );
    }
  }

  void _showPasteDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Paste CSV Content'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            maxLines: 10,
            decoration: const InputDecoration(
              hintText:
                  'Paste your CSV rows here...\ncycle,subject,unit_number,...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _parseCsv(controller.text);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.navy),
            child: const Text('Parse', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        title: const Text('Content Manager'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // CSV format reference
          Card(
            color: AppTheme.navy.withValues(alpha: 0.05),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CSV Column Format',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.navy)),
                  const SizedBox(height: 6),
                  const Text(
                    'cycle, subject, unit_number, unit_type, content_type,\n'
                    'question_text, content_text, sung_filename,\n'
                    'spoken_filename, pdf_filename',
                    style: TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Upload / paste button
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _showPasteDialog,
              icon: const Icon(Icons.paste),
              label: const Text('Paste CSV Content'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.navy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Parse results
          if (_parsedCsv) ...[
            // Errors
            if (_errorRows.isNotEmpty) ...[
              Text(
                '${_errorRows.length} Errors',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: Colors.red),
              ),
              const SizedBox(height: 6),
              ...(_errorRows.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(e,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.red)),
                  ))),
              const SizedBox(height: 12),
            ],

            // Valid preview
            Text(
              '${_validRows.length} Valid Rows',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: Colors.green),
            ),
            const SizedBox(height: 8),
            if (_validRows.isNotEmpty) ...[
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DataTable(
                  columnSpacing: 12,
                  columns: const [
                    DataColumn(label: Text('Subject', style: TextStyle(fontSize: 11))),
                    DataColumn(label: Text('Unit', style: TextStyle(fontSize: 11))),
                    DataColumn(label: Text('Type', style: TextStyle(fontSize: 11))),
                    DataColumn(label: Text('Content', style: TextStyle(fontSize: 11))),
                  ],
                  rows: _validRows.take(10).map((row) {
                    return DataRow(cells: [
                      DataCell(Text(row.subject,
                          style: const TextStyle(fontSize: 11))),
                      DataCell(Text('${row.unitNumber}',
                          style: const TextStyle(fontSize: 11))),
                      DataCell(Text(row.contentType,
                          style: const TextStyle(fontSize: 11))),
                      DataCell(Text(
                        row.contentText.length > 30
                            ? '${row.contentText.substring(0, 30)}...'
                            : row.contentText,
                        style: const TextStyle(fontSize: 11),
                      )),
                    ]);
                  }).toList(),
                ),
              ),
              if (_validRows.length > 10)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '...and ${_validRows.length - 10} more rows',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _importing ? null : _importRows,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _importing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'Confirm Import (${_validRows.length} rows)',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],

            // Import complete
            if (_importedCount > 0) ...[
              const SizedBox(height: 12),
              Text(
                '✅ $_importedCount items imported successfully',
                style: const TextStyle(
                    color: Colors.green, fontWeight: FontWeight.w600),
              ),
            ],
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _CsvRow {
  final String cycle;
  final String subject;
  final int unitNumber;
  final String unitType;
  final String contentType;
  final String? questionText;
  final String contentText;
  final String sungFilename;
  final String spokenFilename;
  final String pdfFilename;

  const _CsvRow({
    required this.cycle,
    required this.subject,
    required this.unitNumber,
    required this.unitType,
    required this.contentType,
    this.questionText,
    required this.contentText,
    required this.sungFilename,
    required this.spokenFilename,
    required this.pdfFilename,
  });
}
