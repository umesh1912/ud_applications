import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Phone sign-in with a one-time code.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pc = context.pc;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          children: [
            Airmail(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pul', style: context.tt.displayLarge!.copyWith(color: pc.blue)),
                        Text('Send money abroad. See every rupee of the cost first.', style: context.tt.bodyLarge),
                      ],
                    ),
                  ),
                  Postmark(label: 'India', color: pc.red, size: 70),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(_sent ? 'Enter the 6-digit code' : 'Your mobile number', style: context.tt.headlineSmall),
            const SizedBox(height: 6),
            Text(
              _sent ? 'Sent by SMS to +91 ${_phone.text}. (Demo: any 6 digits work.)' : 'Use the number linked to your bank account.',
              style: context.tt.bodyMedium!.copyWith(color: pc.muted),
            ),
            const SizedBox(height: 16),
            if (!_sent)
              TextField(
                controller: _phone,
                autofocus: true,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                decoration: InputDecoration(prefixText: '+91  ', labelText: 'Mobile number', errorText: _error),
              )
            else
              TextField(
                controller: _otp,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: context.tt.headlineMedium!.copyWith(letterSpacing: 10),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                decoration: InputDecoration(hintText: '••••••', errorText: _error),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                if (!_sent) {
                  if (_phone.text.length != 10) {
                    setState(() => _error = 'Enter a 10-digit mobile number.');
                    return;
                  }
                  setState(() {
                    _sent = true;
                    _error = null;
                  });
                } else {
                  if (_otp.text.length != 6) {
                    setState(() => _error = 'Enter all 6 digits.');
                    return;
                  }
                  StoreScope.read(context).signIn(_phone.text);
                }
              },
              child: Text(_sent ? 'Verify' : 'Send code'),
            ),
            if (_sent)
              TextButton(onPressed: () => setState(() => _sent = false), child: const Text('Change number')),
            const SizedBox(height: 24),
            const DemoNote(),
          ],
        ),
      ),
    );
  }
}

/// KYC: PAN, ID, video KYC, then a transaction PIN.
class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final _name = TextEditingController();
  final _pan = TextEditingController();
  final _id = TextEditingController();
  final _pin = TextEditingController();
  bool _video = false;
  bool _consent = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _pan.dispose();
    _id.dispose();
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final pc = context.pc;

    if (store.kyc == KycState.inReview) {
      return Scaffold(
        appBar: AppBar(title: const Text('Verifying you')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Postmark(label: 'In review', color: pc.warn, size: 110),
              const SizedBox(height: 24),
              Text('Checking your PAN and video KYC', style: context.tt.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('This usually takes a few minutes. (Demo: about 5 seconds.)',
                  style: context.tt.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              const LinearProgressIndicator(),
            ],
          ),
        ),
      );
    }

    if (store.kyc == KycState.verified && store.txnPin != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Postmark(label: 'Ready', color: pc.ok, size: 110)),
              const SizedBox(height: 24),
              Text('You\'re all set to send money abroad.', textAlign: TextAlign.center, style: context.tt.headlineSmall),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      );
    }

    if (store.kyc == KycState.verified && store.txnPin == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Set a transaction PIN')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Postmark(label: 'Verified', color: pc.ok, size: 90),
            const SizedBox(height: 16),
            Text('You\'re verified, ${store.name.split(' ').first}.', style: context.tt.headlineSmall),
            const SizedBox(height: 6),
            Text('Choose a 4-digit PIN. You\'ll enter it to approve every transfer.', style: context.tt.bodyMedium),
            const SizedBox(height: 16),
            TextField(
              controller: _pin,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
              decoration: InputDecoration(labelText: 'Transaction PIN', errorText: _error),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                if (_pin.text.length != 4) {
                  setState(() => _error = 'Use exactly 4 digits.');
                  return;
                }
                if (const ['0000', '1234', '1111'].contains(_pin.text)) {
                  setState(() => _error = 'That PIN is easy to guess. Pick another.');
                  return;
                }
                store.setTxnPin(_pin.text);
              },
              child: const Text('Save PIN'),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Verify your identity')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(
            'Indian law requires full KYC before money can be sent abroad. It takes about 3 minutes.',
            style: context.tt.bodyMedium,
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Full name as on PAN'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pan,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [LengthLimitingTextInputFormatter(10)],
            decoration: const InputDecoration(labelText: 'PAN', hintText: 'ABCDE1234F'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _id,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
            decoration: const InputDecoration(labelText: 'Last 4 digits of Aadhaar', helperText: 'Or verify with your passport during video KYC'),
          ),
          const SizedBox(height: 16),
          Paper(
            onTap: _video
                ? null
                : () async {
                    await showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Video KYC'),
                        content: const Text(
                            'In the real app a verification officer joins a short video call and checks your original PAN. '
                            'In this demo we\'ll mark it done.'),
                        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Mark as done'))],
                      ),
                    );
                    setState(() => _video = true);
                  },
            child: Row(
              children: [
                Icon(_video ? Icons.check_circle : Icons.videocam_outlined, color: _video ? pc.ok : pc.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_video ? 'Video KYC done' : 'Start video KYC', style: context.tt.titleSmall),
                      Text('Keep your original PAN card ready.', style: context.tt.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _consent,
            onChanged: (v) => setState(() => _consent = v ?? false),
            title: Text('I agree to share my PAN and KYC details for verification and LRS reporting.', style: context.tt.bodyMedium),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (_error != null) Text(_error!, style: context.tt.bodyMedium!.copyWith(color: pc.red)),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              final pan = _pan.text.trim().toUpperCase();
              String? e;
              if (_name.text.trim().length < 3) {
                e = 'Enter your full name as printed on your PAN card.';
              } else if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(pan)) {
                e = 'A PAN has 5 letters, 4 numbers and 1 letter, like ABCDE1234F.';
              } else if (_id.text.length != 4) {
                e = 'Enter the last 4 digits of your Aadhaar.';
              } else if (!_video) {
                e = 'Finish video KYC to continue.';
              } else if (!_consent) {
                e = 'Tick the consent box to continue.';
              }
              setState(() => _error = e);
              if (e == null) store.submitKyc(name: _name.text.trim(), pan: pan);
            },
            child: const Text('Submit for verification'),
          ),
        ],
      ),
    );
  }
}
