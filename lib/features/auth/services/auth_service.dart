import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import '../../../core/constants/app_constants.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserModel?> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await result.user!.updateDisplayName(displayName);
      final user = UserModel(
        uid: result.user!.uid,
        displayName: displayName,
        email: email,
        createdAt: DateTime.now(),
        lastSeen: DateTime.now(),
      );
      await _firestore
          .collection(AppConstants.colUsers)
          .doc(user.uid)
          .set(user.toMap());
      return user;
    } catch (e) {
      rethrow;
    }
  }

  Future<UserModel?> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _setStatus(result.user!.uid, 'online');
      return await getUser(result.user!.uid);
    } catch (e) {
      rethrow;
    }
  }

  Future<UserModel?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;
      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final UserCredential result =
      await _auth.signInWithCredential(credential);
      final isNew = result.additionalUserInfo?.isNewUser ?? false;
      if (isNew) {
        final user = UserModel(
          uid: result.user!.uid,
          displayName: result.user!.displayName ?? '',
          email: result.user!.email ?? '',
          photoURL: result.user!.photoURL ?? '',
          createdAt: DateTime.now(),
          lastSeen: DateTime.now(),
        );
        await _firestore
            .collection(AppConstants.colUsers)
            .doc(user.uid)
            .set(user.toMap());
      }
      await _setStatus(result.user!.uid, 'online');
      return await getUser(result.user!.uid);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) await _setStatus(uid, 'offline');
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _firestore
        .collection(AppConstants.colUsers)
        .doc(uid)
        .get();
    if (doc.exists) return UserModel.fromMap(doc.data()!);
    return null;
  }

  Future<void> _setStatus(String uid, String status) async {
    await _firestore
        .collection(AppConstants.colUsers)
        .doc(uid)
        .update({'status': status, 'lastSeen': Timestamp.now()});
  }
}