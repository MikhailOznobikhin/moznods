import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/dio_client.dart';
import '../api/ws_service.dart';
import '../models/message.dart';
import '../models/user.dart';

class ChatState {
  final List<Message> messages;
  final bool isLoading;
  final String? error;
  final bool isConnected;
  final Map<int, bool> typingUsers;
  final Message? replyingTo;
  final Message? editingMessage;

  ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
    this.isConnected = false,
    this.typingUsers = const {},
    this.replyingTo,
    this.editingMessage,
  });

  ChatState copyWith({
    List<Message>? messages,
    bool? isLoading,
    String? error,
    bool? isConnected,
    Map<int, bool>? typingUsers,
    Message? replyingTo,
    Message? editingMessage,
    bool clearReplyingTo = false,
    bool clearEditingMessage = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isConnected: isConnected ?? this.isConnected,
      typingUsers: typingUsers ?? this.typingUsers,
      replyingTo: clearReplyingTo ? null : (replyingTo ?? this.replyingTo),
      editingMessage: clearEditingMessage
          ? null
          : (editingMessage ?? this.editingMessage),
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final DioClient _client = DioClient();
  final WebSocketService _wsService = WebSocketService();
  int? _currentRoomId;

  ChatNotifier() : super(ChatState());

  Future<void> fetchMessages(int roomId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _client.dio.get('/api/chat/$roomId/messages/');
      final dynamic data = response.data;
      List results;
      if (data is List) {
        results = data;
      } else {
        results = data['results'] ?? [];
      }

      final messages = results
          .map((m) => Message.fromJson(m))
          .toList()
          .reversed
          .toList();
      state = state.copyWith(messages: messages, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void connect(int roomId, String token) {
    _currentRoomId = roomId;
    _wsService.disconnect();
    final url = 'ws://localhost:8000/ws/chat/$roomId';
    _wsService.connect(url, token);

    _wsService.messages.listen((message) {
      final type = message['type'];
      final data = message['data'];

      if (type == 'chat_message') {
        final newMessage = Message.fromJson(data);
        state = state.copyWith(messages: [...state.messages, newMessage]);
      } else if (type == 'message_read') {
        final int messageId = data['message_id'];
        final int userId = data['user_id'];

        state = state.copyWith(
          messages: state.messages.map((m) {
            if (m.id == messageId) {
              final updatedReadBy = List<int>.from(m.readByIds ?? []);
              if (!updatedReadBy.contains(userId)) {
                updatedReadBy.add(userId);
              }
            }
            return m;
          }).toList(),
        );
      } else if (type == 'typing') {
        final int userId = data['user_id'];
        final bool isTyping = data['is_typing'] ?? false;
        final newTypingUsers = Map<int, bool>.from(state.typingUsers);
        if (isTyping) {
          newTypingUsers[userId] = true;
        } else {
          newTypingUsers.remove(userId);
        }
        state = state.copyWith(typingUsers: newTypingUsers);
      } else if (type == 'error') {
        state = state.copyWith(error: message['detail']);
      }
    });

    state = state.copyWith(isConnected: true);
  }

  void sendMessage(String content, {List<int>? attachmentIds, int? replyToId}) {
    _wsService.sendMessage({
      'type': 'chat_message',
      'data': {
        'content': content,
        'attachment_ids': attachmentIds,
        'reply_to': replyToId,
      },
    });
  }

  void setTyping(bool isTyping) {
    if (_currentRoomId == null) return;
    _wsService.sendMessage({
      'type': 'typing',
      'data': {'is_typing': isTyping},
    });
  }

  void addReaction(int messageId, String emoji) {
    _wsService.sendMessage({
      'type': 'reaction',
      'data': {'message_id': messageId, 'emoji': emoji},
    });
  }

  void setReplyingTo(Message? message) {
    if (message != null) {
      state = state.copyWith(replyingTo: message, clearEditingMessage: true);
    } else {
      state = state.copyWith(clearReplyingTo: true);
    }
  }

  void setEditingMessage(Message? message) {
    if (message != null) {
      state = state.copyWith(editingMessage: message, clearReplyingTo: true);
    } else {
      state = state.copyWith(clearEditingMessage: true);
    }
  }

  void editMessage(int messageId, String newContent) {
    _wsService.sendMessage({
      'type': 'edit_message',
      'data': {'message_id': messageId, 'content': newContent},
    });
    state = state.copyWith(
      messages: state.messages.map((m) {
        if (m.id == messageId) {
          return Message(
            id: m.id,
            room: m.room,
            author: m.author,
            content: newContent,
            attachments: m.attachments,
            createdAt: m.createdAt,
            readByIds: m.readByIds,
          );
        }
        return m;
      }).toList(),
      clearEditingMessage: true,
    );
  }

  void deleteMessage(int messageId) async {
    try {
      await _client.dio.delete('/api/chat/messages/$messageId/');
      state = state.copyWith(
        messages: state.messages.where((m) => m.id != messageId).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void disconnect() {
    _wsService.disconnect();
    _currentRoomId = null;
    state = state.copyWith(isConnected: false, typingUsers: {});
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier();
});
