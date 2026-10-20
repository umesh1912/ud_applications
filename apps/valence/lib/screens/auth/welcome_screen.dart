import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/sample_data.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/graph_paper.dart';

/// Sign-in. Phone OTP is the primary path (most students have a phone,
/// not every student has a personal email). Google and email are secondary.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    return Scaffold(
      body: GraphPaper(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: Space.xxl),
                const _PeriodicStrip(),
                const Spacer(),
                Text('Valence', style: context.text.displayMedium),
                const SizedBox(height: Space.s),
                Text(
                  'Lessons, solved examples, notes and mock tests for Physics, Chemistry, Biology, Maths and Computer Science.',
                  style: context.text.bodyLarge!.copyWith(color: vc.muted),
                ),
                const SizedBox(height: Space.xl),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PhoneSignInScreen()),
                  ),
                  icon: const Icon(Icons.phone_iphone),
                  label: const Text('Continue with phone'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                ),
                const SizedBox(height: Space.m),
                OutlinedButton.icon(
                  onPressed: () => _googleSignIn(context),
                  icon: const Icon(Icons.g_mobiledata, size: 30),
                  label: const Text('Continue with Google'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                ),
                const SizedBox(height: Space.s),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const EmailSignInScreen()),
                    ),
                    child: const Text('Use email instead'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.l),
                  child: Text(
                    'By continuing you agree to the Terms and Privacy Policy.',
                    textAlign: TextAlign.center,
                    style: context.text.bodySmall,
                  ),
                ),
              ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _googleSignIn(BuildContext context) {
    // Wire up google_sign_in + Firebase Auth here (see README).
    AppScope.read(context).signIn(contact: 'student@gmail.com');
  }
}

/// Five subject tiles staggered like the corner of a periodic table.
class _PeriodicStrip extends StatelessWidget {
  const _PeriodicStrip();

  @override
  Widget build(BuildContext context) {
    final subjects = SampleData.subjects;
    return ExcludeSemantics(
      child: SizedBox(
        height: 150,
        child: Builder(builder: (context) {
          // Avoid LayoutBuilder here: the parent measures intrinsic height.
          final width = MediaQuery.sizeOf(context).width - 2 * Space.gutter;
          final size = ((width - 4 * 8) / 5).clamp(40.0, 110.0);
          return Stack(
            children: [
              for (var i = 0; i < subjects.length; i++)
                Positioned(
                  left: i * (size + 8),
                  top: (i.isEven ? 0 : 28).toDouble(),
                  width: size,
                  height: size,
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.vc.sheet,
                      border: Border.all(color: subjects[i].color, width: 1.6),
                      borderRadius: BorderRadius.circular(Radii.tile),
                    ),
                    padding: const EdgeInsets.all(5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${subjects[i].number}',
                            style: context.text.labelSmall!.copyWith(color: subjects[i].color)),
                        Expanded(
                          child: Center(
                            child: FittedBox(
                              child: Text(subjects[i].symbol,
                                  style: context.text.headlineMedium!.copyWith(color: subjects[i].color)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class PhoneSignInScreen extends StatefulWidget {
  const PhoneSignInScreen({super.key});

  @override
  State<PhoneSignInScreen> createState() => _PhoneSignInScreenState();
}

class _PhoneSignInScreenState extends State<PhoneSignInScreen> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  bool _codeSent = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  void _sendCode() {
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) {
      setState(() => _error = 'Enter a 10-digit mobile number.');
      return;
    }
    // Firebase: FirebaseAuth.instance.verifyPhoneNumber(...)
    setState(() {
      _error = null;
      _codeSent = true;
    });
  }

  void _verify() {
    if (_otp.text.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from the SMS.');
      return;
    }
    // Demo accepts any 6 digits. Replace with PhoneAuthProvider.credential(...)
    AppScope.read(context).signIn(contact: '+91 ${_phone.text}');
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          children: [
            Text(_codeSent ? 'Enter the code' : 'Your mobile number',
                style: context.text.headlineMedium),
            const SizedBox(height: Space.s),
            Text(
              _codeSent
                  ? 'We sent a 6-digit code to +91 ${_phone.text}.'
                  : 'We\'ll text you a one-time code. No password needed.',
              style: context.text.bodyMedium!.copyWith(color: vc.muted),
            ),
            const SizedBox(height: Space.xl),
            if (!_codeSent)
              TextField(
                controller: _phone,
                autofocus: true,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                decoration: InputDecoration(
                  prefixText: '+91  ',
                  labelText: 'Mobile number',
                  errorText: _error,
                ),
                onSubmitted: (_) => _sendCode(),
              )
            else
              TextField(
                controller: _otp,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: context.text.headlineMedium!.copyWith(letterSpacing: 12),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                decoration: InputDecoration(hintText: '••••••', errorText: _error),
                onChanged: (v) {
                  if (v.length == 6) _verify();
                },
              ),
            const SizedBox(height: Space.l),
            FilledButton(
              onPressed: _codeSent ? _verify : _sendCode,
              child: Text(_codeSent ? 'Verify and continue' : 'Send code'),
            ),
            if (_codeSent)
              TextButton(
                onPressed: () => setState(() {
                  _codeSent = false;
                  _otp.clear();
                }),
                child: const Text('Change number'),
              ),
          ],
        ),
      ),
    );
  }
}

class EmailSignInScreen extends StatefulWidget {
  const EmailSignInScreen({super.key});

  @override
  State<EmailSignInScreen> createState() => _EmailSignInScreenState();
}

class _EmailSignInScreenState extends State<EmailSignInScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _creating = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    // Firebase: signInWithEmailAndPassword / createUserWithEmailAndPassword
    AppScope.read(context).signIn(contact: _email.text.trim());
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            children: [
              Text(_creating ? 'Create an account' : 'Sign in with email',
                  style: context.text.headlineMedium),
              const SizedBox(height: Space.xl),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) =>
                    (v == null || !v.contains('@') || !v.contains('.')) ? 'Enter a valid email address.' : null,
              ),
              const SizedBox(height: Space.m),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: 'Password',
                  helperText: _creating ? 'At least 8 characters.' : null,
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) => (v == null || v.length < 8) ? 'Use at least 8 characters.' : null,
                onFieldSubmitted: (_) => _submit(),
              ),
              if (!_creating)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password reset link sent to your email.')),
                    ),
                    child: const Text('Forgot password?'),
                  ),
                ),
              const SizedBox(height: Space.l),
              FilledButton(
                onPressed: _submit,
                child: Text(_creating ? 'Create account' : 'Sign in'),
              ),
              TextButton(
                onPressed: () => setState(() => _creating = !_creating),
                child: Text(_creating ? 'I already have an account' : 'New here? Create an account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
