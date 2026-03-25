// lib/screens/auth/login_screen.dart — Style 3: Navy & Gold
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _parentKey  = GlobalKey<FormState>();
  final _kidKey     = GlobalKey<FormState>();
  final _emailCtrl  = TextEditingController();
  final _passCtrl   = TextEditingController();
  final _pEmailCtrl = TextEditingController();
  final _kidNameCtrl = TextEditingController();
  final _kidPassCtrl = TextEditingController();
  bool _parentObscure = true;
  bool _kidObscure    = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    for (final c in [_emailCtrl, _passCtrl, _pEmailCtrl, _kidNameCtrl, _kidPassCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _parentLogin() async {
    if (!_parentKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    auth.clearError();
    final ok = await auth.signIn(_emailCtrl.text.trim(), _passCtrl.text.trim());
    if (!ok && mounted) {
      _showError(auth.errorMessage ?? 'Sign in failed');
    }
  }

  Future<void> _kidLogin() async {
    if (!_kidKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    auth.clearError();
    final ok = await auth.signInAsKid(
      _pEmailCtrl.text.trim(),
      _kidNameCtrl.text.trim(),
      _kidPassCtrl.text.trim(),
    );
    if (!ok && mounted) {
      _showError(auth.errorMessage ?? 'Sign in failed');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppTheme.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final auth      = context.watch<AuthProvider>();
    final isLoading = auth.state == AuthState.loading;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeroHeader(),
              const SizedBox(height: 8),
              _buildTabs(),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.54,
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildParentTab(isLoading),
                    _buildKidTab(isLoading),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      width: double.infinity,
      decoration: AppTheme.navyHeaderDecoration,
      child: Stack(
        children: [
          // Circular watermark rings
          Positioned(right: -20, top: -20,
            child: Opacity(opacity: 0.07, child: Container(
              width: 140, height: 140,
              decoration: BoxDecoration(shape: BoxShape.circle,
                border: Border.all(color: AppTheme.gold, width: 2))))),
          Positioned(right: 15, top: 15,
            child: Opacity(opacity: 0.05, child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(shape: BoxShape.circle,
                border: Border.all(color: AppTheme.gold, width: 1))))),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 28, 0, 28),
              child: Column(
                children: [
                  // Logo badge
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.gold, width: 2),
                      color: AppTheme.gold.withValues(alpha: 0.1),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(top: 20,
                          child: Icon(Icons.menu_book_rounded,
                            color: AppTheme.goldLight, size: 34)),
                        Positioned(top: 14,
                          child: Icon(Icons.add, color: AppTheme.gold, size: 18)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('ACHC Hub',
                    style: TextStyle(color: Colors.white, fontSize: 28,
                      fontWeight: FontWeight.w700, letterSpacing: 1.5,
                      fontFamily: 'Georgia')),
                  const SizedBox(height: 4),
                  Text('Aquinas Columbus Homeschool Community',
                    style: TextStyle(color: AppTheme.goldLight.withValues(alpha: 0.85),
                      fontSize: 12, letterSpacing: 0.3)),
                  const SizedBox(height: 4),
                  AppTheme.goldDivider(indent: 60),
                  const SizedBox(height: 4),
                  const Text('Est. 2019',
                    style: TextStyle(color: Colors.white38, fontSize: 11,
                      letterSpacing: 1.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.navyDark,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TabBar(
        controller: _tabCtrl,
        indicator: BoxDecoration(
          color: AppTheme.gold, borderRadius: BorderRadius.circular(8)),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: AppTheme.navy,
        unselectedLabelColor: Colors.white60,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        dividerColor: Colors.transparent,
        tabs: const [Tab(text: 'Parent / Admin'), Tab(text: 'Student Login')],
      ),
    );
  }

  Widget _buildParentTab(bool isLoading) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
    child: Form(
      key: _parentKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              prefixIcon: Icon(Icons.email_outlined, size: 18),
              hintText: 'parent@email.com',
            ),
            validator: (v) => (v == null || !v.contains('@')) ? 'Enter valid email' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passCtrl,
            obscureText: _parentObscure,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline, size: 18),
              suffixIcon: IconButton(
                icon: Icon(_parentObscure ? Icons.visibility_off : Icons.visibility, size: 18),
                onPressed: () => setState(() => _parentObscure = !_parentObscure),
              ),
            ),
            validator: (v) => (v == null || v.length < 6) ? 'Min. 6 characters' : null,
          ),
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: isLoading ? null : _parentLogin,
            child: isLoading
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Sign In'),
          ),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text("Don't have an account?",
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            TextButton(
              onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const RegisterScreen())),
              child: const Text('Register',
                style: TextStyle(color: AppTheme.navy, fontWeight: FontWeight.w700)),
            ),
          ]),
        ],
      ),
    ),
  );

  Widget _buildKidTab(bool isLoading) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
    child: Form(
      key: _kidKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.navy.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.navy.withValues(alpha: 0.15)),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline, color: AppTheme.navy, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text(
                "Use your parent's email + your name + your password",
                style: TextStyle(color: AppTheme.navy, fontSize: 11))),
            ]),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _pEmailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: "Parent's Email",
              prefixIcon: Icon(Icons.email_outlined, size: 18),
            ),
            validator: (v) => (v == null || v.isEmpty) ? "Enter parent's email" : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _kidNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Your First Name',
              prefixIcon: Icon(Icons.person_outline, size: 18),
              hintText: 'e.g. Emma (first name is enough)',
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'Enter your name' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _kidPassCtrl,
            obscureText: _kidObscure,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline, size: 18),
              suffixIcon: IconButton(
                icon: Icon(_kidObscure ? Icons.visibility_off : Icons.visibility, size: 18),
                onPressed: () => setState(() => _kidObscure = !_kidObscure),
              ),
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'Enter password' : null,
          ),
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: isLoading ? null : _kidLogin,
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gold),
            child: isLoading
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Sign In as Student',
                  style: TextStyle(color: AppTheme.navy, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ),
  );
}
