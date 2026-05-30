import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'forgot_password_screen.dart';
import 'register_page.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../theme/avatar_helper.dart';
import '../../services/app_localizations.dart'; // Import Localization
import '../widgets/decorative_background.dart';
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FocusNode _passwordFocusNode = FocusNode();

  String _errorMessage = '';
  bool _isLoading = false;
  bool _isPasswordObscured = true;

  Route _createSlideUpRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutQuart;
        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
  }

  Future<void> _signIn() async {
    if (_isLoading) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final t = AppLocalizations.of(context)!; //

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-credential':
        case 'user-not-found':
        case 'wrong-password':
          _errorMessage = t.translate('error_invalid_credential');
          break;
        case 'invalid-email':
          _errorMessage = t.translate('error_invalid_email');
          break;
        case 'user-disabled':
          _errorMessage = t.translate('error_user_disabled');
          break;
        default:
          _errorMessage = t.translate('general_error');
      }
    } catch (e) {
       _errorMessage = '${t.translate('general_error')}: $e';
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final String email = googleUser.email;
      if (!(email.endsWith('@pnj.ac.id') || email.endsWith('.pnj.ac.id'))) {
        await googleSignIn.signOut();
        setState(() => _errorMessage = 'Access Denied: Must use a valid PNJ email');
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential;
      try {
        userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'account-exists-with-different-credential') {
          final String? existingEmail = e.email;
          if (existingEmail == null) {
            await googleSignIn.signOut();
            setState(() => _errorMessage = 'Account merge failed: Unknown email.');
            setState(() => _isLoading = false);
            return;
          }
          final String? password = await _showPasswordPromptDialog(existingEmail);
          if (password == null || password.isEmpty) {
            await googleSignIn.signOut();
            setState(() => _isLoading = false);
            return;
          }
          setState(() => _isLoading = true);
          final AuthCredential emailCred = EmailAuthProvider.credential(email: existingEmail, password: password);
          final UserCredential existingUser = await FirebaseAuth.instance.signInWithCredential(emailCred);
          userCredential = await existingUser.user!.linkWithCredential(credential);
        } else {
          rethrow;
        }
      }

      final String? fbEmail = userCredential.user?.email;
      if (fbEmail == null || !(fbEmail.endsWith('@pnj.ac.id') || fbEmail.endsWith('.pnj.ac.id'))) {
        await userCredential.user?.delete();
        await FirebaseAuth.instance.signOut();
        await googleSignIn.signOut();
        setState(() => _errorMessage = 'Access Denied: Invalid email domain.');
        setState(() => _isLoading = false);
        return;
      }

      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Google Sign-In Error: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<String?> _showPasswordPromptDialog(String email) async {
    final t = AppLocalizations.of(context)!;
    String? password;
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text('Account Linking Required', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('An account with $email already exists. Enter your password to merge and link your Google account.'),
              SizedBox(height: 16),
              TextField(
                obscureText: true,
                onChanged: (val) => password = val,
                decoration: InputDecoration(
                  labelText: t.translate('auth_enter_password'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text(t.translate('general_cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, password),
              style: ElevatedButton.styleFrom(backgroundColor: SisapaTheme.blue, foregroundColor: Colors.white),
              child: Text('Link Account'),
            ),
          ],
        );
      },
    );
  }

  String? _validateEmail(String? value) {
    final t = AppLocalizations.of(context)!; //
    if (value == null || value.trim().isEmpty) return t.translate('val_email_empty');
    String pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
    RegExp regex = RegExp(pattern);
    if (!regex.hasMatch(value)) return t.translate('val_email_invalid');
    return null;
  }

  String? _validatePassword(String? value) {
    final t = AppLocalizations.of(context)!;
    if (value == null || value.isEmpty) return t.translate('val_password_empty');
    return null;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.primaryColor),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: DecorativeBackground()),

          TweenAnimationBuilder(
            tween: Tween<double>(begin: 1.0, end: 0.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutQuart,
            builder: (context, double value, child) {
              return Transform.translate(
                offset: Offset(0, value * 200),
                child: Opacity(
                  opacity: 1 - value,
                  child: child,
                ),
              );
            },
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Rebranding Header
                      Row(
                        children: [
                          Text(
                            "SAPA",
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: SisapaTheme.blue,
                              letterSpacing: -1.0,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            "PNJ",
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.0,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 40),

                      Text(
                        t.translate('auth_sign_in_title'), //
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 32),

                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(labelText: t.translate('auth_enter_email')), //
                        keyboardType: TextInputType.emailAddress,

                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) {
                          FocusScope.of(context).requestFocus(_passwordFocusNode);
                        },

                        validator: _validateEmail,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                      ),
                      SizedBox(height: 16),

                      TextFormField(
                        controller: _passwordController,
                        focusNode: _passwordFocusNode,
                        obscureText: _isPasswordObscured,
                        decoration: InputDecoration(
                          labelText: t.translate('auth_enter_password'), //
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordObscured ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordObscured = !_isPasswordObscured;
                              });
                            },
                          ),
                        ),

                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          _signIn();
                        },

                        validator: _validatePassword,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                      ),
                      SizedBox(height: 16),

                      if (_errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16, top: 8),
                          child: Center(
                            child: Text(
                              _errorMessage,
                              style: const TextStyle(color: Colors.red, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),

                      Align(
                        alignment: Alignment.center,
                        child: TextButton(
                          onPressed: () {
                             Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => ForgotPasswordScreen()),
                            );
                          },
                          child: Text(t.translate('auth_forgot_pass'), style: TextStyle(color: SisapaTheme.blue)), //
                        ),
                      ),
                      SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _signIn,
                          child: Text(t.translate('auth_login')), //
                          style: ElevatedButton.styleFrom(
                            backgroundColor: SisapaTheme.blue,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: Icon(FontAwesomeIcons.google, size: 20),
                          label: Text("Sign in with Google (@pnj.ac.id)"),
                          onPressed: _signInWithGoogle,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.onSurface,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(t.translate('auth_no_account') + " ", style: TextStyle(color: theme.hintColor)), //
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).pushReplacement(_createSlideUpRoute(RegisterPage()));
                            },
                            child: Text(
                              t.translate('auth_create_one'), //
                              style: TextStyle(
                                color: SisapaTheme.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
