import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import 'primary_button.dart';

void showAppPasswordGuideSheet(BuildContext context, PaperTokens t) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: t.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _AppPasswordGuideContent(t: t),
  );
}

class _AppPasswordGuideContent extends StatelessWidget {
  const _AppPasswordGuideContent({required this.t});

  final PaperTokens t;

  void _copyLink(BuildContext context) {
    Clipboard.setData(const ClipboardData(text: 'https://myaccount.google.com/apppasswords'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied link: https://myaccount.google.com/apppasswords'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Space.margin,
          Space.x3,
          Space.margin,
          MediaQuery.of(context).viewInsets.bottom + Space.x6,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.rule,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: Space.x4),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: t.accentTint,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.key_rounded, size: 20, color: t.accent),
                  ),
                  const SizedBox(width: Space.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Google App Password Guide', style: TypeScale.title(t.ink).copyWith(fontSize: 18)),
                        const SizedBox(height: 2),
                        Text('Takes ~60 seconds to create', style: TypeScale.caption(t.inkSoft)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.x4),
              _buildStep(
                number: '1',
                title: 'Turn on 2-Step Verification',
                description: 'Your Google Account must have 2-Step Verification turned ON. Google requires this before generating app passwords.',
              ),
              const SizedBox(height: Space.x3),
              _buildStep(
                number: '2',
                title: 'Open Google App Passwords',
                description: 'Go to myaccount.google.com/apppasswords or search "App passwords" in your Google Account Security tab.',
                trailing: ActionChip(
                  avatar: Icon(Icons.copy_rounded, size: 14, color: t.accent),
                  label: Text('Copy link', style: TypeScale.caption(t.accent).copyWith(fontWeight: FontWeight.w600)),
                  backgroundColor: t.accentTint,
                  side: BorderSide(color: t.accent.withAlpha(50)),
                  onPressed: () => _copyLink(context),
                ),
              ),
              const SizedBox(height: Space.x3),
              _buildStep(
                number: '3',
                title: 'Name it "Pocket" & tap Create',
                description: 'Type "Pocket" under App name. Google will instantly generate a 16-character code (e.g. abcd efgh ijkl mnop).',
              ),
              const SizedBox(height: Space.x3),
              _buildStep(
                number: '4',
                title: 'Paste code into Pocket',
                description: 'Copy the 16 characters and paste them into Pocket. Spaces are handled automatically.',
              ),
              const SizedBox(height: Space.x4),
              Container(
                padding: const EdgeInsets.all(Space.x3),
                decoration: BoxDecoration(
                  color: t.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: t.rule),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined, size: 16, color: t.accent),
                    const SizedBox(width: Space.x2),
                    Expanded(
                      child: Text(
                        '100% Offline & Private: Never enter your primary Google password. The App Password is kept encrypted on this device only to read bank alert emails.',
                        style: TypeScale.caption(t.inkSoft).copyWith(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.x6),
              PrimaryButton(
                label: 'Got it',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep({
    required String number,
    required String title,
    required String description,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: t.card,
            shape: BoxShape.circle,
            border: Border.all(color: t.rule),
          ),
          child: Text(
            number,
            style: TypeScale.caption(t.ink).copyWith(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        const SizedBox(width: Space.x3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TypeScale.body(t.ink).copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(description, style: TypeScale.caption(t.inkSoft)),
              if (trailing != null) ...[
                const SizedBox(height: Space.x1),
                trailing,
              ],
            ],
          ),
        ),
      ],
    );
  }
}
