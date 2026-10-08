import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/dio_client.dart';
import '../api/ws_service.dart';
import '../models/message.dart';

const _pageSize = 50;
const _typingTimeout = Duration(seconds: 6);

class ChatState {
  final int? roomId;

  /// Oldest first.
  final List<Message> messages;
  final bool isLoading;
  final bool isLoadingOlder;
  final bool hasMore;
  final String? error;
  final bool isConnected;

  /// userId -> display name of people currently typing.
  final Map<int, String> typingUsers;
  final Message? replyingTo;
  final Message? editingMessage;

  ChatState({
    this.roomId,
    this.messages = const [],
    this.isLoading = false,
    this.isLoadingOlder = false,
    this.hasMore = false,
    this.error,
    this.isConnected = false,
    this.typingUsers = const {},
    this.replyingTo,
    this.editingMessage,
  });

  /// [error] is not carried over: a copy clears a stale error unless one is passed.
  ChatState copyWith({
    int? roomId,
    List<Message>? messages,
    bool? isLoading,
    bool? isLoadingOlder,
    bool? hasMore,
    String? error,
    bool? isConnected,
    Map<int, String>? typingUsers,
    Message? replyingTo,
    Message? editingMessage,
    bool clearReplyingTo = false,
    bool clearEditingMessage = false,
  }) {
    return ChatState(
      roomId: roomId ?? this.roomId,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      isConnected: isConnected ?? this.isConnected,
      typingUsers: typingUsers ?? this.typingUsers,
      replyingTo: clearReplyingTo ? null : (replyingTo ?? this.replyingTo),
      editingMessage:
          clearEditingMessage ? null : (editingMessage ?? this.editingMessage),
    );
  }
}

/// Human-readable message from a DRF error response.
String describeError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data.isNotEmpty) {
      final first = data.values.first;
      if (first is List && first.isNotEmpty) return first.first.toString();
      return first.toString();
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return 'No connection';
    }
    return error.message ?? error.toString();
  }
  return error.toString();
}

class ChatNotifier extends StateNotifier<ChatState> {
  final DioClient _client = DioClient();
  final WebSocketService _wsService = WebSocketService();
  StreamSubscription<Map<String, dynamic>>? _messagesSubscription;
  final Map<int, Timer> _typingTimers = {};
  Timer? _markReadTimer;
  bool _typingSent = false;

  ChatNotifier() : super(ChatState());

  String _messagesUrl(int roomId) => '/api/rooms/$roomId/messages/';

  /// Load the latest messages of [roomId] and subscribe to its live events.
  Future<void> openRoom(int roomId, String token) async {
    if (state.roomId == roomId && _wsService.isConnected) return;
    disconnect();
    state = ChatState(roomId: roomId, isLoading: true);
    _connect(roomId, token);
    await _loadLatest(roomId);
  }

  Future<void> _loadLatest(int roomId) async {
    try {
      final response = await _client.dio.get(
        _messagesUrl(roomId),
        queryParameters: {'page_size': _pageSize},
      );
      if (state.roomId != roomId) return;
      final page = _parsePage(response.data);
      state = state.copyWith(
        messages: _merge(state.messages, page.messages),
        isLoading: false,
        hasMore: page.hasMore,
      );
      _scheduleMarkRead();
    } catch (e) {
      if (state.roomId != roomId) return;
      state = state.copyWith(isLoading: false, error: describeError(e));
    }
  }

  Future<void> loadOlder() async {
    final roomId = state.roomId;
    if (roomId == null || state.isLoadingOlder || !state.hasMore || state.messages.isEmpty) {
      return;
    }
    state = state.copyWith(isLoadingOlder: true);
    try {
      final response = await _client.dio.get(
        _messagesUrl(roomId),
        queryParameters: {'page_size': _pageSize, 'before': state.messages.first.id},
      );
      if (state.roomId != roomId) return;
      final page = _parsePage(response.data);
      state = state.copyWith(
        messages: _merge(state.messages, page.messages),
        isLoadingOlder: false,
        hasMore: page.hasMore,
      );
    } catch (e) {
      state = state.copyWith(isLoadingOlder: false, error: describeError(e));
    }
  }

  ({List<Message> messages, bool hasMore}) _parsePage(dynamic data) {
    final List results = data is List ? data : (data['results'] ?? []);
    final hasMore = data is Map && data['next'] != null;
    return (
      messages: results.map((m) => Message.fromJson(m as Map<String, dynamic>)).toList(),
      hasMore: hasMore,
    );
  }

  /// Union by id (incoming wins), sorted oldest first.
  List<Message> _merge(List<Message> current, Iterable<Message> incoming) {
    final byId = {for (final m in current) m.id: m};
    for (final m in incoming) {
      byId[m.id] = m;
    }
    final merged = byId.values.toList()
      ..sort((a, b) {
        final c = a.createdAt.compareTo(b.createdAt);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    return merged;
  }

  void _connect(int roomId, String token) {
    var hasConnectedBefore = false;
    _wsService.connect(
      '${DioClient.wsBaseUrl}/ws/chat/$roomId/',
      token,
      onConnected: () {
        state = state.copyWith(isConnected: true);
        // Events are not replayed: catch up on what we missed while offline.
        if (hasConnectedBefore && state.roomId == roomId) _loadLatest(roomId);
        hasConnectedBefore = true;
      },
      onDone: () => state = state.copyWith(isConnected: false),
    );
    _messagesSubscription?.cancel();
    _messagesSubscription = _wsService.messages.listen(_handleEvent);
  }

  void _handleEvent(Map<String, dynamic> event) {
    final type = event['type'];
    final data = event['data'];
    switch (type) {
      case 'message_created':
      case 'message_updated':
        final message = Message.fromJson(Map<String, dynamic>.from(data as Map));
        if (message.room != state.roomId) return;
        _clearTyping(message.author.id);
        state = state.copyWith(messages: _merge(state.messages, [message]));
        if (type == 'message_created') _scheduleMarkRead();
      case 'messages_read':
        final userId = data['user_id'] as int;
        final ids = (data['message_ids'] as List).cast<int>().toSet();
        state = state.copyWith(
          messages: [
            for (final m in state.messages)
              ids.contains(m.id) && !m.readByIds.contains(userId)
                  ? m.copyWith(readByIds: [...m.readByIds, userId])
                  : m,
          ],
        );
      case 'typing':
        final userId = data['user_id'] as int;
        if (data['is_typing'] == true) {
          state = state.copyWith(
            typingUsers: {...state.typingUsers, userId: (data['display_name'] ?? '') as String},
          );
          _typingTimers[userId]?.cancel();
          _typingTimers[userId] = Timer(_typingTimeout, () => _clearTyping(userId));
        } else {
          _clearTyping(userId);
        }
      case 'error':
        final detail = event['detail'];
        state = state.copyWith(error: detail is List ? detail.join(' ') : '$detail');
    }
  }

  void _clearTyping(int userId) {
    _typingTimers.remove(userId)?.cancel();
    if (!state.typingUsers.containsKey(userId)) return;
    state = state.copyWith(typingUsers: {...state.typingUsers}..remove(userId));
  }

  /// Tell the server we have seen everything up to the newest message (debounced).
  void _scheduleMarkRead() {
    _markReadTimer?.cancel();
    _markReadTimer = Timer(const Duration(milliseconds: 600), () {
      if (state.messages.isEmpty) return;
      _wsService.sendMessage({
        'type': 'mark_read',
        'data': {'message_id': state.messages.last.id},
      });
    });
  }

  /// Sends over REST (works while the socket reconnects, returns real errors);
  /// the broadcast copy is de-duplicated by id.
  Future<bool> sendMessage(String content, {List<int>? attachmentIds}) async {
    final roomId = state.roomId;
    if (roomId == null) return false;
    final replyTo = state.replyingTo;
    state = state.copyWith(clearReplyingTo: true);
    setTyping(false);
    try {
      final response = await _client.dio.post(
        _messagesUrl(roomId),
        data: {
          'content': content,
          'attachment_ids': attachmentIds ?? <int>[],
          if (replyTo != null) 'reply_to': replyTo.id,
        },
      );
      final message = Message.fromJson(response.data as Map<String, dynamic>);
      if (state.roomId == roomId) {
        state = state.copyWith(messages: _merge(state.messages, [message]));
      }
      return true;
    } catch (e) {
      state = state.copyWith(error: describeError(e), replyingTo: replyTo);
      return false;
    }
  }

  Future<bool> editMessage(int messageId, String newContent) async {
    final roomId = state.roomId;
    if (roomId == null) return false;
    try {
      final response = await _client.dio.patch(
        '${_messagesUrl(roomId)}$messageId/',
        data: {'content': newContent},
      );
      final message = Message.fromJson(response.data as Map<String, dynamic>);
      state = state.copyWith(
        messages: _merge(state.messages, [message]),
        clearEditingMessage: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: describeError(e));
      return false;
    }
  }

  Future<void> deleteMessage(int messageId) async {
    final roomId = state.roomId;
    if (roomId == null) return;
    try {
      await _client.dio.delete('${_messagesUrl(roomId)}$messageId/');
      state = state.copyWith(
        messages: [
          for (final m in state.messages) m.id == messageId ? m.deletedCopy() : m,
        ],
      );
    } catch (e) {
      state = state.copyWith(error: describeError(e));
    }
  }

  Future<void> toggleReaction(int messageId, String emoji) async {
    final roomId = state.roomId;
    if (roomId == null) return;
    try {
      final response = await _client.dio.post(
        '${_messagesUrl(roomId)}$messageId/reactions/',
        data: {'emoji': emoji},
      );
      final message = Message.fromJson(response.data as Map<String, dynamic>);
      state = state.copyWith(messages: _merge(state.messages, [message]));
    } catch (e) {
      state = state.copyWith(error: describeError(e));
    }
  }

  void setTyping(bool isTyping) {
    if (state.roomId == null || isTyping == _typingSent && !isTyping) return;
    _typingSent = isTyping;
    _wsService.sendMessage({
      'type': 'typing',
      'data': {'is_typing': isTyping},
    });
  }

  void setReplyingTo(Message? message) {
    state = message == null
        ? state.copyWith(clearReplyingTo: true)
        : state.copyWith(replyingTo: message, clearEditingMessage: true);
  }

  void setEditingMessage(Message? message) {
    state = message == null
        ? state.copyWith(clearEditingMessage: true)
        : state.copyWith(editingMessage: message, clearReplyingTo: true);
  }

  void clearError() => state = state.copyWith();

  void disconnect() {
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
    _markReadTimer?.cancel();
    for (final timer in _typingTimers.values) {
      timer.cancel();
    }
    _typingTimers.clear();
    _typingSent = false;
    _wsService.disconnect();
    state = ChatState();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier();
});
