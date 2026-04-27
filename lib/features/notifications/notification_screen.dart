import 'package:flutter/material.dart';
import '../../core/models/notification.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/incident_service.dart';
import '../incidents/payment_screen.dart';
import 'package:intl/intl.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _service = NotificationService();
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final data = await _service.getNotifications();
    setState(() {
      _notifications = data.map((e) => NotificationModel.fromJson(e)).toList();
      _isLoading = false;
    });
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    if (notification.isRead) return;
    final success = await _service.markAsRead(notification.id);
    if (success) {
      _loadNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Notificaciones', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: cs.primary))
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              color: cs.primary,
              child: _notifications.isEmpty
                  ? _buildEmptyState(cs)
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final notification = _notifications[index];
                        return _NotificationCard(
                          notification: notification,
                          onTap: () {
                            _markAsRead(notification);
                            _handleNavigation(notification);
                          },
                        );
                      },
                    ),
            ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 80, color: cs.onSurface.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            'No tienes notificaciones',
            style: TextStyle(color: cs.onSurface.withOpacity(0.5), fontSize: 18),
          ),
        ],
      ),
    );
  }

  void _handleNavigation(NotificationModel notification) async {
    if (notification.incidentId != null) {
      if (notification.type == 'SERVICE_COMPLETED') {
        // Validación de pago para redirección inteligente
        final incident = await IncidentService().getIncident(notification.incidentId!);
        if (incident != null && incident.paymentStatus != 'completed') {
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => PaymentScreen(incident: incident)),
          );
          return;
        }
      }
      
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        '/incident-detail',
        arguments: notification.incidentId,
      );
    }
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const _NotificationCard({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isUnread = !notification.isRead;
    final isPaymentRequired = (notification.type == 'PAYMENT_PENDING' || notification.type == 'SERVICE_COMPLETED') && 
                               notification.paymentStatus != 'completed';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isUnread ? cs.primary.withOpacity(0.05) : cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnread ? cs.primary.withOpacity(0.2) : cs.outline.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: isUnread ? [
          BoxShadow(
            color: cs.primary.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ] : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLeadingIcon(notification.type, cs),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                color: cs.onSurface,
                                fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (isUnread)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: cs.error,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        style: TextStyle(
                          color: cs.onSurface.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('dd MMM, HH:mm').format(notification.sentAt),
                            style: TextStyle(
                              color: cs.onSurface.withOpacity(0.4),
                              fontSize: 12,
                            ),
                          ),
                          if (isPaymentRequired)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: cs.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.payment, size: 14, color: cs.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    'PAGAR',
                                    style: TextStyle(
                                      color: cs.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeadingIcon(String type, ColorScheme cs) {
    IconData icon;
    Color color;

    switch (type) {
      case 'SERVICE_COMPLETED':
      case 'PAYMENT_PENDING':
        icon = Icons.check_circle_outline;
        color = const Color(0xFF22C55E); // Success semantic color
        break;
      case 'ACCEPTED':
        icon = Icons.handyman_outlined;
        color = cs.primary;
        break;
      case 'REJECTED':
        icon = Icons.cancel_outlined;
        color = cs.error;
        break;
      default:
        icon = Icons.notifications_outlined;
        color = cs.primary;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}
