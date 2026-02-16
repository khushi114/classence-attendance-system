import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendance_system/core/theme/app_colors.dart';
import 'package:attendance_system/features/auth/domain/entities/app_user.dart';

class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('User Management'),
          backgroundColor: AppColors.royalBlue,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Pending'),
              Tab(text: 'Verified'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_UserList(isVerified: false), _UserList(isVerified: true)],
        ),
      ),
    );
  }
}

class _UserList extends StatelessWidget {
  final bool isVerified;

  const _UserList({required this.isVerified});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Client-side filtering to handle missing 'isVerified' fields (legacy users)
        final allDocs = snapshot.data!.docs;
        final docs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final userVerified = data['isVerified'] == true;
          return userVerified == isVerified;
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isVerified
                      ? Icons.check_circle_outline
                      : Icons.pending_outlined,
                  size: 64,
                  color: AppColors.textLight.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  isVerified
                      ? 'No verified users found.'
                      : 'No pending requests.',
                  style: TextStyle(color: AppColors.textLight),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final user = AppUser.fromMap(data);

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isVerified
                      ? AppColors.emerald.withOpacity(0.1)
                      : AppColors.orange.withOpacity(0.1),
                  child: Icon(
                    isVerified ? Icons.check : Icons.person_outline,
                    color: isVerified ? AppColors.emerald : AppColors.orange,
                  ),
                ),
                title: Text(
                  user.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.email),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.royalBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        user.role.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.royalBlue,
                        ),
                      ),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isVerified) ...[
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.error),
                        onPressed: () => _rejectUser(context, user),
                        tooltip: 'Reject',
                      ),
                      IconButton(
                        icon: const Icon(Icons.check, color: AppColors.emerald),
                        onPressed: () => _verifyUser(context, user, true),
                        tooltip: 'Approve',
                      ),
                    ] else
                      IconButton(
                        icon: const Icon(Icons.block, color: AppColors.error),
                        onPressed: () => _verifyUser(context, user, false),
                        tooltip: 'Revoke Access',
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _verifyUser(
    BuildContext context,
    AppUser user,
    bool status,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.id).update({
        'isVerified': status,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status ? '${user.name} approved!' : '${user.name} revoked!',
            ),
            backgroundColor: status ? AppColors.success : AppColors.textPrimary,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _rejectUser(BuildContext context, AppUser user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject User?'),
        content: Text(
          'Are you sure you want to reject and delete ${user.name}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Build the delete operation
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.id)
            .delete();

        // Note: This only deletes the Firestore doc.
        // Firebase Auth user deletion requires Admin SDK or Cloud Function.
        // For this app scope, disabling access (deleting doc) is effectively a rejection.

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${user.name} rejected and removed.'),
              backgroundColor: AppColors.textPrimary,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}
