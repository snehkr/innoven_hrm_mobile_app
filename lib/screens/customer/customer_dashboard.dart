import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

// ── Color Palette ──────────────────────────────────────────────────────────
const _kPrimary = Color(0xFF0D47A1);
const _kAccent  = Color(0xFF1976D2);
const _kBg      = Color(0xFFF4F6FB);
const _kCard    = Colors.white;

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();

  List<dynamic> _products = [];
  List<dynamic> _requests = [];
  bool _isLoading = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    else setState(() => _isRefreshing = true);

    try {
      final productRes = await _apiService.get('/products');
      final instRes    = await _apiService.get('/installations');
      final serviceRes = await _apiService.get('/service-requests');

      List<dynamic> combined = [];
      if (instRes.statusCode == 200) {
        final data = jsonDecode(instRes.body)['data']['requests'] as List;
        combined.addAll(data.map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          m['type'] = 'installation';
          return m;
        }));
      }
      if (serviceRes.statusCode == 200) {
        final data = jsonDecode(serviceRes.body)['data']['requests'] as List;
        combined.addAll(data.map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          m['type'] = (m['request_type'] ?? 'repair') as String;
          return m;
        }));
      }
      combined.sort((a, b) => ((b as Map)['createdAt'] ?? '').compareTo((a as Map)['createdAt'] ?? ''));

      setState(() {
        if (productRes.statusCode == 200) {
          _products = jsonDecode(productRes.body)['data']['products'];
        }
        _requests = combined;
      });
    } catch (_) {}

    setState(() {
      _isLoading = false;
      _isRefreshing = false;
    });
  }

  // ── Status helpers ─────────────────────────────────────────────────────
  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'INSTALLATION_COMPLETED':
      case 'COMPLETED': return const Color(0xFF22C55E);
      case 'OTP_VERIFIED': return const Color(0xFF14B8A6);
      case 'OTP_SENT': return const Color(0xFFF97316);
      case 'BARCODE_VERIFIED': return const Color(0xFF06B6D4);
      case 'ENGINEER_ASSIGNED':
      case 'ENGINEER_VISITING': return const Color(0xFF8B5CF6);
      case 'SERVICE_CENTER_ASSIGNED': return const Color(0xFF3B82F6);
      case 'IN_PROGRESS': return const Color(0xFF6366F1);
      case 'CANCELLED': return const Color(0xFFEF4444);
      default: return const Color(0xFFF59E0B);
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'INSTALLATION_COMPLETED':
      case 'COMPLETED': return Icons.check_circle_rounded;
      case 'ENGINEER_ASSIGNED':
      case 'ENGINEER_VISITING': return Icons.engineering_rounded;
      case 'OTP_VERIFIED':
      case 'OTP_SENT': return Icons.lock_open_rounded;
      case 'CANCELLED': return Icons.cancel_rounded;
      default: return Icons.schedule_rounded;
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: _buildAppBar(user, authProvider, isLandscape),
      body: _isLoading
          ? const _LoadingView()
          : Column(
              children: [
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildProductsTab(isLandscape),
                      _buildRequestsTab(isLandscape),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: _isLoading ? null : _buildFAB(),
    );
  }

  PreferredSizeWidget _buildAppBar(Map? user, AuthProvider auth, bool isLandscape) {
    final name = user?['name']?.toString().split(' ').first ?? 'Customer';
    return PreferredSize(
      preferredSize: Size.fromHeight(isLandscape ? 75 : 110),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(color: Color(0x330D47A1), blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: isLandscape ? 38 : 46,
                  height: isLandscape ? 38 : 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      name[0].toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: isLandscape ? 17 : 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Title
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Hello, $name 👋',
                        style: TextStyle(
                          fontSize: isLandscape ? 15 : 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${_products.length} products · ${_requests.length} requests',
                        style: const TextStyle(fontSize: 11, color: Color(0xB3FFFFFF)),
                      ),
                    ],
                  ),
                ),
                // Refresh button
                _isRefreshing
                    ? Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(8),
                        child: const CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : _AppBarIconBtn(
                        icon: Icons.refresh_rounded,
                        tooltip: 'Refresh',
                        onTap: () => _fetchData(silent: true),
                      ),
                const SizedBox(width: 8),
                // Logout button
                _AppBarIconBtn(
                  icon: Icons.logout_rounded,
                  tooltip: 'Logout',
                  color: const Color(0xFFEF4444),
                  onTap: () => _showLogoutDialog(auth),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(children: [
          Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
          SizedBox(width: 10),
          Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); auth.logout(); },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: _kPrimary,
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: [
          Tab(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.devices_rounded, size: 18),
              const SizedBox(width: 6),
              Text('My Products (${_products.length})'),
            ]),
          ),
          Tab(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.receipt_long_rounded, size: 18),
              const SizedBox(width: 6),
              Text('My Requests (${_requests.length})'),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: () => context.go('/customer/request'),
      icon: const Icon(Icons.add_circle_outline_rounded),
      label: const Text('Request Service', style: TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: _kPrimary,
      foregroundColor: Colors.white,
      elevation: 6,
    );
  }

  // ── Products Tab ───────────────────────────────────────────────────────
  Widget _buildProductsTab(bool isLandscape) {
    if (_products.isEmpty) {
      return _EmptyState(
        icon: Icons.devices_other_rounded,
        title: 'No Products Yet',
        subtitle: 'Products registered by your retailer will appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchData(silent: true),
      child: isLandscape
          ? GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.8,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _products.length,
              itemBuilder: (ctx, i) => _ProductCard(product: _products[i], compact: true),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: _products.length,
              itemBuilder: (ctx, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ProductCard(product: _products[i]),
              ),
            ),
    );
  }

  // ── Requests Tab ───────────────────────────────────────────────────────
  Widget _buildRequestsTab(bool isLandscape) {
    if (_requests.isEmpty) {
      return _EmptyState(
        icon: Icons.inbox_rounded,
        title: 'No Requests Found',
        subtitle: 'Your installation and repair requests will appear here.',
        actionLabel: 'Create Request',
        onAction: () => context.go('/customer/request'),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchData(silent: true),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _requests.length,
        itemBuilder: (ctx, i) {
          final req = _requests[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _RequestCard(
              req: req,
              statusColor: _statusColor(req['status'] ?? 'PENDING'),
              statusIcon: _statusIcon(req['status'] ?? 'PENDING'),
            ),
          );
        },
      ),
    );
  }
}

// ── Product Card ─────────────────────────────────────────────────────────────
class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final bool compact;

  const _ProductCard({required this.product, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final warranty = product['warranty_period_months'] ?? 12;
    final brand = product['brand'] ?? '';

    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: compact
          ? _buildCompact(brand, warranty)
          : _buildFull(brand, warranty),
    );
  }

  Widget _buildCompact(String brand, dynamic warranty) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: _kPrimary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.tv_rounded, color: _kPrimary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(product['model_name'] ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    overflow: TextOverflow.ellipsis),
                Text('SN: ${product['serial_number'] ?? '-'}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          _WarrantyBadge(months: warranty, small: true),
        ],
      ),
    );
  }

  Widget _buildFull(String brand, dynamic warranty) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_kPrimary.withOpacity(0.12), _kAccent.withOpacity(0.06)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.tv_rounded, color: _kPrimary, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product['model_name'] ?? 'Unknown Model',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 3),
                if (brand.isNotEmpty)
                  Text(brand,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.qr_code_2_rounded, size: 13, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text('SN: ${product['serial_number'] ?? '-'}',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontFamily: 'monospace')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _WarrantyBadge(months: warranty),
        ],
      ),
    );
  }
}

class _WarrantyBadge extends StatelessWidget {
  final dynamic months;
  final bool small;
  const _WarrantyBadge({required this.months, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 7 : 10, vertical: small ? 4 : 6),
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded,
              color: const Color(0xFF22C55E), size: small ? 13 : 16),
          if (!small) ...[
            const SizedBox(height: 2),
            Text('$months mo',
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF22C55E))),
          ]
        ],
      ),
    );
  }
}

// ── Request Card ─────────────────────────────────────────────────────────────
class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> req;
  final Color statusColor;
  final IconData statusIcon;

  const _RequestCard({
    required this.req,
    required this.statusColor,
    required this.statusIcon,
  });

  void _showImagePreview(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(url, fit: BoxFit.contain),
            ),
            const SizedBox(height: 16),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 32),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final type = req['type'] as String? ?? 'installation';
    final status = req['status'] as String? ?? 'PENDING';
    final product = req['product_id'] is Map
        ? Map<String, dynamic>.from(req['product_id'] as Map)
        : null;
    final dateStr = req['createdAt'] != null
        ? DateTime.parse(req['createdAt'].toString())
            .toLocal()
            .toString()
            .split(' ')[0]
        : 'N/A';
    final isInstall = type == 'installation';
    final proofUrl = req['installation_proof_url'] ?? req['proof_image_url'];

    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: EdgeInsets.zero,
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (isInstall ? _kPrimary : const Color(0xFFF97316))
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isInstall ? Icons.install_desktop_rounded : Icons.build_rounded,
              color: isInstall ? _kPrimary : const Color(0xFFF97316),
              size: 22,
            ),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  'Ticket #${req['ticket_number'] ?? '-'}',
                  style:
                      const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isInstall ? _kPrimary : const Color(0xFFF97316))
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isInstall ? 'INSTALL' : 'REPAIR',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: isInstall ? _kPrimary : const Color(0xFFF97316),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(statusIcon, size: 12, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  status.replaceAll('_', ' '),
                  style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _kBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _InfoRow(Icons.devices_rounded, 'Product',
                      product?['model_name'] ?? 'N/A'),
                  const SizedBox(height: 8),
                  _InfoRow(Icons.qr_code_rounded, 'Serial No.',
                      product?['serial_number'] ?? 'N/A'),
                  const SizedBox(height: 8),
                  _InfoRow(Icons.calendar_today_rounded, 'Created', dateStr),
                  if (req['issue_description'] != null) ...[
                    const SizedBox(height: 8),
                    _InfoRow(Icons.description_rounded, 'Issue',
                        req['issue_description']),
                  ],
                  if ((req['status'] == 'INSTALLATION_COMPLETED' ||
                          req['status'] == 'COMPLETED') &&
                      proofUrl != null) ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Service Proof',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey)),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: () => _showImagePreview(context, proofUrl!),
                        child: Image.network(
                          proofUrl!,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Text('$label: ',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black54)),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: _kPrimary.withOpacity(0.5)),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.5)),
            if (actionLabel != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded),
                label: Text(actionLabel!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Loading view ──────────────────────────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: _kBg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _kPrimary),
            SizedBox(height: 16),
            Text('Loading your data...',
                style: TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

// ── AppBar Icon Button ────────────────────────────────────────────────────────
class _AppBarIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _AppBarIconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color == Colors.white
                ? Colors.white.withOpacity(0.15)
                : color.withOpacity(0.18),
            shape: BoxShape.circle,
            border: Border.all(
              color: color == Colors.white
                  ? Colors.white.withOpacity(0.3)
                  : color.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}
