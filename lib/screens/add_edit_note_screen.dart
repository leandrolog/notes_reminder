import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/note_model.dart';
import '../providers/note_provider.dart';
import '../widgets/custom_textfield.dart';

class AddEditNoteScreen extends StatefulWidget {
  final Note? note;

  const AddEditNoteScreen({super.key, this.note});

  @override
  State<AddEditNoteScreen> createState() => _AddEditNoteScreenState();
}

class _AddEditNoteScreenState extends State<AddEditNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;

  DateTime? _selectedReminder;
  bool _isSaving = false;

  bool get _isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
    _selectedReminder = widget.note?.reminderDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickReminderDateTime() async {
    final now = DateTime.now();
    final initialDate = _selectedReminder ?? now;

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 10),
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedReminder ?? now),
    );

    if (time == null) return;

    final reminder = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    if (reminder.isBefore(now)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione uma data/hora futura.')),
      );
      return;
    }

    setState(() => _selectedReminder = reminder);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedReminder != null &&
        _selectedReminder!.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao e permitido lembrete em data passada.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final note = Note(
        id: widget.note?.id,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        reminderDate: _selectedReminder,
        createdAt: widget.note?.createdAt ?? now,
        updatedAt: now,
      );

      final provider = context.read<NoteProvider>();
      if (_isEditing) {
        await provider.updateNote(note);
      } else {
        await provider.addNote(note);
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao salvar nota. Tente novamente.')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    if (!_isEditing || widget.note == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir nota'),
        content: const Text('Tem certeza que deseja excluir esta nota?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      await context.read<NoteProvider>().deleteNote(widget.note!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nota excluida.')),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao excluir nota. Tente novamente.')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reminderLabel = _selectedReminder == null
        ? 'Sem lembrete'
        : DateFormat('dd/MM/yyyy HH:mm').format(_selectedReminder!);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Nota' : 'Nova Nota'),
        actions: [
          if (_isEditing)
            IconButton(
              onPressed: _isSaving ? null : _delete,
              tooltip: 'Excluir',
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B1020), Color(0xFF121B35), Color(0xFF1C1130)],
          ),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              CustomTextField(
                controller: _titleController,
                label: 'Titulo',
                hint: 'Digite o titulo da nota',
                maxLines: 1,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _contentController,
                label: 'Conteudo',
                hint: 'Digite o conteudo da nota',
                maxLines: 6,
                validator: (value) {
                  final title = _titleController.text.trim();
                  final content = value?.trim() ?? '';
                  if (title.isEmpty && content.isEmpty) {
                    return 'Informe titulo ou conteudo.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Lembrete'),
                  subtitle: Text(reminderLabel),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: _pickReminderDateTime,
                        icon: const Icon(Icons.calendar_month_outlined),
                      ),
                      IconButton(
                        onPressed: _selectedReminder == null
                            ? null
                            : () => setState(() => _selectedReminder = null),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isEditing && widget.note?.reminderDate != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Horario salvo: ${DateFormat('dd/MM/yyyy HH:mm').format(widget.note!.reminderDate!)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_isEditing ? 'Atualizar' : 'Salvar'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
