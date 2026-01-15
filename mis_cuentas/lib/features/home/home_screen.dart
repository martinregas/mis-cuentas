import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../core/providers.dart';
import '../../core/models/pdf_import.dart';
import '../import_pdf/import_controller.dart';
import '../import_pdf/debug_extract_screen.dart';
import '../transactions/transaction_list_screen.dart';

final importsProvider = FutureProvider<List<PdfImport>>((ref) async {
  // Watch importController to refresh when new file is imported
  ref.watch(importControllerProvider);
  final db = ref.read(databaseHelperProvider);
  return db.getImports();
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final importsAsync = ref.watch(importsProvider);
    final importState = ref.watch(importControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Cuentas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TransactionListScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['pdf'],
              );
              if (result != null && result.files.single.path != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DebugExtractScreen(
                      file: File(result.files.single.path!),
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildImportCard(context, ref, importState),
            const SizedBox(height: 24),
            Text(
              "Recent Imports",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: importsAsync.when(
                data: (imports) {
                  if (imports.isEmpty) {
                    return const Center(child: Text("No imports yet."));
                  }
                  return ListView.builder(
                    itemCount: imports.length,
                    itemBuilder: (context, index) {
                      final imp = imports[index];
                      return ListTile(
                        leading: const Icon(
                          Icons.picture_as_pdf,
                          color: Colors.redAccent,
                        ),
                        title: Text(imp.fileName),
                        subtitle: Text(
                          DateFormat.yMMMd().format(imp.importDate),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            ref.read(importControllerProvider.notifier).pickAndImportPdf(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildImportCard(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<void> state,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(
              Icons.cloud_upload_outlined,
              size: 48,
              color: Colors.white70,
            ),
            const SizedBox(height: 16),
            Text(
              "Import Bank Statement",
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Select a PDF file to analyze expenses.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 16),
            if (state.isLoading)
              const CircularProgressIndicator()
            else if (state.hasError)
              Text(
                "Error: ${state.error}",
                style: const TextStyle(color: Colors.redAccent),
              )
            else
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => ref
                        .read(importControllerProvider.notifier)
                        .pickAndImportPdf(),
                    icon: const Icon(Icons.upload_file),
                    label: const Text("Select PDFs"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => ref
                        .read(importControllerProvider.notifier)
                        .pickAndImportFolder(),
                    icon: const Icon(Icons.folder_open),
                    label: const Text("Select Folder"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
