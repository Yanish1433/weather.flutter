import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAuthServices {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<User?> signUpWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      print('User signed up: ${credential.user?.uid}');
      return credential.user;
    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Error: ${e.code} - ${e.message}");
      rethrow;
    } catch (e) {
      print("Unexpected error during signup: $e");
      throw Exception('Unexpected error during signup: $e');
    }
  }

  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      print('User signed in: ${credential.user?.uid}');
      return credential.user;
    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Error: ${e.code} - ${e.message}");
      rethrow;
    } catch (e) {
      print("Unexpected error during login: $e");
      throw Exception('Unexpected error during login: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      print('User signed out');
    } catch (e) {
      print("Error signing out: $e");
      throw Exception('Error signing out: $e');
    }
  }

  User? getCurrentUser() {
    final user = _auth.currentUser;
    print('Current user: ${user?.uid}');
    return user;
  }
}