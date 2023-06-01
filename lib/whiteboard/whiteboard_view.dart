import 'dart:async';

import 'package:fluffy_board/dashboard/dashboard.dart';
import 'package:fluffy_board/dashboard/filemanager/file_manager_types.dart';
import 'package:fluffy_board/utils/export_utils.dart';
import 'package:fluffy_board/utils/screen_utils.dart';
import 'package:fluffy_board/whiteboard/infinite_canvas.dart';
import 'package:fluffy_board/whiteboard/overlays/minimap.dart';
import 'package:fluffy_board/whiteboard/texts_canvas.dart';
import 'package:fluffy_board/whiteboard/api/toolbar_options.dart';
import 'package:fluffy_board/whiteboard/overlays/toolbar/background_toolbar.dart';
import 'package:fluffy_board/whiteboard/overlays/toolbar/eraser_toolbar.dart';
import 'package:fluffy_board/whiteboard/overlays/toolbar/figure_toolbar.dart';
import 'package:fluffy_board/whiteboard/overlays/toolbar/higlighter_toolbar.dart';
import 'package:fluffy_board/whiteboard/overlays/toolbar/pencil_toolbar.dart';
import 'package:fluffy_board/whiteboard/overlays/toolbar/straight_line_toolbar.dart';
import 'package:fluffy_board/whiteboard/overlays/toolbar/text_toolbar.dart';
import 'package:fluffy_board/whiteboard/overlays/zoom.dart';
import 'package:fluffy_board/whiteboard/whiteboard-data/bookmark.dart';
import 'package:fluffy_board/whiteboard/whiteboard-data/scribble.dart';
import 'package:fluffy_board/whiteboard/whiteboard-data/textitem.dart';
import 'package:fluffy_board/whiteboard/whiteboard-data/upload.dart';
import 'package:fluffy_board/whiteboard/whiteboard_settings.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:localstorage/localstorage.dart';
import 'overlays/toolbar.dart' as Toolbar;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

typedef OnSaveOfflineWhiteboard = Function();

class WhiteboardView extends StatefulWidget {
  final Whiteboard? whiteboard;
  final ExtWhiteboard? extWhiteboard;
  final OfflineWhiteboard? offlineWhiteboard;
  final String authToken;
  final String id;
  final bool online;

  WhiteboardView(this.whiteboard, this.extWhiteboard, this.offlineWhiteboard, this.authToken, this.id, this.online);

  @override
  _WhiteboardViewState createState() => _WhiteboardViewState();
}

class _WhiteboardViewState extends State<WhiteboardView> {
  Toolbar.ToolbarOptions? toolbarOptions;
  ZoomOptions zoomOptions = new ZoomOptions(1);
  List<Upload> uploads = [];
  List<TextItem> texts = [];
  List<Bookmark> bookmarks = [];
  List<Scribble> scribbles = [];
  Offset offset = Offset.zero;
  Offset _sessionOffset = Offset.zero;
  final LocalStorage fileManagerStorage = new LocalStorage('filemanager');
  final LocalStorage settingsStorage = new LocalStorage('settings');
  String toolbarLocation = "left";
  bool stylusOnly = false;
  late Timer autoSaveTimer;

  @override
  void initState() {
    super.initState();
    autoSaveTimer = Timer.periodic(Duration(seconds: 30), (timer) => saveOfflineWhiteboard());
    settingsStorage.ready.then((value) => setState(() {
          _getSettings();
          _getToolBarOptions();
        }));
    _getWhiteboardData();
  }

  void _getSettings() {
    setState(() {
      toolbarLocation = settingsStorage.getItem("toolbar-location") ?? "left";
      stylusOnly = settingsStorage.getItem("stylus-only") ?? false;
    });
  }

  @override
  void dispose() {
    super.dispose();
    autoSaveTimer.cancel();
  }

  @override
  Widget build(BuildContext context) {
    AppBar appBar = AppBar(
        title: Text(
          widget.whiteboard == null
              ? widget.extWhiteboard == null
                  ? widget.offlineWhiteboard!.name
                  : widget.extWhiteboard!.name
              : widget.whiteboard!.name,
        ),
        actions: [
          PopupMenuButton(
              onSelected: (value) => {
                    setState(() {
                      switch (value) {
                        case 0:
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.tryingExportImage)));
                          ExportUtils.exportPNG(scribbles, uploads, texts, toolbarOptions!,
                              new Offset(ScreenUtils.getScreenWidth(context), ScreenUtils.getScreenHeight(context)), offset, zoomOptions.scale);
                          break;
                        case 1:
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.tryingExportPDF)));
                          ExportUtils.exportPDF(scribbles, uploads, texts, toolbarOptions!,
                              new Offset(ScreenUtils.getScreenWidth(context), ScreenUtils.getScreenHeight(context)), offset, zoomOptions.scale);
                          break;
                        case 2:
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.tryingExportScreenSizeImage)));
                          ExportUtils.exportScreenSizePNG(scribbles, uploads, texts, toolbarOptions!,
                              new Offset(ScreenUtils.getScreenWidth(context), ScreenUtils.getScreenHeight(context)), offset, zoomOptions.scale);
                          break;
                      }
                    })
                  },
              itemBuilder: (BuildContext context) => <PopupMenuEntry>[
                    PopupMenuItem(child: Text(AppLocalizations.of(context)!.exportImage), value: 0),
                    PopupMenuItem(child: Text(AppLocalizations.of(context)!.exportPDF), value: 1),
                    PopupMenuItem(child: Text(AppLocalizations.of(context)!.exportScreenSizeImage), value: 2),
                  ],
              icon: Icon(Icons.import_export)),
          IconButton(
              icon: Icon(Icons.settings),
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (context) => WhiteboardSettings()));
                _getSettings();
              }),
        ]);

    if (toolbarOptions == null) {
      return Dashboard.loading(
          widget.whiteboard == null
              ? widget.extWhiteboard == null
                  ? widget.offlineWhiteboard!.name
                  : widget.extWhiteboard!.name
              : widget.whiteboard!.name,
          context);
    }

    Widget toolbar = (widget.whiteboard != null || (widget.extWhiteboard != null && widget.extWhiteboard!.edit) || widget.offlineWhiteboard != null)
        ? (Toolbar.Toolbar(
            toolbarLocation: toolbarLocation,
            onSaveOfflineWhiteboard: () => saveOfflineWhiteboard(),
            texts: texts,
            scribbles: scribbles,
            toolbarOptions: toolbarOptions!,
            zoomOptions: zoomOptions,
            offset: offset,
            sessionOffset: _sessionOffset,
            uploads: uploads,
            onChangedToolbarOptions: (toolBarOptions) {
              setState(() {
                this.toolbarOptions = toolBarOptions;
              });
            },
            onScribblesChange: (scribbles) {
              setState(() {
                this.scribbles = scribbles;
              });
            },
            onUploadsChange: (uploads) {
              setState(() {
                this.uploads = uploads;
              });
            },
            onTextItemsChange: (textItems) {
              setState(() {
                this.texts = textItems;
              });
            },
          ))
        : Container();

    return Scaffold(
        appBar: (appBar),
        body: Stack(children: [
          Container(
            decoration: BoxDecoration(),
            child: InfiniteCanvasPage(
              stylusOnly: stylusOnly,
              id: widget.id,
              onSaveOfflineWhiteboard: () => saveOfflineWhiteboard(),
              authToken: widget.authToken,
              toolbarOptions: toolbarOptions!,
              zoomOptions: zoomOptions,
              appBarHeight: appBar.preferredSize.height,
              onScribblesChange: (scribbles) {
                setState(() {
                  this.scribbles = scribbles;
                });
              },
              onUploadsChange: (uploads) {
                setState(() {
                  this.uploads = uploads;
                });
              },
              onTextItemsChange: (textItems) {
                setState(() {
                  this.texts = textItems;
                });
              },
              onChangedZoomOptions: (zoomOptions) {
                setState(() {
                  this.zoomOptions = zoomOptions;
                });
              },
              offset: offset,
              texts: texts,
              sessionOffset: _sessionOffset,
              onOffsetChange: (offset, sessionOffset) => {
                setState(() {
                  this.offset = offset;
                  this._sessionOffset = sessionOffset;
                })
              },
              uploads: uploads,
              onChangedToolbarOptions: (toolBarOptions) {
                setState(() {
                  this.toolbarOptions = toolBarOptions;
                });
              },
              scribbles: scribbles,
              onDontFollow: () {},
            ),
          ),
          TextsCanvas(
            sessionOffset: _sessionOffset,
            offset: offset,
            texts: texts,
            toolbarOptions: toolbarOptions!,
          ),
          toolbar,
          if (settingsStorage.getItem("zoom-panel") ?? true)
            ZoomView(
              toolbarOptions: toolbarOptions!,
              toolbarLocation: toolbarLocation,
              zoomOptions: zoomOptions,
              offset: offset,
              onChangedZoomOptions: (zoomOptions) {
                setState(() {
                  this.zoomOptions = zoomOptions;
                });
              },
              onChangedOffset: (offset) {
                setState(() {
                  this.offset = offset;
                });
              },
            ),
          // if (settingsStorage.getItem("minimap") ?? true)
          //   MinimapView(
          //     toolbarOptions: toolbarOptions!,
          //     offset: offset,
          //     onChangedOffset: (offset) {
          //       setState(() {
          //         this.offset = offset;
          //       });
          //     },
          //     toolbarLocation: toolbarLocation,
          //     texts: texts,
          //     scribbles: scribbles,
          //     scale: zoomOptions.scale,
          //     uploads: uploads,
          //     screenSize: Offset(ScreenUtils.getScreenWidth(context),
          //         ScreenUtils.getScreenHeight(context)),
          //   )
        ]));
  }

  Future _getToolBarOptions() async {
    PencilOptions pencilOptions = await GetToolbarOptions.getPencilOptions(widget.authToken, widget.online);
    HighlighterOptions highlighterOptions = await GetToolbarOptions.getHighlighterOptions(widget.authToken, widget.online);
    EraserOptions eraserOptions = await GetToolbarOptions.getEraserOptions(widget.authToken, widget.online);
    StraigtLineOptions straightLineOptions = await GetToolbarOptions.getStraightLineOptions(widget.authToken, widget.online);
    TextOptions textItemOptions = await GetToolbarOptions.getTextItemOptions(widget.authToken, widget.online);
    FigureOptions figureOptions = await GetToolbarOptions.getFigureOptions(widget.authToken, widget.online);
    BackgroundOptions backgroundOptions = await GetToolbarOptions.getBackgroundOptions(widget.authToken, widget.online);
    setState(() {
      toolbarOptions = new Toolbar.ToolbarOptions(
        Toolbar.SelectedTool.move,
        pencilOptions,
        highlighterOptions,
        straightLineOptions,
        eraserOptions,
        figureOptions,
        textItemOptions,
        backgroundOptions,
        false,
        Toolbar.SettingsSelected.none,
      );
    });
  }

  Future _getWhiteboardData() async {
    if (widget.offlineWhiteboard != null) {
      print("Get Offset" + widget.offlineWhiteboard!.offset.toString());
      print("Get scale" + widget.offlineWhiteboard!.scale.toString());
      setState(() {
        offset = widget.offlineWhiteboard!.offset;
        zoomOptions.scale = widget.offlineWhiteboard!.scale;
      });
    }
  }

  saveOfflineWhiteboard() async {
    // if (widget.offlineWhiteboard == null) return;
    // await fileManagerStorage.setItem(
    //     "offline_whiteboard-" + widget.offlineWhiteboard!.uuid,
    //     new OfflineWhiteboard(
    //             widget.offlineWhiteboard!.uuid,
    //             widget.offlineWhiteboard!.directory,
    //             widget.offlineWhiteboard!.name,

    //             offset + _sessionOffset,
    //             zoomOptions.scale)
    //         .toJSONEncodable());
    // print("Save");
  }
}

extension HexColor on Color {
  /// String is in the format "aabbcc" or "ffaabbcc" with an optional leading "#".
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  /// String is in the format "aabbcc" or "ffaabbcc" with an optional leading "#".
  static Color fromHexWithOpacity(Color color, double opacity) {
    return Color.fromRGBO(color.red, color.green, color.blue, opacity);
  }

  /// Prefixes a hash sign if [leadingHashSign] is set to `true` (default is `true`).
  String toHex({bool leadingHashSign = true}) => '${leadingHashSign ? '#' : ''}'
      '${alpha.toRadixString(16).padLeft(2, '0')}'
      '${red.toRadixString(16).padLeft(2, '0')}'
      '${green.toRadixString(16).padLeft(2, '0')}'
      '${blue.toRadixString(16).padLeft(2, '0')}';
}
