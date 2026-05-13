import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

const _kPrimary  = Color(0xFF0D47A1);
const _kBg       = Color(0xFFF1F4F9);

class EngineerDashboard extends StatefulWidget {
  const EngineerDashboard({super.key});
  @override
  State<EngineerDashboard> createState() => _EngineerDashboardState();
}

class _EngineerDashboardState extends State<EngineerDashboard>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  List<dynamic> _jobs = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  late TabController _tabController;

  final _statuses  = ['ALL', 'PENDING', 'IN_PROGRESS', 'DONE'];
  final _tabLabels = ['All', 'Pending', 'Active', 'Done'];
  final _tabIcons  = [Icons.grid_view_rounded, Icons.schedule_rounded, Icons.engineering_rounded, Icons.check_circle_rounded];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchJobs();
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  Future<void> _fetchJobs({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    else setState(() => _isRefreshing = true);
    try {
      final responses = await Future.wait([
        _apiService.get('/installations/assigned'),
        _apiService.get('/service-requests'),
      ]);

      final instRes = responses[0];
      final servRes = responses[1];
      
      List<dynamic> combined = [];
      
      if (instRes.statusCode == 200) {
        final body = jsonDecode(instRes.body);
        final innerData = body['data'] ?? {};
        // Check both 'jobs' and 'requests' just in case
        final data = (innerData['jobs'] ?? innerData['requests'] ?? []) as List;
        
        combined.addAll(data.map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          m['type'] = 'installation';
          return m;
        }));
      } else {
        debugPrint('Inst Fetch failed: ${instRes.statusCode} ${instRes.body}');
      }
      
      if (servRes.statusCode == 200) {
        final body = jsonDecode(servRes.body);
        final innerData = body['data'] ?? {};
        // Check both 'requests' and 'jobs' just in case
        final data = (innerData['requests'] ?? innerData['jobs'] ?? []) as List;
        
        combined.addAll(data.map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          m['type'] = (m['request_type'] ?? 'repair') as String;
          return m;
        }));
      } else {
        debugPrint('Serv Fetch failed: ${servRes.statusCode} ${servRes.body}');
      }

      // Sort by creation date descending
      combined.sort((a, b) => (b['createdAt'] ?? '').compareTo(a['createdAt'] ?? ''));
      
      if (mounted) setState(() => _jobs = combined);
    } catch (e) {
      debugPrint('Fetch Error: $e');
      if (mounted) _snack('Failed to sync jobs', error: true);
    } finally {
      if (mounted) setState(() { _isLoading = false; _isRefreshing = false; });
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  List<dynamic> _filter(String key) {
    if (key == 'ALL') return _jobs;
    if (key == 'IN_PROGRESS') {
      return _jobs.where((j) => const [
        'ENGINEER_ASSIGNED','ENGINEER_VISITING','BARCODE_VERIFIED','OTP_SENT','OTP_VERIFIED','IN_PROGRESS'
      ].contains(j['status'])).toList();
    }
    if (key == 'DONE') {
      return _jobs.where((j) => const ['INSTALLATION_COMPLETED', 'COMPLETED'].contains(j['status'])).toList();
    }
    return _jobs.where((j) => j['status'] == key).toList();
  }

  // ── Status helpers ─────────────────────────────────────────────────────
  Color _statusColor(String s) {
    switch (s) {
      case 'INSTALLATION_COMPLETED':
      case 'COMPLETED':              return const Color(0xFF22C55E);
      case 'OTP_VERIFIED':           return const Color(0xFF14B8A6);
      case 'OTP_SENT':               return const Color(0xFFF97316);
      case 'BARCODE_VERIFIED':       return const Color(0xFF06B6D4);
      case 'ENGINEER_VISITING':      return const Color(0xFF8B5CF6);
      case 'ENGINEER_ASSIGNED':
      case 'IN_PROGRESS':            return const Color(0xFF6366F1);
      case 'PENDING':                return const Color(0xFFF59E0B);
      default:                       return Colors.grey;
    }
  }

  Map<String, dynamic> _actionConfig(dynamic job) {
    final status = job['status'];
    final id     = job['_id'];
    if (status == 'OTP_VERIFIED') return {
      'label': 'Upload Proof', 'icon': Icons.cloud_upload_rounded,
      'color': const Color(0xFF22C55E), 'route': '/engineer/proof/$id',
    };
    if (status == 'BARCODE_VERIFIED' || status == 'OTP_SENT') return {
      'label': 'Verify OTP', 'icon': Icons.lock_open_rounded,
      'color': const Color(0xFFF97316), 'route': '/engineer/otp/$id',
    };
    return {
      'label': 'Scan Barcode', 'icon': Icons.qr_code_scanner_rounded,
      'color': _kPrimary, 'route': '/engineer/scan/$id',
    };
  }

  // ── Summary stats ──────────────────────────────────────────────────────
  int get _pending   => _jobs.where((j) => j['status'] == 'PENDING').length;
  int get _active    => _filter('IN_PROGRESS').length;
  int get _completed => _jobs.where((j) => const ['INSTALLATION_COMPLETED', 'COMPLETED'].contains(j['status'])).length;

  void _showQuickActions(dynamic job) {
    final status = job['status'] ?? 'PENDING';
    final customer = job['customer_id'] as Map?;
    final phone = customer?['phone']?.toString();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _kPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.assignment_rounded, color: _kPrimary),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Ticket #${job['ticket_number']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text(status.replaceAll('_', ' '), style: TextStyle(color: _statusColor(status), fontSize: 12, fontWeight: FontWeight.bold)),
              ])),
            ]),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            _ActionTile(
              icon: Icons.phone_rounded, color: const Color(0xFF22C55E),
              label: 'Call Customer', sub: phone ?? 'No number',
              onTap: () {
                Navigator.pop(context);
                if (phone != null) {
                  // Use url_launcher or similar here
                  _snack('Calling $phone...');
                }
              },
            ),
            _ActionTile(
              icon: Icons.edit_note_rounded, color: const Color(0xFF6366F1),
              label: 'Update Status', sub: 'Add notes or change status',
              onTap: () {
                Navigator.pop(context);
                _snack('Status update coming soon');
              },
            ),
            _ActionTile(
              icon: Icons.info_outline_rounded, color: Colors.blue,
              label: 'View Full Details', sub: 'Customer & Product history',
              onTap: () {
                Navigator.pop(context);
                _snack('Details view coming soon');
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: _buildAppBar(user, auth, isLandscape),
      body: _isLoading
          ? const _Loader()
          : Column(children: [
              _buildTabBar(),
              Expanded(child: TabBarView(
                controller: _tabController,
                children: _statuses.map((s) => _buildJobList(s, isLandscape)).toList(),
              )),
            ]),
    );
  }

  PreferredSizeWidget _buildAppBar(Map? user, AuthProvider auth, bool isLandscape) {
    final name = user?['name']?.toString().split(' ').first ?? 'Engineer';
    final email = user?['email']?.toString() ?? '';
    return PreferredSize(
      preferredSize: Size.fromHeight(isLandscape ? 88 : 150),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF283593)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(color: Color(0x440D47A1), blurRadius: 14, offset: Offset(0, 4)),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: isLandscape
                ? _buildBarLandscape(name, email, auth)
                : _buildBarPortrait(name, email, auth),
          ),
        ),
      ),
    );
  }

  Widget _buildBarPortrait(String name, String email, AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _Avatar(name: name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Hi, $name 👷', style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text(email, style: const TextStyle(fontSize: 11, color: Color(0xB3FFFFFF)),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            _isRefreshing
                ? Container(
                    width: 36, height: 36,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12), shape: BoxShape.circle),
                    child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : _AppBarIconBtn(
                    icon: Icons.refresh_rounded,
                    tooltip: 'Refresh',
                    onTap: () => _fetchJobs(silent: true)),
            const SizedBox(width: 8),
            _AppBarIconBtn(
              icon: Icons.logout_rounded,
              tooltip: 'Logout',
              color: const Color(0xFFEF4444),
              onTap: () => _showLogoutDialog(auth)),
          ],
        ),
        const SizedBox(height: 10),
        // Stats row
        Row(children: [
          Expanded(child: _StatChip(label: 'Total',   value: _jobs.length, color: Colors.white24,                              icon: Icons.assignment_rounded)),
          const SizedBox(width: 6),
          Expanded(child: _StatChip(label: 'Pending', value: _pending,     color: const Color(0xFFF59E0B).withOpacity(0.35),   icon: Icons.schedule_rounded)),
          const SizedBox(width: 6),
          Expanded(child: _StatChip(label: 'Active',  value: _active,      color: const Color(0xFF6366F1).withOpacity(0.35),   icon: Icons.engineering_rounded)),
          const SizedBox(width: 6),
          Expanded(child: _StatChip(label: 'Done',    value: _completed,   color: const Color(0xFF22C55E).withOpacity(0.35),   icon: Icons.check_circle_rounded)),
        ]),
      ],
    );
  }

  Widget _buildBarLandscape(String name, String email, AuthProvider auth) {
    return Row(children: [
      _Avatar(name: name),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text('Hi, $name 👷', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(email, style: const TextStyle(fontSize: 11, color: Color(0xB3FFFFFF)), overflow: TextOverflow.ellipsis),
      ])),
      const SizedBox(width: 10),
      _StatChip(label: 'Pending', value: _pending,   color: const Color(0xFFF59E0B).withOpacity(0.35), icon: Icons.schedule_rounded),
      const SizedBox(width: 6),
      _StatChip(label: 'Active',  value: _active,    color: const Color(0xFF6366F1).withOpacity(0.35), icon: Icons.engineering_rounded),
      const SizedBox(width: 6),
      _StatChip(label: 'Done',    value: _completed, color: const Color(0xFF22C55E).withOpacity(0.35), icon: Icons.check_circle_rounded),
      const SizedBox(width: 10),
      _isRefreshing
          ? Container(
              width: 34, height: 34, padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), shape: BoxShape.circle),
              child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : _AppBarIconBtn(icon: Icons.refresh_rounded, tooltip: 'Refresh', onTap: () => _fetchJobs(silent: true)),
      const SizedBox(width: 8),
      _AppBarIconBtn(
          icon: Icons.logout_rounded, tooltip: 'Logout',
          color: const Color(0xFFEF4444), onTap: () => _showLogoutDialog(auth)),
    ]);
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); auth.logout(); },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
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
        unselectedLabelColor: Colors.white38,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        tabs: List.generate(4, (i) => Tab(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(_tabIcons[i], size: 14),
            const SizedBox(width: 4),
            Text(_tabLabels[i]),
          ]),
        )),
      ),
    );
  }

  Widget _buildJobList(String filter, bool isLandscape) {
    final list = _filter(filter);
    if (list.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 80, height: 80,
          decoration: BoxDecoration(color: _kPrimary.withOpacity(0.07), shape: BoxShape.circle),
          child: Icon(Icons.inbox_rounded, size: 40, color: _kPrimary.withOpacity(0.4))),
        const SizedBox(height: 16),
        Text('No jobs here', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
        const SizedBox(height: 6),
        Text('Pull down to refresh', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
      ]));
    }
    return RefreshIndicator(
      onRefresh: _fetchJobs,
      color: _kPrimary,
      child: isLandscape
          ? GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, childAspectRatio: 1.6,
                crossAxisSpacing: 12, mainAxisSpacing: 12,
              ),
              itemCount: list.length,
              itemBuilder: (_, i) => _JobCard(
                job: list[i], statusColor: _statusColor(list[i]['status'] ?? ''),
                actionConfig: _actionConfig(list[i]),
                onAction: (route) => context.go(route),
                onMore: () => _showQuickActions(list[i]),
                compact: true,
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: list.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _JobCard(
                  job: list[i], statusColor: _statusColor(list[i]['status'] ?? ''),
                  actionConfig: _actionConfig(list[i]),
                  onAction: (route) => context.go(route),
                  onMore: () => _showQuickActions(list[i]),
                ),
              ),
            ),
    );
  }
}

// ── Job Card ──────────────────────────────────────────────────────────────────
class _JobCard extends StatelessWidget {
  final dynamic job;
  final Color statusColor;
  final Map<String, dynamic> actionConfig;
  final void Function(String) onAction;
  final VoidCallback onMore;
  final bool compact;

  const _JobCard({
    required this.job, required this.statusColor,
    required this.actionConfig, required this.onAction,
    required this.onMore,
    this.compact = false,
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
    final status   = job['status'] ?? 'PENDING';
    final customer = (job['customer_id'] as Map?)?.cast<String, dynamic>() ?? {};
    final product  = (job['product_id'] as Map?)?.cast<String, dynamic>() ?? {};
    final isDone   = const ['INSTALLATION_COMPLETED', 'COMPLETED'].contains(status);

    final proofUrl = job['installation_proof_url'] ?? job['proof_image_url'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Ticket row
          Row(children: [
            Expanded(child: Text('#${job['ticket_number'] ?? '-'}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: compact ? 12 : 14),
                overflow: TextOverflow.ellipsis)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text((job['type'] ?? 'JOB').toUpperCase(),
                  style: const TextStyle(color: _kPrimary, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 10, vertical: compact ? 3 : 5),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withOpacity(0.4)),
              ),
              child: Text(status.replaceAll('_', ' '),
                  style: TextStyle(color: statusColor, fontSize: compact ? 8 : 10, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.more_vert_rounded, size: 20, color: Colors.grey),
              onPressed: onMore,
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
          ]),
          SizedBox(height: compact ? 8 : 12),
          // Customer + product info
          _InfoLine(Icons.person_rounded, customer['name'] ?? 'Unknown', compact: compact),
          SizedBox(height: compact ? 3 : 5),
          _InfoLine(Icons.tv_rounded, '${product['model_name'] ?? 'N/A'} • ${product['serial_number'] ?? '-'}', compact: compact),
          if (!compact && customer['phone'] != null) ...[
            const SizedBox(height: 5),
            _InfoLine(Icons.phone_rounded, customer['phone']),
          ],
          
          if (isDone && proofUrl != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => _showImagePreview(context, proofUrl),
                child: Image.network(
                  proofUrl, height: 60, width: double.infinity, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 60, color: Colors.grey.shade100,
                    child: const Icon(Icons.image_not_supported_rounded, color: Colors.grey, size: 20),
                  ),
                ),
              ),
            ),
          ],

          SizedBox(height: compact ? 10 : 14),
          // Action button or done badge
          isDone
              ? Row(children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 16),
                  const SizedBox(width: 6),
                  Text('Completed', style: TextStyle(color: const Color(0xFF22C55E),
                      fontWeight: FontWeight.w700, fontSize: compact ? 11 : 13)),
                ])
              : SizedBox(
                  width: double.infinity,
                  height: compact ? 34 : 42,
                  child: ElevatedButton.icon(
                    onPressed: () => onAction(actionConfig['route']),
                    icon: Icon(actionConfig['icon'] as IconData, size: compact ? 14 : 17),
                    label: Text(actionConfig['label'],
                        style: TextStyle(fontSize: compact ? 11 : 13, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: actionConfig['color'] as Color,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
        ]),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String sub;
  final VoidCallback onTap;

  const _ActionTile({required this.icon, required this.color, required this.label, required this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Container(
      width: 44, height: 44,
      decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 22),
    ),
    title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
    subtitle: Text(sub, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
    onTap: onTap,
  );
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool compact;
  const _InfoLine(this.icon, this.text, {this.compact = false});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: compact ? 12 : 14, color: Colors.grey.shade400),
    const SizedBox(width: 5),
    Expanded(child: Text(text,
        style: TextStyle(fontSize: compact ? 11 : 13, color: Colors.grey.shade700),
        overflow: TextOverflow.ellipsis)),
  ]);
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;
  const _StatChip({required this.label, required this.value, required this.color, required this.icon});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: Colors.white, size: 16),
      const SizedBox(height: 2),
      Text('$value', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9)),
    ]),
  );
}

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});
  @override
  Widget build(BuildContext context) => Container(
    width: 48, height: 48,
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.4), width: 2)),
    child: Center(child: Text(name[0].toUpperCase(),
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20))),
  );
}

class _AppBarIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;
  const _AppBarIconBtn({required this.icon, required this.tooltip, required this.onTap, this.color = Colors.white});
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: color == Colors.white ? Colors.white.withOpacity(0.15) : color.withOpacity(0.18),
          shape: BoxShape.circle,
          border: Border.all(
            color: color == Colors.white ? Colors.white.withOpacity(0.3) : color.withOpacity(0.5), width: 1),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    ),
  );
}

class _Loader extends StatelessWidget {
  const _Loader();
  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: _kBg,
    body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      CircularProgressIndicator(color: _kPrimary),
      SizedBox(height: 16),
      Text('Loading jobs...', style: TextStyle(color: Colors.grey)),
    ])),
  );
}
