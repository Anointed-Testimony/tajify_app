class UserModel {
  final int id;
  final String uuid;
  final String name;
  final String username;
  final String email;
  final String? phone;
  final String? dateOfBirth;
  final String? profilePicture;
  final String userType;
  final DateTime? emailVerifiedAt;
  final DateTime? phoneVerifiedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.id,
    required this.uuid,
    required this.name,
    required this.username,
    required this.email,
    this.phone,
    this.dateOfBirth,
    this.profilePicture,
    required this.userType,
    this.emailVerifiedAt,
    this.phoneVerifiedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 0,
      uuid: json['uuid'] ?? '',
      name: json['name'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      dateOfBirth: json['date_of_birth'],
      profilePicture: json['profile_picture'],
      userType: json['user_type'] ?? 'user',
      emailVerifiedAt: json['email_verified_at'] != null 
          ? DateTime.parse(json['email_verified_at']) 
          : null,
      phoneVerifiedAt: json['phone_verified_at'] != null 
          ? DateTime.parse(json['phone_verified_at']) 
          : null,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uuid': uuid,
      'name': name,
      'username': username,
      'email': email,
      'phone': phone,
      'date_of_birth': dateOfBirth,
      'profile_picture': profilePicture,
      'user_type': userType,
      'email_verified_at': emailVerifiedAt?.toIso8601String(),
      'phone_verified_at': phoneVerifiedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserModel copyWith({
    int? id,
    String? uuid,
    String? name,
    String? username,
    String? email,
    String? phone,
    String? dateOfBirth,
    String? profilePicture,
    String? userType,
    DateTime? emailVerifiedAt,
    DateTime? phoneVerifiedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      profilePicture: profilePicture ?? this.profilePicture,
      userType: userType ?? this.userType,
      emailVerifiedAt: emailVerifiedAt ?? this.emailVerifiedAt,
      phoneVerifiedAt: phoneVerifiedAt ?? this.phoneVerifiedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isEmailVerified => emailVerifiedAt != null;
  bool get isPhoneVerified => phoneVerifiedAt != null;
  bool get isAdmin => userType == 'admin';
  bool get isUser => userType == 'user';

  @override
  String toString() {
    return 'UserModel(id: $id, uuid: $uuid, name: $name, username: $username, email: $email, phone: $phone, userType: $userType)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
} 