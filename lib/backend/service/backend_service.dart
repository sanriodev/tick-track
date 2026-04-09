// ignore_for_file: avoid_dynamic_calls

import 'dart:convert';

import 'package:ticktrack/models/activity/activity_model.dart';
import 'package:ticktrack/models/note/note_api_model.dart';
import 'package:ticktrack/models/task/dto/create_task_dto.dart';
import 'package:ticktrack/models/task/task_api_model.dart';
import 'package:ticktrack/models/tasklist/dto/update_task_list_dto.dart';
import 'package:ticktrack/models/tasklist/task_list_api_model.dart';
import 'package:ticktrack/models/note/dto/create_note_dto.dart';
import 'package:ticktrack/models/tasklist/dto/create_task_list_dto.dart';
import 'package:ticktrack/models/note/dto/update_note_dto.dart';
import 'package:blvckleg_dart_core/abstract/backend_abstract.dart';

class Backend extends ABackend {
  static final Backend _instance = Backend._privateConstructor();
  factory Backend() => _instance;
  Backend._privateConstructor() {
    super.init();
  }

  Future<TaskList> createTaskList(CreateTaskListDto list) async {
    final body = json.encode(list);
    final res = await post(body, 'v1/task-list/');

    if (res.statusCode == 200 || res.statusCode == 201) {
      final jsonData = await json.decode(utf8.decode(res.bodyBytes))['data']
          as Map<String, dynamic>;

      final taskList = TaskList.fromJson(jsonData);

      return taskList;
    } else {
      throw res;
    }
  }

  Future<List<TaskList>> getAllTaskLists() async {
    final res = await get('v1/task-list/');

    if (res.statusCode == 200 || res.statusCode == 201) {
      final jsonData = await json.decode(utf8.decode(res.bodyBytes))['data']
          as List<dynamic>;
      var taskLists = <TaskList>[];
      taskLists = jsonData
          .map((e) => TaskList.fromJson(e as Map<String, dynamic>))
          .toList();

      return taskLists;
    } else {
      throw res;
    }
  }

  Future<TaskList> updateTaskList(UpdateTaskListDto taskList) async {
    final body = json.encode(taskList.toJson());
    final res = await put(body, 'v1/task-list/');

    if (res.statusCode == 200 || res.statusCode == 201) {
      final jsonData = await json.decode(utf8.decode(res.bodyBytes))['data']
          as Map<String, dynamic>;

      final updatedTaskList = TaskList.fromJson(jsonData);

      return updatedTaskList;
    } else {
      throw res;
    }
  }

  Future<TaskList> deleteTaskList(int id) async {
    final res = await delete('v1/task-list/$id');

    if (res.statusCode == 200 || res.statusCode == 201) {
      final jsonData = await json.decode(utf8.decode(res.bodyBytes))['data']
          as Map<String, dynamic>;

      final taskList = TaskList.fromJson(jsonData);

      return taskList;
    } else {
      throw res;
    }
  }

  Future<Note> createNote(CreateNoteDto note) async {
    final body = json.encode(note.toJson());
    final res = await post(body, 'v1/note/');

    if (res.statusCode == 200 || res.statusCode == 201) {
      final jsonData = await json.decode(utf8.decode(res.bodyBytes))['data']
          as Map<String, dynamic>;

      final note = Note.fromJson(jsonData);

      return note;
    } else {
      throw res;
    }
  }

  Future<List<Note>> getAllNotes() async {
    final res = await get('v1/note/');

    if (res.statusCode == 200 || res.statusCode == 201) {
      final jsonData = await json.decode(utf8.decode(res.bodyBytes))['data']
          as List<dynamic>;
      var notes = <Note>[];
      notes = jsonData
          .map((e) => Note.fromJson(e as Map<String, dynamic>))
          .toList();

      return notes;
    } else {
      throw res;
    }
  }

  Future<Note> getNote(int id) async {
    final res = await get('v1/note/$id');

    if (res.statusCode == 200 || res.statusCode == 201) {
      final jsonData = await json.decode(utf8.decode(res.bodyBytes))['data']
          as Map<String, dynamic>;

      final note = Note.fromJson(jsonData);

      return note;
    } else {
      throw res;
    }
  }

  Future<Note> updateNote(UpdateNoteDto note) async {
    final body = json.encode(note.toJson());
    final res = await put(body, 'v1/note/');

    if (res.statusCode == 200 || res.statusCode == 201) {
      final jsonData = await json.decode(utf8.decode(res.bodyBytes))['data']
          as Map<String, dynamic>;

      final updatedNote = Note.fromJson(jsonData);

      return updatedNote;
    } else {
      throw res;
    }
  }

  Future<Note> deleteNote(int id) async {
    final res = await delete('v1/note/$id');

    if (res.statusCode == 200 || res.statusCode == 201) {
      final jsonData = await json.decode(utf8.decode(res.bodyBytes))['data']
          as Map<String, dynamic>;

      final note = Note.fromJson(jsonData);

      return note;
    } else {
      throw res;
    }
  }

  Future<Task> createTask(CreateTaskDto task) async {
    final body = json.encode(task.toJson());
    final res = await post(body, 'v1/task/');

    if (res.statusCode == 200 || res.statusCode == 201) {
      final jsonData = await json.decode(utf8.decode(res.bodyBytes))['data']
          as Map<String, dynamic>;

      final createdTask = Task.fromJson(jsonData);

      return createdTask;
    } else {
      throw res;
    }
  }

  Future<List<Task>> getAllTasks() async {
    final res = await get('v1/task/');

    if (res.statusCode == 200 || res.statusCode == 201) {
      final jsonData = await json.decode(utf8.decode(res.bodyBytes))['data']
          as List<dynamic>;
      var tasks = <Task>[];
      tasks = jsonData
          .map((e) => Task.fromJson(e as Map<String, dynamic>))
          .toList();

      return tasks;
    } else {
      throw res;
    }
  }

  Future<List<Task>> getAllTasksForList(int taskListId) async {
    final res = await get('v1/task/list/$taskListId');

    if (res.statusCode == 200 || res.statusCode == 201) {
      final jsonData = await json.decode(utf8.decode(res.bodyBytes))['data']
          as List<dynamic>;
      var tasks = <Task>[];
      tasks = jsonData
          .map((e) => Task.fromJson(e as Map<String, dynamic>))
          .toList();

      return tasks;
    } else {
      throw res;
    }
  }

  Future<Task> updateTask(Task task) async {
    final body = json.encode(task.toJson());
    final res = await put(body, 'v1/task/');

    if (res.statusCode == 200 || res.statusCode == 201) {
      final jsonData = await json.decode(utf8.decode(res.bodyBytes))['data']
          as Map<String, dynamic>;

      final updatedTask = Task.fromJson(jsonData);

      return updatedTask;
    } else {
      throw res;
    }
  }

  Future<Task> deleteTask(int id) async {
    final res = await delete('v1/task/$id');

    if (res.statusCode == 200 || res.statusCode == 201) {
      final jsonData = await json.decode(utf8.decode(res.bodyBytes))['data']
          as Map<String, dynamic>;

      final task = Task.fromJson(jsonData);

      return task;
    } else {
      throw res;
    }
  }

  Future<List<EventlogMessage<dynamic>>> getActivity(String filterMode) async {
    if (filterMode != 'own' && filterMode != 'any') {
      throw 'Invalid filter mode';
    }
    final res = await get('v1/activity/?filterMode=$filterMode');

    if (res.statusCode == 200 || res.statusCode == 201) {
      final jsonData = await json.decode(utf8.decode(res.bodyBytes))['data'];
      final activity = (jsonData as List<dynamic>)
          .map((e) =>
              EventlogMessage<dynamic>.fromJson(e as Map<String, dynamic>))
          .toList();
      return activity;
    } else {
      throw res;
    }
  }

  Future<void> setActivityPrivacy(bool publicActivity) async {
    final body = '';
    final res = await patch(
      body,
      'v1/activity/public-activity?publicActivity=$publicActivity',
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      return;
    } else {
      throw res;
    }
  }

  Future<void> requestAccess(String username, String email) async {
    final body = json.encode({
      'username': username,
      'email': email,
    });
    final res = await post(body, 'v1/application/request-access');

    if (res.statusCode == 200 || res.statusCode == 201) {
      return;
    } else {
      throw res;
    }
  }
}
