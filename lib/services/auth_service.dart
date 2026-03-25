// lib/services/auth_service.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'package:uuid/uuid.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  // Sign in with email/password
  Future<UserModel?> signInWithEmailPassword(
      String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      if (cred.user != null) {
        return await getUserData(cred.user!.uid);
      }
      return null;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Student login: parent email + student name + student password
  Future<UserModel?> signInAsKid(
      String parentEmail, String kidName, String kidPassword) async {
    try {
      // Find parent by email
      final parentQuery = await _db
          .collection('users')
          .where('email', isEqualTo: parentEmail.toLowerCase().trim())
          .where('role', isEqualTo: 'parent')
          .get();

      if (parentQuery.docs.isEmpty) {
        throw Exception('Parent account not found');
      }

      final parentDoc = parentQuery.docs.first;
      final parentData = parentDoc.data();
      final kidUids = List<String>.from(parentData['kidUids'] as List? ?? []);

      // Find student by name within this family
      for (final kidUid in kidUids) {
        final kidDoc = await _db.collection('users').doc(kidUid).get();
        if (kidDoc.exists) {
          final kidData = kidDoc.data()!;
          final storedName = (kidData['displayName'] as String? ?? '').toLowerCase();
          final inputName = kidName.toLowerCase().trim();
          // Match on full name OR just the first name (first token)
          final storedFirst = storedName.split(' ').first;
          final inputFirst = inputName.split(' ').first;
          if (storedName == inputName || storedFirst == inputFirst) {
            // Always build email from the stored full name so the
            // Firebase account is found correctly
            final kidEmail = _buildKidEmail(parentEmail, storedName);
            try {
              final cred = await _auth.signInWithEmailAndPassword(
                  email: kidEmail, password: kidPassword);
              if (cred.user != null) {
                return await getUserData(cred.user!.uid);
              }
            } catch (_) {
              throw Exception('Incorrect password for $kidName');
            }
          }
        }
      }
      throw Exception('Student "$kidName" not found under this parent account');
    } catch (e) {
      rethrow;
    }
  }

  // Register parent account
  Future<UserModel?> registerParent({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      if (cred.user == null) return null;

      await cred.user!.updateDisplayName(displayName);

      final familyId = _uuid.v4();
      final user = UserModel(
        uid: cred.user!.uid,
        email: email,
        displayName: displayName,
        role: UserRole.parent,
        familyId: familyId,
        kidUids: [],
        createdAt: DateTime.now(),
      );

      await _db.collection('users').doc(user.uid).set({
        ...user.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Create family document
      await _db.collection('families').doc(familyId).set({
        'id': familyId,
        'parentUid': user.uid,
        'parentName': displayName,
        'parentEmail': email,
        'memberUids': [user.uid],
        'createdAt': FieldValue.serverTimestamp(),
      });

      return user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Add student to family (called by parent) — uses secondary FirebaseApp to
  // avoid signing out the currently-logged-in parent.
  Future<UserModel?> addKidToFamily({
    required UserModel parent,
    required String kidName,
    required String kidPassword,
  }) async {
    if (kidName.trim().isEmpty) {
      throw Exception('Student name cannot be empty');
    }
    // Password is optional — generate one if blank
    final finalPassword = kidPassword.trim().isEmpty
        ? 'ACHC${kidName.trim().replaceAll(' ', '')}2024!'
        : kidPassword.trim();
    if (finalPassword.length < 6) {
      throw Exception('Student password must be at least 6 characters');
    }

    final kidEmail = _buildKidEmail(parent.email, kidName.trim());

    try {
      // Use a secondary Firebase App instance so the parent stays signed in
      FirebaseApp? secondaryApp;
      try {
        secondaryApp = Firebase.app('kidCreation');
      } catch (_) {
        secondaryApp = await Firebase.initializeApp(
          name: 'kidCreation',
          options: Firebase.app().options,
        );
      }

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final cred = await secondaryAuth.createUserWithEmailAndPassword(
          email: kidEmail, password: finalPassword);
      if (cred.user == null) throw Exception('Failed to create student account');

      await cred.user!.updateDisplayName(kidName.trim());
      // Sign out of secondary app immediately (parent still logged in on primary)
      await secondaryAuth.signOut();

      final kid = UserModel(
        uid: cred.user!.uid,
        email: kidEmail,
        displayName: kidName.trim(),
        role: UserRole.student,
        parentUid: parent.uid,
        familyId: parent.familyId,
        kidUids: [],
        createdAt: DateTime.now(),
      );

      await _db.collection('users').doc(kid.uid).set({
        ...kid.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update parent's kidUids
      await _db.collection('users').doc(parent.uid).update({
        'kidUids': FieldValue.arrayUnion([kid.uid]),
      });

      // Update family document
      if (parent.familyId != null) {
        await _db.collection('families').doc(parent.familyId).update({
          'memberUids': FieldValue.arrayUnion([kid.uid]),
          'kidUids': FieldValue.arrayUnion([kid.uid]),
        });
      }

      return kid;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Get user data from Firestore
  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!, uid);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user data: $e');
      return null;
    }
  }

  // Get students for a parent
  Future<List<UserModel>> getKidsForParent(String parentUid) async {
    try {
      final snap = await _db
          .collection('users')
          .where('parentUid', isEqualTo: parentUid)
          .get();
      return snap.docs
          .map((d) => UserModel.fromMap(d.data(), d.id))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Update FCM token
  Future<void> updateFcmToken(String uid, String token) async {
    await _db.collection('users').doc(uid).update({'fcmToken': token});
  }

  // Save Moodle credentials
  Future<void> saveMoodleCredentials(
      String uid, String moodleUrl, String moodleToken) async {
    await _db.collection('users').doc(uid).update({
      'moodleUrl': moodleUrl,
      'moodleToken': moodleToken,
    });
  }

  String _buildKidEmail(String parentEmail, String kidName) {
    final sanitizedName =
        kidName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final parentUser = parentEmail.split('@').first;
    return '${parentUser}_$sanitizedName@achc-student.app';
  }

  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }
}
