class Profile {
  const Profile({
    required this.id,
    required this.displayName,
    required this.role,
    this.headline,
    this.mutedUntil,
  });

  final String id;
  final String displayName;
  final String role;
  final String? headline;
  final DateTime? mutedUntil;

  bool get isLearner => role == 'learner';
  bool get isMentor => role == 'mentor';
  bool get isModerator => role == 'moderator';

  bool get isMuted => mutedUntil != null && mutedUntil!.isAfter(DateTime.now());

  factory Profile.fromJson(Map<String, dynamic> json) {
    final muted = json['muted_until'] as String?;
    return Profile(
      id: json['id'] as String,
      displayName: json['display_name'] as String? ?? 'Member',
      role: json['role'] as String? ?? 'learner',
      headline: json['headline'] as String?,
      mutedUntil: muted == null ? null : DateTime.parse(muted).toLocal(),
    );
  }

  Profile copyWith({String? displayName, String? headline}) {
    return Profile(
      id: id,
      displayName: displayName ?? this.displayName,
      role: role,
      headline: headline ?? this.headline,
      mutedUntil: mutedUntil,
    );
  }
}
