class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final bool biometricEnabled;
  final String? fcmToken;
  final String? phoneNumber;
  final bool? isPhoneVerified;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.createdAt,
    this.lastLoginAt,
    this.biometricEnabled = false,
    this.fcmToken,
    this.phoneNumber,
    this.isPhoneVerified = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastLoginAt': lastLoginAt?.millisecondsSinceEpoch,
      'biometricEnabled': biometricEnabled,
      'fcmToken': fcmToken,
      'phoneNumber': phoneNumber,
      'isPhoneVerified': isPhoneVerified,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] as String,
      email: map['email'] as String,
      displayName: map['displayName'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      lastLoginAt: map['lastLoginAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastLoginAt'] as int)
          : null,
      biometricEnabled: map['biometricEnabled'] as bool? ?? false,
      fcmToken: map['fcmToken'] as String?,
      phoneNumber: map['phoneNumber'] as String?,
      isPhoneVerified: map['isPhoneVerified'] as bool? ?? false,
    );
  }

  AppUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    bool? biometricEnabled,
    String? fcmToken,
    String? phoneNumber,
    bool? isPhoneVerified,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      fcmToken: fcmToken ?? this.fcmToken,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
    );
  }
}