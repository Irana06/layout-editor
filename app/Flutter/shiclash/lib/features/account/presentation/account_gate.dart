import 'package:flutter/material.dart';
import 'package:shiclash/core/theme/app_theme.dart';
import 'package:shiclash/features/account/data/google_account_controller.dart';

class AccountGate extends StatelessWidget {
  const AccountGate({
    super.key,
    required this.account,
    required this.onContinueOffline,
  });

  final GoogleAccountController account;
  final VoidCallback onContinueOffline;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                children: [
                  Container(
                    width: 148,
                    height: 148,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: AppColors.line),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x663D2412),
                          blurRadius: 36,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/branding/shiclash-mark.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'SHICLASH',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Base-mu, tersimpan di mana pun.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Masuk atau daftar dengan satu akun Google. Layout tetap disimpan di HP dan dapat dicadangkan ke ruang privat aplikasi di Google Drive.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: account.busy ? null : account.signIn,
                      icon: const Icon(Icons.g_mobiledata_rounded, size: 30),
                      label: Text(
                        account.busy
                            ? 'Menghubungkan…'
                            : 'Masuk / daftar dengan Google',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: account.busy ? null : onContinueOffline,
                      icon: const Icon(Icons.phone_android),
                      label: const Text('Lanjutkan offline'),
                    ),
                  ),
                  if (account.error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      account.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Text(
                    'Shiclash hanya meminta akses ke file backup yang dibuat aplikasi ini, bukan seluruh isi Google Drive.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
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
