import 'package:ticktrack/models/note/note_api_model.dart';
import 'package:flutter/material.dart';

class NotesPreviewWidget extends StatefulWidget {
  const NotesPreviewWidget(
      {super.key,
      required this.themeMode,
      required this.onPressed,
      required this.notes,
      required this.isLoading});
  final ThemeMode themeMode;
  final List<Note> notes;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  State<NotesPreviewWidget> createState() => _NotesPreviewWidgetState();
}

class _NotesPreviewWidgetState extends State<NotesPreviewWidget> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2.0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .secondaryHeaderColor
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context)
                              .secondaryHeaderColor
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(
                        Icons.note_alt,
                        color: Theme.of(context).secondaryHeaderColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Notizen',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .secondaryHeaderColor
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context)
                          .secondaryHeaderColor
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    '${widget.notes.length}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).secondaryHeaderColor,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (widget.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (widget.notes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Text(
                  'Keine Notizen vorhanden',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                ),
              )
            else
              ...widget.notes.take(5).map((note) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      children: [
                        Icon(Icons.sticky_note_2_outlined,
                            size: 20, color: Colors.grey.shade400),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            note.title,
                            style: Theme.of(context).textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  )),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: widget.onPressed,
                child: Text(
                  'Mehr anzeigen',
                  style: TextStyle(
                    color: Theme.of(context).secondaryHeaderColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
