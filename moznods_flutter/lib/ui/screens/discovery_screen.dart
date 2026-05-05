import 'dart:async';
import 'package:flutter/material.dart';
import 'package:moznods_flutter/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../store/room_provider.dart';
import 'dashboard_layout.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final _searchController = TextEditingController();
  String _filter = 'all';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(roomProvider.notifier).fetchPublicRooms();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _queueFetch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(roomProvider.notifier).fetchPublicRooms(
        search: _searchController.text,
        isChannel: _filter == 'all' ? null : _filter == 'channels',
      );
    });
  }

  Future<void> _joinByUsername(String username) async {
    final room = await ref.read(roomProvider.notifier).joinRoomByUsername(username);
    if (!mounted) {
      return;
    }
    context.go('/room/${room.id}');
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(roomProvider);
    final isMobile = MediaQuery.of(context).size.width < 768;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      drawer: isMobile ? const Drawer(child: Sidebar()) : null,
      body: Row(
        children: [
          if (!isMobile) const Sidebar(),
          Expanded(
            child: Container(
              color: const Color(0xFF313338),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFF1E1F22))),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.public, color: Color(0xFFB5BAC1)),
                            const SizedBox(width: 8),
                            Text(
                              l10n.discover,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _searchController,
                          onChanged: (_) => _queueFetch(),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: l10n.searchPublicRooms,
                            hintStyle: const TextStyle(color: Color(0xFF80848E)),
                            prefixIcon: const Icon(Icons.search, color: Color(0xFF80848E)),
                            filled: true,
                            fillColor: const Color(0xFF383A40),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _FilterChip(
                              selected: _filter == 'all',
                              label: l10n.filterAll,
                              onTap: () {
                                setState(() => _filter = 'all');
                                _queueFetch();
                              },
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              selected: _filter == 'rooms',
                              label: l10n.filterRooms,
                              onTap: () {
                                setState(() => _filter = 'rooms');
                                _queueFetch();
                              },
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              selected: _filter == 'channels',
                              label: l10n.filterChannels,
                              onTap: () {
                                setState(() => _filter = 'channels');
                                _queueFetch();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: roomState.publicRooms.isEmpty
                        ? Center(
                            child: Text(
                              l10n.noPublicRoomsFound,
                              style: const TextStyle(color: Color(0xFF80848E)),
                            ),
                          )
                        : ListView.builder(
                            itemCount: roomState.publicRooms.length,
                            itemBuilder: (context, index) {
                              final room = roomState.publicRooms[index];
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2B2D31),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: const Color(0xFF5865F2),
                                      child: Icon(
                                        room.isChannel ? Icons.tag : Icons.forum,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            room.name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '@${room.username ?? ""}',
                                            style: const TextStyle(
                                              color: Color(0xFF80848E),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: room.username == null
                                          ? null
                                          : () => _joinByUsername(room.username!),
                                      child: Text(l10n.join),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final bool selected;
  final String label;
  final VoidCallback onTap;

  const _FilterChip({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF5865F2) : const Color(0xFF383A40),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }
}
