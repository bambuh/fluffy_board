import 'dart:convert';

import 'package:fluffy_board/utils/ScreenUtils.dart';
import 'package:fluffy_board/utils/own_icons_icons.dart';
import 'package:fluffy_board/whiteboard/InfiniteCanvas.dart';
import 'package:fluffy_board/whiteboard/Websocket/WebsocketConnection.dart';
import 'package:fluffy_board/whiteboard/Websocket/WebsocketSend.dart';
import 'package:fluffy_board/whiteboard/Websocket/WebsocketTypes.dart';
import 'package:flutter/material.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';
import 'dart:ui';

import '../../../DrawPoint.dart';
import '../../../WhiteboardView.dart';
import '../../Toolbar.dart' as Toolbar;
import 'dart:math';

class ScribbleSettings extends StatefulWidget {
  Scribble? selectedScribble;
  List<Scribble> scribbles;
  OnScribblesChange onScribblesChange;
  Toolbar.ToolbarOptions toolbarOptions;
  Toolbar.OnChangedToolbarOptions onChangedToolbarOptions;
  WebsocketConnection? websocketConnection;

  ScribbleSettings(
      {required this.selectedScribble,
      required this.toolbarOptions,
      required this.onChangedToolbarOptions,
      required this.scribbles,
      required this.onScribblesChange,
      required this.websocketConnection});

  @override
  _ScribbleSettingsState createState() => _ScribbleSettingsState();
}

class _ScribbleSettingsState extends State<ScribbleSettings> {
  double rotation = 1;

  @override
  @override
  Widget build(BuildContext context) {
    const _borderRadius = 50.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 24),
      child: Card(
        elevation: 20,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_borderRadius),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Row(
                children: [
                  RotatedBox(
                    quarterTurns: -1,
                    child: Slider.adaptive(
                      value: widget.selectedScribble!.strokeWidth,
                      onChanged: (value) {
                        setState(() {
                          widget.selectedScribble!.strokeWidth = value;
                        });
                      },
                      onChangeEnd: (value) {
                        WebsocketSend.sendScribbleUpdate(
                            widget.selectedScribble!,
                            widget.websocketConnection);
                      },
                      min: 1,
                      max: 50,
                    ),
                  ),
                ],
              ),
              SleekCircularSlider(
                appearance: CircularSliderAppearance(
                    size: 50,
                    startAngle: 270,
                    angleRange: 360,
                    infoProperties: InfoProperties(modifier: (double value) {
                      final roundedValue = value.ceil().toInt().toString();
                      return '$roundedValue °';
                    })),
                initialValue: rotation,
                min: 0,
                max: 360,
                onChange: (value) {
                  setState(() {
                    rotation = value;
                  });
                },
                onChangeEnd: (value) async {
                  int index =
                      widget.scribbles.indexOf(widget.selectedScribble!);
                  List<DrawPoint> newPoints = [];
                  ScreenUtils.calculateScribbleBounds(widget.selectedScribble!);
                  Offset middlePoint = new Offset(
                      (widget.selectedScribble!.rightExtremity -
                              widget.selectedScribble!.leftExtremity) /
                          2,
                      (widget.selectedScribble!.bottomExtremity -
                              widget.selectedScribble!.topExtremity) /
                          2);
                  print(middlePoint);
                  for (DrawPoint point in widget.selectedScribble!.points) {
                    // https://math.stackexchange.com/questions/1964905/rotation-around-non-zero-point
                    // x′=5+(x−5)cos(φ)−(y−10)sin(φ)
                    double newX = middlePoint.dx +
                        (point.dx - middlePoint.dx) * cos(rotation) -
                        (point.dy - middlePoint.dy) * sin(rotation);
                    // y′=10+(x−5)sin(φ)+(y−10)cos(φ)
                    double newY = middlePoint.dy +
                        (point.dx - middlePoint.dx) * sin(rotation) +
                        (point.dy - middlePoint.dy) * cos(rotation);
                    newPoints.add(new DrawPoint(newX, newY));
                  }
                  widget.selectedScribble!.points = newPoints;
                  widget.scribbles[index] = widget.selectedScribble!;
                  widget.onScribblesChange(widget.scribbles);
                  // WebsocketSend.sendUploadImageDataUpdate(
                  //     widget.selectedUpload!, widget.websocketConnection);
                  setState(() {
                    rotation = 0;
                  });
                },
              ),
              OutlinedButton(
                  onPressed: () {
                    widget.toolbarOptions.colorPickerOpen =
                        !widget.toolbarOptions.colorPickerOpen;
                    widget.onChangedToolbarOptions(widget.toolbarOptions);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Icon(OwnIcons.color_lens,
                        color: widget.selectedScribble!.color),
                  )),
              OutlinedButton(
                  onPressed: () {
                    setState(() {
                      widget.scribbles.remove(widget.selectedScribble!);
                      WebsocketSend.sendScribbleDelete(
                          widget.selectedScribble!, widget.websocketConnection);
                      widget.onScribblesChange(widget.scribbles);
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Icon(Icons.delete),
                  ))
            ],
          ),
        ),
      ),
    );
  }
}
