import 'package:ticktrack/models/tasklist/task_list_api_model.dart';
import 'package:flutter/material.dart';

class TodoPreviewWidget extends StatefulWidget {
  const TodoPreviewWidget(
      {super.key,
      required this.themeMode,
      required this.onPressed,
      required this.taskLists,
      required this.isLoading});
  final ThemeMode themeMode;
  final VoidCallback onPressed;
  final List<TaskList> taskLists;
  final bool isLoading;

  @override
  State<TodoPreviewWidget> createState() => _TodoPreviewWidgetState();
}

class _TodoPreviewWidgetState extends State<TodoPreviewWidget> {
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
                            .primaryColor
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context)
                              .primaryColor
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(
                        Icons.checklist,
                        color: Theme.of(context).primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Aufgabenlisten',
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
                    color:
                        Theme.of(context).primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          Theme.of(context).primaryColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    '${widget.taskLists.length}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (widget.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (widget.taskLists.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Text(
                  'Keine Aufgabenlisten vorhanden',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                ),
              )
            else
              ...widget.taskLists.take(5).map((taskList) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      children: [
                        Icon(Icons.check_box_outline_blank,
                            size: 20, color: Colors.grey.shade400),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            taskList.name,
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
                    color: Theme.of(context).primaryColor,
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
