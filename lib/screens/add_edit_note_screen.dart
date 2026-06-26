import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/note_model.dart';
import '../providers/note_provider.dart';
import '../services/notification_service.dart';
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
      final reminderStatus = _isEditing
          ? await provider.updateNote(note)
          : await provider.addNote(note);

      if (!mounted) return;

      // The ScaffoldMessenger lives above this route, so the message keeps
      // showing on the Home screen after we pop back.
      final messenger = ScaffoldMessenger.of(context);
      final errorColor = Theme.of(context).colorScheme.error;
      Navigator.of(context).pop();

      _showReminderSnackBar(messenger, reminderStatus, errorColor);
    } on DatabaseException catch (e) {
      if (!mounted) return;
      _showError(
        'Nao foi possivel salvar a nota no banco de dados.${kDebugMode ? '\n($e)' : ''}',
      );
    } catch (e) {
      if (!mounted) return;
      _showError(
        'Erro inesperado ao salvar a nota. Tente novamente.${kDebugMode ? '\n($e)' : ''}',
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Shows the post-save feedback. When the reminder could only be scheduled
  /// inexactly (or not at all) because of the exact-alarm permission, the
  /// SnackBar offers a "Permitir" action that opens the system "Alarms &
  /// reminders" screen.
  void _showReminderSnackBar(
    ScaffoldMessengerState messenger,
    ReminderStatus status,
    Color errorColor,
  ) {
    final baseMessage =
        _isEditing ? 'Nota atualizada com sucesso.' : 'Nota criada com sucesso.';
    final when = _selectedReminder == null
        ? ''
        : DateFormat('dd/MM/yyyy HH:mm').format(_selectedReminder!);

    final (String message, bool needsExactAlarm) = switch (status) {
      ReminderStatus.scheduled => ('$baseMessage Lembrete agendado para $when.', false),
      ReminderStatus.scheduledInexact => (
          '$baseMessage Lembrete agendado para $when, mas pode atrasar alguns '
              'minutos. Ative "Alarmes e lembretes" para o horario exato.',
          true,
        ),
      ReminderStatus.failed => (
          '$baseMessage Porem o lembrete nao pode ser agendado. Ative a '
              'permissao de alarmes/notificacoes do aplicativo.'
              '\n[diag] ${NotificationService.instance.lastScheduleError ?? "sem detalhe"}',
          true,
        ),
      ReminderStatus.none => (baseMessage, false),
    };

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: status == ReminderStatus.failed ? errorColor : null,
        duration: needsExactAlarm
            ? const Duration(seconds: 8)
            : const Duration(seconds: 4),
        action: needsExactAlarm
            ? SnackBarAction(
                label: 'Permitir',
                onPressed: () {
                  // Opens the system settings screen; safe even if the user
                  // backs out without granting.
                  NotificationService.instance.openExactAlarmsSettings();
                },
              )
            : null,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
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
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Nota excluida com sucesso.')),
      );
    } catch (_) {
      if (!mounted) return;
      _showError('Nao foi possivel excluir a nota. Tente novamente.');
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
