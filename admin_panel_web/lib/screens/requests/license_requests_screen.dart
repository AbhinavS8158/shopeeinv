import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/models/license_request_model.dart';
import '../../core/theme/admin_theme.dart';
import '../../services/license_service.dart';

class LicenseRequestsScreen extends StatefulWidget {
  const LicenseRequestsScreen({super.key});

  @override
  State<LicenseRequestsScreen> createState() => _LicenseRequestsScreenState();
}

class _LicenseRequestsScreenState extends State<LicenseRequestsScreen> {
  String _filter = 'All'; // 'All', 'Pending', 'Approved', 'Rejected'
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<LicenseService>();
    final allRequests = service.licenseRequests;

    final filtered = allRequests.where((r) {
      if (_filter == 'Pending' && !r.isPending) return false;
      if (_filter == 'Approved' && !r.isApproved) return false;
      if (_filter == 'Rejected' && !r.isRejected) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchShop = r.shopName.toLowerCase().contains(q);
        final matchUser = r.customerName.toLowerCase().contains(q);
        final matchEmail = r.email.toLowerCase().contains(q);
        final matchId = r.id.toLowerCase().contains(q);
        final matchPhone = r.phone.toLowerCase().contains(q);
        if (!matchShop && !matchUser && !matchEmail && !matchId && !matchPhone) {
          return false;
        }
      }
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'License Requests',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AdminTheme.textWhite,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (service.pendingRequestsCount > 0) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AdminTheme.warning.withValues(alpha: 0.2),
                            border: Border.all(color: AdminTheme.warning.withValues(alpha: 0.5)),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${service.pendingRequestsCount} PENDING',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AdminTheme.warning,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Review business applications, configure terminal capacity, and grant or reject application licenses.',
                    style: TextStyle(fontSize: 13, color: AdminTheme.textMuted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Search and Filters Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AdminTheme.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AdminTheme.borderColor),
            ),
            child: Row(
              children: [
                // Search Input
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: AdminTheme.textWhite, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search by shop name, user, email, phone or request ID...',
                      hintStyle: const TextStyle(color: AdminTheme.textMuted, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: AdminTheme.textMuted, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: AdminTheme.textMuted, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AdminTheme.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AdminTheme.borderColor),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  ),
                ),
                const SizedBox(width: 16),

                // Filter Chips
                Wrap(
                  spacing: 8,
                  children: [
                    _buildFilterChip('All', allRequests.length),
                    _buildFilterChip('Pending', service.pendingRequestsCount, color: AdminTheme.warning),
                    _buildFilterChip('Approved', allRequests.where((r) => r.isApproved).length, color: AdminTheme.success),
                    _buildFilterChip('Rejected', allRequests.where((r) => r.isRejected).length, color: AdminTheme.danger),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Requests Table
          Container(
            decoration: BoxDecoration(
              color: AdminTheme.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AdminTheme.borderColor),
            ),
            child: filtered.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.inbox_outlined, size: 48, color: AdminTheme.textMuted),
                          SizedBox(height: 12),
                          Text(
                            'No license requests found',
                            style: TextStyle(color: AdminTheme.textWhite, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Requests submitted by registered shops will appear here for administrator review.',
                            style: TextStyle(color: AdminTheme.textMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(const Color(0xFF0F172A)),
                      headingTextStyle: const TextStyle(
                        color: AdminTheme.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      dataRowColor: WidgetStateProperty.resolveWith((states) {
                        return states.contains(WidgetState.hovered)
                            ? const Color(0xFF1E293B).withValues(alpha: 0.5)
                            : Colors.transparent;
                      }),
                      dataTextStyle: const TextStyle(color: AdminTheme.textWhite, fontSize: 13),
                      horizontalMargin: 20,
                      columnSpacing: 24,
                      columns: const [
                        DataColumn(label: Text('REQUEST ID')),
                        DataColumn(label: Text('SHOP NAME')),
                        DataColumn(label: Text('OWNER / USER')),
                        DataColumn(label: Text('CONTACT')),
                        DataColumn(label: Text('BUSINESS TYPE')),
                        DataColumn(label: Text('DATE')),
                        DataColumn(label: Text('STATUS')),
                        DataColumn(label: Text('ACTIONS')),
                      ],
                      rows: filtered.map((req) {
                        return DataRow(
                          cells: [
                            DataCell(
                              Text(
                                req.id,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: AdminTheme.primaryLight,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            DataCell(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    req.shopName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.textWhite),
                                  ),
                                  if (req.gstin.isNotEmpty)
                                    Text('GST: ${req.gstin}', style: const TextStyle(fontSize: 11, color: AdminTheme.textMuted)),
                                ],
                              ),
                            ),
                            DataCell(Text(req.customerName)),
                            DataCell(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(req.email, style: const TextStyle(fontSize: 12)),
                                  Text(req.phone, style: const TextStyle(fontSize: 11, color: AdminTheme.textMuted)),
                                ],
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(req.businessType, style: const TextStyle(fontSize: 11, color: AdminTheme.textMuted)),
                              ),
                            ),
                            DataCell(
                              Text(
                                DateFormat('dd MMM yyyy, hh:mm a').format(req.requestedAt),
                                style: const TextStyle(fontSize: 12, color: AdminTheme.textMuted),
                              ),
                            ),
                            DataCell(_buildStatusBadge(req.status)),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // View Details Button
                                  IconButton(
                                    icon: const Icon(Icons.visibility_outlined, size: 18, color: AdminTheme.textMuted),
                                    tooltip: 'View Complete Details',
                                    onPressed: () => _showDetailsDialog(context, req),
                                  ),

                                  if (req.isPending) ...[
                                    // Approve Button
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.check, size: 14),
                                      label: const Text('Approve', style: TextStyle(fontSize: 12)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AdminTheme.success,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                      onPressed: () => _showApproveDialog(context, req),
                                    ),
                                    const SizedBox(width: 8),

                                    // Reject Button
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.close, size: 14),
                                      label: const Text('Reject', style: TextStyle(fontSize: 12)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AdminTheme.danger,
                                        side: const BorderSide(color: AdminTheme.danger),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                      onPressed: () => _showRejectDialog(context, req),
                                    ),
                                  ] else if (req.isApproved && req.licenseKey != null) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AdminTheme.success.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AdminTheme.success.withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        req.licenseKey!,
                                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AdminTheme.success),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int count, {Color? color}) {
    final isSelected = _filter == label;
    final chipColor = color ?? AdminTheme.primaryLight;

    return InkWell(
      onTap: () => setState(() => _filter = label),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? chipColor.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? chipColor : AdminTheme.borderColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AdminTheme.textMuted,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? chipColor : const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color text;

    switch (status.toLowerCase()) {
      case 'approved':
        bg = AdminTheme.success.withValues(alpha: 0.15);
        text = AdminTheme.success;
        break;
      case 'rejected':
        bg = AdminTheme.danger.withValues(alpha: 0.15);
        text = AdminTheme.danger;
        break;
      case 'pending':
      default:
        bg = AdminTheme.warning.withValues(alpha: 0.15);
        text = AdminTheme.warning;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: text.withValues(alpha: 0.4)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: text),
      ),
    );
  }

  // View Details Modal Dialog
  void _showDetailsDialog(BuildContext context, LicenseRequestModel req) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AdminTheme.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AdminTheme.borderColor),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 540),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Application Request Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AdminTheme.textWhite),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AdminTheme.textMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(color: AdminTheme.borderColor, height: 24),
              _buildModalRow('Request ID', req.id),
              _buildModalRow('User Name', req.customerName),
              _buildModalRow('User ID', req.customerId),
              _buildModalRow('Shop Name', req.shopName),
              _buildModalRow('Shop ID', req.shopId),
              _buildModalRow('Business Type', req.businessType),
              _buildModalRow('Email', req.email),
              _buildModalRow('Phone', req.phone),
              _buildModalRow('Address', req.address),
              _buildModalRow('GSTIN', req.gstin.isNotEmpty ? req.gstin : 'Not provided'),
              _buildModalRow('Submission Date', DateFormat('dd/MM/yyyy hh:mm a').format(req.requestedAt)),
              _buildModalRow('Current Status', req.status),
              if (req.rejectionReason != null && req.rejectionReason!.isNotEmpty)
                _buildModalRow('Rejection Reason', req.rejectionReason!, isAlert: true),
              if (req.adminNotes != null && req.adminNotes!.isNotEmpty)
                _buildModalRow('Notes', req.adminNotes!),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalRow(String label, String value, {bool isAlert = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(fontSize: 13, color: AdminTheme.textMuted)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isAlert ? AdminTheme.danger : AdminTheme.textWhite,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Approval Modal Dialog
  void _showApproveDialog(BuildContext context, LicenseRequestModel req) {
    String licenseType = 'Standard';
    String validityType = '1_year';
    int maxDevices = 2;
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          backgroundColor: AdminTheme.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AdminTheme.borderColor),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AdminTheme.success.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_outline, color: AdminTheme.success, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Approve License for "${req.shopName}"',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AdminTheme.textWhite),
                      ),
                    ),
                  ],
                ),
                const Divider(color: AdminTheme.borderColor, height: 24),
                const Text(
                  'Configure the application license parameters before issuing to this merchant terminal:',
                  style: TextStyle(fontSize: 13, color: AdminTheme.textMuted),
                ),
                const SizedBox(height: 16),

                // License Type Dropdown
                DropdownButtonFormField<String>(
                  initialValue: licenseType,
                  dropdownColor: const Color(0xFF0F172A),
                  style: const TextStyle(color: AdminTheme.textWhite, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'License Plan / Tier',
                    labelStyle: const TextStyle(color: AdminTheme.textMuted),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Standard', child: Text('Standard Plan')),
                    DropdownMenuItem(value: 'Trial', child: Text('Trial Plan')),
                    DropdownMenuItem(value: 'Premium', child: Text('Premium Plan')),
                    DropdownMenuItem(value: 'Enterprise', child: Text('Enterprise Multi-Terminal')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => licenseType = val);
                  },
                ),
                const SizedBox(height: 12),

                // Validity Type Dropdown
                DropdownButtonFormField<String>(
                  initialValue: validityType,
                  dropdownColor: const Color(0xFF0F172A),
                  style: const TextStyle(color: AdminTheme.textWhite, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Validity Duration',
                    labelStyle: const TextStyle(color: AdminTheme.textMuted),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: const [
                    DropdownMenuItem(value: '30_days', child: Text('30 Days')),
                    DropdownMenuItem(value: '3_months', child: Text('3 Months')),
                    DropdownMenuItem(value: '6_months', child: Text('6 Months')),
                    DropdownMenuItem(value: '1_year', child: Text('1 Year (Standard Annual)')),
                    DropdownMenuItem(value: 'lifetime', child: Text('Lifetime Perpetual')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => validityType = val);
                  },
                ),
                const SizedBox(height: 12),

                // Device Limit Dropdown
                DropdownButtonFormField<int>(
                  initialValue: maxDevices,
                  dropdownColor: const Color(0xFF0F172A),
                  style: const TextStyle(color: AdminTheme.textWhite, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Maximum Device Terminals Allowed',
                    labelStyle: const TextStyle(color: AdminTheme.textMuted),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1 Terminal (Single Mobile)')),
                    DropdownMenuItem(value: 2, child: Text('2 Terminals (Default Mobile + POS)')),
                    DropdownMenuItem(value: 3, child: Text('3 Terminals')),
                    DropdownMenuItem(value: 5, child: Text('5 Terminals (Store Fleet)')),
                    DropdownMenuItem(value: 10, child: Text('10 Terminals (Enterprise)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => maxDevices = val);
                  },
                ),
                const SizedBox(height: 12),

                // Notes
                TextField(
                  controller: notesController,
                  style: const TextStyle(color: AdminTheme.textWhite, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Admin Approval Notes (Optional)',
                    labelStyle: const TextStyle(color: AdminTheme.textMuted),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Generate & Assign License'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminTheme.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final service = Provider.of<LicenseService>(context, listen: false);
                        final success = await service.approveLicenseRequest(
                          requestId: req.id,
                          licenseType: licenseType,
                          validityType: validityType,
                          maxDevices: maxDevices,
                          adminNotes: notesController.text.trim(),
                        );
                        if (context.mounted && success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AdminTheme.success,
                              content: Text('License issued and approved for ${req.shopName}!'),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Reject Modal Dialog
  void _showRejectDialog(BuildContext context, LicenseRequestModel req) {
    final reasonController = TextEditingController();
    String? localError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          backgroundColor: AdminTheme.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AdminTheme.borderColor),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AdminTheme.danger.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.cancel_outlined, color: AdminTheme.danger, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Reject Request: "${req.shopName}"',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AdminTheme.textWhite),
                      ),
                    ),
                  ],
                ),
                const Divider(color: AdminTheme.borderColor, height: 24),
                const Text(
                  'Please provide a clear reason for the rejection. This message will be presented directly to the user so they can rectify their shop details and resubmit.',
                  style: TextStyle(fontSize: 13, color: AdminTheme.textMuted, height: 1.4),
                ),
                const SizedBox(height: 16),

                if (localError != null) ...[
                  Text(localError!, style: const TextStyle(color: AdminTheme.danger, fontSize: 12)),
                  const SizedBox(height: 8),
                ],

                TextField(
                  controller: reasonController,
                  style: const TextStyle(color: AdminTheme.textWhite, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Rejection Reason *',
                    hintText: 'e.g. Invalid GST number or unverified business location.',
                    hintStyle: const TextStyle(color: AdminTheme.textMuted),
                    labelStyle: const TextStyle(color: AdminTheme.textMuted),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminTheme.danger,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: () async {
                        final reason = reasonController.text.trim();
                        if (reason.isEmpty) {
                          setModalState(() => localError = 'Rejection reason is required.');
                          return;
                        }

                        Navigator.pop(ctx);
                        final service = Provider.of<LicenseService>(context, listen: false);
                        final success = await service.rejectLicenseRequest(
                          requestId: req.id,
                          reason: reason,
                        );

                        if (context.mounted && success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AdminTheme.danger,
                              content: Text('Request for "${req.shopName}" has been rejected.'),
                            ),
                          );
                        }
                      },
                      child: const Text('Confirm Rejection'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
