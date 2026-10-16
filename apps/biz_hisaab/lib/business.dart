import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ud_core/ud_core.dart';

import 'db.dart';
import 'gst.dart';
import 'main.dart' show appName;
import 'pdf.dart';
import 'ui.dart';

/// Business profile. Shown on first launch, later from More.
class BusinessPage extends StatefulWidget {
  const BusinessPage({super.key, this.firstRun = false});
  final bool firstRun;

  @override
  State<BusinessPage> createState() => _BusinessPageState();
}

class _BusinessPageState extends State<BusinessPage> {
  late final Business _b = Business.fromJson(db.biz.toJson());
  late final _name = TextEditingController(text: _b.name);
  late final _phone = TextEditingController(text: _b.phone);
  late final _email = TextEditingController(text: _b.email);
  late final _gstin = TextEditingController(text: _b.gstin);
  late final _address = TextEditingController(text: _b.address);
  late final _upi = TextEditingController(text: _b.upi);
  late final _bank = TextEditingController(text: _b.bankName);
  late final _acc = TextEditingController(text: _b.accountNo);
  late final _ifsc = TextEditingController(text: _b.ifsc);

  Future<void> _pickImage(bool logo) async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 90);
    if (x == null) return;
    final dir = await udDir('hisaab/images');
    final ext = x.path.split('.').last.toLowerCase();
    final path = '${dir.path}/${logo ? 'logo' : 'sign'}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await File(x.path).copy(path);
    setState(() {
      if (logo) {
        _b.logoPath = path;
      } else {
        _b.signPath = path;
      }
    });
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      udToast(context, context.tr('need_biz_name'));
      return;
    }
    final g = _gstin.text.trim().toUpperCase();
    if (g.isNotEmpty && !isValidGstin(g)) {
      udToast(context, context.tr('bad_gstin'));
      return;
    }
    final upi = _upi.text.trim();
    if (upi.isNotEmpty && !upi.contains('@')) {
      udToast(context, context.tr('bad_upi'));
      return;
    }
    _b
      ..name = _name.text.trim()
      ..phone = _phone.text.trim()
      ..email = _email.text.trim()
      ..gstin = g
      ..address = _address.text.trim()
      ..upi = upi
      ..bankName = _bank.text.trim()
      ..accountNo = _acc.text.trim()
      ..ifsc = _ifsc.text.trim().toUpperCase();
    if (g.isNotEmpty) _b.state = stateFromGstin(g) ?? _b.state;
    db.biz = _b;
    await db.save();
    if (!mounted) return;
    if (widget.firstRun) {
      udToast(context, context.tr('welcome_done'));
    } else {
      udToast(context, context.tr('saved'));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final t = UdTokens.of(context);
    Widget imageTile(String label, String path, bool logo) => Expanded(
          child: UdPressable(
            onTap: () => _pickImage(logo),
            onLongPress: path.isEmpty
                ? null
                : () => setState(() {
                      if (logo) {
                        _b.logoPath = '';
                      } else {
                        _b.signPath = '';
                      }
                    }),
            borderRadius: 18,
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              SizedBox(
                height: 64,
                child: path.isNotEmpty && File(path).existsSync()
                    ? Image.file(File(path), fit: BoxFit.contain)
                    : Icon(logo ? Icons.add_photo_alternate_outlined : Icons.draw_outlined, size: 36, color: t.accent),
              ),
              const SizedBox(height: 6),
              Text(label, style: text.labelMedium),
            ]),
          ),
        );

    return UdPage(
      eyebrow: widget.firstRun ? appName : null,
      title: context.tr(widget.firstRun ? 'setup_title' : 'business_profile'),
      subtitle: widget.firstRun ? context.tr('setup_sub') : null,
      showBack: !widget.firstRun,
      actions: [if (widget.firstRun) const UdSettingsButton(appName: appName)],
      dock: UdDock(label: context.tr(widget.firstRun ? 'start' : 'save'), icon: Icons.check_rounded, onPressed: _save),
      slivers: [
        UdSliverPad(
          sliver: SliverList.list(children: [
            Field(_name, context.tr('biz_name'), caps: TextCapitalization.words, autofocus: widget.firstRun),
            Field(_phone, context.tr('phone'), type: TextInputType.phone),
            Field(_address, context.tr('address'), maxLines: 3),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr('gst_registered')),
              subtitle: Text(context.tr('gst_registered_sub'), style: text.bodySmall),
              value: _b.gstEnabled,
              onChanged: (v) => setState(() => _b.gstEnabled = v),
            ),
            if (_b.gstEnabled)
              Field(_gstin, context.tr('gstin'), caps: TextCapitalization.characters, hint: context.tr('optional'), onChanged: (v) {
                final s = stateFromGstin(v.trim());
                if (s != null) setState(() => _b.state = s);
              }),
            PickField(
              label: context.tr('state'),
              value: '${stateName(_b.state)} (${_b.state})',
              icon: Icons.place_outlined,
              onTap: () async {
                final s = await pickState(context);
                if (s != null) setState(() => _b.state = s);
              },
            ),
            UdLabel(context.tr('get_paid')),
            Field(_upi, context.tr('upi_id'), hint: 'name@okbank', caps: TextCapitalization.none),
            Text(context.tr('upi_hint'), style: text.bodySmall),
            const SizedBox(height: 14),
            Field(_bank, context.tr('bank_name'), hint: context.tr('optional'), caps: TextCapitalization.words),
            Row(children: [
              Expanded(child: Field(_acc, context.tr('account_no'), type: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(child: Field(_ifsc, 'IFSC', caps: TextCapitalization.characters)),
            ]),
            Field(_email, context.tr('email'), type: TextInputType.emailAddress, caps: TextCapitalization.none, hint: context.tr('optional')),
            UdLabel(context.tr('logo_sign')),
            Row(children: [
              imageTile(context.tr('logo'), _b.logoPath, true),
              const SizedBox(width: 12),
              imageTile(context.tr('signature'), _b.signPath, false),
            ]),
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text(context.tr('logo_hint'), style: text.bodySmall),
            ),
          ]),
        ),
      ],
    );
  }
}

class InvoiceSettingsPage extends StatefulWidget {
  const InvoiceSettingsPage({super.key});

  @override
  State<InvoiceSettingsPage> createState() => _InvoiceSettingsPageState();
}

class _InvoiceSettingsPageState extends State<InvoiceSettingsPage> {
  late final Business _b = Business.fromJson(db.biz.toJson());
  late final _prefix = TextEditingController(text: _b.invoicePrefix);
  late final _terms = TextEditingController(text: _b.terms);

  Future<void> _save() async {
    _b
      ..invoicePrefix = _prefix.text.trim()
      ..terms = _terms.text.trim();
    db.biz = _b;
    await db.save();
    if (mounted) {
      udToast(context, context.tr('saved'));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = UdTokens.of(context);
    return UdPage(
      title: context.tr('invoice_settings'),
      dock: UdDock(label: context.tr('save'), icon: Icons.check_rounded, onPressed: _save),
      slivers: [
        UdSliverPad(
          sliver: SliverList.list(children: [
            UdLabel(context.tr('print_size')),
            Chips<String>(
              values: const ['a4', 'a5', '80', '58'],
              selected: _b.printSize,
              label: (s) => context.tr('ps_$s'),
              onSelect: (s) => setState(() => _b.printSize = s),
            ),
            const SizedBox(height: 18),
            UdLabel(context.tr('invoice_colour')),
            Wrap(spacing: 12, children: [
              for (var i = 0; i < pdfThemes.length; i++)
                GestureDetector(
                  onTap: () => setState(() => _b.colour = i),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Color(pdfThemes[i]),
                      shape: BoxShape.circle,
                      border: Border.all(color: _b.colour == i ? t.ink : Colors.transparent, width: 3),
                    ),
                    child: _b.colour == i ? const Icon(Icons.check_rounded, color: Colors.white) : null,
                  ),
                ),
            ]),
            const SizedBox(height: 18),
            Field(_prefix, context.tr('invoice_prefix'), caps: TextCapitalization.characters, hint: 'INV-'),
            Field(_terms, context.tr('terms'), maxLines: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr('default_incl')),
              value: _b.taxInclusive,
              onChanged: (v) => setState(() => _b.taxInclusive = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr('round_off')),
              value: _b.roundOff,
              onChanged: (v) => setState(() => _b.roundOff = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr('gst_registered')),
              value: _b.gstEnabled,
              onChanged: (v) => setState(() => _b.gstEnabled = v),
            ),
          ]),
        ),
      ],
    );
  }
}
