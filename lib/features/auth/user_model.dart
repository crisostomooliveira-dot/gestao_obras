class UserModel {
  final String id;
  final String username;
  final bool isMaster;
  final Map<String, bool> permissions;

  UserModel({
    required this.id,
    required this.username,
    required this.isMaster,
    required this.permissions,
  });
}
