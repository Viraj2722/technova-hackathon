// Create a new file: lib/services/user_service.dart

import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class UserService {
  static const String _userIdKey = 'supabase_user_id';
  static const String _firebaseUidKey = 'firebase_uid';

  static final supabase.SupabaseClient _supabaseClient =
      supabase.Supabase.instance.client;

  // Save user IDs to local storage
  static Future<void> saveUserIds({
    required String supabaseUserId,
    required String firebaseUid,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, supabaseUserId);
    await prefs.setString(_firebaseUidKey, firebaseUid);
  }

  // Get Supabase user ID from local storage
  static Future<String?> getSupabaseUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  // Get Firebase UID from local storage
  static Future<String?> getFirebaseUid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_firebaseUidKey);
  }

  // Get Supabase user ID from Firebase UID
  static Future<String?> getSupabaseUserIdFromFirebase(
      String firebaseUid) async {
    try {
      final response = await _supabaseClient
          .from('users')
          .select('id')
          .eq('firebase_uid', firebaseUid)
          .maybeSingle();

      if (response != null) {
        return response['id'] as String;
      }
      return null;
    } catch (e) {
      print('Error getting Supabase user ID: $e');
      return null;
    }
  }

  // Get current user's Supabase ID (tries multiple methods)
  static Future<String?> getCurrentSupabaseUserId() async {
    // First try from local storage
    String? userId = await getSupabaseUserId();
    if (userId != null) return userId;

    // If not in storage, try to get from current Firebase user
    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      userId = await getSupabaseUserIdFromFirebase(firebaseUser.uid);
      if (userId != null) {
        // Save for future use
        await saveUserIds(
          supabaseUserId: userId,
          firebaseUid: firebaseUser.uid,
        );
        return userId;
      }
    }

    return null;
  }

  // Clear all user data (for logout)
  static Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_firebaseUidKey);
  }

  // Check if user is logged in and has valid Supabase ID
  static Future<bool> isUserLoggedIn() async {
    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
    final supabaseUserId = await getCurrentSupabaseUserId();

    return firebaseUser != null && supabaseUserId != null;
  }
}
