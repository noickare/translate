import 'dart:convert';

MessageModel messageModelFromJson(String str) =>
    MessageModel.fromJson(json.decode(str));

String messageModelToJson(MessageModel data) => json.encode(data.toJson());

class MessageModel {
  MessageModel({
    required this.id,
    required this.username,
    required this.sentAt,
    required this.message,
  });

  String id;
  String username;
  String sentAt;
  String message;

  factory MessageModel.fromJson(Map<String, dynamic> json) => MessageModel(
        id: json["id"],
        username: json["username"],
        sentAt: json["sentAt"],
        message: json["message"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "username": username,
        "sentAt": sentAt,
        "message": message,
      };
}
