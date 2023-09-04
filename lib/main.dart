import 'package:flutter/material.dart';
import 'home_widget.dart';

void main() => runApp(App());

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sheet Music Viewer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        //primarySwatch: Color.fromRGBO(80, 121, 184, 255),
        primarySwatch: Colors.blueGrey,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            textStyle: TextStyle(fontSize: 20.0),
            padding: EdgeInsets.all(12)
          )
        ),
        textTheme: TextTheme(
          bodyText1: TextStyle(fontSize: 28.0),
          //bodyMedium: TextStyle(fontSize: 18.0),
        )
      ),
      home: Home(),
    );
  }
}