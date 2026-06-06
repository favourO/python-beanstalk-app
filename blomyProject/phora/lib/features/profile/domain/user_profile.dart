class UserProfile {
  const UserProfile({
    required this.userId,
    required this.email,
    required this.emailVerified,
    required this.accountMode,
    required this.fullName,
  });

  final String userId;
  final String email;
  final bool emailVerified;
  final String accountMode;
  final String fullName;

  String get initials {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return 'P';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length.clamp(1, 2)).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
