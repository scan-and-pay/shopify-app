import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String uid;
  final String? email;
  final String? phoneNumber;
  final String? name;
  final String? payId;
  final bool hasPinEnabled;
  final DateTime createdAt;
  final DateTime lastLoginAt;
  final bool isActive;
  final String authMethod; // 'email' or 'phone'

  // New business fields
  final String? businessName;
  final String? abn;
  final String? address;
  
  User({
    required this.uid,
    this.email,
    this.phoneNumber,
    this.name,
    this.payId,
    this.hasPinEnabled = false,
    required this.createdAt,
    required this.lastLoginAt,
    this.isActive = true,
    required this.authMethod,

    this.businessName,
    this.abn,
    this.address,
  });
  
  // Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'phoneNumber': phoneNumber,
      'name': name,
      'payId': payId,
      'hasPinEnabled': hasPinEnabled,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': Timestamp.fromDate(lastLoginAt),
      'isActive': isActive,
      'authMethod': authMethod,

      'businessName': businessName,
      'abn': abn,
      'address': address,
    };
  }
  
  // Create from Firestore document
  factory User.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return User(
      uid: doc.id,
      email: data['email'],
      phoneNumber: data['phoneNumber'],
      name: data['name'],
      payId: data['payId'],
      hasPinEnabled: data['hasPinEnabled'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastLoginAt: (data['lastLoginAt'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
      authMethod: data['authMethod'] ?? 'email',

      businessName: data['businessName'],
      abn: data['abn'],
      address: data['address'],
    );
  }
  
  // Create from JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      uid: json['uid'],
      email: json['email'],
      phoneNumber: json['phoneNumber'],
      name: json['name'],
      payId: json['payId'],
      hasPinEnabled: json['hasPinEnabled'] ?? false,
      createdAt: json['createdAt'] is Timestamp 
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.parse(json['createdAt']),
      lastLoginAt: json['lastLoginAt'] is Timestamp 
          ? (json['lastLoginAt'] as Timestamp).toDate()
          : DateTime.parse(json['lastLoginAt']),
      isActive: json['isActive'] ?? true,
      authMethod: json['authMethod'] ?? 'email',

      // New business fields
    businessName: json['businessName'],
    abn: json['abn'],
    address: json['address'],
    );
  }
  
  // Copy with new values
  User copyWith({
    String? uid,
    String? email,
    String? phoneNumber,
    String? name,
    String? payId,
    bool? hasPinEnabled,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    bool? isActive,
    String? authMethod,

    // NEW
    String? businessName,
    String? abn,
    String? address,

  }) {
    return User(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      name: name ?? this.name,
      payId: payId ?? this.payId,
      hasPinEnabled: hasPinEnabled ?? this.hasPinEnabled,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isActive: isActive ?? this.isActive,
      authMethod: authMethod ?? this.authMethod,

      // NEW
      businessName: businessName ?? this.businessName,
      abn: abn ?? this.abn,
      address: address ?? this.address,

    );
  }
  
  // Get display name (name or email/phone)
  String get displayName {
    if (name != null && name!.isNotEmpty) {
      return name!;
    }
    if (email != null && email!.isNotEmpty) {
      return email!;
    }
    if (phoneNumber != null && phoneNumber!.isNotEmpty) {
      return phoneNumber!;
    }
    return 'User';
  }
  
  // Get contact method used for auth
  String get contactMethod {
    if (authMethod == 'email' && email != null) {
      return email!;
    }
    if (authMethod == 'phone' && phoneNumber != null) {
      return phoneNumber!;
    }
    return 'Unknown';
  }
  
@override
String toString() {
  return 'User(uid: $uid, name: $name, email: $email, phone: $phoneNumber, '
         'payId: $payId, businessName: $businessName, abn: $abn, address: $address, '
         'hasPinEnabled: $hasPinEnabled, authMethod: $authMethod)';
}

  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          uid == other.uid;
  
  @override
  int get hashCode => uid.hashCode;
}