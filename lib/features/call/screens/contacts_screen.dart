import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/contact_provider.dart';
import '../models/contact_model.dart';
import '../services/trtc_service.dart';
import 'package:tencent_calls_uikit/tencent_calls_uikit.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthProvider>().user?.uid;
      if (uid != null) {
        context.read<ContactProvider>().listenContacts(uid);
      }
    });
  }

  void _showAddContactDialog() {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final contactProvider = ctx.watch<ContactProvider>();
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text('Add Contact',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: emailController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      hintText: 'Enter email address',
                      prefixIcon: Icon(Icons.email_outlined,
                          color: AppColors.textSecondary),
                    ),
                  ),
                  if (contactProvider.errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(contactProvider.errorMessage!,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 13)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    context.read<ContactProvider>().clearError();
                    Navigator.pop(ctx);
                  },
                  child: const Text('Cancel',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: contactProvider.isLoading
                      ? null
                      : () async {
                    final uid =
                        context.read<AuthProvider>().user?.uid;
                    if (uid == null) return;
                    final contact = await context
                        .read<ContactProvider>()
                        .searchUser(emailController.text.trim());
                    if (contact != null && ctx.mounted) {
                      await context
                          .read<ContactProvider>()
                          .addContact(uid, contact);
                      context.read<ContactProvider>().clearError();
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                          Text('${contact.displayName} added!'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size(80, 40)),
                  child: contactProvider.isLoading
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                      : const Text('Search & Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showGroupCallDialog() {
    final contacts = context.read<ContactProvider>().contacts;
    final selected = <String>{};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Group Call',
              style: TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: double.maxFinite,
            child: contacts.isEmpty
                ? const Text('No contacts available.',
                style: TextStyle(color: AppColors.textSecondary))
                : ListView(
              shrinkWrap: true,
              children: contacts.map((contact) {
                return CheckboxListTile(
                  value: selected.contains(contact.uid),
                  onChanged: (val) {
                    setDialogState(() {
                      if (val == true) {
                        selected.add(contact.uid);
                      } else {
                        selected.remove(contact.uid);
                      }
                    });
                  },
                  title: Text(contact.displayName,
                      style: const TextStyle(
                          color: AppColors.textPrimary)),
                  subtitle: Text(
                    contact.status == 'online'
                        ? 'Active now'
                        : 'Offline',
                    style: TextStyle(
                      color: contact.status == 'online'
                          ? AppColors.success
                          : AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  activeColor: AppColors.primary,
                  checkColor: Colors.white,
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: selected.isEmpty
                  ? null
                  : () async {
                Navigator.pop(ctx);
                final currentUser =
                    context.read<AuthProvider>().user;
                if (currentUser == null) return;
                await TRTCService.login(currentUser.uid);
                await TRTCService.groupCall(selected.toList());
              },
              style:
              ElevatedButton.styleFrom(minimumSize: const Size(80, 40)),
              child: Text('Call (${selected.length})'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRemoveContactDialog(ContactModel contact) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove Contact',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: Text('Remove ${contact.displayName} from contacts?',
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final uid = context.read<AuthProvider>().user?.uid;
              if (uid == null) return;
              await context
                  .read<ContactProvider>()
                  .removeContact(uid, contact.uid);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              minimumSize: const Size(80, 40),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showContactProfile(ContactModel contact) {
    Color statusColor;
    String statusText;
    switch (contact.status) {
      case 'online':
        statusColor = AppColors.success;
        statusText = 'Active now';
        break;
      case 'busy':
        statusColor = AppColors.warning;
        statusText = 'In a call';
        break;
      default:
        statusColor = AppColors.textSecondary;
        statusText = 'Offline';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Stack(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: Text(
                      contact.displayName.isNotEmpty
                          ? contact.displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      border:
                      Border.all(color: AppColors.surface, width: 3),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(contact.displayName,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(contact.email,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: statusColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(statusText,
                    style: TextStyle(color: statusColor, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final currentUser = context.read<AuthProvider>().user;
                  if (currentUser == null) return;
                  await TRTCService.login(currentUser.uid);
                  await TRTCService.call(contact.uid);
                },
                icon: const Icon(Icons.videocam_rounded),
                label: const Text('Video Call'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final contactProvider = context.watch<ContactProvider>();
    final user = auth.user;
    final contacts = contactProvider.contacts;
    final onlineContacts = contactProvider.onlineContacts;
    final uid = user?.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello, ${user?.displayName.split(' ').first ?? 'there'} 👋',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Who are you calling today?',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.person_add_rounded,
                                color: AppColors.primary, size: 20),
                            onPressed: _showAddContactDialog,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Quick Actions - hanya New Call dan Group Call
                    Row(
                      children: [
                        _buildQuickAction(
                          icon: Icons.videocam_rounded,
                          label: 'New Call',
                          gradient: [
                            AppColors.primary,
                            AppColors.primaryDark
                          ],
                          onTap: _showAddContactDialog,
                        ),
                        const SizedBox(width: 12),
                        _buildQuickAction(
                          icon: Icons.group_rounded,
                          label: 'Group Call',
                          gradient: const [
                            Color(0xFFFC466B),
                            Color(0xFF3F5EFB)
                          ],
                          onTap: _showGroupCallDialog,
                        ),
                      ],
                    ),
                    // Recent Calls
                    if (uid != null) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Recent Calls',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _RecentCalls(uid: uid),
                    ],
                    if (onlineContacts.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Online Now',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 90,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: onlineContacts.length,
                          itemBuilder: (context, index) =>
                              _buildOnlineAvatar(onlineContacts[index]),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'All Contacts',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${contacts.length} contacts',
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            if (contacts.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Column(
                    children: [
                      Icon(Icons.people_outline_rounded,
                          size: 64,
                          color: AppColors.textSecondary.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      const Text('No contacts yet',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 16)),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _showAddContactDialog,
                        icon: const Icon(Icons.person_add_rounded,
                            color: AppColors.primary),
                        label: const Text('Add Contact',
                            style: TextStyle(color: AppColors.primary)),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildContactTile(contacts[index]),
                  ),
                  childCount: contacts.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(height: 6),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOnlineAvatar(ContactModel contact) {
    return GestureDetector(
      onTap: () => _showContactProfile(contact),
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      contact.displayName.isNotEmpty
                          ? contact.displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.background, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              contact.displayName.split(' ').first,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactTile(ContactModel contact) {
    Color statusColor;
    String statusText;
    switch (contact.status) {
      case 'online':
        statusColor = AppColors.success;
        statusText = 'Active now';
        break;
      case 'busy':
        statusColor = AppColors.warning;
        statusText = 'In a call';
        break;
      default:
        statusColor = AppColors.textSecondary;
        statusText = 'Offline';
    }

    return GestureDetector(
      onTap: () => _showContactProfile(contact),
      onLongPress: () => _showRemoveContactDialog(contact),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      contact.displayName.isNotEmpty
                          ? contact.displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.background, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(contact.displayName,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(statusText,
                      style: TextStyle(
                          color: contact.status == 'online'
                              ? AppColors.success
                              : AppColors.textSecondary,
                          fontSize: 13)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.videocam_rounded,
                  color: AppColors.primary, size: 22),
              onPressed: () async {
                final currentUser = context.read<AuthProvider>().user;
                if (currentUser == null) return;
                await TRTCService.login(currentUser.uid);
                await TRTCService.call(contact.uid);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentCalls extends StatelessWidget {
  final String uid;
  const _RecentCalls({required this.uid});

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0:00';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final callerStream = FirebaseFirestore.instance
        .collection(AppConstants.colCallHistory)
        .where('callerId', isEqualTo: uid)
        .snapshots();

    final receiverStream = FirebaseFirestore.instance
        .collection(AppConstants.colCallHistory)
        .where('receiverId', isEqualTo: uid)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: callerStream,
      builder: (context, callerSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: receiverStream,
          builder: (context, receiverSnap) {
            if (callerSnap.connectionState == ConnectionState.waiting ||
                receiverSnap.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 60,
                child: Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2),
                ),
              );
            }

            final allDocs = [
              ...(callerSnap.data?.docs ?? []),
              ...(receiverSnap.data?.docs ?? []),
            ];

            final seen = <String>{};
            final uniqueDocs = allDocs.where((doc) => seen.add(doc.id)).toList();

            uniqueDocs.sort((a, b) {
              final aTime = (a.data() as Map)['startTime'] as Timestamp?;
              final bTime = (b.data() as Map)['startTime'] as Timestamp?;
              if (aTime == null || bTime == null) return 0;
              return bTime.compareTo(aTime);
            });

            final recent = uniqueDocs.take(3).toList();

            if (recent.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text('No recent calls',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ),
              );
            }

            return Column(
              children: recent.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final isOutgoing = data['callerId'] == uid;
                final name = isOutgoing
                    ? (data['receiverName'] ?? 'Unknown')
                    : (data['callerName'] ?? 'Unknown');
                final remoteUid = isOutgoing
                    ? (data['receiverId'] ?? '')
                    : (data['callerId'] ?? '');
                final status = data['status'] ?? 'completed';
                final duration = (data['duration'] as int?) ?? 0;
                final startTime =
                (data['startTime'] as Timestamp).toDate();

                Color statusColor;
                IconData statusIcon;
                String statusText;
                switch (status) {
                  case 'missed':
                    statusColor = AppColors.error;
                    statusIcon = Icons.call_missed_rounded;
                    statusText = 'Missed';
                    break;
                  case 'rejected':
                    statusColor = AppColors.warning;
                    statusIcon = Icons.call_end_rounded;
                    statusText = 'Declined';
                    break;
                  default:
                    statusColor = AppColors.success;
                    statusIcon = isOutgoing
                        ? Icons.call_made_rounded
                        : Icons.call_received_rounded;
                    statusText = _formatDuration(duration);
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryDark],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(statusIcon, size: 12, color: statusColor),
                                const SizedBox(width: 4),
                                Text(statusText,
                                    style: TextStyle(
                                        color: statusColor, fontSize: 12)),
                                const SizedBox(width: 6),
                                Text(
                                  '• ${DateFormat('MMM d, HH:mm').format(startTime)}',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.videocam_rounded,
                            color: AppColors.primary, size: 20),
                        onPressed: () async {
                          final currentUser =
                              context.read<AuthProvider>().user;
                          if (currentUser == null || remoteUid.isEmpty) return;
                          await TRTCService.login(currentUser.uid);
                          await TRTCService.call(remoteUid);
                        },
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}