class Profile {
  const Profile({
    required this.id,
    required this.displayName,
    required this.role,
  });

  final String id;
  final String displayName;
  final String role;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      displayName: json['display_name'] as String? ?? 'Member',
      role: json['role'] as String? ?? 'learner',
    );
  }
}
