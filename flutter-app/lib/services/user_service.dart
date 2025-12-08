import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/foundation.dart';
import 'package:scan__pay/models/user.dart' as model;

class UserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
  
  // Collection reference
  static CollectionReference get _usersCollection => _firestore.collection('users');
  
  // Create or update user in Firestore
  static Future<model.User> createOrUpdateUser({
    required String uid,
    String? email,
    String? phoneNumber,
    String? name,
    String? payId,
    bool? hasPinEnabled,
    String authMethod = 'email',
    String? businessName,
    String? abn,
    String? address,
  }) async {
    final now = DateTime.now();
    final userRef = _usersCollection.doc(uid);
    
    // Check if user already exists
    final existingDoc = await userRef.get();
    
    if (existingDoc.exists) {
      // Update existing user
      final userData = existingDoc.data() as Map<String, dynamic>;
      
      final updatedUser = model.User(
        uid: uid,
        email: email ?? userData['email'],
        phoneNumber: phoneNumber ?? userData['phoneNumber'],
        name: name ?? userData['name'],
        payId: payId ?? userData['payId'],
        hasPinEnabled: hasPinEnabled ?? userData['hasPinEnabled'] ?? false,
        createdAt: (userData['createdAt'] as Timestamp).toDate(),
        lastLoginAt: now,
        isActive: userData['isActive'] ?? true,
        authMethod: authMethod,
        businessName: businessName ?? userData['businessName'],
        abn: abn ?? userData['abn'],
        address: address ?? userData['address'],
      );
      
      await userRef.update({
        'lastLoginAt': Timestamp.fromDate(now),
        'authMethod': authMethod,
        if (email != null) 'email': email,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        if (name != null) 'name': name,
        if (payId != null) 'payId': payId,
        if (hasPinEnabled != null) 'hasPinEnabled': hasPinEnabled,
        if (businessName != null) 'businessName': businessName,
        if (abn != null) 'abn': abn,
        if (address != null) 'address': address,
      });
      
      return updatedUser;
    } else {
      // Create new user
      final newUser = model.User(
        uid: uid,
        email: email,
        phoneNumber: phoneNumber,
        name: name,
        payId: payId,
        hasPinEnabled: hasPinEnabled ?? false,
        createdAt: now,
        lastLoginAt: now,
        isActive: true,
        authMethod: authMethod,
        businessName: businessName,
        abn: abn,
        address: address,
      );
      
      await userRef.set(newUser.toJson());
      return newUser;
    }
  }
  
  // Get user by UID
  static Future<model.User?> getUserByUid(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      
      if (doc.exists) {
        return model.User.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }
  
  // Get current user from Firestore
  static Future<model.User?> getCurrentUser() async {
    final authUser = _auth.currentUser;
    if (authUser == null) return null;
    
    return getUserByUid(authUser.uid);
  }
  
  // Update user profile
  static Future<void> updateUserProfile({
    required String uid,
    String? name,
    String? payId,
    bool? hasPinEnabled,
    String? businessName,
    String? abn,
    String? address,
    String? sellerStatus,
    String? basiqUserId,
  }) async {
    try {
      final updates = <String, dynamic>{};
      
      if (name != null) updates['name'] = name;
      if (payId != null) updates['payId'] = payId;
      if (hasPinEnabled != null) updates['hasPinEnabled'] = hasPinEnabled;
      if (businessName != null) updates['businessName'] = businessName;
      if (abn != null) updates['abn'] = abn;
      if (address != null) updates['address'] = address;
      if (sellerStatus != null) updates['sellerStatus'] = sellerStatus;
      if (basiqUserId != null) updates['basiqUserId'] = basiqUserId;
      
      if (updates.isNotEmpty) {
        await _usersCollection.doc(uid).update(updates);
      }
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }
  
  // Update last login time
  static Future<void> updateLastLogin(String uid) async {
    try {
      await _usersCollection.doc(uid).update({
        'lastLoginAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to update last login: $e');
    }
  }
  
  // Deactivate user account
  static Future<void> deactivateUser(String uid) async {
    try {
      await _usersCollection.doc(uid).update({
        'isActive': false,
      });
    } catch (e) {
      throw Exception('Failed to deactivate user: $e');
    }
  }
  
  // Get user by email
  static Future<model.User?> getUserByEmail(String email) async {
    try {
      final query = await _usersCollection
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        return model.User.fromFirestore(query.docs.first);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user by email: $e');
    }
  }
  
  // Get user by phone number
  static Future<model.User?> getUserByPhone(String phoneNumber) async {
    try {
      final query = await _usersCollection
          .where('phoneNumber', isEqualTo: phoneNumber)
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        return model.User.fromFirestore(query.docs.first);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user by phone: $e');
    }
  }
  
  // Check if PayID is available
  static Future<bool> isPayIdAvailable(String payId, [String? excludeUid]) async {
    try {
      var query = _usersCollection.where('payId', isEqualTo: payId);
      
      final results = await query.get();
      
      // If no results, PayID is available
      if (results.docs.isEmpty) return true;
      
      // If excluding a UID (for current user updates), check if it's the only match
      if (excludeUid != null) {
        final otherUsers = results.docs.where((doc) => doc.id != excludeUid);
        return otherUsers.isEmpty;
      }
      
      // PayID is taken
      return false;
    } catch (e) {
      throw Exception('Failed to check PayID availability: $e');
    }
  }
  
  // Get user statistics
  static Future<Map<String, dynamic>> getUserStats(String uid) async {
    try {
      final user = await getUserByUid(uid);
      if (user == null) {
        throw Exception('User not found');
      }
      
      // Calculate account age
      final accountAge = DateTime.now().difference(user.createdAt).inDays;
      
      // Get last login info
      final daysSinceLastLogin = DateTime.now().difference(user.lastLoginAt).inDays;
      
      return {
        'accountAge': accountAge,
        'daysSinceLastLogin': daysSinceLastLogin,
        'authMethod': user.authMethod,
        'isActive': user.isActive,
        'hasPayId': user.payId != null && user.payId!.isNotEmpty,
        'profileComplete': user.name != null && user.payId != null,
      };
    } catch (e) {
      throw Exception('Failed to get user stats: $e');
    }
  }
  }

