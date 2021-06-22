import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:io';
import 'dart:typed_data';

import 'package:fluffy_board/whiteboard/overlays/Toolbar/FigureToolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../DrawPoint.dart';
import '../WhiteboardView.dart';
import 'WebsocketTypes.dart';
import 'dart:ui' as ui;

typedef OnScribbleAdd = Function(Scribble);
typedef OnScribbleUpdate = Function(Scribble);
typedef OnScribbleDelete = Function(String);

typedef OnUploadAdd = Function(Upload);
typedef OnUploadUpdate = Function(Upload);

class WebsocketConnection {
  static WebsocketConnection? _singleton = null;

  StreamController<String> streamController =
      new StreamController.broadcast(sync: true);

  late WebSocket channel;
  String whiteboard;
  String auth_token;
  bool disconnect = false;

  OnScribbleAdd onScribbleAdd;
  OnScribbleUpdate onScribbleUpdate;
  OnScribbleDelete onScribbleDelete;

  OnUploadAdd onUploadAdd;
  OnUploadUpdate onUploadUpdate;

  WebsocketConnection(
      {required this.whiteboard,
      required this.auth_token,
      required this.onScribbleAdd,
      required this.onScribbleUpdate,
      required this.onScribbleDelete,
      required this.onUploadAdd,
      required this.onUploadUpdate});

  static WebsocketConnection getInstance({
    required String whiteboard,
    required String auth_token,
    required Function(Scribble) onScribbleAdd,
    required Function(Scribble) onScribbleUpdate,
    required Function(String) onScribbleDelete,
    required Function(Upload) onUploadAdd,
    required Function(Upload) onUploadUpdate,
  }) {
    if (_singleton == null) {
      _singleton = new WebsocketConnection(
          whiteboard: whiteboard,
          auth_token: auth_token,
          onScribbleAdd: onScribbleAdd,
          onScribbleUpdate: onScribbleUpdate,
          onScribbleDelete: onScribbleDelete,
          onUploadAdd: onUploadAdd,
          onUploadUpdate: onUploadUpdate);
      _singleton!.initWebSocketConnection(whiteboard, auth_token);
    }
    ;
    return _singleton!;
  }

  dispose() {
    disconnect = true;
    channel.close();
    _singleton = null;
  }

  initWebSocketConnection(String whiteboard, String auth_token) async {
    print("conecting...");
    this.channel = await connectWs(whiteboard, auth_token);
    // this.channel.pingInterval = Duration(seconds: 5);
    print("socket connection initialized");
    this
        .channel
        .done
        .then((dynamic _) => _onDisconnected(whiteboard, auth_token));
    startListener(whiteboard, auth_token);
  }

  startListener(String whiteboard, String auth_token) {
    this.channel.listen((streamData) {
      String message = streamData;
      if (message.startsWith(r"scribble-add#")) {
        WSScribbleAdd json = WSScribbleAdd.fromJson(
            jsonDecode(message.replaceFirst(r"scribble-add#", ""))
                as Map<String, dynamic>);
        Scribble newScribble = Scribble(
            json.uuid,
            json.strokeWidth,
            StrokeCap.values[json.strokeCap],
            HexColor.fromHex(json.color),
            json.points,
            SelectedFigureTypeToolbar.values[json.selectedFigureTypeToolbar],
            PaintingStyle.values[json.paintingStyle]);
        onScribbleAdd(newScribble);
      } else if (message.startsWith(r"scribble-update#")) {
        WSScribbleUpdate json = WSScribbleUpdate.fromJson(
            jsonDecode(message.replaceFirst(r"scribble-update#", ""))
                as Map<String, dynamic>);
        Scribble newScribble = Scribble(
            json.uuid,
            json.strokeWidth,
            StrokeCap.values[json.strokeCap],
            HexColor.fromHex(json.color),
            json.points,
            SelectedFigureTypeToolbar.none,
            PaintingStyle.values[json.paintingStyle]);
        onScribbleUpdate(newScribble);
      } else if (message.startsWith(r"scribble-delete#")) {
        WSScribbleDelete json = WSScribbleDelete.fromJson(
            jsonDecode(message.replaceFirst(r"scribble-delete#", ""))
                as Map<String, dynamic>);
        onScribbleDelete(json.uuid);
      } else if (message.startsWith(r"upload-add#")) {
        WSUploadAdd json = WSUploadAdd.fromJson(
            jsonDecode(message.replaceFirst(r"upload-add#", ""))
                as Map<String, dynamic>);
        Uint8List uint8list = Uint8List.fromList(json.imageData);
        ui.decodeImageFromList(uint8list, (image) {
          Upload newUpload = Upload(
              json.uuid,
              UploadType.values[json.uploadType],
              uint8list,
              new Offset(json.offset_dx, json.offset_dy),
              image);
          onUploadAdd(newUpload);
        });
      } else if (message.startsWith(r"upload-update#")) {
        WSUploadUpdate json = WSUploadUpdate.fromJson(
            jsonDecode(message.replaceFirst(r"upload-update#", ""))
                as Map<String, dynamic>);
        onUploadUpdate(new Upload(
            json.uuid,
            UploadType.Image,
            Uint8List.fromList(List.empty()),
            new Offset(json.offset_dx, json.offset_dy),
            null));
      }
    }, onDone: () {
      print("connecting aborted");
      if (!disconnect) initWebSocketConnection(whiteboard, auth_token);
    }, onError: (e) {
      print('Server error: $e');
      initWebSocketConnection(whiteboard, auth_token);
    });
  }

  connectWs(String whiteboard, String auth_token) async {
    try {
      WebSocket webSocket = await WebSocket.connect(
          dotenv.env['WS_API_URL']! + "/$whiteboard/$auth_token");
      return webSocket;
    } catch (e) {
      print("Error! can not connect WS connectWs " + e.toString());
      await Future.delayed(Duration(milliseconds: 10000));
      return await connectWs(whiteboard, auth_token);
    }
  }

  void _onDisconnected(String whiteboard, String auth_token) {
    if (!disconnect) initWebSocketConnection(whiteboard, auth_token);
  }
}
