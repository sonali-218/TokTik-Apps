import 'package:firebase_auth/firebase_auth.dart';

/// Error de autenticación con mensaje en español (nunca se muestra el
/// código crudo de Firebase al usuario).
class AuthFailure implements Exception {
  final String message;
  AuthFailure(this.message);

  @override
  String toString() => message;
}

/// Envuelve FirebaseAuth: registro, inicio y cierre de sesión.
class AuthService {
  final FirebaseAuth _auth;

  AuthService({FirebaseAuth? firebaseAuth})
      : _auth = firebaseAuth ?? FirebaseAuth.instance;

  /// Emite null sin sesión y un User con sesión. AuthGate lo escucha.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> register({required String email, required String password}) async {
    try {
      await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e.code));
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(
          email: email.trim(), password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e.code));
    }
  }

  Future<void> signOut() => _auth.signOut();

  String _message(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Ya existe una cuenta registrada con ese correo.';
      case 'invalid-email':
        return 'El correo electrónico no tiene un formato válido.';
      case 'weak-password':
        return 'La contraseña es demasiado débil (mínimo 6 caracteres).';
      case 'user-not-found':
        return 'No existe ninguna cuenta registrada con ese correo.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos.';
      case 'user-disabled':
        return 'Esta cuenta fue deshabilitada.';
      case 'too-many-requests':
        return 'Demasiados intentos fallidos. Intenta más tarde.';
      case 'network-request-failed':
        return 'Sin conexión a internet.';
      default:
        return 'No se pudo completar la operación (código: $code).';
    }
  }
}
