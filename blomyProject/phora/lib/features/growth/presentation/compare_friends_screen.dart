import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:phora/features/growth/domain/growth_models.dart';
import 'package:phora/features/growth/growth_providers.dart';

class CompareFriendsScreen extends ConsumerStatefulWidget {
  const CompareFriendsScreen({super.key});

  @override
  ConsumerState<CompareFriendsScreen> createState() =>
      _CompareFriendsScreenState();
}

class _CompareFriendsScreenState extends ConsumerState<CompareFriendsScreen> {
  final _emailController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final networkAsync = ref.watch(friendNetworkProvider);
    final dims = context.dims;
    return Scaffold(
      appBar: AppBar(title: const Text('Compare with friends')),
      body: networkAsync.when(
        data:
            (network) => RefreshIndicator(
              onRefresh:
                  () => ref.read(friendNetworkProvider.notifier).refresh(),
              child: ListView(
                padding: EdgeInsets.all(dims.scaleSpace(20)),
                children: [
                  Text(
                    'Compare only summary-level patterns. Exact dates and sensitive logs stay private.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  SizedBox(height: dims.scaleSpace(16)),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Friend email',
                            hintText: 'name@example.com',
                          ),
                        ),
                      ),
                      SizedBox(width: dims.scaleSpace(12)),
                      FilledButton(
                        onPressed: _submitting ? null : _sendRequest,
                        child: Text(_submitting ? 'Sending…' : 'Add'),
                      ),
                    ],
                  ),
                  SizedBox(height: dims.scaleSpace(24)),
                  _NetworkSection(
                    title: 'Friends',
                    emptyLabel: 'No friends yet',
                    children: [
                      for (final friend in network.friends)
                        _FriendTile(
                          connection: friend,
                          onToggleCompare:
                              (enabled) => ref
                                  .read(friendNetworkProvider.notifier)
                                  .setComparisonPermission(
                                    friendId: friend.friend.id,
                                    enabled: enabled,
                                  ),
                          onViewComparison:
                              () => context.push(
                                '/growth/compare/${friend.friend.id}',
                              ),
                        ),
                    ],
                  ),
                  SizedBox(height: dims.scaleSpace(20)),
                  _NetworkSection(
                    title: 'Incoming requests',
                    emptyLabel: 'No incoming requests',
                    children: [
                      for (final request in network.incomingRequests)
                        _RequestTile(
                          connection: request,
                          onAccept:
                              () => ref
                                  .read(friendNetworkProvider.notifier)
                                  .acceptRequest(request.id),
                          onDecline:
                              () => ref
                                  .read(friendNetworkProvider.notifier)
                                  .declineRequest(request.id),
                        ),
                    ],
                  ),
                  SizedBox(height: dims.scaleSpace(20)),
                  _NetworkSection(
                    title: 'Sent requests',
                    emptyLabel: 'No pending requests',
                    children: [
                      for (final request in network.outgoingRequests)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(request.friend.displayName),
                          subtitle: const Text('Waiting for them to accept'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
      ),
    );
  }

  Future<void> _sendRequest() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    setState(() => _submitting = true);
    try {
      await ref.read(friendNetworkProvider.notifier).sendRequest(email);
      _emailController.clear();
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}

class FriendComparisonDetailScreen extends ConsumerWidget {
  const FriendComparisonDetailScreen({super.key, required this.friendId});

  final String friendId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comparisonAsync = ref.watch(comparisonSummaryProvider(friendId));
    final dims = context.dims;
    final colors = context.phora.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Comparison summary')),
      body: comparisonAsync.when(
        data:
            (comparison) => ListView(
              padding: EdgeInsets.all(dims.scaleSpace(20)),
              children: [
                Text(
                  comparison.headline,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: dims.scaleSpace(8)),
                Text(comparison.summary),
                SizedBox(height: dims.scaleSpace(16)),
                Container(
                  padding: EdgeInsets.all(dims.scaleSpace(16)),
                  decoration: BoxDecoration(
                    color: colors.bgCard,
                    borderRadius: BorderRadius.circular(dims.scaleRadius(20)),
                    border: Border.all(color: colors.border),
                  ),
                  child: Text(comparison.safeNotice),
                ),
                SizedBox(height: dims.scaleSpace(20)),
                for (final metric in comparison.metrics)
                  _MetricCard(metric: metric),
                if (comparison.similarities.isNotEmpty) ...[
                  SizedBox(height: dims.scaleSpace(20)),
                  const Text(
                    'Similarities',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: dims.scaleSpace(10)),
                  for (final item in comparison.similarities)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.check_circle_outline),
                      title: Text(item),
                    ),
                ],
                if (comparison.differences.isNotEmpty) ...[
                  SizedBox(height: dims.scaleSpace(16)),
                  const Text(
                    'Differences',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: dims.scaleSpace(10)),
                  for (final item in comparison.differences)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.compare_arrows_rounded),
                      title: Text(item),
                    ),
                ],
              ],
            ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final ComparisonMetricModel metric;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    return Container(
      margin: EdgeInsets.only(bottom: dims.scaleSpace(12)),
      padding: EdgeInsets.all(dims.scaleSpace(16)),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(dims.scaleRadius(20)),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric.label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: dims.scaleSpace(10)),
          Text('You: ${metric.mine}'),
          Text('Friend: ${metric.friend}'),
          SizedBox(height: dims.scaleSpace(8)),
          Text(metric.summary),
        ],
      ),
    );
  }
}

class _NetworkSection extends StatelessWidget {
  const _NetworkSection({
    required this.title,
    required this.emptyLabel,
    required this.children,
  });

  final String title;
  final String emptyLabel;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (children.isEmpty)
          Text(emptyLabel, style: Theme.of(context).textTheme.bodyMedium)
        else
          ...children,
      ],
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({
    required this.connection,
    required this.onToggleCompare,
    required this.onViewComparison,
  });

  final FriendConnectionModel connection;
  final ValueChanged<bool> onToggleCompare;
  final VoidCallback onViewComparison;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        connection.friend.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        connection.comparePermissionGrantedByFriend
                            ? 'They are sharing comparison summaries.'
                            : 'Waiting for their comparison permission.',
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: connection.comparePermissionGrantedByMe,
                  onChanged: onToggleCompare,
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: connection.compareEnabled ? onViewComparison : null,
                child: const Text('View comparison'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.connection,
    required this.onAccept,
    required this.onDecline,
  });

  final FriendConnectionModel connection;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(connection.friend.displayName),
        subtitle: const Text('Wants to compare summary patterns with you'),
        trailing: Wrap(
          spacing: 8,
          children: [
            TextButton(onPressed: onDecline, child: const Text('Decline')),
            FilledButton(onPressed: onAccept, child: const Text('Accept')),
          ],
        ),
      ),
    );
  }
}
