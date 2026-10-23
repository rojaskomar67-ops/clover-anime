import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'clover_api.dart';
import 'models.dart';

/// Firebase auth + remote app config (same Firestore layout as the original app).
class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const defaultAdmins = {
    'renukumaribharti53@gmail.com',
    'hemaketu123@gmail.com',
    'rojaskomar67@gmail.com',
  };

  bool firebaseReady = false;
  User? user;
  Set<String> adminEmails = {...defaultAdmins};
  Announcement? announcement;
  UpdateConfig? update;
  final _subs = <StreamSubscription>[];

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  bool get isAdmin => user?.email != null && adminEmails.contains(user!.email!.toLowerCase());

  void start() {
    if (!firebaseReady) return;
    FirebaseAuth.instance.authStateChanges().listen((u) {
      user = u;
      notifyListeners();
    });
    _subs.add(_db.collection('app_config').doc('admins').snapshots().listen((s) {
      final list = (s.data()?['emails'] as List?)?.map((e) => e.toString().toLowerCase()) ?? [];
      adminEmails = {...defaultAdmins, ...list};
      notifyListeners();
    }, onError: (_) {}));
    _subs.add(_db.collection('app_config').doc('announcement').snapshots().listen((s) {
      final d = s.data();
      announcement = d == null ? null : Announcement.fromMap(d);
      notifyListeners();
    }, onError: (_) {}));
    _subs.add(_db.collection('app_config').doc('update').snapshots().listen((s) {
      final d = s.data();
      update = d == null ? null : UpdateConfig.fromMap(d);
      notifyListeners();
    }, onError: (_) {}));
    _subs.add(_db.collection('app_config').doc('api').snapshots().listen((s) {
      final d = s.data();
      if (d != null && d['isApiActive'] != false) {
        CloverApi.instance.setBaseUrl(d['primaryApiUrl']?.toString());
      }
    }, onError: (_) {}));
  }

  /// Signs in, or creates the account if the email is new (same as the original app).
  Future<String?> signIn(String email, String password) async {
    if (!firebaseReady) return 'Accounts are unavailable right now.';
    final e = email.trim().toLowerCase();
    if (!e.contains('@') || !e.contains('.')) return 'Please enter a valid email address.';
    if (password.trim().length < 6) return 'Password must be at least 6 characters.';
    final auth = FirebaseAuth.instance;
    try {
      UserCredential cred;
      try {
        cred = await auth.signInWithEmailAndPassword(email: e, password: password.trim());
      } on FirebaseAuthException catch (err) {
        if (err.code == 'user-not-found' || err.code == 'invalid-credential') {
          try {
            cred = await auth.createUserWithEmailAndPassword(email: e, password: password.trim());
          } on FirebaseAuthException catch (c) {
            if (c.code == 'email-already-in-use') {
              return 'Incorrect password for this account.';
            }
            rethrow;
          }
        } else {
          rethrow;
        }
      }
      final u = cred.user!;
      final now = DateTime.now().millisecondsSinceEpoch;
      final ref = _db.collection('users').doc(u.uid);
      final snap = await ref.get();
      await ref.set({
        'uid': u.uid,
        'email': e,
        'displayName': u.displayName ?? e.split('@').first,
        'role': adminEmails.contains(e) ? 'admin' : (snap.data()?['role'] ?? 'user'),
        if (!snap.exists) 'createdAt': now,
        'lastLoginAt': now,
      }, SetOptions(merge: true));
      return null;
    } on FirebaseAuthException catch (err) {
      switch (err.code) {
        case 'wrong-password':
          return 'Incorrect password for this account.';
        case 'weak-password':
          return 'Password must be at least 6 characters.';
        case 'too-many-requests':
          return 'Too many attempts. Try again later.';
        case 'network-request-failed':
          return 'No internet connection.';
        default:
          return err.message ?? 'Unable to sign in.';
      }
    } catch (err) {
      return 'Unable to sign in. Check your internet.';
    }
  }

  Future<void> signOut() async {
    if (firebaseReady) await FirebaseAuth.instance.signOut();
  }

  // ---------- Admin ----------
  Future<void> saveAnnouncement(Map<String, dynamic> data) => _db
      .collection('app_config')
      .doc('announcement')
      .set({...data, 'updatedAt': DateTime.now().millisecondsSinceEpoch}, SetOptions(merge: true));

  Future<void> saveUpdate(Map<String, dynamic> data) => _db
      .collection('app_config')
      .doc('update')
      .set({...data, 'updatedAt': DateTime.now().millisecondsSinceEpoch}, SetOptions(merge: true));

  Future<void> saveApi(String url, bool active) => _db.collection('app_config').doc('api').set({
        'primaryApiUrl': url,
        'isApiActive': active,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));

  Future<void> saveAdmins(Set<String> emails) => _db
      .collection('app_config')
      .doc('admins')
      .set({'emails': emails.difference(defaultAdmins).toList()}, SetOptions(merge: true));

  Stream<List<UserProfile>> users() => _db
      .collection('users')
      .orderBy('lastLoginAt', descending: true)
      .limit(300)
      .snapshots()
      .map((s) => s.docs.map((d) => UserProfile.fromMap(d.data())).toList());

  Future<void> setRole(String uid, String role) =>
      _db.collection('users').doc(uid).set({'role': role}, SetOptions(merge: true));

  Stream<List<Broadcast>> broadcasts() => _db
      .collection('broadcasts')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map((d) => Broadcast.fromMap(d.id, d.data())).toList());

  Future<void> publishBroadcast(String title, String message, String type, bool asBanner) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'b_$now';
    await _db.collection('broadcasts').doc(id).set({
      'id': id,
      'title': title,
      'message': message,
      'type': type,
      'displayMode': 'both',
      'createdAt': now,
      'createdBy': user?.email ?? '',
    });
    if (asBanner) {
      await saveAnnouncement({
        'title': title,
        'message': message,
        'type': type,
        'enabled': true,
        'isEnabled': true,
      });
    }
  }

  Future<void> deleteBroadcast(String id) => _db.collection('broadcasts').doc(id).delete();
}
