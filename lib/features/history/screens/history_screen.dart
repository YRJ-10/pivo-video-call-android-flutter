import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/providers/auth_provider.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0:00';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().user?.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Call History',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search calls...',
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppColors.textSecondary),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear_rounded,
                            color: AppColors.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (uid != null)
              Expanded(
                child: _HistoryList(
                  uid: uid,
                  searchQuery: _searchQuery,
                  formatDuration: _formatDuration,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  final String uid;
  final String searchQuery;
  final String Function(int) formatDuration;

  const _HistoryList({
    required this.uid,
    required this.searchQuery,
    required this.formatDuration,
  });

  void _showDeleteDialog(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete History',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: const Text('Remove this call from history?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection(AppConstants.colCallHistory)
                  .doc(docId)
                  .delete();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              minimumSize: const Size(80, 40),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
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
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            final allDocs = [
              ...(callerSnap.data?.docs ?? []),
              ...(receiverSnap.data?.docs ?? []),
            ];

            final seen = <String>{};
            final uniqueDocs =
            allDocs.where((doc) => seen.add(doc.id)).toList();

            uniqueDocs.sort((a, b) {
              final aTime = (a.data() as Map)['startTime'] as Timestamp?;
              final bTime = (b.data() as Map)['startTime'] as Timestamp?;
              if (aTime == null || bTime == null) return 0;
              return bTime.compareTo(aTime);
            });

            final filtered = uniqueDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final name = uid == data['callerId']
                  ? (data['receiverName'] ?? '')
                  : (data['callerName'] ?? '');
              return searchQuery.isEmpty ||
                  name.toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();

            if (filtered.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history_rounded,
                        size: 64,
                        color: AppColors.textSecondary.withOpacity(0.3)),
                    const SizedBox(height: 16),
                    const Text('No call history yet',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 16)),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final doc = filtered[index];
                final data = doc.data() as Map<String, dynamic>;
                final isOutgoing = data['callerId'] == uid;
                final name = isOutgoing
                    ? (data['receiverName'] ?? 'Unknown')
                    : (data['callerName'] ?? 'Unknown');
                final status = data['status'] ?? 'completed';
                final duration = (data['duration'] as int?) ?? 0;
                final startTime =
                (data['startTime'] as Timestamp).toDate();

                return GestureDetector(
                  onLongPress: () => _showDeleteDialog(context, doc.id),
                  child: _HistoryTile(
                    name: name,
                    status: status,
                    durationText: formatDuration(duration),
                    isOutgoing: isOutgoing,
                    time: startTime,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final String name;
  final String status;
  final String durationText;
  final bool isOutgoing;
  final DateTime time;

  const _HistoryTile({
    required this.name,
    required this.status,
    required this.durationText,
    required this.isOutgoing,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
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
        statusText = durationText;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
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
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(statusText,
                        style: TextStyle(color: statusColor, fontSize: 13)),
                    const SizedBox(width: 8),
                    Text(
                      '• ${DateFormat('MMM d, HH:mm').format(time)}',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.videocam_rounded,
              color: AppColors.primary, size: 22),
        ],
      ),
    );
  }
}