import 'package:ticktrack/enum/privacy_mode_enum.dart';

class CreateTaskListDto {
  String name;
  PrivacyMode? privacyMode;
  int? groupId;

  CreateTaskListDto({
    required this.name,
    this.privacyMode,
    this.groupId,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'privacyMode': privacyMode,
      if (groupId != null) 'groupId': groupId,
    };
  }
}
