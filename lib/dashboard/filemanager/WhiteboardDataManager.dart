import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:fluffy_board/utils/ScreenUtils.dart';
import 'package:fluffy_board/whiteboard/DrawPoint.dart';
import 'package:fluffy_board/whiteboard/Websocket/WebsocketTypes.dart';
import 'package:fluffy_board/whiteboard/WhiteboardView.dart';
import 'package:fluffy_board/whiteboard/overlays/Toolbar/FigureToolbar.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:localstorage/localstorage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'FileManagerTypes.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

typedef OnGotDirectoriesAndWhiteboards = Function(Directories, Whiteboards, ExtWhiteboards, Set<
    String>, OfflineWhiteboards);

class WhiteboardDataManager {
  static final LocalStorage settingsStorage = new LocalStorage('settings');
  static final LocalStorage fileManagerStorageIndex =
  new LocalStorage('filemanager-index');
  static final LocalStorage fileManagerStorage =
  new LocalStorage('filemanager');

  static Future<void> getDirectoriesAndWhiteboards(bool online,
      String currentDirectory,
      String auth_token,
      RefreshController _refreshController,
      Directories directories,
      Whiteboards whiteboards,
      ExtWhiteboards extWhiteboards,
      Set<String> offlineWhiteboardIds,
      OfflineWhiteboards offlineWhiteboards,
      OnGotDirectoriesAndWhiteboards onGotDirectoriesAndWhiteboards) async {
    await getOfflineWhiteboards(
        offlineWhiteboardIds, currentDirectory, offlineWhiteboards);
    Directories offlineDirectories = getOfflineDirectories(currentDirectory);
    if (!online) {
      directories = offlineDirectories;
      whiteboards = new Whiteboards([]);
      extWhiteboards = new ExtWhiteboards([]);
      onGotDirectoriesAndWhiteboards(directories, whiteboards, extWhiteboards, offlineWhiteboardIds, offlineWhiteboards);
      _refreshController.refreshCompleted();
      return;
    }
    http.Response dirResponse = await http.post(
        Uri.parse((settingsStorage.getItem("REST_API_URL") ??
            dotenv.env['REST_API_URL']!) +
            "/filemanager/directory/get"),
        headers: {
          "content-type": "application/json",
          "accept": "application/json",
          "charset": "utf-8",
          'Authorization': 'Bearer ' + auth_token,
        },
        body: jsonEncode({
          "parent": currentDirectory,
        }));
    http.Response wbResponse = await http.post(
        Uri.parse((settingsStorage.getItem("REST_API_URL") ??
            dotenv.env['REST_API_URL']!) +
            "/filemanager/whiteboard/get"),
        headers: {
          "content-type": "application/json",
          "accept": "application/json",
          "charset": "utf-8",
          'Authorization': 'Bearer ' + auth_token,
        },
        body: jsonEncode({
          "directory": currentDirectory,
        }));
    http.Response wbExtResponse = await http.post(
        Uri.parse((settingsStorage.getItem("REST_API_URL") ??
            dotenv.env['REST_API_URL']!) +
            "/filemanager-ext/whiteboard/get"),
        headers: {
          "content-type": "application/json",
          "accept": "application/json",
          "charset": "utf-8",
          'Authorization': 'Bearer ' + auth_token,
        },
        body: jsonEncode({
          "directory": currentDirectory,
        }));
    Directories _directories =
    Directories.fromJson(jsonDecode(utf8.decode((dirResponse.bodyBytes))));
    List<String> directoryUuids = [];
    for (Directory directory in _directories.list) {
      directoryUuids.add(directory.id);
    }
    List<Directory> removeOfflineDirectories = [];
    for (Directory offlineDirectory in offlineDirectories.list) {
      if (!directoryUuids.contains(offlineDirectory.id)) {
        http.Response response = await http.post(
            Uri.parse((settingsStorage.getItem("REST_API_URL") ??
                dotenv.env['REST_API_URL']!) +
                "/filemanager/directory/create"),
            headers: {
              "content-type": "application/json",
              "accept": "application/json",
              'Authorization': 'Bearer ' + auth_token,
            },
            body: jsonEncode({
              'filename': offlineDirectory.filename,
              'parent': offlineDirectory.parent,
            }));
        if (response.statusCode == 200) {
          removeOfflineDirectories.add(offlineDirectory);
        }
      }
    }
    for (Directory dir in removeOfflineDirectories) {
      offlineDirectories.list.remove(dir);
    }
    await fileManagerStorage.setItem(
        "_directories", _directories.toJSONEncodable());

    Whiteboards _whiteboards =
    Whiteboards.fromJson(jsonDecode(utf8.decode((wbResponse.bodyBytes))));
    ExtWhiteboards _extWhiteboards = ExtWhiteboards.fromJson(
        jsonDecode(utf8.decode((wbExtResponse.bodyBytes))));
    fileManagerStorage.setItem("_directories", _directories.toJSONEncodable());

    directories = _directories;
    whiteboards = _whiteboards;
    extWhiteboards = _extWhiteboards;
    onGotDirectoriesAndWhiteboards(directories, whiteboards, extWhiteboards, offlineWhiteboardIds, offlineWhiteboards);
    if (dirResponse.statusCode == 200 &&
        wbResponse.statusCode == 200 &&
        wbExtResponse.statusCode == 200)
      _refreshController.refreshCompleted();
    else
      _refreshController.refreshFailed();
  }

  static getOfflineWhiteboards(Set<String> offlineWhiteboardIds,
      String currentDirectory, OfflineWhiteboards offlineWhiteboards) async {
    await fileManagerStorageIndex.ready;
    await fileManagerStorage.ready;
    try {
      offlineWhiteboardIds = Set.of(
          jsonDecode(fileManagerStorageIndex.getItem("indexes"))
              .cast<String>() ??
              []);
    } catch (e) {
      offlineWhiteboardIds = Set.of([]);
    }
    List<OfflineWhiteboard> _offlineWhiteboards = List.empty(growable: true);
    for (String id in offlineWhiteboardIds) {
      Map<String, dynamic>? json =
          fileManagerStorage.getItem("offline_whiteboard-" + id) ?? [];
      if (json != null) {
        OfflineWhiteboard offlineWhiteboard =
        await OfflineWhiteboard.fromJson(json);
        for (Scribble scribble in offlineWhiteboard.scribbles.list) {
          ScreenUtils.calculateScribbleBounds(scribble);
          ScreenUtils.bakeScribble(scribble, 1);
        }
        for (Upload upload in offlineWhiteboard.uploads.list) {
          final ui.Codec codec = await PaintingBinding.instance!
              .instantiateImageCodec(upload.uint8List);
          final ui.FrameInfo frameInfo = await codec.getNextFrame();
          upload.image = frameInfo.image;
        }
        if ((offlineWhiteboard.directory.isEmpty && currentDirectory.isEmpty) ||
            offlineWhiteboard.directory == currentDirectory) {
          _offlineWhiteboards.add(offlineWhiteboard);
        }
      }
    }
    offlineWhiteboards = new OfflineWhiteboards(_offlineWhiteboards);
  }

  static Directories getOfflineDirectories(String currentDirectory) {
    Directories directories = new Directories([]);
    try {
      directories = Directories.fromOfflineJson(
          fileManagerStorage.getItem("directories"));
    } catch (e) {
      directories = new Directories([]);
    }
    List<Directory> removeList = [];
    for (Directory dir in directories.list) {
      if ((currentDirectory.isEmpty &&
          dir.parent == "00000000-0000-0000-0000-000000000000")) {} else
      if (dir.parent != currentDirectory) {
        removeList.add(dir);
      }
    }
    for (Directory dir in removeList) {
      directories.list.remove(dir);
    }
    return directories;
  }

  static Future<Scribbles> getScribbles(String whiteboard, String permissionId,
      String auth_token) async {
    http.Response scribbleResponse = await http.post(
        Uri.parse((settingsStorage.getItem("REST_API_URL") ??
            dotenv.env['REST_API_URL']!) +
            "/whiteboard/scribble/get"),
        headers: {
          "content-type": "application/json",
          "accept": "application/json",
          'Authorization': 'Bearer ' + auth_token,
        },
        body: jsonEncode(
            {"whiteboard": whiteboard, "permission_id": permissionId}));
    List<Scribble> scribbles = new List.empty(growable: true);
    if (scribbleResponse.statusCode == 200) {
      List<DecodeGetScribble> decodedScribbles =
      DecodeGetScribbleList.fromJsonList(jsonDecode(scribbleResponse.body));
      for (DecodeGetScribble decodeGetScribble in decodedScribbles) {
        Scribble newScribble = new Scribble(
            decodeGetScribble.uuid,
            decodeGetScribble.strokeWidth,
            StrokeCap.values[decodeGetScribble.strokeCap],
            HexColor.fromHex(decodeGetScribble.color),
            decodeGetScribble.points,
            SelectedFigureTypeToolbar
                .values[decodeGetScribble.selectedFigureTypeToolbar],
            PaintingStyle.values[decodeGetScribble.paintingStyle]);
        ScreenUtils.calculateScribbleBounds(newScribble);
        ScreenUtils.bakeScribble(newScribble, 1);
      }
    }
    return new Scribbles(scribbles);
  }

  static Future<Uploads> getUploads(String whiteboard, String permissionId,
      String auth_token) async {
    http.Response uploadResponse = await http.post(
        Uri.parse((settingsStorage.getItem("REST_API_URL") ??
            dotenv.env['REST_API_URL']!) +
            "/whiteboard/upload/get"),
        headers: {
          "content-type": "application/json",
          "accept": "application/json",
          'Authorization': 'Bearer ' + auth_token,
        },
        body: jsonEncode(
            {"whiteboard": whiteboard, "permission_id": permissionId}));
    if (uploadResponse.statusCode == 200) {
      List<DecodeGetUpload> decodedUploads =
      DecodeGetUploadList.fromJsonList(jsonDecode(uploadResponse.body));
      List<Upload> decodedUploadsWithImages =
      await getDecodedUploadImages(decodedUploads);
      return new Uploads(decodedUploadsWithImages);
    }
    return new Uploads([]);
  }

  static Future<List<Upload>> getDecodedUploadImages(
      List<DecodeGetUpload> decodedUploads) async {
    List<Upload> uploads = new List.empty(growable: true);
    for (DecodeGetUpload decodeGetUpload in decodedUploads) {
      Uint8List uint8list = Uint8List.fromList(decodeGetUpload.imageData);
      final ui.Codec codec =
      await PaintingBinding.instance!.instantiateImageCodec(uint8list);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      uploads.add(new Upload(
          decodeGetUpload.uuid,
          UploadType.values[decodeGetUpload.uploadType],
          uint8list,
          new Offset(decodeGetUpload.offset_dx, decodeGetUpload.offset_dy),
          frameInfo.image));
    }
    return uploads;
  }

  static Future<TextItems> getTextItems(String whiteboard, String permissionId,
      String auth_token) async {
    http.Response textItemResponse = await http.post(
        Uri.parse((settingsStorage.getItem("REST_API_URL") ??
            dotenv.env['REST_API_URL']!) +
            "/whiteboard/textitem/get"),
        headers: {
          "content-type": "application/json",
          "accept": "application/json",
          'Authorization': 'Bearer ' + auth_token,
        },
        body: jsonEncode(
            {"whiteboard": whiteboard, "permission_id": permissionId}));
    List<TextItem> texts = new List.empty(growable: true);
    if (textItemResponse.statusCode == 200) {
      List<DecodeGetTextItem> decodeTextItems =
      DecodeGetTextItemList.fromJsonList(jsonDecode(textItemResponse.body));
      for (DecodeGetTextItem decodeGetTextItem in decodeTextItems) {
        texts.add(new TextItem(
            decodeGetTextItem.uuid,
            false,
            decodeGetTextItem.strokeWidth,
            decodeGetTextItem.maxWidth,
            decodeGetTextItem.maxHeight,
            HexColor.fromHex(decodeGetTextItem.color),
            decodeGetTextItem.contentText,
            new Offset(
                decodeGetTextItem.offset_dx, decodeGetTextItem.offset_dy),
            decodeGetTextItem.rotation));
      }
    }
    return new TextItems(texts);
  }

  static Future<Bookmarks> getBookmarks(String whiteboard, String permissionId,
      String auth_token) async {
    http.Response textItemResponse = await http.post(
        Uri.parse((settingsStorage.getItem("REST_API_URL") ??
            dotenv.env['REST_API_URL']!) +
            "/whiteboard/bookmark/get"),
        headers: {
          "content-type": "application/json",
          "accept": "application/json",
          'Authorization': 'Bearer ' + auth_token,
        },
        body: jsonEncode(
            {"whiteboard": whiteboard, "permission_id": permissionId}));
    List<Bookmark> bookmarks = new List.empty(growable: true);
    if (textItemResponse.statusCode == 200) {
      List<DecodeGetBookmark> decodeBookmarks =
      DecodeGetBookmarkList.fromJsonList(jsonDecode(textItemResponse.body));
      for (DecodeGetBookmark decodeGetBookmark in decodeBookmarks) {
        bookmarks.add(new Bookmark(
            decodeGetBookmark.uuid,
            decodeGetBookmark.name,
            new Offset(
                decodeGetBookmark.offset_dx, decodeGetBookmark.offset_dy),
            decodeGetBookmark.scale));
      }
    }
    return new Bookmarks(bookmarks);
  }
}
