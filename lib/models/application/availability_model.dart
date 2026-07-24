/// Result of the registration dry run: tells the app for username and email
/// separately whether they are still free and, when both belong to one and the
/// same account, whether that account ever finished its email confirmation.
class Availability {
  final bool available;
  final bool usernameAvailable;
  final bool emailAvailable;
  final bool sameUser;
  final bool confirmed;

  Availability({
    required this.available,
    required this.usernameAvailable,
    required this.emailAvailable,
    required this.sameUser,
    required this.confirmed,
  });

  /// Both fields point at one existing account that never confirmed its email
  /// - the registration can simply be resumed with a fresh code.
  bool get isUnconfirmedAccount => sameUser && !confirmed;

  factory Availability.fromJson(Map<String, dynamic> json) {
    return Availability(
      available: json['available'] as bool,
      usernameAvailable: json['usernameAvailable'] as bool,
      emailAvailable: json['emailAvailable'] as bool,
      sameUser: json['sameUser'] as bool,
      confirmed: json['confirmed'] as bool,
    );
  }
}
