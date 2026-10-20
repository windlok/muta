import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import 'tasks_view_model.dart';

class AddTaskSheet extends ConsumerStatefulWidget {
  const AddTaskSheet({super.key});

  @override
  ConsumerState<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends ConsumerState<AddTaskSheet> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  DateTime? _dueDate;
  bool _aiAnalyze = true;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.taskTitleRequired)),
      );
      return;
    }
    final title = _title.text.trim();
    final description = _description.text.trim();
    final dueDate = _dueDate;
    final aiAnalyze = _aiAnalyze;

    // Önce kapat, sonra kaydet (modal kapanırken üst ekranın yeniden
    // çizilmesi element yaşam döngüsü hatalarına yol açabiliyor).
    final messenger = ScaffoldMessenger.of(context);
    final viewModel = ref.read(tasksViewModelProvider.notifier);
    Navigator.of(context).pop();
    try {
      await viewModel.addTask(
        title: title,
        description: description,
        dueDate: dueDate,
        aiAnalyze: aiAnalyze,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.saveFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.newTask,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _title,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l.titleLabel,
              hintText: l.taskTitleHint,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _description,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: l.descriptionOptional,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    _dueDate == null
                        ? l.pickDate
                        : '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}',
                  ),
                ),
              ),
              if (_dueDate != null)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _dueDate = null),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.aiPrioritize),
            subtitle: Text(
              l.aiPrioritizeSubtitle,
              style: const TextStyle(fontSize: 12),
            ),
            value: _aiAnalyze,
            onChanged: (v) => setState(() => _aiAnalyze = v),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _save,
            child: Text(l.save),
          ),
        ],
      ),
    );
  }
}
