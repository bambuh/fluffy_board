import 'package:fluffy_board/utils/ScreenUtils.dart';
import 'package:fluffy_board/utils/own_icons_icons.dart';
import 'package:flutter/material.dart';
import 'dart:ui';

import '../Toolbar.dart' as Toolbar;

import 'DrawOptions.dart';

class HighlighterOptions extends DrawOptions {
  HighlighterOptions(List<Color> colors, double strokeWidth, StrokeCap strokeCap, int currentColor, dynamic Function(DrawOptions) onHighlighterChange)
      : super(colors, strokeWidth, strokeCap, currentColor, onHighlighterChange);
}

class EncodeHighlighterOptions{
  List<String> colorPresets;
  double strokeWidth;
  int selectedColor;

  EncodeHighlighterOptions(this.colorPresets, this.strokeWidth, this.selectedColor);

  Map toJson() {
    return {
      'color_presets': colorPresets,
      'stroke_width': strokeWidth,
      'selected_color': selectedColor,
    };
  }
}


class DecodeHighlighterOptions{
  late List<dynamic> colorPresets;
  late double strokeWidth;
  int selectedColor;


  DecodeHighlighterOptions(this.colorPresets, this.strokeWidth, this.selectedColor);

  factory DecodeHighlighterOptions.fromJson(dynamic json){
    return DecodeHighlighterOptions(json['color_presets'] as List<dynamic>, json['stroke_width'] as double, json['selected_color'] as int);
  }
}

class HighlighterToolbar extends StatefulWidget {
  Toolbar.ToolbarOptions toolbarOptions;
  Toolbar.OnChangedToolbarOptions onChangedToolbarOptions;

  HighlighterToolbar(
      {required this.toolbarOptions, required this.onChangedToolbarOptions});

  @override
  _HighlighterToolbarState createState() => _HighlighterToolbarState();
}

class _HighlighterToolbarState extends State<HighlighterToolbar> {
  int beforeIndex = -1;
  int realBeforeIndex = 0;
  late List<bool> selectedColorList;

  @override
  void initState() {
    super.initState();
    selectedColorList = List.generate(3, (i) => i == widget.toolbarOptions.highlighterOptions.currentColor ? true : false);
  }

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
              RotatedBox(
                quarterTurns: -1,
                child: Slider.adaptive(
                  value: widget.toolbarOptions.highlighterOptions.strokeWidth,
                  onChanged: (value) {
                    setState(() {
                      widget.toolbarOptions.highlighterOptions.strokeWidth = value;
                      widget.onChangedToolbarOptions(widget.toolbarOptions);
                    });
                  },
                  onChangeEnd: (value) {
                    widget.toolbarOptions.highlighterOptions.onDrawOptionChange(widget.toolbarOptions.highlighterOptions);
                  },
                  min: 5,
                  max: 50,
                ),
              ),
              ToggleButtons(
                  onPressed: (index) {
                    setState(() {
                      widget.toolbarOptions.highlighterOptions.currentColor =
                          index;
                      widget.toolbarOptions.colorPickerOpen =
                          !widget.toolbarOptions.colorPickerOpen;

                      for (int buttonIndex = 0;
                          buttonIndex < selectedColorList.length;
                          buttonIndex++) {
                        if (buttonIndex == index) {
                          selectedColorList[buttonIndex] = true;
                        } else {
                          selectedColorList[buttonIndex] = false;
                        }
                      }
                      if (beforeIndex == index) {
                        widget.toolbarOptions.colorPickerOpen = false;
                        beforeIndex = -1;
                      } else if (beforeIndex == -1) {
                        widget.toolbarOptions.colorPickerOpen = false;
                        beforeIndex = -2;
                      } else if (realBeforeIndex != index) {
                        widget.toolbarOptions.colorPickerOpen = false;
                      } else {
                        widget.toolbarOptions.colorPickerOpen = true;
                        beforeIndex = index;
                      }
                      realBeforeIndex = index;

                      widget.onChangedToolbarOptions(widget.toolbarOptions);
                      widget.toolbarOptions.highlighterOptions.onDrawOptionChange(
                          widget.toolbarOptions.highlighterOptions);
                    });
                  },
                  direction: Axis.vertical,
                  isSelected: selectedColorList,
                  children: <Widget>[
                    Icon(OwnIcons.color_lens,
                        color: widget
                            .toolbarOptions.highlighterOptions.colorPresets[0]),
                    Icon(OwnIcons.color_lens,
                        color: widget
                            .toolbarOptions.highlighterOptions.colorPresets[1]),
                    Icon(OwnIcons.color_lens,
                        color: widget
                            .toolbarOptions.highlighterOptions.colorPresets[2]),
                  ]),
            ],
          ),
        ),
      ),
    );
  }
}
