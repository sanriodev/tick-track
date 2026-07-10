import 'package:ticktrack/screens/activity/activity_screen.dart';
import 'package:ticktrack/screens/groups/group_create_screen.dart';
import 'package:ticktrack/screens/groups/group_onboarding_screen.dart';
import 'package:ticktrack/screens/home/home_screen.dart';
import 'package:ticktrack/screens/login/login_screen.dart';
import 'package:ticktrack/screens/login/onboarding/onboarding_screen.dart';
import 'package:ticktrack/screens/notes/notes_edit_screen.dart';
import 'package:ticktrack/screens/notes/notes_screen.dart';
import 'package:ticktrack/screens/splash/splash_screen.dart';
import 'package:ticktrack/screens/task-lists/task_list_screen.dart';
import 'package:ticktrack/screens/task-lists/tasks_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

GoRouter createRouter() {
  const int transitionDuration = 350;

  return GoRouter(
    initialLocation: '/splashscreen',
    routes: [
      GoRoute(
        name: 'splashscreen',
        path: '/splashscreen',
        pageBuilder: (context, state) => NoTransitionPage(
          child: SplashScreen(),
          key: state.pageKey,
          name: 'splashscreen',
        ),
      ),
      GoRoute(
        name: 'home',
        path: '/',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          name: 'home',
          child: HomeScreen(),
          transitionDuration: const Duration(milliseconds: transitionDuration),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurveTween(curve: Curves.easeIn).animate(animation),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        name: 'activity',
        path: '/activity',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          name: 'activity',
          child: const ActivityScreen(),
          transitionDuration: const Duration(milliseconds: transitionDuration),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurveTween(curve: Curves.easeIn).animate(animation),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        name: 'login',
        path: '/login',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          name: 'login',
          child: const LoginScreen(),
          transitionDuration: const Duration(milliseconds: transitionDuration),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurveTween(curve: Curves.easeIn).animate(animation),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        name: 'onboarding',
        path: '/onboarding',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          name: 'onboarding',
          child: const OnboardingScreen(),
          transitionDuration: const Duration(milliseconds: transitionDuration),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurveTween(curve: Curves.easeIn).animate(animation),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        name: 'group-onboarding',
        path: '/group-onboarding',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          name: 'group-onboarding',
          child: const GroupOnboardingScreen(),
          transitionDuration: const Duration(milliseconds: transitionDuration),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurveTween(curve: Curves.easeIn).animate(animation),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        name: 'group-create',
        path: '/group-create',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          name: 'group-create',
          child: const GroupCreateScreen(),
          transitionDuration: const Duration(milliseconds: transitionDuration),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurveTween(curve: Curves.easeIn).animate(animation),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        name: 'notes',
        path: '/notes',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const NotesScreen(),
          key: state.pageKey,
          name: 'notes',
          transitionDuration: const Duration(milliseconds: transitionDuration),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurveTween(curve: Curves.easeIn).animate(animation),
              child: child,
            );
          },
        ),
        routes: [
          GoRoute(
            name: 'notes-edit',
            path: 'notes-edit',
            pageBuilder: (context, state) => CustomTransitionPage(
              child: const NotesEditScreen(),
              key: state.pageKey,
              name: 'notes-edit',
              transitionDuration:
                  const Duration(milliseconds: transitionDuration),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: CurveTween(curve: Curves.easeIn).animate(animation),
                  child: child,
                );
              },
            ),
          ),
        ],
      ),
      GoRoute(
        name: 'task-lists',
        path: '/task-lists',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const TaskListScreen(),
          key: state.pageKey,
          name: 'task-lists',
          transitionDuration: const Duration(milliseconds: transitionDuration),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurveTween(curve: Curves.easeIn).animate(animation),
              child: child,
            );
          },
        ),
        routes: [
          GoRoute(
            name: 'tasks',
            path: 'tasks',
            pageBuilder: (context, state) => CustomTransitionPage(
              child: const TasksScreen(),
              key: state.pageKey,
              name: 'tasks',
              transitionDuration:
                  const Duration(milliseconds: transitionDuration),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: CurveTween(curve: Curves.easeIn).animate(animation),
                  child: child,
                );
              },
            ),
          ),
        ],
      ),
    ],
  );
}
