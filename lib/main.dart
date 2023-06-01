import 'package:fluffy_board/documentation/file_manager_introduction.dart';
import 'package:flutter/material.dart';

import 'dashboard/dashboard.dart';
import 'dashboard/edit_account.dart';
import 'dashboard/server_settings.dart';
import 'documentation/about.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:easy_dynamic_theme/easy_dynamic_theme.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

Future main() async {
  await dotenv.load(fileName: ".env");
  print(dotenv.env['REST_API_URL']);
  runApp(EasyDynamicThemeWidget(child: FluffyboardApp()));
}

class FluffyboardApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return buildMaterialApp('/dashboard', context);
    // return buildMaterialApp('/login', context);
  }
}

var lightThemeData = new ThemeData(
  brightness: Brightness.light,
);

var darkThemeData = ThemeData(
  brightness: Brightness.dark,
);

Widget buildMaterialApp(String initialRoute, context) {
  return MaterialApp(
    theme: lightThemeData,
    darkTheme: darkThemeData,
    themeMode: EasyDynamicTheme.of(context).themeMode,
    title: 'Flutter Demo',
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routes: {
      '/about': (context) => About(),
      '/intro': (context) => FileManagerIntroduction(),
      '/dashboard': (context) => Dashboard(),
      '/edit-account': (context) => EditAccount(),
    },
    initialRoute: initialRoute,
  );
}
