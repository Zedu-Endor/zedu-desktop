import 'dart:io';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// A list of common timezone labels for the timezone dropdown.
const List<String> _kTimezones = [
  '(UTC-12:00) International Date Line West',
  '(UTC-11:00) Midway Island, Samoa',
  '(UTC-10:00) Hawaii',
  '(UTC-09:00) Alaska',
  '(UTC-08:00) Pacific Time (US & Canada)',
  '(UTC-07:00) Mountain Time (US & Canada)',
  '(UTC-06:00) Central Time (US & Canada)',
  '(UTC-05:00) Eastern Time (US & Canada)',
  '(UTC-04:00) Atlantic Time (Canada)',
  '(UTC-03:00) Buenos Aires, Georgetown',
  '(UTC-02:00) Mid-Atlantic',
  '(UTC-01:00) Azores, Cape Verde Islands',
  '(UTC+00:00) London, Dublin, Lisbon',
  '(UTC+01:00) West Central Africa',
  '(UTC+02:00) Cairo, Helsinki, Bucharest',
  '(UTC+03:00) Moscow, Nairobi, Baghdad',
  '(UTC+04:00) Abu Dhabi, Muscat',
  '(UTC+05:00) Islamabad, Karachi',
  '(UTC+05:30) Chennai, Kolkata, Mumbai',
  '(UTC+06:00) Almaty, Dhaka',
  '(UTC+07:00) Bangkok, Hanoi, Jakarta',
  '(UTC+08:00) Beijing, Singapore, Perth',
  '(UTC+09:00) Tokyo, Seoul, Osaka',
  '(UTC+10:00) Sydney, Guam, Vladivostok',
  '(UTC+11:00) Solomon Islands, New Caledonia',
  '(UTC+12:00) Auckland, Wellington, Fiji',
];

Future<void> showEditProfileDialog(
  BuildContext context,
  ProfileAccount account,
  ValueChanged<ProfileAccount> onSave,
) async {
  await showDialog<void>(
    context: context,
    builder: (context) => _EditProfileDialog(account: account, onSave: onSave),
  );
}

class _EditProfileDialog extends ConsumerStatefulWidget {
  const _EditProfileDialog({required this.account, required this.onSave});

  final ProfileAccount account;
  final ValueChanged<ProfileAccount> onSave;

  @override
  ConsumerState<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends ConsumerState<_EditProfileDialog> {
  late final TextEditingController nameCtrl;
  late final TextEditingController displayNameCtrl;
  late final TextEditingController usernameCtrl;
  late final TextEditingController emailCtrl;
  late final TextEditingController phoneCtrl;
  late final TextEditingController titleCtrl;
  late final TextEditingController pronunciationCtrl;

  final formKey = GlobalKey<FormState>();

  late String selectedTimezone;
  late String selectedCountry;

  File? _selectedAvatar;
  bool _removeAvatarRequested = false;
  bool _isUploading = false;
  String? _uploadError;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.account.name);
    displayNameCtrl = TextEditingController(text: widget.account.displayName);
    usernameCtrl = TextEditingController(text: widget.account.username);
    emailCtrl = TextEditingController(text: widget.account.email);
    phoneCtrl = TextEditingController(text: widget.account.phoneNumber);
    titleCtrl = TextEditingController(text: widget.account.title);
    pronunciationCtrl = TextEditingController(
      text: widget.account.namePronunciation,
    );

    selectedTimezone = widget.account.timezone.isNotEmpty
        ? widget.account.timezone
        : _kTimezones.first;
    selectedCountry = widget.account.country;
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    displayNameCtrl.dispose();
    usernameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    titleCtrl.dispose();
    pronunciationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: false,
        lockParentWindow: true,
      );

      if (result == null || result.files.isEmpty) return;
      final path = result.files.single.path;
      if (path == null) {
        setState(() => _uploadError = 'Could not access the selected image');
        return;
      }

      final file = File(path);
      final size = await file.length();
      const maxSize = 5 * 1024 * 1024; // 5MB

      if (size > maxSize) {
        if (!mounted) return;
        setState(() => _uploadError = 'File size must be less than 5MB');
        return;
      }

      if (!mounted) return;
      setState(() {
        _selectedAvatar = file;
        _removeAvatarRequested = false;
        _uploadError = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _uploadError = 'Failed to pick image: $e');
      }
    }
  }

  Future<void> _removeAvatar() async {
    setState(() {
      _selectedAvatar = null;
      _removeAvatarRequested = true;
      _uploadError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final currentAvatar = _removeAvatarRequested
        ? null
        : profileAvatarImageProvider(widget.account.avatarUrl);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 640,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Edit your profile',
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: colors.textHint),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Divider(height: 0, color: colors.divider),

            // Scrollable form body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Form(
                  key: formKey,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left column — form fields
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppTextField(
                              label: 'Full Name',
                              controller: nameCtrl,
                              hint: 'Enter your full name',
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Name is required'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            AppTextField(
                              label: 'Display Name',
                              controller: displayNameCtrl,
                              hint: 'Enter display name',
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'This could be your first name, or a nickname — however you\'d like people to refer to you.',
                                style: context.textTheme.bodySmall?.copyWith(
                                  color: colors.textHint,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            AppTextField(
                              label: 'Username',
                              controller: usernameCtrl,
                              hint: 'Enter username',
                            ),
                            const SizedBox(height: 16),
                            AppTextField(
                              label: 'Email',
                              controller: emailCtrl,
                              hint: 'Enter your email',
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Email is required';
                                }
                                if (!v.contains('@')) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            AppTextField(
                              label: 'Phone Number',
                              controller: phoneCtrl,
                              hint: '+1 234 567 8900',
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 16),
                            AppTextField(
                              label: 'Title',
                              controller: titleCtrl,
                              hint: 'e.g. Product Manager',
                            ),
                            const SizedBox(height: 16),
                            AppTextField(
                              label: 'Name Pronunciation',
                              controller: pronunciationCtrl,
                              hint: "e.g. Zoe (pronounced 'zo-ee')",
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'This could be a phonetic pronunciation, or an example of something your name sounds like.',
                                style: context.textTheme.bodySmall?.copyWith(
                                  color: colors.textHint,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Timezone dropdown
                            ProfileFieldLabel('Timezone'),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue:
                                  _kTimezones.contains(selectedTimezone)
                                  ? selectedTimezone
                                  : _kTimezones.first,
                              isExpanded: true,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide(color: colors.divider),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide(color: colors.divider),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                              ),
                              items: _kTimezones
                                  .map(
                                    (tz) => DropdownMenuItem(
                                      value: tz,
                                      child: Text(
                                        tz,
                                        style: context.textTheme.bodySmall,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setState(
                                () => selectedTimezone = v ?? selectedTimezone,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Country dropdown (searchable)
                            ProfileFieldLabel('Country'),
                            const SizedBox(height: 6),
                            Autocomplete<String>(
                              initialValue: TextEditingValue(
                                text: selectedCountry,
                              ),
                              optionsBuilder: (textEditingValue) {
                                if (textEditingValue.text.isEmpty) {
                                  return kCountries;
                                }
                                return kCountries.where(
                                  (c) => c.toLowerCase().contains(
                                    textEditingValue.text.toLowerCase(),
                                  ),
                                );
                              },
                              onSelected: (value) {
                                setState(() => selectedCountry = value);
                              },
                              fieldViewBuilder:
                                  (
                                    context,
                                    controller,
                                    focusNode,
                                    onFieldSubmitted,
                                  ) {
                                    return TextFormField(
                                      controller: controller,
                                      focusNode: focusNode,
                                      decoration: InputDecoration(
                                        hintText: 'Search or select a country',
                                        hintStyle: context.textTheme.bodySmall
                                            ?.copyWith(color: colors.textHint),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          borderSide: BorderSide(
                                            color: colors.divider,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          borderSide: BorderSide(
                                            color: colors.divider,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 14,
                                            ),
                                        suffixIcon: Icon(
                                          Icons.keyboard_arrow_down,
                                          color: colors.textHint,
                                        ),
                                      ),
                                      style: context.textTheme.bodySmall,
                                      onFieldSubmitted: (_) =>
                                          onFieldSubmitted(),
                                    );
                                  },
                              optionsViewBuilder:
                                  (context, onSelected, options) {
                                    return Align(
                                      alignment: Alignment.topLeft,
                                      child: Material(
                                        elevation: 4,
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          width: 360,
                                          constraints: const BoxConstraints(
                                            maxHeight: 240,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colors.background,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: colors.divider,
                                            ),
                                          ),
                                          child: ListView.builder(
                                            padding: EdgeInsets.zero,
                                            shrinkWrap: true,
                                            itemCount: options.length,
                                            itemBuilder: (context, index) {
                                              final option = options.elementAt(
                                                index,
                                              );
                                              return InkWell(
                                                onTap: () => onSelected(option),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 10,
                                                      ),
                                                  child: Text(
                                                    option,
                                                    style: context
                                                        .textTheme
                                                        .bodySmall,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),

                      // Right column — profile photo
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Profile Photo',
                              style: context.textTheme.labelSmall?.copyWith(
                                color: colors.textHint,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: Stack(
                                children: [
                                  Container(
                                    width: 160,
                                    height: 160,
                                    decoration: BoxDecoration(
                                      color: colors.accent.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      image: _selectedAvatar != null
                                          ? DecorationImage(
                                              image: FileImage(
                                                _selectedAvatar!,
                                              ),
                                              fit: BoxFit.cover,
                                            )
                                          : (currentAvatar == null
                                                ? null
                                                : DecorationImage(
                                                    image: currentAvatar,
                                                    fit: BoxFit.cover,
                                                  )),
                                    ),
                                    child:
                                        (_selectedAvatar == null &&
                                            currentAvatar == null)
                                        ? Icon(
                                            Icons.person,
                                            size: 80,
                                            color: colors.accent,
                                          )
                                        : null,
                                  ),
                                  if (_isUploading)
                                    Container(
                                      width: 160,
                                      height: 160,
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          color: colors.primary,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_uploadError != null)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    _uploadError!,
                                    style: context.textTheme.bodySmall
                                        ?.copyWith(color: colors.error),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            Center(
                              child: TextButton.icon(
                                onPressed: _isUploading ? null : _pickAvatar,
                                icon: Icon(
                                  Icons.upload_outlined,
                                  size: 16,
                                  color: _isUploading
                                      ? colors.textHint
                                      : colors.primary,
                                ),
                                label: Text(
                                  _isUploading
                                      ? 'Uploading...'
                                      : 'Upload photo',
                                  style: context.textTheme.bodySmall?.copyWith(
                                    color: _isUploading
                                        ? colors.textHint
                                        : colors.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            if (_selectedAvatar != null || currentAvatar != null)
                              Center(
                                child: TextButton(
                                  onPressed: _isUploading
                                      ? null
                                      : _removeAvatar,
                                  child: Text(
                                    'Remove photo',
                                    style: context.textTheme.bodySmall
                                        ?.copyWith(
                                          color: colors.error,
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Divider(height: 0, color: colors.divider),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: colors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  AppButton(
                    label: 'Save Changes',
                    expand: false,
                    height: 40,
                    onPressed: _isUploading
                        ? null
                        : () async {
                            if (!(formKey.currentState?.validate() ?? false)) {
                              return;
                            }

                            final navigator = Navigator.of(context);

                            // If avatar selected, upload first
                            if (_selectedAvatar != null) {
                              setState(() => _isUploading = true);
                              try {
                                final repository = ref.read(
                                  userProfileRepositoryProvider,
                                );
                                final result = await repository.uploadAvatar(
                                  _selectedAvatar!.path,
                                );

                                switch (result) {
                                  case Success<ProfileAccount>():
                                    widget.onSave(
                                      widget.account.copyWith(
                                        name: nameCtrl.text.trim(),
                                        displayName: displayNameCtrl.text
                                            .trim(),
                                        username: usernameCtrl.text.trim(),
                                        email: emailCtrl.text.trim(),
                                        phoneNumber: phoneCtrl.text.trim(),
                                        title: titleCtrl.text.trim(),
                                        namePronunciation: pronunciationCtrl
                                            .text
                                            .trim(),
                                        timezone: selectedTimezone,
                                        country: selectedCountry,
                                        avatarUrl: result.value.avatarUrl,
                                      ),
                                    );
                                    if (mounted) navigator.pop();
                                  case Failure<ProfileAccount>():
                                    if (mounted) {
                                      setState(() {
                                        _isUploading = false;
                                        _uploadError = result.error.message;
                                      });
                                    }
                                }
                              } catch (e) {
                                if (mounted) {
                                  setState(() {
                                    _isUploading = false;
                                    _uploadError = 'Upload failed: $e';
                                  });
                                }
                              }
                            } else {
                              final updatedAccount = widget.account.copyWith(
                                name: nameCtrl.text.trim(),
                                displayName: displayNameCtrl.text.trim(),
                                username: usernameCtrl.text.trim(),
                                email: emailCtrl.text.trim(),
                                phoneNumber: phoneCtrl.text.trim(),
                                title: titleCtrl.text.trim(),
                                namePronunciation: pronunciationCtrl.text
                                    .trim(),
                                timezone: selectedTimezone,
                                country: selectedCountry,
                                clearAvatarUrl: _removeAvatarRequested,
                              );

                              if (_removeAvatarRequested) {
                                setState(() => _isUploading = true);
                                final result = await ref
                                    .read(userProfileRepositoryProvider)
                                    .deleteAvatar();
                                switch (result) {
                                  case Success<void>():
                                    widget.onSave(updatedAccount);
                                    if (mounted) navigator.pop();
                                  case Failure<void>():
                                    if (mounted) {
                                      setState(() {
                                        _isUploading = false;
                                        _uploadError = result.error.message;
                                      });
                                    }
                                }
                              } else {
                                // Save profile details when the avatar is unchanged.
                                widget.onSave(updatedAccount);
                                if (mounted) navigator.pop();
                              }
                            }
                          },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
