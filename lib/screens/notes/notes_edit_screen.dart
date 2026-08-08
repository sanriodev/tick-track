// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';

import 'package:image_picker/image_picker.dart';
import 'package:ticktrack/backend/service/backend_service.dart';
import 'package:ticktrack/state/note_attachment_store.dart';
import 'package:ticktrack/util/markdown_editing.dart';
import 'package:ticktrack/util/markdown_helper.dart';
import 'package:ticktrack/widgets/note/markdown_toolbar.dart';
import 'package:ticktrack/widgets/note/note_markdown_view.dart';
import 'package:ticktrack/enum/privacy_mode_enum.dart';
import 'package:ticktrack/models/note/note_api_model.dart';
import 'package:ticktrack/models/note/dto/update_note_dto.dart';
import 'package:ticktrack/state/group_context.dart';
import 'package:ticktrack/util/haptics.dart';
import 'package:ticktrack/util/helpers.dart';
import 'package:ticktrack/util/share_helper.dart';
import 'package:ticktrack/widgets/app_drawer_widget.dart';
import 'package:ticktrack/widgets/group/group_context_switcher.dart';
import 'package:blvckleg_dart_core/exception/session_expired.dart';
import 'package:blvckleg_dart_core/service/auth_backend_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

const Duration _autosaveDelay = Duration(milliseconds: 900);

enum _SaveState { idle, unsaved, saving, saved, failed }

enum _EditorMode { write, preview }

class NotesEditScreen extends StatefulWidget {
  const NotesEditScreen({super.key});

  @override
  State<NotesEditScreen> createState() => _NotesEditScreenState();
}

class _NotesEditScreenState extends State<NotesEditScreen> {
  final TextEditingController _commentController = TextEditingController();
  late int id;
  Note? note;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _initialized = false;

  Timer? _autosaveTimer;
  _SaveState _saveState = _SaveState.idle;

  _EditorMode _mode = _EditorMode.preview;
  bool _uploadingImage = false;
  String _lastKnownText = '';

  String _savedContent = '';

  bool get _hasUnsavedChanges => _commentController.text != _savedContent;

  bool get _isEditable =>
      note != null &&
      (note!.user?.username == AuthBackend().loggedInUser?.user?.username ||
          note!.privacyMode == PrivacyMode.public);

  @override
  void initState() {
    super.initState();
    GroupContext().addListener(_onGroupContextChanged);
    _commentController.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    GroupContext().removeListener(_onGroupContextChanged);
    _commentController.removeListener(_onControllerChanged);
    _commentController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (_commentController.text == _lastKnownText) {
      return;
    }
    _lastKnownText = _commentController.text;
    _onContentChanged(_commentController.text);
  }

  void _onGroupContextChanged() {
    if (mounted) {
      navigateToRoute(context, 'notes');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final extra = GoRouterState.of(context).extra;
      if (extra is int) {
        id = extra;
        _initialized = true;
        _loadNote();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fehlender Parameter für Notiz.')),
          );
          Navigator.of(context).pop();
        });
      }
    }
  }

  Future<void> _loadNote() async {
    try {
      final backend = Backend();
      final loaded = await backend.getNote(id);
      setState(() {
        note = loaded;
        _savedContent = loaded.content ?? '';
        _lastKnownText = _savedContent;
        _commentController.text = _savedContent;
        _saveState = _SaveState.idle;
      });
      await NoteAttachmentStore().loadForNote(id);
    } catch (e) {
      if (e is SessionExpiredException) {
        await showBackendError(context, e, 'Bitte melde dich erneut an.');
      } else if (mounted) {
        await showBackendError(context, e, 'Aktion fehlgeschlagen');
      }
    }
  }

  void _onContentChanged(String value) {
    note?.content = value;
    _autosaveTimer?.cancel();

    final next = _hasUnsavedChanges ? _SaveState.unsaved : _SaveState.idle;
    if (next != _saveState) {
      setState(() => _saveState = next);
    }

    if (next == _SaveState.unsaved) {
      _autosaveTimer = Timer(_autosaveDelay, _saveNote);
    }
  }

  Future<void> _saveNote({bool force = false}) async {
    _autosaveTimer?.cancel();

    if (!_isEditable || (!force && !_hasUnsavedChanges)) {
      return;
    }

    final content = _commentController.text;
    setState(() => _saveState = _SaveState.saving);

    try {
      final backend = Backend();
      await backend.updateNote(UpdateNoteDto(
        id: note?.id ?? id,
        title: note?.title ?? '',
        privacyMode: note?.privacyMode,
        content: content,
      ));
      if (!mounted) {
        return;
      }
      setState(() {
        _savedContent = content;
        _saveState = _hasUnsavedChanges ? _SaveState.unsaved : _SaveState.saved;
      });
      if (_saveState == _SaveState.unsaved) {
        _autosaveTimer = Timer(_autosaveDelay, _saveNote);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saveState = _SaveState.failed);
      }
      if (e is SessionExpiredException) {
        await showBackendError(context, e, 'Bitte melde dich erneut an.');
      } else if (mounted) {
        await showBackendError(context, e, 'Aktion fehlgeschlagen');
      }
    }
  }

  Future<void> _saveAndLeave() async {
    await _saveNote();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _insertImage() async {
    final source = await _askImageSource();
    if (source == null) {
      return;
    }

    final picked = await _pickImage(source);
    if (picked == null) {
      return;
    }

    setState(() => _uploadingImage = true);
    try {
      final bytes = await picked.readAsBytes();
      final attachment = await Backend().createNoteAttachment(
        id,
        base64Encode(bytes),
      );
      NoteAttachmentStore().rememberUpload(attachment, bytes);
      insertBlockAtCursor(_commentController, attachment.markdownReference);
      Haptics.tap();
      await _saveNote(force: true);
    } catch (e) {
      Haptics.warning();
      await showBackendError(context, e, 'Bild konnte nicht hochgeladen werden');
    } finally {
      if (mounted) {
        setState(() => _uploadingImage = false);
      }
    }
  }

  Future<ImageSource?> _askImageSource() {
    final theme = Theme.of(context);

    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: theme.cardColor,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: PhosphorIcon(
                PhosphorIconsRegular.camera,
                color: theme.primaryIconTheme.color,
              ),
              title: Text('Foto aufnehmen',
                  style: theme.primaryTextTheme.titleSmall),
              onTap: () =>
                  Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: PhosphorIcon(
                PhosphorIconsRegular.image,
                color: theme.primaryIconTheme.color,
              ),
              title: Text('Aus Galerie wählen',
                  style: theme.primaryTextTheme.titleSmall),
              onTap: () =>
                  Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<XFile?> _pickImage(ImageSource source) async {
    try {
      return await ImagePicker().pickImage(
        source: source,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 85,
      );
    } catch (e) {
      Haptics.warning();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Kein Zugriff auf Kamera oder Fotos. '
              'Du kannst das in den Systemeinstellungen erlauben.',
            ),
          ),
        );
      }
      return null;
    }
  }

  Future<void> _insertLink() async {
    final link = await showDialog<_LinkInput>(
      context: context,
      builder: (dialogContext) => const _LinkDialog(),
    );
    if (link == null) {
      return;
    }
    insertLink(_commentController, label: link.label, url: link.url);
  }

  void _toggleMode(_EditorMode mode) {
    Haptics.tick();
    FocusScope.of(context).unfocus();
    setState(() => _mode = mode);
  }

  Widget _buildContextMenu(BuildContext context, EditableTextState state) {
    final items = state.contextMenuButtonItems;
    final selection = _commentController.selection;
    final hasSelection = selection.isValid && !selection.isCollapsed;

    if (hasSelection && note != null) {
      items.add(
        ContextMenuButtonItem(
          label: 'Teilen',
          onPressed: () {
            state.hideToolbar();
            shareText(
              context,
              selection.textInside(_commentController.text),
              subject: note!.title,
            );
          },
        ),
      );
    }

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: state.contextMenuAnchors,
      buttonItems: items,
    );
  }

  Widget? _buildSaveIndicator() {
    final style = Theme.of(context).primaryTextTheme.displayMedium;

    switch (_saveState) {
      case _SaveState.idle:
        return null;
      case _SaveState.unsaved:
        return Text('Nicht gespeichert', style: style);
      case _SaveState.saving:
        return Text('Speichert …', style: style);
      case _SaveState.saved:
        return Text('Gespeichert', style: style);
      case _SaveState.failed:
        return Text('Speichern fehlgeschlagen', style: style);
    }
  }

  @override
  Widget build(BuildContext context) {
    final indicator = _buildSaveIndicator();

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && _hasUnsavedChanges) {
          _saveNote();
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(note?.title ?? 'Notiz bearbeiten',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).primaryTextTheme.titleMedium),
              if (indicator != null) indicator,
            ],
          ),
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: _saveAndLeave,
              color: Theme.of(context).primaryIconTheme.color,
            ),
          ),
          actions: [
            const GroupContextSwitcher(),
            if (note != null)
              IconButton(
                icon: const PhosphorIcon(
                  PhosphorIconsRegular.shareNetwork,
                  semanticLabel: 'Notiz teilen',
                ),
                tooltip: 'Notiz teilen',
                color: Theme.of(context).primaryIconTheme.color,
                onPressed: () => shareNote(context, note!),
              ),
            if (_isEditable)
              IconButton(
                icon: const Icon(Icons.save),
                tooltip: 'Speichern',
                color: Theme.of(context).primaryIconTheme.color,
                onPressed: () {
                  Haptics.tap();
                  _saveNote(force: true);
                },
              ),
            IconButton(
              color: Theme.of(context).primaryIconTheme.color,
              icon: const PhosphorIcon(
                PhosphorIconsRegular.gear,
                semanticLabel: 'Einstellungen',
              ),
              onPressed: () {
                _scaffoldKey.currentState?.openEndDrawer();
              },
            ),
          ],
        ),
        endDrawer: AppDrawer(),
        body: Container(
          color: Theme.of(context).cardColor,
          child: Column(
            children: [
              _buildModeSwitch(),
              if (_uploadingImage)
                const LinearProgressIndicator(minHeight: 2)
              else
                const Divider(height: 1),
              Expanded(child: _buildContent()),
              if (_mode == _EditorMode.write && _isEditable) _buildToolbar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeSwitch() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SegmentedButton<_EditorMode>(
        segments: const [
          ButtonSegment(
            value: _EditorMode.preview,
            label: Text('Rich Text'),
            icon: PhosphorIcon(PhosphorIconsRegular.eye, size: 16),
          ),
          ButtonSegment(
            value: _EditorMode.write,
            label: Text('Markdown'),
            icon: PhosphorIcon(PhosphorIconsRegular.pencilSimple, size: 16),
          ),
        ],
        selected: {_mode},
        showSelectedIcon: false,
        expandedInsets: EdgeInsets.zero,
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(
            theme.primaryTextTheme.displayMedium,
          ),
          visualDensity: VisualDensity.compact,
        ),
        onSelectionChanged: (selection) => _toggleMode(selection.first),
      ),
    );
  }

  Widget _buildContent() {
    if (_mode == _EditorMode.preview) {
      return _buildPreview();
    }
    return _buildEditor();
  }

  Widget _buildPreview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: NoteMarkdownView(
        markdown: _commentController.text,
        onToggleTask: _isEditable ? _toggleTask : null,
      ),
    );
  }

  void _toggleTask(int taskIndex) {
    Haptics.tick();
    _replaceContent(toggleTaskAt(_commentController.text, taskIndex));
  }

  void _replaceContent(String content) {
    final previousOffset = _commentController.selection.baseOffset;
    _commentController.value = TextEditingValue(
      text: content,
      selection: TextSelection.collapsed(
        offset: previousOffset.clamp(0, content.length),
      ),
    );
  }

  Widget _buildEditor() {
    return TextField(
      controller: _commentController,
      enabled: _isEditable,
      textAlignVertical: TextAlignVertical.top,
      expands: true,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
      textInputAction: TextInputAction.newline,
      contextMenuBuilder: _buildContextMenu,
      cursorColor: Theme.of(context).primaryColor,
      scrollPadding: const EdgeInsets.all(24),
      style: Theme.of(context).primaryTextTheme.titleSmall,
      decoration: InputDecoration(
        hintText: 'Notiz in Markdown...',
        hintStyle: Theme.of(context).primaryTextTheme.titleSmall,
        contentPadding: const EdgeInsets.all(16.0),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        filled: false,
      ),
    );
  }

  Widget _buildToolbar() {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        ),
        child: MarkdownToolbar(
          controller: _commentController,
          enabled: !_uploadingImage,
          onInsertImage: _insertImage,
          onInsertLink: _insertLink,
        ),
      ),
    );
  }
}

class _LinkInput {
  final String label;
  final String url;

  const _LinkInput({required this.label, required this.url});
}

class _LinkDialog extends StatefulWidget {
  const _LinkDialog();

  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();

  @override
  void dispose() {
    _labelController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _submit() {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      return;
    }
    final label = _labelController.text.trim();
    Navigator.of(context).pop(
      _LinkInput(label: label.isEmpty ? url : label, url: url),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text('Link einfügen', style: theme.primaryTextTheme.bodySmall),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _labelController,
            style: theme.primaryTextTheme.bodySmall,
            decoration: InputDecoration(
              labelText: 'Text (optional)',
              labelStyle: theme.primaryTextTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _urlController,
            autofocus: true,
            keyboardType: TextInputType.url,
            style: theme.primaryTextTheme.bodySmall,
            decoration: InputDecoration(
              labelText: 'Adresse',
              hintText: 'https://',
              labelStyle: theme.primaryTextTheme.bodySmall,
            ),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceEvenly,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child:
              Text('Abbrechen', style: theme.primaryTextTheme.titleSmall),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(
            'Einfügen',
            style: theme.primaryTextTheme.titleSmall?.copyWith(
              color: theme.brightness == Brightness.light
                  ? Colors.white
                  : Colors.grey[900],
            ),
          ),
        ),
      ],
    );
  }
}
