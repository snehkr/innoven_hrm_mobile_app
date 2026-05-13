import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  late AnimationController _animController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      _showDialog('Please enter your email and password.');
      return;
    }
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (success) {
      final role = authProvider.user!['role'];
      if (role == 'engineer') {
        context.go('/engineer');
      } else if (role == 'customer') {
        context.go('/customer');
      } else {
        await authProvider.logout();
        _showDialog(
          'Access denied for role: "${role.replaceAll('_', ' ').toUpperCase()}".\n\nThis app is exclusively for Engineers and Customers.',
        );
      }
    } else {
      _showDialog('Invalid email or password.\nPlease check your credentials and try again.');
    }
  }

  void _showDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.block_rounded, size: 32, color: Colors.red.shade600),
              ),
              const SizedBox(height: 14),
              const Text('Access Denied',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade700, height: 1.5)),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 10),
              const Text('Allowed Roles',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _RoleChip(
                        icon: Icons.engineering_rounded,
                        label: 'Engineer',
                        color: Colors.blue.shade700),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _RoleChip(
                        icon: Icons.person_rounded,
                        label: 'Customer',
                        color: Colors.green.shade700),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Try Again',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Shared input decoration ──────────────────────────────────────────────
  InputDecoration _inputDeco({
    required String label,
    required String hint,
    required IconData prefixIconData,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Container(
        margin: const EdgeInsets.all(9),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: const Color(0xFF0D47A1).withOpacity(0.08),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(prefixIconData, size: 18, color: const Color(0xFF0D47A1)),
      ),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF5F7FA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFFE8ECF0), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 2),
      ),
    );
  }

  // ── Form fields widget ───────────────────────────────────────────────────
  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 26,
              decoration: BoxDecoration(
                color: const Color(0xFF0D47A1),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome Back',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D1B2A))),
                Text('Sign in to continue',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 22),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          style: const TextStyle(fontSize: 14),
          decoration: _inputDeco(
            label: 'Email Address',
            hint: 'you@example.com',
            prefixIconData: Icons.alternate_email_rounded,
          ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: const TextStyle(fontSize: 14),
          decoration: _inputDeco(
            label: 'Password',
            hint: '••••••••',
            prefixIconData: Icons.lock_outline_rounded,
            suffix: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.grey.shade500,
                size: 19,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          onFieldSubmitted: (_) => _isLoading ? null : _handleLogin(),
        ),
        const SizedBox(height: 22),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  const Color(0xFF0D47A1).withOpacity(0.5),
              elevation: 4,
              shadowColor: const Color(0xFF0D47A1).withOpacity(0.35),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13)),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Sign In',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F4FF),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: const Color(0xFFBBD0FF)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 16, color: Color(0xFF0D47A1)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This app is for Engineers & Customers only. Admins use the web panel.',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue.shade900,
                      height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Branding column ──────────────────────────────────────────────────────
  Widget _buildBranding({bool compact = false}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Shrink content when space is very tight (e.g. keyboard open)
        final h = constraints.maxHeight;
        final tiny = h < 210; // Increased threshold to catch overlaps earlier
        final logoSz = compact ? 64.0 : (tiny ? 60.0 : 80.0);
        final gap1 = compact ? 10.0 : (tiny ? 6.0 : 14.0);
        final gap2 = compact ? 4.0 : (tiny ? 2.0 : 5.0);
        final gap3 = compact ? 12.0 : (tiny ? 8.0 : 16.0);
        final title = compact ? 17.0 : (tiny ? 16.0 : 21.0);
        final sub = compact ? 11.0 : (tiny ? 10.0 : 13.0);

        return ClipRect(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: logoSz,
                  height: logoSz,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withOpacity(0.4), width: 2),
                  ),
                  child: Icon(Icons.support_agent_rounded,
                      size: logoSz * 0.54, color: Colors.white),
                ),
                SizedBox(height: gap1),
                Text(
                  'INNOVEN SUPPORT',
                  style: TextStyle(
                    fontSize: title,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 2.5,
                  ),
                ),
                SizedBox(height: gap2),
                Text(
                  'Service Lifecycle Management',
                  style: TextStyle(
                      fontSize: sub, color: Colors.white70, letterSpacing: 0.4),
                ),
                if (!tiny) ...[
                  SizedBox(height: gap3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _TopRoleBadge(
                          icon: Icons.engineering_rounded,
                          label: 'Engineers',
                          compact: compact),
                      Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          width: 1,
                          height: 16,
                          color: Colors.white24),
                      _TopRoleBadge(
                          icon: Icons.person_rounded,
                          label: 'Customers',
                          compact: compact),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1976D2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: isLandscape ? _buildLandscape() : _buildPortrait(),
          ),
        ),
      ),
    );
  }

  // ── Portrait layout ──────────────────────────────────────────────────────
  Widget _buildPortrait() {
    return Column(
      children: [
        // Branding top area - Expanded keeps it centered in the top space
        Expanded(
          flex: 3,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Center(child: _buildBranding()),
          ),
        ),
        // Login card - Expanded ensures it fills the bottom 70%
        Expanded(
          flex: 7,
          child: SlideTransition(
            position: _slideAnim,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(26, 32, 26, 24),
                  child: _buildForm(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Landscape layout ─────────────────────────────────────────────────────
  Widget _buildLandscape() {
    return Row(
      children: [
        // Left: branding
        Expanded(
          flex: 4,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildBranding(compact: true),
            ),
          ),
        ),
        // Right: login card
        Expanded(
          flex: 6,
          child: SlideTransition(
            position: _slideAnim,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Container(
                height: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.horizontal(left: Radius.circular(30)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                  child: _buildForm(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Helper widgets ───────────────────────────────────────────────────────────

class _TopRoleBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool compact;

  const _TopRoleBadge({
    required this.icon,
    required this.label,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 14, vertical: compact ? 5 : 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: compact ? 13 : 15),
          SizedBox(width: compact ? 4 : 6),
          Text(label,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 11 : 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _RoleChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
        ],
      ),
    );
  }
}
