import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../services/api.dart';
import '../services/response_utils.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../theme/ion.dart';
import '../widgets/rn_kit.dart';

/// Port of `frontend/app/edit-profile.tsx` (Expo v2.11.1).
///
/// Writes through `/Profile/UpdateProfile` (multipart), which expects the identity fields
/// (Id, UserId, IcNo, BranchId, ClubId) echoed back alongside the edits.
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

  Map<String, dynamic> get _user => UserSession.instance.authData ?? const <String, dynamic>{};
  String _u(String k) => '${_user[k] ?? ''}'.trim();

  @override
  void initState() {
    super.initState();
    _name.text = _u('name');
    _email.text = _u('emailAddress');
    _phone.text = _u('handPhone');
    _gender = _u('gender');
    _address.text = _u('address1');
    _postal.text = _u('postalCode');
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _address, _postal]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _openPicker() async {
    final c = context.appColors;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: c.overlay,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(Gaps.xl, 12, Gaps.xl, 24 + MediaQuery.paddingOf(ctx).bottom),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.xxl)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 44,
            height: 5,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(3)),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            for (final o in const [
              (label: 'Gallery', icon: Ion.images, color: Color(0xFFFB7185), source: ImageSource.gallery),
              (label: 'Camera', icon: Ion.camera, color: Color(0xFF34D399), source: ImageSource.camera),
            ])
              Touchable(
                onPress: () => Navigator.pop(ctx, o.source),
                child: Column(children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(color: o.color, borderRadius: BorderRadius.circular(20)),
                    child: Icon(o.icon, size: 26, color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  Text(o.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary)),
                ]),
              ),
          ]),
        ]),
      ),
    );
    if (source == null) return;
    try {
      final img = await ImagePicker().pickImage(source: source, imageQuality: 60, maxWidth: 1024, maxHeight: 1024);
      if (img == null) return;
      final bytes = await img.readAsBytes();
      if (mounted) {
        setState(() {
          _picked = img;
          _pickedBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) notify(context, 'Could not pick image', friendlyError(e));
    }
  }

  Future<void> _save() async {
    if (_user.isEmpty) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      await notify(context, 'Name required', 'Please enter your name.');
      return;
    }
    setState(() => _saving = true);
    final s = UserSession.instance;
    final fields = <String, String>{
      'Id': _u('id'),
      'UserId': _u('userId'),
      'IcNo': _u('icNo'),
      'Name': name,
      'EmailAddress': _email.text.trim(),
      'HandPhone': _phone.text.trim(),
      'Gender': _gender,
      'Address1': _address.text,
      'Address2': _u('address2'),
      'Address3': _u('address3'),
      'Address4': _u('address4'),
      'PostalCode': _postal.text,
      'BranchId': _u('branchId'),
      'ClubId': _u('clubId'),
    };
    // Web has no file path for a multipart part, so the photo also rides as base64
    // `ProfilePic`; the server ignores whichever field it does not bind.
    final photoB64 = _pickedBytes == null ? null : base64Encode(_pickedBytes!);
    if (photoB64 != null) fields['ProfilePic'] = photoB64;
    try {
      final res = await Api.profileUpdateProfile(fields,
          photoPath: !kIsWeb && _picked != null ? _picked!.path : null);
      final dpUrl = unwrapData(res);
      await s.updateUser({
        'name': name,
        'emailAddress': _email.text.trim(),
        'handPhone': _phone.text.trim(),
        'gender': _gender,
        'address1': _address.text,
        'postalCode': _postal.text,
        if (dpUrl is String && dpUrl.trim().isNotEmpty) 'profilePic': dpUrl.trim(),
      });
      if (photoB64 != null) await s.setLocalPhoto(photoB64);
      if (!mounted) return;
      setState(() => _saving = false);
      await notify(context, 'Saved', 'Your profile has been updated.');
      if (mounted) safeBack(context);
    } catch (e) {
      // Keep the picked photo on this device even when the save failed.
      if (photoB64 != null) await s.setLocalPhoto(photoB64);
      if (!mounted) return;
      setState(() => _saving = false);
      notify(context, 'Update failed', friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final session = context.watch<UserSession>();
    final avatarUrl = session.studentPhoto;

    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 8),
          child: Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textSecondary)),
        );

    Widget field(String l, TextEditingController ctrl, IconData icon,
        {TextInputType? keyboard, bool multiline = false}) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        label(l),
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: c.border),
          ),
          child: Row(crossAxisAlignment: multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center, children: [
            Padding(
              padding: EdgeInsets.only(top: multiline ? 12 : 0),
              child: Icon(icon, size: 18, color: c.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: multiline ? 70 : null,
                child: TextField(
                  controller: ctrl,
                  keyboardType: multiline ? TextInputType.multiline : keyboard,
                  maxLines: multiline ? null : 1,
                  expands: multiline,
                  textAlignVertical: multiline ? TextAlignVertical.top : null,
                  textCapitalization:
                      keyboard == TextInputType.emailAddress ? TextCapitalization.none : TextCapitalization.sentences,
                  cursorColor: c.primary,
                  style: TextStyle(color: c.textPrimary, fontSize: 15),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    hintText: l,
                    hintStyle: TextStyle(color: c.textMuted, fontSize: 15),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ]);
    }

    Widget readRow(String l, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Text(l, maxLines: 1, style: TextStyle(fontSize: 13, color: c.textSecondary)),
            const SizedBox(width: Gaps.md),
            Expanded(
              child: Text(v.isEmpty ? '—' : v,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 13, color: c.textPrimary, fontWeight: FontWeight.w600)),
            ),
          ]),
        );

    Widget avatar;
    if (_pickedBytes != null) {
      avatar = Image.memory(_pickedBytes!, width: 110, height: 110, fit: BoxFit.cover);
    } else if (avatarUrl.isNotEmpty || session.localPhotoB64.isNotEmpty) {
      Widget initials() => Center(
            child: Text(initialsOf(_name.text),
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: c.primary)),
          );
      avatar = session.localPhotoB64.isNotEmpty
          ? Image.memory(base64Decode(session.localPhotoB64),
              width: 110, height: 110, fit: BoxFit.cover, errorBuilder: (_, __, ___) => initials())
          : CachedNetworkImage(
              imageUrl: avatarUrl, width: 110, height: 110, fit: BoxFit.cover, errorWidget: (_, __, ___) => initials());
    } else {
      avatar = Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.border, width: 2)),
        alignment: Alignment.center,
        child: Text(initialsOf(_name.text),
            style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: c.primary)),
      );
    }

    return Scaffold(
      backgroundColor: c.background,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const RnHeader(title: 'Edit Profile'),
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(Gaps.xl, Gaps.xl, Gaps.xl, 60),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(children: [
                  Touchable(
                    onPress: _openPicker,
                    activeOpacity: 0.85,
                    child: SizedBox(
                      width: 110,
                      height: 110,
                      child: Stack(children: [
                        Container(
                          width: 110,
                          height: 110,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle),
                          child: avatar,
                        ),
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: c.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: c.background, width: 3),
                            ),
                            child: const Icon(Ion.camera, size: 16, color: Colors.white),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('Tap to change photo',
                      style: TextStyle(fontSize: 12, color: c.textSecondary, fontWeight: FontWeight.w600)),
                ]),
              ),
              field('Name', _name, Ion.personOutline),
              field('Email', _email, Ion.mailOutline, keyboard: TextInputType.emailAddress),
              field('Mobile No', _phone, Ion.callOutline, keyboard: TextInputType.phone),
              label('Gender'),
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(children: [
                  for (final g in const ['Male', 'Female']) ...[
                    if (g == 'Female') const SizedBox(width: 12),
                    Expanded(
                      child: Touchable(
                        onPress: () => setState(() => _gender = g),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _gender == g ? c.primary : c.surface,
                            borderRadius: BorderRadius.circular(Radii.md),
                            border: Border.all(color: _gender == g ? c.primary : c.border),
                          ),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(g == 'Male' ? Ion.male : Ion.female,
                                size: 16, color: _gender == g ? Colors.white : c.primary),
                            const SizedBox(width: 8),
                            Text(g,
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: _gender == g ? Colors.white : c.textPrimary)),
                          ]),
                        ),
                      ),
                    ),
                  ],
                ]),
              ),
              field('Address', _address, Ion.locationOutline, multiline: true),
              field('Postal Code', _postal, Ion.mapOutline, keyboard: TextInputType.number),
              Container(
                margin: const EdgeInsets.only(top: 6, bottom: 20),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.md)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('Read-only',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.textMuted, letterSpacing: 1)),
                  ),
                  readRow('IC No', _u('icNo')),
                  readRow('Registration No', _u('code')),
                  readRow('Grade', _u('currentGrade')),
                ]),
              ),
              Touchable(
                onPress: _saving ? null : _save,
                activeOpacity: 0.9,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 54),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: c.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(Radii.md),
                    boxShadow: Shadows.strong(c),
                  ),
                  child: _saving
                      ? const Center(
                          child: SizedBox(
                              width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)))
                      : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Ion.checkmark, size: 18, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Save Changes',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                        ]),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}
