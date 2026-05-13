import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../services/api_service.dart';

const _kPrimary   = Color(0xFF0D47A1);
const _kBg        = Color(0xFFF4F6FB);

class RequestServiceScreen extends StatefulWidget {
  const RequestServiceScreen({super.key});

  @override
  State<RequestServiceScreen> createState() => _RequestServiceScreenState();
}

class _RequestServiceScreenState extends State<RequestServiceScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  String? _selectedProductId;
  String _requestType = 'installation';
  String _issueType = 'other';
  List<dynamic> _products = [];
  bool _isLoadingProducts = true;
  bool _isSubmitting = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  final List<Map<String, dynamic>> _issueTypes = [
    {'value': 'no_power',       'label': 'No Power',        'icon': Icons.power_off_rounded},
    {'value': 'display_issue',  'label': 'Display Issue',   'icon': Icons.tv_off_rounded},
    {'value': 'sound_issue',    'label': 'Sound Issue',     'icon': Icons.volume_off_rounded},
    {'value': 'remote_issue',   'label': 'Remote Issue',    'icon': Icons.settings_remote_rounded},
    {'value': 'connectivity',   'label': 'Connectivity',    'icon': Icons.wifi_off_rounded},
    {'value': 'physical_damage','label': 'Physical Damage', 'icon': Icons.broken_image_rounded},
    {'value': 'other',          'label': 'Other',           'icon': Icons.help_outline_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();
    _fetchProducts();
  }

  @override
  void dispose() {
    _animController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _fetchProducts() async {
    try {
      final res = await _apiService.get('/products');
      if (res.statusCode == 200) {
        setState(() {
          _products = jsonDecode(res.body)['data']['products'];
          _isLoadingProducts = false;
        });
      } else {
        setState(() => _isLoadingProducts = false);
      }
    } catch (_) {
      setState(() => _isLoadingProducts = false);
    }
  }

  Future<void> _submitRequest() async {
    if (_selectedProductId == null) {
      Fluttertoast.showToast(
          msg: 'Please select a product', backgroundColor: Colors.orange);
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final endpoint =
          _requestType == 'installation' ? '/installations' : '/service-requests';
      final payload = {
        'product_id': _selectedProductId,
        if (_requestType == 'repair') ...{
          'request_type': 'repair',
          'issue_type': _issueType,
          'issue_description': _descriptionController.text.trim(),
        }
      };

      final res = await _apiService.post(endpoint, payload);

      if (res.statusCode == 201) {
        Fluttertoast.showToast(
            msg: 'Request Submitted Successfully! ✓',
            backgroundColor: const Color(0xFF22C55E),
            toastLength: Toast.LENGTH_LONG);
        if (mounted) context.go('/customer');
      } else {
        final msg = jsonDecode(res.body)['message'] ?? 'Failed to submit';
        Fluttertoast.showToast(msg: msg, backgroundColor: Colors.red);
      }
    } catch (_) {
      Fluttertoast.showToast(
          msg: 'Network error. Please try again.', backgroundColor: Colors.red);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── Shared input decoration ───────────────────────────────────────────
  InputDecoration _deco(String label, {Widget? prefix, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: prefix,
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xFFE0E7EF), width: 1.5)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: _kPrimary, width: 2)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Colors.red, width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Colors.red, width: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.go('/customer'),
        ),
        title: const Text('New Service Request',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      ),
      body: _isLoadingProducts
          ? const Center(child: CircularProgressIndicator(color: _kPrimary))
          : FadeTransition(
              opacity: _fadeAnim,
              child: isLandscape
                  ? _buildLandscapeLayout()
                  : _buildPortraitLayout(),
            ),
    );
  }

  // ── Portrait ──────────────────────────────────────────────────────────
  Widget _buildPortraitLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionHeader('Service Type', Icons.category_rounded),
            const SizedBox(height: 12),
            _buildTypeSelector(),
            const SizedBox(height: 24),
            _buildSectionHeader('Select Product', Icons.devices_rounded),
            const SizedBox(height: 12),
            _buildProductDropdown(),
            if (_requestType == 'repair') ...[
              const SizedBox(height: 24),
              _buildSectionHeader('Issue Details', Icons.report_problem_rounded),
              const SizedBox(height: 12),
              _buildIssueGrid(),
              const SizedBox(height: 14),
              _buildDescriptionField(),
            ],
            const SizedBox(height: 32),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  // ── Landscape ─────────────────────────────────────────────────────────
  Widget _buildLandscapeLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left panel: type + product
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 10, 40),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSectionHeader('Service Type', Icons.category_rounded),
                  const SizedBox(height: 12),
                  _buildTypeSelector(),
                  const SizedBox(height: 20),
                  _buildSectionHeader('Select Product', Icons.devices_rounded),
                  const SizedBox(height: 12),
                  _buildProductDropdown(),
                  const SizedBox(height: 24),
                  _buildSubmitButton(),
                ],
              ),
            ),
          ),
        ),
        // Divider
        const VerticalDivider(width: 1, color: Color(0xFFE0E7EF)),
        // Right panel: issue details (only for repair)
        Expanded(
          flex: 5,
          child: _requestType == 'repair'
              ? SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(10, 20, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSectionHeader(
                          'Issue Details', Icons.report_problem_rounded),
                      const SizedBox(height: 12),
                      _buildIssueGrid(compact: true),
                      const SizedBox(height: 14),
                      _buildDescriptionField(),
                    ],
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.install_desktop_rounded,
                          size: 60, color: _kPrimary.withOpacity(0.3)),
                      const SizedBox(height: 12),
                      Text('Installation Request',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade500)),
                      const SizedBox(height: 6),
                      Text('Select a product and submit',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade400)),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  // ── Components ────────────────────────────────────────────────────────
  Widget _buildSectionHeader(String label, IconData icon) {
    return Row(
      children: [
        Container(
          width: 3, height: 18,
          decoration: BoxDecoration(
              color: _kPrimary, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 16, color: _kPrimary),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }

  Widget _buildTypeSelector() {
    return Row(
      children: [
        Expanded(
          child: _TypeCard(
            title: 'Installation',
            subtitle: 'New product setup',
            icon: Icons.install_desktop_rounded,
            isSelected: _requestType == 'installation',
            selectedColor: _kPrimary,
            onTap: () => setState(() => _requestType = 'installation'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TypeCard(
            title: 'Repair',
            subtitle: 'Fix an issue',
            icon: Icons.build_rounded,
            isSelected: _requestType == 'repair',
            selectedColor: const Color(0xFFF97316),
            onTap: () => setState(() => _requestType = 'repair'),
          ),
        ),
      ],
    );
  }

  Widget _buildProductDropdown() {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: _selectedProductId,
      hint: const Text('Choose your product'),
      decoration: _deco(
        'Product',
        prefix: Container(
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _kPrimary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.tv_rounded, size: 16, color: _kPrimary),
        ),
      ),
      items: _products.map<DropdownMenuItem<String>>((p) {
        return DropdownMenuItem(
          value: p['_id'],
          child: Text(
            '${p['model_name']} (${p['serial_number']})',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          ),
        );
      }).toList(),
      onChanged: (v) => setState(() => _selectedProductId = v),
    );
  }

  Widget _buildIssueGrid({bool compact = false}) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: compact ? 4 : 3,
        childAspectRatio: compact ? 0.85 : 1.0,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _issueTypes.length,
      itemBuilder: (_, i) {
        final item = _issueTypes[i];
        final isSelected = _issueType == item['value'];
        return GestureDetector(
          onTap: () => setState(() => _issueType = item['value']),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFF97316).withOpacity(0.1)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFF97316)
                    : const Color(0xFFE0E7EF),
                width: isSelected ? 2 : 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  item['icon'] as IconData,
                  size: compact ? 20 : 24,
                  color: isSelected
                      ? const Color(0xFFF97316)
                      : Colors.grey.shade500,
                ),
                const SizedBox(height: 5),
                Text(
                  item['label'],
                  style: TextStyle(
                    fontSize: compact ? 9 : 10,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? const Color(0xFFF97316)
                        : Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      maxLines: 4,
      style: const TextStyle(fontSize: 14),
      decoration: _deco('Describe the problem...').copyWith(
        alignLabelWithHint: true,
      ),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Description is required' : null,
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kPrimary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _kPrimary.withOpacity(0.5),
          elevation: 4,
          shadowColor: _kPrimary.withOpacity(0.35),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.send_rounded, size: 18),
                  const SizedBox(width: 10),
                  const Text('Submit Request',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
      ),
    );
  }
}

// ── Type Card ─────────────────────────────────────────────────────────────────
class _TypeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _TypeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor.withOpacity(0.07) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? selectedColor : const Color(0xFFE0E7EF),
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: selectedColor.withOpacity(0.15),
                    blurRadius: 12,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Column(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? selectedColor.withOpacity(0.12)
                    : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  size: 26,
                  color: isSelected ? selectedColor : Colors.grey.shade500),
            ),
            const SizedBox(height: 10),
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isSelected ? selectedColor : Colors.black87)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 10,
                    color: isSelected
                        ? selectedColor.withOpacity(0.7)
                        : Colors.grey.shade500),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
