import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/note_model.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasReminder = note.reminderDate != null;
    final createdAt = DateFormat('dd/MM/yyyy HH:mm').format(note.createdAt);
    final reminderText = hasReminder
        ? DateFormat('dd/MM/yyyy HH:mm').format(note.reminderDate!)
        : 'Sem lembrete';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      note.title.isEmpty ? '(Sem titulo)' : note.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (hasReminder)
                    Icon(Icons.notifications_active, color: scheme.tertiary),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                note.content.isEmpty ? '(Sem conteudo)' : note.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Criada: $createdAt',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Lembrete: $reminderText',
                style: TextStyle(
                  fontSize: 12,
                  color: hasReminder ? scheme.tertiary : scheme.onSurfaceVariant,
                  fontWeight: hasReminder ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
