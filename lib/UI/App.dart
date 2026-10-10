import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:psw_frontend/UI/pages/Layout.dart';
import 'package:psw_frontend/model/support/Constants.dart';


class App extends StatelessWidget {


  @override
  Widget build(BuildContext context) {
    ColorScheme schemaScuro = ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.dark);
    return MaterialApp(
      title: Constants.APP_NAME,
      debugShowCheckedModeBanner: false,
      // scritte già in italiano; le traduzioni di Flutter servono a calendario, orologio e dialoghi
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: [Locale("it")],
      locale: Locale("it"),
      // tema Material 3 generato da un solo colore
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorScheme: schemaScuro,
        // i widget dell'esempio usano primaryColor, che nel tema scuro sarebbe quasi nero
        primaryColor: schemaScuro.primary,
      ),
      home: Layout(title: Constants.APP_NAME),
    );
  }


}
