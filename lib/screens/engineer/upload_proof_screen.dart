import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/constants.dart';

const _kPrimary = Color(0xFF0D47A1);
const _kGreen   = Color(0xFF22C55E);
const _kBg      = Color(0xFFF1F4F9);

class UploadProofScreen extends StatefulWidget {
  final String ticketId;
  const UploadProofScreen({super.key, required this.ticketId});

  @override
  State<UploadProofScreen> createState() => _UploadProofScreenState();
}

class _UploadProofScreenState extends State<UploadProofScreen>
    with SingleTickerProviderStateMixin {
  File? _selectedImage;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();
  late AnimationController _successController;

  @override
  void initState() {
    super.initState();
    _successController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600));
  }

  @override
  void dispose() { _successController.dispose(); super.dispose(); }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
        source: source, imageQuality: 80, maxWidth: 1400);
    if (picked != null) setState(() => _selectedImage = File(picked.path));
  }

  Future<void> _uploadProof() async {
    if (_selectedImage == null) {
      Fluttertoast.showToast(msg: 'Please capture or select an image first',
          backgroundColor: Colors.orange);
      return;
    }
    setState(() => _isUploading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final uri   = Uri.parse('${AppConstants.baseUrl}/installations/${widget.ticketId}/complete');
      final req   = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(await http.MultipartFile.fromPath('image', _selectedImage!.path,
            contentType: MediaType('image', 'jpeg')));

      final streamed = await req.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);

      String msg = '';
      try { msg = jsonDecode(response.body)['message'] ?? ''; } catch (_) { msg = response.body; }

      if (response.statusCode == 200) {
        Fluttertoast.showToast(
            msg: '🎉 Installation Completed! Warranty Activated.',
            backgroundColor: _kGreen, toastLength: Toast.LENGTH_LONG);
        await _successController.forward();
        if (mounted) context.go('/engineer');
      } else {
        Fluttertoast.showToast(
            msg: 'Upload failed (${response.statusCode}): $msg',
            backgroundColor: const Color(0xFFEF4444), toastLength: Toast.LENGTH_LONG);
      }
    } on TimeoutException {
      Fluttertoast.showToast(msg: 'Request timed out', backgroundColor: const Color(0xFFEF4444));
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error: $e',
          backgroundColor: const Color(0xFFEF4444), toastLength: Toast.LENGTH_LONG);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showSourcePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      backgroundColor: Colors.white,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Text('Select Photo Source',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: _SourceTile(
              icon: Icons.camera_alt_rounded,
              label: 'Camera',
              color: _kPrimary,
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
            )),
            const SizedBox(width: 14),
            Expanded(child: _SourceTile(
              icon: Icons.photo_library_rounded,
              label: 'Gallery',
              color: const Color(0xFF7C3AED),
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
            )),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.go('/engineer'),
        ),
        title: const Text('Upload Installation Proof',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: isLandscape ? _buildLandscape() : _buildPortrait(),
    );
  }

  // ── Portrait ───────────────────────────────────────────────────────────
  Widget _buildPortrait() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _buildStatusBanner(),
        const SizedBox(height: 20),
        _buildImagePicker(height: 240),
        const SizedBox(height: 16),
        _buildPickerButtons(),
        const SizedBox(height: 28),
        _buildUploadButton(),
        const SizedBox(height: 16),
        _buildTip(),
      ]),
    );
  }

  // ── Landscape ──────────────────────────────────────────────────────────
  Widget _buildLandscape() {
    return Row(children: [
      // Left: image preview
      Expanded(
        flex: 5,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Expanded(child: _buildImagePicker()),
            const SizedBox(height: 12),
            _buildPickerButtons(),
          ]),
        ),
      ),
      // Right: info + upload
      Expanded(
        flex: 5,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _buildStatusBanner(),
            const SizedBox(height: 20),
            _buildUploadButton(),
            const SizedBox(height: 14),
            _buildTip(),
          ]),
        ),
      ),
    ]);
  }

  // ── Components ─────────────────────────────────────────────────────────
  Widget _buildStatusBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kGreen, Color(0xFF16A34A)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: _kGreen.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Row(children: [
        Container(width: 52, height: 52,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
          child: const Icon(Icons.verified_rounded, color: Colors.white, size: 28)),
        const SizedBox(width: 14),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('OTP Verified!', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 3),
          Text('Capture the completed installation\nas final proof to close the ticket.',
              style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 12, height: 1.4)),
        ])),
      ]),
    );
  }

  Widget _buildImagePicker({double? height}) {
    return GestureDetector(
      onTap: _showSourcePicker,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _selectedImage != null ? _kGreen : Colors.grey.shade200,
            width: _selectedImage != null ? 2.5 : 1.5,
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        clipBehavior: Clip.antiAlias,
        child: _selectedImage != null
            ? Stack(fit: StackFit.expand, children: [
                Image.file(_selectedImage!, fit: BoxFit.cover),
                Positioned(bottom: 10, right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 5),
                      Text('Change', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ]),
                  ),
                ),
              ])
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 64, height: 64,
                  decoration: BoxDecoration(color: _kPrimary.withOpacity(0.07), shape: BoxShape.circle),
                  child: Icon(Icons.add_a_photo_rounded, size: 32, color: _kPrimary.withOpacity(0.5))),
                const SizedBox(height: 12),
                Text('Tap to capture photo',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                const SizedBox(height: 6),
                Text('or choose from gallery',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
              ]),
      ),
    );
  }

  Widget _buildPickerButtons() {
    return Row(children: [
      Expanded(child: OutlinedButton.icon(
        onPressed: () => _pickImage(ImageSource.camera),
        icon: const Icon(Icons.camera_alt_rounded, size: 18),
        label: const Text('Camera'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _kPrimary,
          side: const BorderSide(color: _kPrimary, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      )),
      const SizedBox(width: 12),
      Expanded(child: OutlinedButton.icon(
        onPressed: () => _pickImage(ImageSource.gallery),
        icon: const Icon(Icons.photo_library_rounded, size: 18),
        label: const Text('Gallery'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF7C3AED),
          side: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      )),
    ]);
  }

  Widget _buildUploadButton() {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: _isUploading ? null : _uploadProof,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kGreen,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          elevation: 4,
          shadowColor: _kGreen.withOpacity(0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _isUploading
            ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
                SizedBox(width: 12),
                Text('Uploading...', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ])
            : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.cloud_done_rounded, size: 22),
                SizedBox(width: 10),
                Text('Complete Installation',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ]),
      ),
    );
  }

  Widget _buildTip() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.lightbulb_outline_rounded, size: 18, color: Colors.amber.shade700),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Tip: Ensure the TV, serial number sticker, and installation area are all clearly visible in the photo.',
            style: TextStyle(fontSize: 12, color: Colors.amber.shade900, height: 1.5),
          ),
        ),
      ]),
    );
  }
}

// ── Source Tile ───────────────────────────────────────────────────────────────
class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SourceTile({required this.icon, required this.label,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
      ),
    );
  }
}
