import 'package:flutter/material.dart';

import '../../../../services/app_localizations.dart';
import '../../../../theme/app_theme.dart';

class DepartmentBadge extends StatelessWidget {
  final String code;
  final String? fullDeptName;
  final String? fullProdiName;

  const DepartmentBadge({
    super.key,
    required this.code,
    this.fullDeptName,
    this.fullProdiName,
  });

  @override
  Widget build(BuildContext context) {
    final parts = code.split('-');
    if (parts.length < 2) return const SizedBox.shrink();

    final dept = parts[0];
    final prodi = parts[1];
    final deptColor = _departmentColor(dept);
    final prodiColor = _programColor(prodi);

    return GestureDetector(
      onTap: () {
        if (fullDeptName != null && fullProdiName != null) {
          _showBadgeInfo(context, fullDeptName!, fullProdiName!);
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BadgePart(label: dept, color: deptColor),
          const SizedBox(width: 4),
          _BadgePart(label: prodi, color: prodiColor),
        ],
      ),
    );
  }

  Color _departmentColor(String dept) {
    final upper = dept.toUpperCase();
    if (upper == 'TE') return const Color(0xFF00008B);
    if (upper == 'TS') return const Color(0xFF5D4037);
    return Colors.primaries[dept.hashCode.abs() % Colors.primaries.length];
  }

  Color _programColor(String prodi) {
    if (prodi.toUpperCase() == 'BM') return Colors.orange;
    return Colors.primaries[prodi.hashCode.abs() % Colors.primaries.length];
  }

  void _showBadgeInfo(BuildContext context, String dept, String prodi) {
    final t = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (context) => FrostedAlertDialog(
        title: Text(t.translate('profile_academic_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.translate('profile_dept'),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            Text(dept, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            Text(
              t.translate('profile_prodi'),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            Text(prodi, style: const TextStyle(fontSize: 16)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              t.translate('general_cancel'),
              style: const TextStyle(color: SisapaTheme.blue),
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgePart extends StatelessWidget {
  final String label;
  final Color color;

  const _BadgePart({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
