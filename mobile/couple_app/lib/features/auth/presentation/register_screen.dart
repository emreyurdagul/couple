import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Kayıt ol')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameCtl,
                    decoration: const InputDecoration(labelText: 'Görünen ad'),
                    autofillHints: const [AutofillHints.name],
                    validator: (v) => (v == null || v.trim().length < 2)
                        ? 'En az 2 karakter'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailCtl,
                    decoration: const InputDecoration(labelText: 'E-posta'),
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'E-posta gerekli';
                      if (!v.contains('@') || !v.contains('.')) {
                        return 'Geçerli bir e-posta gir';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordCtl,
                    decoration: const InputDecoration(
                      labelText: 'Parola (min. 8 karakter)',
                    ),
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: (v) => (v == null || v.length < 8)
                        ? 'En az 8 karakter'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  if (_error != null) ...[
                    Text(_error!,
                        style:
                            TextStyle(color: Theme.of(context).colorScheme.error)),
                    const SizedBox(height: 12),
                  ],
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Kayıt ol'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy ? null : () => context.go('/login'),
                    child: const Text('Zaten hesabın var mı? Giriş yap'),
                  ),
                ],
              ),
            ),
          ),
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
