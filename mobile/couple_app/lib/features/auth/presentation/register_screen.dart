import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/journal_field.dart';
import '../../../shared/widgets/paper_scaffold.dart';
import '../../../shared/widgets/stamp_button.dart';
import '../../../shared/widgets/wordmark.dart';
import '../state/auth_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtl = TextEditingController();
  final _passwordCtl = TextEditingController();
  final _nameCtl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailCtl.dispose();
    _passwordCtl.dispose();
    _nameCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).register(
            email: _emailCtl.text.trim(),
            password: _passwordCtl.text,
            displayName: _nameCtl.text.trim(),
          );
    } on DioException catch (e) {
      setState(() => _error = _readableError(e));
    } catch (e) {
      setState(() => _error = 'Beklenmedik hata: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PaperScaffold(
      pageNumber: 1,
      body: Form(
        key: _formKey,
        child: AutofillGroup(
          child: ListView(
            children: [
              const SizedBox(height: AppSpacing.md),
              const Wordmark(),
              const SizedBox(height: AppSpacing.xl),
              Text('İlk sayfa.', style: AppText.display(context)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Adınla başla — sonra partnerinle birleşir.',
                style: AppText.subtitle(context),
              ),
              const SizedBox(height: AppSpacing.xxl),
              JournalField(
                controller: _nameCtl,
                label: 'görünen ad',
                autofillHints: const [AutofillHints.name],
                textInputAction: TextInputAction.next,
                validator: (v) => (v == null || v.trim().length < 2)
                    ? 'En az 2 karakter'
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              JournalField(
                controller: _emailCtl,
                label: 'e-posta',
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'E-posta gerekli';
                  if (!v.contains('@') || !v.contains('.')) {
                    return 'Geçerli bir e-posta gir';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              JournalField(
                controller: _passwordCtl,
                label: 'parola (min. 8)',
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                validator: (v) => (v == null || v.length < 8)
                    ? 'En az 8 karakter'
                    : null,
              ),
              const SizedBox(height: AppSpacing.xl),
              if (_error != null) ...[
                _ErrorNote(_error!),
                const SizedBox(height: AppSpacing.md),
              ],
              StampButton(
                label: 'Hesabımı aç',
                onPressed: _busy ? null : _submit,
                busy: _busy,
              ),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: GestureDetector(
                  onTap: _busy ? null : () => context.go('/login'),
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.inkSoft,
                      ),
                      children: [
                        const TextSpan(text: 'Zaten kayıtlı mısın?  '),
                        TextSpan(
                          text: 'giriş yap →',
                          style: GoogleFonts.fraunces(
                            fontStyle: FontStyle.italic,
                            color: AppColors.stamp,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.error, width: 2)),
      ),
      child: Text(
        message,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: AppColors.error,
          height: 1.4,
        ),
      ),
    );
  }
}

String _readableError(DioException e) {
  final code = e.response?.statusCode;
  final data = e.response?.data;
  if (code == 409 && data is Map && data['error'] == 'email_in_use') {
    return 'Bu e-posta zaten kayıtlı.';
  }
  if (code == 400 && data is Map && data['error'] == 'register_failed') {
    final details = data['details'];
    if (details is List && details.isNotEmpty) return details.first.toString();
  }
  if (e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout) {
    return 'Sunucuya bağlanılamadı.';
  }
  return 'Kayıt başarısız.';
}
