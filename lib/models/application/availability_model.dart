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
