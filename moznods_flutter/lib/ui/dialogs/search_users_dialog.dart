import 'package:flutter/material.dart';
import 'package:moznods_flutter/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/dio_client.dart';
import '../../models/user.dart';

class SearchUsersDialog extends ConsumerStatefulWidget {
  final Function(User) onUserSelected;

  const SearchUsersDialog({super.key, required this.onUserSelected});

  @override
  ConsumerState<SearchUsersDialog> createState() => _SearchUsersDialogState();
}

class _SearchUsersDialogState extends ConsumerState<SearchUsersDialog> {
  final _searchController = TextEditingController();
  final _dioClient = DioClient();
  List<User> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await _dioClient.dio.get(
        '/api/auth/search/',
        queryParameters: {'q': query},
      );
      final dynamic data = response.data;
      final List results = data is List
          ? data
          : (data is Map && data['results'] is List ? data['results'] as List : <dynamic>[]);
      setState(() {
        _searchResults = results.map((u) => User.fromJson(u)).toList();
        _isLoading = false;
        _hasSearched = true;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasSearched = true;
        _searchResults = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: const Color(0xFF2B2D31),
      title: Text(l10n.addMembers, style: const TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 300,
        height: 300,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: l10n.searchUsersHint,
                hintStyle: const TextStyle(color: Color(0xFF80848E)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF80848E)),
                filled: true,
                fillColor: const Color(0xFF1E1F22),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _searchUsers,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF5865F2)),
                    )
                  : _searchResults.isEmpty
                      ? Center(
                          child: Text(
                            _hasSearched ? l10n.noUsersFound : l10n.startTypingToSearch,
                            style: const TextStyle(color: Color(0xFF80848E)),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final user = _searchResults[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF5865F2),
                                child: Text(
                                  user.username[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(
                                user.displayName,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                '@${user.username}',
                                style: const TextStyle(color: Color(0xFF80848E)),
                              ),
                              onTap: () {
                                widget.onUserSelected(user);
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel, style: const TextStyle(color: Color(0xFFB5BAC1))),
        ),
      ],
    );
  }
}

void showSearchUsersDialog(BuildContext context, Function(User) onUserSelected) {
  showDialog(
    context: context,
    builder: (context) => SearchUsersDialog(onUserSelected: onUserSelected),
  );
}
