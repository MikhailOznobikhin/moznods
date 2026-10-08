import 'package:flutter/material.dart';

import '../../api/dio_client.dart';
import '../../models/room.dart';
import '../../models/user.dart';

const _palette = [
  Color(0xFF5865F2),
  Color(0xFF3BA55C),
  Color(0xFFFAA61A),
  Color(0xFFED4245),
  Color(0xFFEB459E),
  Color(0xFF9B59B6),
  Color(0xFF1ABC9C),
  Color(0xFF607D8B),
];

Color colorForId(int id) => _palette[id.abs() % _palette.length];

/// Media URLs come relative when serialized without a request (socket events).
String? absoluteMediaUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('http')) return url;
  return '${DioClient.baseUrl}${url.startsWith('/') ? '' : '/'}$url';
}

String _initial(String text) {
  final trimmed = text.trim();
  return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
}

class _InitialAvatar extends StatelessWidget {
  final String label;
  final Color color;
  final double radius;
  final String? imageUrl;
  final IconData? icon;

  const _InitialAvatar({
    required this.label,
    required this.color,
    required this.radius,
    this.imageUrl,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final url = absoluteMediaUrl(imageUrl);
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      foregroundImage: url != null ? NetworkImage(url) : null,
      child: icon != null
          ? Icon(icon, color: Colors.white, size: radius)
          : Text(
              _initial(label),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: radius * 0.85,
              ),
            ),
    );
  }
}

class UserAvatar extends StatelessWidget {
  final User? user;
  final double radius;

  const UserAvatar({super.key, required this.user, this.radius = 18});

  @override
  Widget build(BuildContext context) {
    final u = user;
    return _InitialAvatar(
      label: u == null ? '?' : (u.displayName.isNotEmpty ? u.displayName : u.username),
      color: u == null ? const Color(0xFF4E5058) : colorForId(u.id),
      radius: radius,
      imageUrl: u?.avatarUrl,
    );
  }
}

class RoomAvatar extends StatelessWidget {
  final Room room;
  final double radius;

  const RoomAvatar({super.key, required this.room, this.radius = 18});

  @override
  Widget build(BuildContext context) {
    if (room.isDirect && room.peer != null) {
      return UserAvatar(user: room.peer, radius: radius);
    }
    return _InitialAvatar(
      label: room.displayTitle,
      color: colorForId(room.id),
      radius: radius,
      imageUrl: room.avatar,
      icon: room.isChannel && (room.avatar == null || room.avatar!.isEmpty) ? Icons.campaign : null,
    );
  }
}
