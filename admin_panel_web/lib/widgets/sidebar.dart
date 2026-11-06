import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/admin_theme.dart';
import '../services/license_service.dart';

class AdminSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelectIndex;

  const AdminSidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelectIndex,
  });

  @override
  Widget build(BuildContext context) {
    final service = context.watch<LicenseService>();
    final expiredCount = service.expiredLicenses;
    final blockedCount = service.blockedCustomers;

    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: AdminTheme.sidebarBg,
        border: Border(right: BorderSide(color: AdminTheme.borderColor, width: 1)),
      ),
      child: Column(
        children: [
          // Brand Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AdminTheme.borderColor)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AdminTheme.primary, Color(0xFF4338CA)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AdminTheme.primary.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.shield_outlined, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ShopeeInv',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AdminTheme.textWhite,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Admin & License Hub',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AdminTheme.primaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Navigation Links
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              children: [
                _buildSectionHeader('Management'),
                _buildNavItem(
                  index: 0,
                  title: 'Dashboard',
                  icon: Icons.dashboard_outlined,
                  selectedIcon: Icons.dashboard,
                ),
                _buildNavItem(
                  index: 1,
                  title: 'Customers',
                  icon: Icons.people_outline,
                  selectedIcon: Icons.people,
                ),
                _buildNavItem(
                  index: 11,
                  title: 'License Requests',
                  icon: Icons.assignment_outlined,
                  selectedIcon: Icons.assignment,
                  badgeText: service.pendingRequestsCount > 0 ? '${service.pendingRequestsCount}' : null,
                  badgeColor: AdminTheme.warning,
                ),
                _buildNavItem(
                  index: 2,
                  title: 'License Keys',
                  icon: Icons.vpn_key_outlined,
                  selectedIcon: Icons.vpn_key,
                ),
                _buildNavItem(
                  index: 3,
                  title: 'Connected Devices',
                  icon: Icons.laptop_mac_outlined,
                  selectedIcon: Icons.laptop_mac,
                ),

                const SizedBox(height: 18),
                _buildSectionHeader('Enforcement & Logs'),
                _buildNavItem(
                  index: 4,
                  title: 'Device History',
                  icon: Icons.history_outlined,
                  selectedIcon: Icons.history,
                ),
                _buildNavItem(
                  index: 5,
                  title: 'Expired Licenses',
                  icon: Icons.timer_off_outlined,
                  selectedIcon: Icons.timer_off,
                  badgeText: expiredCount > 0 ? '$expiredCount' : null,
                  badgeColor: AdminTheme.danger,
                ),
                _buildNavItem(
                  index: 6,
                  title: 'Blocked Accounts',
                  icon: Icons.person_off_outlined,
                  selectedIcon: Icons.person_off,
                  badgeText: blockedCount > 0 ? '$blockedCount' : null,
                  badgeColor: AdminTheme.warning,
                ),
                _buildNavItem(
                  index: 7,
                  title: 'Activity Logs',
                  icon: Icons.receipt_long_outlined,
                  selectedIcon: Icons.receipt_long,
                ),

                const SizedBox(height: 18),
                _buildSectionHeader('Tools & Settings'),
                _buildNavItem(
                  index: 8,
                  title: 'Device Simulator',
                  icon: Icons.phone_android_outlined,
                  selectedIcon: Icons.phone_android,
                  isHighlighted: true,
                ),
                _buildNavItem(
                  index: 9,
                  title: 'System Settings',
                  icon: Icons.settings_outlined,
                  selectedIcon: Icons.settings,
                ),
              ],
            ),
          ),

          // Admin User Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AdminTheme.borderColor)),
              color: Color(0xFF090E1A),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AdminTheme.primary.withValues(alpha: 0.2),
                  child: Text(
                    service.currentAdminName.substring(0, 2).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AdminTheme.primaryLight,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        service.currentAdminName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AdminTheme.textWhite,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        service.currentAdminRole == 'SUPER_ADMIN' ? 'Super Admin' : 'Staff Admin',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AdminTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, size: 18, color: AdminTheme.textMuted),
                  tooltip: 'Sign Out',
                  onPressed: () => service.logout(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: AdminTheme.textSubtle,
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String title,
    required IconData icon,
    required IconData selectedIcon,
    String? badgeText,
    Color badgeColor = AdminTheme.primary,
    bool isHighlighted = false,
  }) {
    final isSelected = selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () => onSelectIndex(index),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AdminTheme.primary
                : (isHighlighted ? AdminTheme.primary.withValues(alpha: 0.1) : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
            border: isHighlighted && !isSelected
                ? Border.all(color: AdminTheme.primary.withValues(alpha: 0.4))
                : null,
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? selectedIcon : icon,
                size: 19,
                color: isSelected
                    ? Colors.white
                    : (isHighlighted ? AdminTheme.primaryLight : AdminTheme.textMuted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isHighlighted ? AdminTheme.primaryLight : AdminTheme.textWhite),
                  ),
                ),
              ),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badgeText,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
