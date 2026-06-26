import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../models/note_model.dart';
import '../services/notification_service.dart';

/// Outcome of scheduling a reminder while saving a note.
enum ReminderStatus {
  /// The note had no reminder, so nothing was scheduled.
  none,

  /// The reminder was scheduled as an exact alarm.
  scheduled,

  /// The reminder was scheduled, but only as an inexact alarm because the OS
  /// blocks exact alarms. It still fires, but may be delayed a few minutes —
  /// the UI can offer to enable the exact-alarm permission.
  scheduledInexact,

  /// The note was saved, but the reminder could not be scheduled
  /// (for example, the OS denied the alarm/notification permission).
  failed,
}

class NoteProvider extends ChangeNotifier {
  final DatabaseHelper _databaseHelper;

  NoteProvider({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  List<Note> _notes = [];
  bool _isLoading = false;

  List<Note> get notes => List.unmodifiable(_notes);
  bool get isLoading => _isLoading;

  Future<void> loadNotes() async {
    _setLoading(true);
    try {
      final loadedNotes = await _databaseHelper.getAllNotes();
      _notes = _sortNotes(loadedNotes);
    } catch (_) {
      _notes = [];
    } finally {
      _setLoading(false);
    }
  }

  /// Inserts a new note. The database write is awaited (a failure here is a real
  /// save error and is rethrown), while the reminder scheduling can only affect
  /// the returned [ReminderStatus] — it never breaks the save.
  Future<ReminderStatus> addNote(Note note) async {
    final inserted = await _databaseHelper.insertNote(note);
    _notes = _sortNotes([..._notes, inserted]);
    notifyListeners();

    return _syncReminder(inserted);
  }

  /// Updates an existing note and re-syncs its reminder.
  Future<ReminderStatus> updateNote(Note note) async {
    if (note.id == null) return ReminderStatus.none;

    await _databaseHelper.updateNote(note);

    final index = _notes.indexWhere((n) => n.id == note.id);
    if (index >= 0) {
      _notes[index] = note;
    }
    _notes = _sortNotes(_notes);
    notifyListeners();

    return _syncReminder(note);
  }

  Future<void> deleteNote(Note note) async {
    if (note.id == null) return;

    await _databaseHelper.deleteNote(note.id!);
    await NotificationService.instance.cancelNotification(note.id!);
    _notes.removeWhere((n) => n.id == note.id);
    notifyListeners();
  }

  Future<void> searchNotes(String query) async {
    _setLoading(true);
    try {
      if (query.trim().isEmpty) {
        await loadNotes();
        return;
      }
      final result = await _databaseHelper.searchNotes(query.trim());
      _notes = _sortNotes(result);
    } catch (_) {
      _notes = [];
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  List<Note> _sortNotes(List<Note> items) {
    final sorted = [...items];
    sorted.sort((a, b) {
      if (a.reminderDate != null && b.reminderDate != null) {
        final reminderCompare = a.reminderDate!.compareTo(b.reminderDate!);
        if (reminderCompare != 0) return reminderCompare;
      }

      if (a.reminderDate != null && b.reminderDate == null) return -1;
      if (a.reminderDate == null && b.reminderDate != null) return 1;

      return b.createdAt.compareTo(a.createdAt);
    });
    return sorted;
  }

  /// Cancels any previously scheduled reminder for the note and schedules a new
  /// one when a reminder date is set. Always safe to call: notification errors
  /// are turned into a [ReminderStatus.failed] instead of being thrown, so the
  /// note stays saved even if the OS blocks scheduling.
  Future<ReminderStatus> _syncReminder(Note note) async {
    if (note.id == null) return ReminderStatus.none;

    // Cancel the old reminder first so edits/removals don't fire stale alarms.
    await NotificationService.instance.cancelNotification(note.id!);

    if (note.reminderDate == null) return ReminderStatus.none;

    final outcome = await NotificationService.instance.scheduleNotification(
      id: note.id!,
      title: 'Lembrete de Nota',
      body: note.title.isEmpty ? '(Sem titulo)' : note.title,
      scheduledDate: note.reminderDate!,
    );

    return switch (outcome) {
      ScheduleOutcome.exact => ReminderStatus.scheduled,
      ScheduleOutcome.inexact => ReminderStatus.scheduledInexact,
      ScheduleOutcome.failed => ReminderStatus.failed,
    };
  }
}
