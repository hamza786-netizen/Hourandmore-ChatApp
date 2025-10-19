class Message {
  final int? id;
  final String? firebaseId;
  final String text;
  final String senderId;
  final String senderEmail;
  final String receiverId;
  final DateTime timestamp;
  final bool isRead;
  final bool isSynced;

  Message({
    this.id,
    this.firebaseId,
    required this.text,
    required this.senderId,
    required this.senderEmail,
    required this.receiverId,
    required this.timestamp,
    this.isRead = false,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firebaseId': firebaseId,
      'text': text,
      'senderId': senderId,
      'senderEmail': senderEmail,
      'receiverId': receiverId,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isRead': isRead ? 1 : 0,
      'isSynced': isSynced ? 1 : 0,
    };
  }

  Map<String, dynamic> toFirebaseMap() {
    return {
      'text': text,
      'senderId': senderId,
      'senderEmail': senderEmail,
      'receiverId': receiverId,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isRead': isRead,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] as int?,
      firebaseId: map['firebaseId'] as String?,
      text: map['text'] as String,
      senderId: map['senderId'] as String,
      senderEmail: map['senderEmail'] as String,
      receiverId: map['receiverId'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      isRead: (map['isRead'] as int?) == 1,
      isSynced: (map['isSynced'] as int?) == 1,
    );
  }

  factory Message.fromFirebaseMap(Map<String, dynamic> map, String docId) {
    return Message(
      firebaseId: docId,
      text: map['text'] as String,
      senderId: map['senderId'] as String,
      senderEmail: map['senderEmail'] as String,
      receiverId: map['receiverId'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      isRead: map['isRead'] as bool? ?? false,
      isSynced: true,
    );
  }

  Message copyWith({
    int? id,
    String? firebaseId,
    String? text,
    String? senderId,
    String? senderEmail,
    String? receiverId,
    DateTime? timestamp,
    bool? isRead,
    bool? isSynced,
  }) {
    return Message(
      id: id ?? this.id,
      firebaseId: firebaseId ?? this.firebaseId,
      text: text ?? this.text,
      senderId: senderId ?? this.senderId,
      senderEmail: senderEmail ?? this.senderEmail,
      receiverId: receiverId ?? this.receiverId,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}