import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/theme/admin_theme.dart';
import '../../services/license_service.dart';
import '../../widgets/stat_card.dart';

class DashboardScreen extends StatelessWidget {
  final ValueChanged<int> onNavigate;

  const DashboardScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<LicenseService>();
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    final utilizationPercent = service.totalAllowedSlots > 0
        ? ((service.totalConnectedDevices / service.totalAllowedSlots) * 100).clamp(0, 100).round()
        : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Executive Dashboard',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AdminTheme.textWhite,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Live overview of registered shops, active licenses, device slot capacity, and security.',
                    style: TextStyle(fontSize: 13, color: AdminTheme.textMuted),
                  ),
                ],
              ),
              Wrap(
                spacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => onNavigate(2), // Licenses
                    icon: const Icon(Icons.vpn_key, size: 16),
                    label: const Text('Manage Licenses'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => onNavigate(8), // Simulator
                    icon: const Icon(Icons.phone_android, size: 16, color: AdminTheme.primaryLight),
                    label: const Text('Device Simulator', style: TextStyle(color: AdminTheme.primaryLight)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AdminTheme.primary.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Pending Requests Alert Banner
          if (service.pendingRequestsCount > 0) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: AdminTheme.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AdminTheme.warning.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AdminTheme.warning.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.notifications_active, color: AdminTheme.warning, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${service.pendingRequestsCount} License Request(s) Awaiting Review',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AdminTheme.textWhite,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'New shop owners have registered and are waiting for admin approval to access ShopeeInv.',
                          style: TextStyle(fontSize: 12, color: AdminTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.warning,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('Review Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: () => onNavigate(11),
                  ),
                ],
              ),
            ),
          ],

          // 4 Metric KPI Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width > 1100 ? 4 : (width > 600 ? 2 : 1);

              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: crossAxisCount == 4 ? 1.6 : 1.9,
                children: [
                  StatCard(
                    title: 'Total Customers',
                    value: '${service.totalCustomers}',
                    subtitle: '${service.activeCustomers} Active • ${service.blockedCustomers} Blocked',
                    icon: Icons.storefront_outlined,
                    iconColor: AdminTheme.primary,
                    trailingBadge: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AdminTheme.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${service.activeCustomers} Active',
                        style: const TextStyle(color: AdminTheme.success, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    onTap: () => onNavigate(1), // Customers
                  ),
                  StatCard(
                    title: 'Licenses Issued',
                    value: '${service.totalLicenses}',
                    subtitle: '${service.activeLicenses} Active • ${service.expiredLicenses} Expired',
                    icon: Icons.vpn_key_outlined,
                    iconColor: AdminTheme.success,
                    trailingBadge: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AdminTheme.danger.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${service.expiredLicenses} Expired',
                        style: const TextStyle(color: AdminTheme.danger, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    onTap: () => onNavigate(2), // Licenses
                  ),
                  StatCard(
                    title: 'Connected Devices',
                    value: '${service.totalConnectedDevices}',
                    subtitle: 'of ${service.totalAllowedSlots} allowed slots (${service.availableSlots} free)',
                    icon: Icons.laptop_mac_outlined,
                    iconColor: AdminTheme.info,
                    trailingBadge: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AdminTheme.info.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${service.availableSlots} Free',
                        style: const TextStyle(color: AdminTheme.info, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    onTap: () => onNavigate(3), // Devices
                  ),
                  StatCard(
                    title: 'Fleet Capacity Used',
                    value: '$utilizationPercent%',
                    subtitle: '${service.totalConnectedDevices} / ${service.totalAllowedSlots} total slots assigned',
                    icon: Icons.memory,
                    iconColor: AdminTheme.purple,
                    trailingBadge: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AdminTheme.purple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Quota',
                        style: TextStyle(color: AdminTheme.purple, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    onTap: () => onNavigate(3),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Charts Row
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildConnectionTrafficChart(service)),
                const SizedBox(width: 20),
                Expanded(flex: 2, child: _buildLicenseDistributionChart(service)),
              ],
            )
          else ...[
            _buildConnectionTrafficChart(service),
            const SizedBox(height: 20),
            _buildLicenseDistributionChart(service),
          ],
          const SizedBox(height: 24),

          // Hardware Fleet & Recent Tables
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildRecentCustomers(service),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildRecentLicenses(service),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionTrafficChart(LicenseService service) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AdminTheme.panelBg.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminTheme.borderColor.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Device Connection Traffic & Security',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AdminTheme.textWhite),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Allowed connections vs blocked device limit attempts',
                    style: TextStyle(fontSize: 12, color: AdminTheme.textMuted),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AdminTheme.scaffoldBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Last 7 Days', style: TextStyle(fontSize: 11, color: AdminTheme.textMuted)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => const FlLine(color: Color(0xFF1E293B), strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Today'];
                        final idx = val.toInt();
                        if (idx >= 0 && idx < days.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(days[idx], style: const TextStyle(color: AdminTheme.textSubtle, fontSize: 10)),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (val, meta) => Text(
                        val.toInt().toString(),
                        style: const TextStyle(color: AdminTheme.textSubtle, fontSize: 10),
                      ),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 1),
                      FlSpot(1, 3),
                      FlSpot(2, 2),
                      FlSpot(3, 5),
                      FlSpot(4, 4),
                      FlSpot(5, 7),
                      FlSpot(6, 6),
                    ],
                    isCurved: true,
                    color: AdminTheme.success,
                    barWidth: 3,
                    belowBarData: BarAreaData(
                      show: true,
                      color: AdminTheme.success.withValues(alpha: 0.1),
                    ),
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 0),
                      FlSpot(1, 1),
                      FlSpot(2, 0),
                      FlSpot(3, 2),
                      FlSpot(4, 1),
                      FlSpot(5, 1),
                      FlSpot(6, 2),
                    ],
                    isCurved: true,
                    color: AdminTheme.danger,
                    barWidth: 2,
                    belowBarData: BarAreaData(
                      show: true,
                      color: AdminTheme.danger.withValues(alpha: 0.08),
                    ),
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ChartLegend(color: AdminTheme.success, label: 'Allowed Connections'),
              SizedBox(width: 24),
              _ChartLegend(color: AdminTheme.danger, label: 'Blocked (Limit Reached / Blacklisted)'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLicenseDistributionChart(LicenseService service) {
    final active = service.activeLicenses.toDouble();
    final expired = service.expiredLicenses.toDouble();
    final suspended = service.suspendedLicenses.toDouble();

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AdminTheme.panelBg.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminTheme.borderColor.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'License Status Quota',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AdminTheme.textWhite),
          ),
          const SizedBox(height: 2),
          const Text(
            'Active, Expired & Suspended distribution',
            style: TextStyle(fontSize: 12, color: AdminTheme.textMuted),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 46,
                sections: [
                  PieChartSectionData(
                    value: active > 0 ? active : 1,
                    color: AdminTheme.success,
                    title: '${active.toInt()}',
                    titleStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  ),
                  PieChartSectionData(
                    value: expired > 0 ? expired : 0.01,
                    color: AdminTheme.danger,
                    title: expired > 0 ? '${expired.toInt()}' : '',
                    titleStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  ),
                  PieChartSectionData(
                    value: suspended > 0 ? suspended : 0.01,
                    color: AdminTheme.warning,
                    title: suspended > 0 ? '${suspended.toInt()}' : '',
                    titleStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ChartLegend(color: AdminTheme.success, label: 'Active ($active)'),
              _ChartLegend(color: AdminTheme.danger, label: 'Expired ($expired)'),
              _ChartLegend(color: AdminTheme.warning, label: 'Suspended ($suspended)'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentCustomers(LicenseService service) {
    final recent = service.customers.take(4).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminTheme.panelBg.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminTheme.borderColor.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Customers',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AdminTheme.textWhite),
              ),
              TextButton(
                onPressed: () => onNavigate(1),
                child: const Text('View All', style: TextStyle(fontSize: 12, color: AdminTheme.primaryLight)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recent.length,
            separatorBuilder: (context, index) => const Divider(color: Color(0xFF1E293B)),
            itemBuilder: (context, idx) {
              final c = recent[idx];
              final devCount = service.devices.where((d) => d.customerId == c.id && d.status == 'Active').length;

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AdminTheme.primary.withValues(alpha: 0.2),
                  child: Text(
                    c.shopName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: AdminTheme.primaryLight, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  c.shopName,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AdminTheme.textWhite),
                ),
                subtitle: Text(
                  '${c.name} • ${c.email}',
                  style: const TextStyle(fontSize: 11, color: AdminTheme.textMuted),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: c.status == 'Active' ? AdminTheme.success.withValues(alpha: 0.15) : AdminTheme.danger.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$devCount devs',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: c.status == 'Active' ? AdminTheme.success : AdminTheme.danger,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecentLicenses(LicenseService service) {
    final recent = service.licenses.take(4).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminTheme.panelBg.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminTheme.borderColor.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Issued License Keys',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AdminTheme.textWhite),
              ),
              TextButton(
                onPressed: () => onNavigate(2),
                child: const Text('View All', style: TextStyle(fontSize: 12, color: AdminTheme.primaryLight)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recent.length,
            separatorBuilder: (context, index) => const Divider(color: Color(0xFF1E293B)),
            itemBuilder: (context, idx) {
              final lic = recent[idx];
              final isExpired = lic.effectiveStatus == 'Expired';

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isExpired ? AdminTheme.danger.withValues(alpha: 0.15) : AdminTheme.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.vpn_key, size: 18, color: isExpired ? AdminTheme.danger : AdminTheme.success),
                ),
                title: Text(
                  lic.licenseKey,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: AdminTheme.textWhite),
                ),
                subtitle: Text(
                  '${lic.customerName} • Limit: ${lic.maxDevices} devs',
                  style: const TextStyle(fontSize: 11, color: AdminTheme.textMuted),
                ),
                trailing: Text(
                  lic.expiresAt != null ? DateFormat('dd MMM yyyy').format(lic.expiresAt!) : 'Lifetime',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isExpired ? AdminTheme.danger : AdminTheme.textSubtle,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _ChartLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: AdminTheme.textMuted)),
      ],
    );
  }
}
