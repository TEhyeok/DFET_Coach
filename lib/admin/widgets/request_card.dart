import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/request_item.dart';
import '../../theme/admin_theme.dart';

class RequestCard extends StatelessWidget {
  final RequestItem request;
  final VoidCallback onTap;

  const RequestCard({
    super.key,
    required this.request,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final statusColor = _getStatusColor(request.status);
    final typeIcon = _getTypeIcon(request.type);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: AdminTheme.glassDecoration(
            color: isLight ? AdminTheme.surfaceLight : AdminTheme.surface,
            opacity: 0.6,
            isLight: isLight,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      request.status.name.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    DateFormat('MMM d, HH:mm').format(request.createdAt),
                    style: AdminTheme.bodyMedium.copyWith(
                      fontSize: 12,
                      color: isLight ? AdminTheme.textSecondaryLight : AdminTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AdminTheme.primary.withOpacity(0.2),
                    backgroundImage: request.userPhotoUrl != null
                        ? NetworkImage(request.userPhotoUrl!)
                        : null,
                    child: request.userPhotoUrl == null
                        ? Text(
                            request.userName.isNotEmpty
                                ? request.userName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: AdminTheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      request.userName,
                      style: AdminTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isLight ? AdminTheme.textPrimaryLight : AdminTheme.textWhite,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(typeIcon, size: 16, color: AdminTheme.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      request.title,
                      style: AdminTheme.titleMedium.copyWith(
                        fontSize: 14,
                        color: isLight ? AdminTheme.textPrimaryLight : AdminTheme.textWhite,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                request.description,
                style: AdminTheme.bodyMedium.copyWith(
                  color: isLight ? AdminTheme.textSecondaryLight : AdminTheme.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(RequestStatus status) {
    switch (status) {
      case RequestStatus.newRequest:
        return AdminTheme.error;
      case RequestStatus.inProgress:
        return AdminTheme.warning;
      case RequestStatus.completed:
        return AdminTheme.success;
      case RequestStatus.rejected:
        return AdminTheme.textDisabled;
    }
  }

  IconData _getTypeIcon(RequestType type) {
    switch (type) {
      case RequestType.postureCheck:
        return Icons.accessibility_new_rounded;
      case RequestType.dietFeedback:
        return Icons.restaurant_rounded;
      case RequestType.generalInquiry:
        return Icons.help_outline_rounded;
    }
  }
}
