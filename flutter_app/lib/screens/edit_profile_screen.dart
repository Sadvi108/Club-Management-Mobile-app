import '../theme/app_icons.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../services/api.dart';
import '../services/response_utils.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/gradient_button.dart';

/// Edit Profile — name, contact, address and display picture.
///
/// Writes through `/Profile/UpdateProfile`, which is multipart/form-data and expects the
/// identity fields (Id, UserId, IcNo, BranchId, ClubId) echoed back alongside the edits.
/// Omitting them has the server treat the update as a different record.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _postal = TextEditingController();
  String _gender = '';

  XFile? _picked;
  Uint8List? _pickedBytes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = UserSession.instance;
    _name.text = s.displayName.trim();
    _email.text = s.email;
    _phone.text = s.phone;
    _address.text = _field(s, ['address1', 'Address1', 'address']);
    _postal.text = _field(s, ['postalCode', 'PostalCode', 'postcode']);
    _gender = _field(s, ['gender', 'Gender']);
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _address, _postal]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _field(UserSession s, List<String> keys) {
    for (final src in [s.myInfo, s.authData, s.studentAddtnlInfo]) {
      if (src == null) continue;
      for (final k in keys) {
        final v = src[k];
        if (v != null && '$v'.trim().isNotEmpty) return '$v'.trim();
      }
    }
    return '';
  }

  void _toast(String msg, {int seconds = 4}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: Duration(seconds: seconds)));
  }

  Future<void> _pick(ImageSource source) async {
    Navigator.of(context).maybePop();
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: source,
        imageQuality: 60,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (file == null) return;
      // Read the bytes now: on web there is no file path to upload from later, and the
      // preview needs them either way.
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _picked = file;
        _pickedBytes = bytes;
      });
    } catch (e) {
      _toast('Could not pick an image: ${friendlyError(e)}');
    }
  }

  void _choosePhoto() {
    final c = context.appColors;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xxl))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: Icon(Icons.photo_camera_outlined, color: c.primary),
            title: const Text('Take a photo'),
            onTap: () => _pick(ImageSource.camera),
          ),
          ListTile(
            leading: Icon(Icons.photo_library_outlined, color: c.primary),
            title: const Text('Choose from gallery'),
            onTap: () => _pick(ImageSource.gallery),
          ),
          const SizedBox(height: Gaps.sm),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _toast('Please enter your name.');
      return;
    }
    setState(() => _saving = true);
    final s = UserSession.instance;

    // Identity fields go back verbatim. The server keys the update on them, and a blank
    // Id would create or overwrite the wrong record rather than fail loudly.
    final fields = <String, String>{
      'Id': _field(s, ['id', 'Id']),
      'UserId': _field(s, ['userId', 'UserId']),
      'IcNo': _field(s, ['icNo', 'IcNo', 'nric']),
      'Name': name,
      'EmailAddress': _email.text.trim(),
      'HandPhone': _phone.text.trim(),
      'Gender': _gender,
      'Address1': _address.text.trim(),
      'Address2': _field(s, ['address2', 'Address2']),
      'Address3': _field(s, ['address3', 'Address3']),
      'Address4': _field(s, ['address4', 'Address4']),
      'PostalCode': _postal.text.trim(),
      'BranchId': _field(s, ['branchId', 'BranchId']),
      'ClubId': _field(s, ['clubId', 'ClubId']),
    };

    // The photo goes up BOTH ways on purpose. The Expo app attaches a `files` part; this
    // app's older profile sheet sent a base64 `ProfilePic` field, and neither has been
    // confirmed against the live server as the one that sticks. Servers ignore form fields
    // they do not bind, so sending both costs one field and removes the coin flip. It also
    // means web — which has no filesystem path for a multipart file — can still set a photo.
    final photoB64 = _pickedBytes == null ? null : base64Encode(_pickedBytes!);
    if (photoB64 != null) fields['ProfilePic'] = photoB64;

    try {
      final canUploadFile = !kIsWeb && _picked != null;
      final res = await Api.profileUpdateProfile(
        fields,
        photoPath: canUploadFile ? _picked!.path : null,
      );

      // Mirror the edit locally so the profile screen updates without a round trip.
      final info = Map<String, dynamic>.from(s.myInfo ?? {});
      info['name'] = name;
      info['emailAddress'] = _email.text.trim();
      info['handPhone'] = _phone.text.trim();
      info['gender'] = _gender;
      info['address1'] = _address.text.trim();
      info['postalCode'] = _postal.text.trim();

      final returned = unwrapData(res);
      if (returned is String && returned.trim().isNotEmpty) {
        info['photo'] = returned.trim();
      }
      s.myInfo = info;

      // The API exposes no read-back for an uploaded picture, so cache it on-device.
      if (photoB64 != null) await s.setLocalPhoto(photoB64);
      s.touch();

      if (!mounted) return;
      setState(() => _saving = false);
      _toast('Your profile has been updated.');
      Navigator.of(context).maybePop();
    } catch (e) {
      // Keep the picked photo on this device even when the server rejected the save —
      // otherwise the avatar reverts and it reads as though the pick itself failed.
      if (photoB64 != null) await s.setLocalPhoto(photoB64);
      if (!mounted) return;
      setState(() => _saving = false);
      _toast('Update failed: ${friendlyError(e)}', seconds: 6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final s = context.watch<UserSession>();

    return Scaffold(
      backgroundColor: c.background,
      body: Column(children: [
        const AppHeader(title: 'Edit Profile', showBack: true),
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding:
                const EdgeInsets.fromLTRB(Gaps.lg, Gaps.md, Gaps.lg, Gaps.xxxl),
            children: [
              Center(child: _avatar(c, s)),
              const SizedBox(height: Gaps.xl),
              _label(c, 'FULL NAME'),
              _input(c, _name, hint: 'Your name', capitalize: true),
              _label(c, 'EMAIL'),
              _input(c, _email,
                  hint: 'you@example.com',
                  keyboard: TextInputType.emailAddress),
              _label(c, 'PHONE'),
              _input(c, _phone,
                  hint: '01x-xxxxxxx', keyboard: TextInputType.phone),
              _label(c, 'GENDER'),
              _genderRow(c),
              _label(c, 'ADDRESS'),
              _input(c, _address,
                  hint: 'Street address', maxLines: 2, capitalize: true),
              _label(c, 'POSTAL CODE'),
              _input(c, _postal, hint: '43000', keyboard: TextInputType.number),
              const SizedBox(height: Gaps.xl),
              GradientButton(
                label: 'Save changes',
                trailingIcon: AppIcons.check,
                loading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _avatar(AppColors c, UserSession s) {
    final initials = s.displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    ImageProvider? image;
    if (_pickedBytes != null) {
      image = MemoryImage(_pickedBytes!);
    } else if (s.localPhotoB64.isNotEmpty) {
      try {
        image = MemoryImage(base64Decode(s.localPhotoB64));
      } catch (_) {
        image = null;
      }
    } else if (s.studentPhoto.isNotEmpty) {
      image = NetworkImage(s.studentPhoto);
    }

    return Stack(children: [
      Container(
        width: 104,
        height: 104,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: c.surfaceAlt,
          border: Border.all(color: c.border, width: 2),
          image: image == null
              ? null
              : DecorationImage(image: image, fit: BoxFit.cover),
        ),
        alignment: Alignment.center,
        child: image == null
            ? Text(initials.isEmpty ? '?' : initials,
                style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 30,
                    fontWeight: FontWeight.w800))
            : null,
      ),
      Positioned(
        right: 0,
        bottom: 0,
        child: Material(
          color: c.primary,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _saving ? null : _choosePhoto,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.photo_camera, size: 18, color: Colors.white),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _label(AppColors c, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: Gaps.md),
        child: Text(text,
            style: TextStyle(
                color: c.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
      );

  Widget _input(
    AppColors c,
    TextEditingController controller, {
    String? hint,
    TextInputType? keyboard,
    int maxLines = 1,
    bool capitalize = false,
  }) =>
      TextField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: maxLines,
        enabled: !_saving,
        textCapitalization:
            capitalize ? TextCapitalization.words : TextCapitalization.none,
        style: TextStyle(
            color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: c.textMuted, fontWeight: FontWeight.w400),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          filled: true,
          fillColor: c.surface,
          enabledBorder: _pill(c.border),
          focusedBorder: _pill(c.primary),
          disabledBorder: _pill(c.border),
        ),
      );

  OutlineInputBorder _pill(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
        borderSide: BorderSide(color: color),
      );

  Widget _genderRow(AppColors c) {
    // Free text on the server; these two cover the values it actually stores, and an
    // unrecognised existing value stays selected rather than being silently rewritten.
    const options = ['Male', 'Female'];
    final known = options.any((o) => o.toLowerCase() == _gender.toLowerCase());
    return Wrap(spacing: Gaps.sm, children: [
      for (final o in options)
        ChoiceChip(
          label: Text(o),
          selected: o.toLowerCase() == _gender.toLowerCase(),
          onSelected:
              _saving ? null : (v) => setState(() => _gender = v ? o : ''),
        ),
      if (!known && _gender.isNotEmpty)
        ChoiceChip(label: Text(_gender), selected: true, onSelected: null),
    ]);
  }
}
