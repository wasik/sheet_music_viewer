import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsFootpedalConfigRow extends StatefulWidget {
  final String storageKey;
  final String label;

  const SettingsFootpedalConfigRow({Key? key, required this.label, required this.storageKey}) : super(key: key);



  @override
  _SettingsFootpedalConfigRowState createState() => _SettingsFootpedalConfigRowState();
}


class _SettingsFootpedalConfigRowState extends State<SettingsFootpedalConfigRow> {

  @override
  void initState() {
    super.initState();
    getKeySettings();
  }

  int keyId = 0;
  bool isListeningForKeypress = false;

  void setKeySettings(int newKeyId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(widget.storageKey, newKeyId);
    setState(() {
      keyId = newKeyId;
    });
  }

  void getKeySettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
print("Getting key settings..");
    int? retrievedKeyId = prefs.getInt(widget.storageKey);
    if (retrievedKeyId == null) {
      setState(() {
        keyId = 0;
      });
    } else {
      setState(() {
        keyId = retrievedKeyId;
      });
    }
  }



  @override
  Widget build(BuildContext context) {
    //return Container();
    String keyLabel = "";
    if (keyId == 0) {
      keyLabel = "N/A";
    } else {
      keyLabel = LogicalKeyboardKey(keyId).keyLabel;
    }

    Widget? lastSelector;

      lastSelector = ElevatedButton(
        child: Text("Choose"),
        onPressed: () {
          isListeningForKeypress = true;

          showDialog<String>(
            context: context,
            builder: (BuildContext context) => AlertDialog(
              title: const Text('AlertDialog Title'),
              content: KeyboardListener(focusNode: FocusNode(),
              autofocus: true,
              child: Text("Press key"),
              onKeyEvent: (event) {
                if (isListeningForKeypress && event.logicalKey.keyId > 0) {
                  isListeningForKeypress = false;
                  setKeySettings(event.logicalKey.keyId);
                  Navigator.pop(context, 'key');
                }
              }),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context, 'Cancel'),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          );


          /*
          setState(() {
            isListeningForKeypress = true;
          });

           */
        },
      );

    //setKeySettings(event.logicalKey.keyId);

    return ListTile(title: Text('${widget.label}: $keyLabel'),
    trailing: lastSelector
    );

  }
}
