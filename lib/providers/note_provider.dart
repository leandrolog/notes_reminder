import 'dart:async';

import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../models/note_model.dart';
import '../services/notification_service.dart';

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

  Future<void> addNote(Note note) async {
    try {
      final inserted = await _databaseHelper.insertNote(note);
      _notes = _sortNotes([..._notes, inserted]);
      notifyListeners();

      if (inserted.id != null && inserted.reminderDate != null) {
        unawaited(_scheduleReminder(inserted));
      }
    } catch (_) {
      rethrow;
    }
  }

  Future<void> updateNote(Note note) async {
    try {
      if (note.id == null) return;

      await _databaseHelper.updateNote(note);

      final index = _notes.indexWhere((n) => n.id == note.id);
      if (index >= 0) {
        _notes[index] = note;
      }
      _notes = _sortNotes(_notes);
      notifyListeners();

      unawaited(_rescheduleReminder(note));
    } catch (_) {
      rethrow;
    }
  }

  Future<void> deleteNote(Note note) async {
    try {
      if (note.id == null) return;

      await _databaseHelper.deleteNote(note.id!);
      unawaited(
        _ignoreNotificationErrors(
          () => NotificationService.instance.cancelNotification(note.id!),
        ),
      );
      _notes.removeWhere((n) => n.id == note.id);
      notifyListeners();
    } catch (_) {
      rethrow;
    }
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

  Future<void> _rescheduleReminder(Note note) async {
    if (note.id == null) return;

    await _ignoreNotificationErrors(
      () => NotificationService.instance.cancelNotification(note.id!),
    );

    if (note.reminderDate != null) {
      await _scheduleReminder(note);
    }
  }

  Future<void> _scheduleReminder(Note note) async {
    if (note.id == null || note.reminderDate == null) return;

    await _ignoreNotificationErrors(
      () => NotificationService.instance.scheduleNotification(
        id: note.id!,
        title: 'Lembrete de Nota',
        body: note.title.isEmpty ? '(Sem titulo)' : note.title,
        scheduledDate: note.reminderDate!,
      ),
    );
  }

  Future<void> _ignoreNotificationErrors(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // The note reminder remains saved even if Android blocks scheduling.
    }
  }
}
