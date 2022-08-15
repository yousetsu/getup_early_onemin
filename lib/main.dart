import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter_picker/flutter_picker.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import "package:intl/intl.dart";
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:isolate';
import 'dart:ui';
import 'package:timezone/timezone.dart' as tz;

import 'package:flutter/cupertino.dart';
import 'package:rxdart/subjects.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'dart:io';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';

import 'package:fluttertoast/fluttertoast.dart';

final AudioCache _player = AudioCache();
late AudioPlayer _ap;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Streams are created so that app can respond to notification-related events
/// since the plugin is initialised in the `main` function
final BehaviorSubject<ReceivedNotification> didReceiveLocalNotificationSubject =
    BehaviorSubject<ReceivedNotification>();

final BehaviorSubject<String?> selectNotificationSubject =
    BehaviorSubject<String?>();

const MethodChannel platform =
    MethodChannel('dexterx.dev/flutter_local_notifications_example');

class ReceivedNotification {
  ReceivedNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;
  final String? title;
  final String? body;
  final String? payload;
}

String? selectedNotificationPayload;

final int helloAlarmID = 19820822;
const String cns_getupstatus_s = '1';
const String cns_getupstatus_f = '0';
const bool cns_alarm_on = true;
const bool cns_alarm_off = false;

/// The name associated with the UI isolate's [SendPort].
/// UI isolate の[SendPort]に関連付けられた名前
const String isolateName = 'isolate';

/// A port used to communicate from a background isolate to the UI isolate.
/// バックグラウンドisolateからUI isolate への通信に使用されるポート
final ReceivePort Recvport = ReceivePort();

Future<void> main() async {
  // Register the UI isolate's SendPort to allow for communication from the
  // background isolate.
  WidgetsFlutterBinding.ensureInitialized();

  await _configureLocalTimeZone();

  final NotificationAppLaunchDetails? notificationAppLaunchDetails = !kIsWeb &&
          Platform.isLinux
      ? null
      : await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
  String initialRoute = '/';
  if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
    selectedNotificationPayload = notificationAppLaunchDetails!.payload;
    initialRoute = '/';
  }

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  /// Note: permissions aren't requested here just to demonstrate that can be
  /// done later
  final IOSInitializationSettings initializationSettingsIOS =
      IOSInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          onDidReceiveLocalNotification: (
            int id,
            String? title,
            String? body,
            String? payload,
          ) async {
            didReceiveLocalNotificationSubject.add(
              ReceivedNotification(
                id: id,
                title: title,
                body: body,
                payload: payload,
              ),
            );
          });
  const MacOSInitializationSettings initializationSettingsMacOS =
      MacOSInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );
  final LinuxInitializationSettings initializationSettingsLinux =
      LinuxInitializationSettings(
    defaultActionName: 'Open notification',
    defaultIcon: AssetsLinuxIcon('icons/app_icon.png'),
  );
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
    macOS: initializationSettingsMacOS,
    linux: initializationSettingsLinux,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings,
      onSelectNotification: (String? payload) async {
    if (payload != null) {
      debugPrint('notification payload: $payload');
    }
    selectedNotificationPayload = payload;
    selectNotificationSubject.add(payload);
  });

  //UI isolateのSendPortを登録して、バックグラウンドisolateからの通信を可能にします。
  IsolateNameServer.registerPortWithName(
    Recvport.sendPort,
    isolateName,
  );

  runApp(new MyApp());
}

Future<void> _configureLocalTimeZone() async {
  if (kIsWeb || Platform.isLinux) {
    return;
  }
  tz.initializeTimeZones();
  final String? timeZoneName = await FlutterNativeTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(timeZoneName!));
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Generated App',
      theme: new ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: const Color(0xFF2196f3),
        accentColor: const Color(0xFF2196f3),
        hintColor: const Color(0xFF2196f3),
        //canvasColor: const Color(0x000000f3),
        canvasColor: const Color(0xFF515254),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => FirstScreen(),
        '/setting': (context) => SecondScreen(),
        '/list': (context) => ThirdScreen(),
      },
    );
  }
}

class FirstScreen extends StatefulWidget {
  FirstScreen({Key? key}) : super(key: key); //コンストラクタ

  @override
  _FirstScreenState createState() => new _FirstScreenState();
}

class _FirstScreenState extends State<FirstScreen> {
  final _controllerTitle = TextEditingController();
  final _controllergoalday = TextEditingController();
  final _text_controller_kankaku = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _goalvisible = false;
  DateTime _getuptime = DateTime.utc(0, 0, 0);
  DateTime _goalgetuptime = DateTime.utc(0, 0, 0);
  DateTime _goal_bedin_time = DateTime.utc(0, 0, 0);
  int int_min_kankaku = 1;
  int _goal_day = 0;
  bool alarm_flg = false;
  MaterialColor primaryColor = Colors.orange;
  String str_starstop = '開始';

  //現在日付
  late String strStartdate;
  final TextStyle styleA = TextStyle(
    fontSize: 28.0,
    color: Colors.white,
  );
  final TextStyle styleB = TextStyle(fontSize: 15.0, color: Colors.white);
  late VideoPlayerController _controller;

  @override
  void initState() {
    _getuptime = DateTime.utc(0, 0, 0);
    super.initState();
    LoadPref();
    AndroidAlarmManager.initialize();
  }

  Future<void> _soundalarm() async {
    debugPrint('Alarm Start test.mp3');

    //  final player = AudioCache();
    // await player.play('test.mp3');

    debugPrint('Alarm End test.mp3');
//void soundalarm() {
    //debugPrint('Alarm fired!');
    //  FlutterRingtonePlayer.play(
    //  android: AndroidSounds.notification,
    //  // Android用のサウンド
    //  ios: const IosSound(1023),
    //  // iOS用のサウンド
    //  looping: true,
    //  // Androidのみ。ストップするまで繰り返す
    //  asAlarm: true,
    //  // Androidのみ。サイレントモードでも音を鳴らす
    //  volume: 0.5, // Androidのみ。0.0〜1.0
    //  );
//FlutterRingtonePlayer.playAlarm();
  }

  // The background
  // static SendPort? uiSendPort = Recvport.sendPort;
  static SendPort? uiSendPort;

  stopTheSound() async {
    await flutterLocalNotificationsPlugin.cancel(helloAlarmID);

    await AndroidAlarmManager.oneShot(
        Duration(seconds: 0), helloAlarmID, stopSound,
        exact: true, wakeup: true, alarmClock: true, allowWhileIdle: true);
  }

  static stopSound() async {
    await FlutterRingtonePlayer.stop();
  }

  // The callback for our alarm
  static Future<void> callsound_start() async {
    debugPrint('Alarm fired!');
    FlutterRingtonePlayer.playAlarm();
  }

  //アラームのセット
  Future<void> alramset() async {
    DateTime _nowtime;
    DateTime _getupalarmtime;
    //int _diffmin = 0;
    int _hour;
    int _minute;
    int _second;
    int _diffSecond = 0;
    int _hour_now;
    int _minute_now;
    int _second_now;
    String str_nowtime;
    String str_getuptime;
    String _str_date;
    String _str_date_plusone;

    _str_date = '2022-01-16 ';
    _str_date_plusone = '2022-01-17 ';

    //現在時間の算出
    _hour_now = DateTime.now().hour;
    _minute_now = DateTime.now().minute;
    _second_now = DateTime.now().second;
    str_nowtime = _str_date +
        _hour_now.toString().padLeft(2, '0') +
        ':' +
        _minute_now.toString().padLeft(2, '0') +
        ':' +
        _second_now.toString().padLeft(2, '0') +
        '.0';
    _nowtime = DateTime.parse(str_nowtime);

    //起床したい時刻の算出
    _hour = _getuptime.hour;
    _minute = _getuptime.minute;
    _second = _getuptime.second;

    str_getuptime = _str_date +
        _hour.toString().padLeft(2, '0') +
        ':' +
        _minute.toString().padLeft(2, '0') +
        ':' +
        _second.toString().padLeft(2, '0') +
        '.0';
    _getupalarmtime = DateTime.parse(str_getuptime);

    //起床したい時刻 - 現時刻
    _diffSecond = _getupalarmtime.difference(_nowtime).inSeconds;

    if (_diffSecond >= 0) {
      //現時刻が起床日当日になっている場合はそのままでOK
      //(ほとんどありえないケース)

    } else {
      //現時刻が起床日前日になっている場合(ほとんどこのケース)
      str_getuptime = _str_date_plusone +
          _hour.toString().padLeft(2, '0') +
          ':' +
          _minute.toString().padLeft(2, '0') +
          ':' +
          _second.toString().padLeft(2, '0') +
          '.0';
      _getupalarmtime = DateTime.parse(str_getuptime);
      _diffSecond = _getupalarmtime.difference(_nowtime).inSeconds;
    }

    debugPrint('Alarm Set!');

    await AndroidAlarmManager.oneShot(
      Duration(seconds: _diffSecond),
      helloAlarmID,
      callsound_start,
      alarmClock: true,
      allowWhileIdle: true,
      exact: true,
      wakeup: true,
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
        helloAlarmID,
        'scheduled title',
        'scheduled body',
        tz.TZDateTime.now(tz.local).add(Duration(seconds: _diffSecond)),
        const NotificationDetails(
            android: AndroidNotificationDetails(
                'full screen channel id', 'full screen channel name',
                channelDescription: 'full screen channel description',
                priority: Priority.high,
                importance: Importance.high,
                fullScreenIntent: true)),
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime);
    int int_hour;
    int int_hour_amari_sec;
    int int_minute;
    int int_second;
    int_hour = (_diffSecond / 3600).floor();
    int_hour_amari_sec = (_diffSecond % 3600).floor();
    int_minute = (int_hour_amari_sec / 60).floor();
    int_second = (int_hour_amari_sec % 60).floor();
    Fluttertoast.showToast(
        msg: int_hour.toString() +
            "時間" +
            int_minute.toString() +
            "分" +
            int_second.toString() +
            "秒後にアラームが鳴ります。");
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controllerTitle,
          textAlign: TextAlign.center,
          readOnly: true,
          enabled: false,
          style: const TextStyle(
              fontSize: 20.0,
              color: Colors.white,
              decoration: TextDecoration.none),
        ),
        automaticallyImplyLeading: false, //戻るボタン非表示
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.all(20.0),
            ),
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                // 枠線
                border: Border.all(color: Colors.blue, width: 2),
                // 角丸
                borderRadius: BorderRadius.circular(8),
                color: Colors.blue,
              ),

              /// TOMMOROW GET UP TIME
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: <Widget>[
                        Icon(Icons.alarm, color: Colors.white, size: 50),
                        Text('TOMMOROW GET UP TIME', style: styleB),
                      ]),
                  ElevatedButton(
                    child: Text(
                      DateFormat.Hm().format(_getuptime),
                      style: TextStyle(fontSize: 50),
                    ),
                    style: ElevatedButton.styleFrom(
                      primary: Colors.lightBlueAccent,
                      onPrimary: Colors.white,
                      padding:
                          EdgeInsets.symmetric(vertical: 10, horizontal: 100),
                    ),
                    onPressed: () async {
                      Picker(
                        adapter: DateTimePickerAdapter(
                            type: PickerDateTimeType.kHM,
                            value: _getuptime,
                            customColumnType: [3, 4]),
                        title: Text("Select Time"),
                        onConfirm: (Picker picker, List value) {
                          setState(() => {
                                _getuptime = DateTime.utc(
                                    0, 0, 0, value[0], value[1], 0),
                                _savegetuptimepref(_getuptime),
                                LoadPref(),
                              });
                        },
                      ).showModal(context);
                    },
                  ),

                  ///INTERVAL
                  Padding(
                    padding: EdgeInsets.all(10.0),
                  ),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: <Widget>[
                        Icon(Icons.watch_later, color: Colors.white, size: 50),
                        Text('INTERVAL(Minutes)', style: styleB),
                      ]),
                  Container(
                    padding: EdgeInsets.all(5.0),
                    alignment: Alignment.bottomCenter,
                    width: 300.0,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.lightBlueAccent),
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.lightBlueAccent,
                    ),
                    child: TextFormField(
                      controller: _text_controller_kankaku,
                      //ここに初期値
                      validator: (value) {
                        if (value != null && value.isEmpty) {
                          return 'please interval';
                        }
                        return null;
                      },
                      decoration: InputDecoration(hintText: "1~99"),
                      style: TextStyle(
                        fontSize: 30,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                      onFieldSubmitted: (String value) {
                        if (_formKey.currentState?.validate() != null &&
                            _formKey.currentState?.validate() == true) {
                          _savekankakupref(value);
                        }
                      },
                      maxLength: 2,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),

                  ///GOAL GET UP TIME
                  Padding(
                    padding: EdgeInsets.all(10.0),
                  ),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: <Widget>[
                        Icon(Icons.emoji_events, color: Colors.white, size: 50),
                        Text('GOAL GET UP TIME', style: styleB),
                      ]),

                  ///GOAL GET UP TIME BUTTON
                  ElevatedButton(
                    child: Text(
                      DateFormat.Hm().format(_goalgetuptime),
                      style: TextStyle(fontSize: 50),
                    ),
                    style: ElevatedButton.styleFrom(
                      primary: Colors.lightBlueAccent,
                      onPrimary: Colors.white,
                      padding:
                          EdgeInsets.symmetric(vertical: 10, horizontal: 100),
                    ),
                    onPressed: () async {
                      Picker(
                        adapter: DateTimePickerAdapter(
                            type: PickerDateTimeType.kHM,
                            value: _goalgetuptime,
                            customColumnType: [3, 4]),
                        title: Text("Select Time"),
                        onConfirm: (Picker picker, List value) {
                          setState(() => {
                                _goalgetuptime = DateTime.utc(
                                    0, 0, 0, value[0], value[1], 0),
                                _savegoalgetuptimepref(_goalgetuptime),
                                LoadPref(),
                              });
                        },
                      ).showModal(context);
                    },
                  ),
                ],
              ),
            ),

            ///Until the goal is achieved 〇 days(20%)
            ///

            Padding(
              padding: EdgeInsets.all(20.0),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.start, children: <Widget>[
              Padding(
                padding: EdgeInsets.all(20.0),
              ),
              //プログレスバー
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 75,
                    height: 75,
                    child: CircularProgressIndicator(
                      value: 0.8,
                      semanticsLabel: 'Until the Goal',
                    ),
                  ),
                  Text("100%",
                      style: TextStyle(fontSize: 20, color: Colors.white)),
                ],
              ),
            ]),
            Visibility(
              visible: _goalvisible,
              child: TextField(
                controller: _controllergoalday,
                textAlign: TextAlign.center,
                readOnly: true,
                enabled: false,
                style: const TextStyle(
                    fontSize: 40.0,
                    color: Colors.white,
                    decoration: TextDecoration.none),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(20.0),
            ),
            ///Recommended bedtime
            Text(
              'Recommended bedtime',
              style: styleB,
            ),
            //ここに目標就寝時刻を表示
            Text(DateFormat.Hm().format(_goal_bedin_time),
                style: const TextStyle(fontSize: 40.0, color: Colors.white)),
            Padding(
              padding: EdgeInsets.all(20.0),
            ),

            new Divider(
              color: Colors.white,
              thickness: 1.0,
            ),
            //開始ボタン
            SizedBox(
              width: 200, //横幅
              height: 70, //高さ
              child: ElevatedButton(
                child: Text(
                  str_starstop,
                  style: const TextStyle(
                    fontSize: 35.0,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  primary: primaryColor,
                  onPrimary: Colors.white,
                  shape: const StadiumBorder(),
                  elevation: 16,
                ),
                onPressed: buttonPressed,
              ),
            ),

          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black87,
        selectedItemColor: Colors.deepOrange,
        unselectedItemColor: Colors.orangeAccent,
        currentIndex: 0,
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(label: 'ホーム', icon: Icon(Icons.home)),
          BottomNavigationBarItem(label: '設定', icon: Icon(Icons.settings)),
          BottomNavigationBarItem(label: '履歴', icon: Icon(Icons.list)),
        ],
        onTap: (int index) {
          if (index == 1) {
            Navigator.pushNamed(context, '/setting');
          } else if (index == 2) {
            Navigator.pushNamed(context, '/list');
          }
        },
      ),
    );
  }

  Future<void> buttonPressed() async {
    //void buttonPressed() {
    alarm_flg = !alarm_flg;
    setState(() {
      primaryColor = alarm_flg ? Colors.orange : Colors.blue;
      str_starstop = alarm_flg ? '開始' : '停止';
    });
    if (alarm_flg == cns_alarm_off) {
      _saveAlarm(alarm_flg);
      await alramset();
      strStartdate = DateTime.now().toIso8601String();
      SharedPreferences.getInstance().then((SharedPreferences prefs) {
        prefs.setString('startdate', strStartdate);
      });
    } else {
      stopTheSound();
      _saveAlarm(alarm_flg);

      showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
                title: Text("Confirm"),
                content: Text("目標の時間に起きれましたか？"),
                actions: <Widget>[
                  FlatButton(
                      child: const Text('Yes'),
                      onPressed: () => Navigator.pop<String>(context, 'Yes')),
                  FlatButton(
                      child: const Text('No'),
                      onPressed: () => Navigator.pop<String>(context, 'No')),
                  FlatButton(
                      child: const Text('Cancel Alarm'),
                      onPressed: () => Navigator.pop<String>(context, 'Cancel'))
                ],
              )).then<void>((value) => resultAlert(value));
    }
  }

  void resultAlert(String value) {
    setState(() {
      switch (value) {
        case 'Yes':
          showDialog(
              context: context,
              builder: (BuildContext context) => AlertDialog(
                    title: Text("確認"),
                    content: Text("明日の起床時間を前倒しします。"),
                    actions: <Widget>[
                      FlatButton(
                          child: const Text('OK'),
                          onPressed: () =>
                              Navigator.pop<String>(context, 'Ok')),
                    ],
                  )).then<void>((value) => resultSuccess(value));
          break;
        case 'No':
          showDialog(
              context: context,
              builder: (BuildContext context) => AlertDialog(
                    title: Text("確認"),
                    content: Text("明日も同じ時刻で再チャレンジ！"),
                    actions: <Widget>[
                      FlatButton(
                          child: const Text('OK'),
                          onPressed: () =>
                              Navigator.pop<String>(context, 'Ok')),
                    ],
                  )).then<void>((value) => resultFailure(value));
          break;
        case 'Cancel':
          break;
      }
    });
  }

  //早起き成功
  void resultSuccess(String value) {
    //履歴テーブルに成功情報をセット
    saveData(cns_getupstatus_s);
    //明日の起床時間を算出・セット
    //本日の目標就寝時刻を算出
    setState(() {
      _getuptime = _getuptime.subtract(Duration(minutes: int_min_kankaku));
      _goal_bedin_time =
          _goal_bedin_time.subtract(Duration(minutes: int_min_kankaku));
    });
    _savegetuptimepref(_getuptime);
    //目標までの日数を-1
    _goal_day = _goal_day - 1;
    //目標までの日数を保存
    SharedPreferences.getInstance().then((SharedPreferences prefs) {
      prefs.setInt('goal_day', _goal_day);
    });
    //目標までの日数を画面に表示
    _controllergoalday.text = "目標まであと" + _goal_day.toString() + "日";
  }

  //早起き失敗
  void resultFailure(String value) {
    //履歴テーブルに失敗情報をセット
    saveData(cns_getupstatus_f);
  }

  //明日の起床時間をセット
  void _savegetuptimepref(DateTime value) async {
    SharedPreferences.getInstance().then((SharedPreferences prefs) {
      prefs.setString('getuptime', value.toString());
    });
  }

  //アラームon off
  void _saveAlarm(bool value) async {
    SharedPreferences.getInstance().then((SharedPreferences prefs) {
      prefs.setBool('Alarmonoff', value);
    });
  }

  void _savekankakupref(String value) async {
    SharedPreferences.getInstance().then((SharedPreferences prefs) {
      prefs.setString('kankaku', value);
    });
  }

  //目標起床時刻の保存
  void _savegoalgetuptimepref(DateTime value) async {
    SharedPreferences.getInstance().then((SharedPreferences prefs) {
      prefs.setString('goalgetuptime', value.toString());
    });
  }

  /*------------------------------------------------------------------
第一画面ロード(FirstScreen)
 -------------------------------------------------------------------*/
  void LoadPref() async {
    SharedPreferences.getInstance().then((SharedPreferences prefs) {
      setState(() {
        //アラームボタン
        alarm_flg = prefs.getBool('Alarmonoff') ?? false;
        primaryColor = alarm_flg ? Colors.orange : Colors.blue;
        str_starstop = alarm_flg ? 'START' : 'STOP';

        //起床時間の取得
        String? str_getuptime = prefs.getString('getuptime');
        if (str_getuptime != null && str_getuptime != "") {
          _getuptime = DateTime.parse(str_getuptime);
        } else {
          _getuptime = DateTime.utc(0, 0, 0, 6, 0);
          SharedPreferences.getInstance().then((SharedPreferences prefs) {
            prefs.setString('getuptime', _getuptime.toString());
          });
        }
        ;
        //間隔の取得
        if (prefs.getString('kankaku') != null &&
            prefs.getString('kankaku') != "") {
          int_min_kankaku = int.parse(prefs.getString('kankaku')!);
          _controllerTitle.text = 'Get up early by ' +
              (prefs.getString('kankaku') ?? '') +
              ' minute every day';
        } else {
          _controllerTitle.text = 'Get up early by 1 minute every day';
          SharedPreferences.getInstance().then((SharedPreferences prefs) {
            prefs.setString('kankaku', "1");
          });
        }
        //目標までの日にち算出
        int amari = 0;
        int _diffmin;
        //最終目標の起床時間を取得
        //明日の起床時刻の取得
        String? str_goalgetuptime = prefs.getString('goalgetuptime');
        if (str_goalgetuptime != null && str_goalgetuptime != "") {
          _goalgetuptime = DateTime.parse(str_goalgetuptime);
        } else {
          _goalgetuptime = DateTime.utc(0, 0, 0, 6, 0);
          SharedPreferences.getInstance().then((SharedPreferences prefs) {
            prefs.setString('goalgetuptime', _goalgetuptime.toString());
          });
        }
        ;
        if (_goalgetuptime != DateTime.utc(0, 0, 0, 0, 0)) {
          //目標起床時刻がセットされていれば目標までの日数を表示する
          _goalvisible = true;
          //目標起床時間 - 現在起床時間
          _diffmin = _getuptime.difference(_goalgetuptime).inMinutes;
          //目標までの時間（分）を間隔（分）で割、目標までの日数を計算する
          if (int_min_kankaku != 0) {
            _goal_day = _diffmin ~/ int_min_kankaku;
            amari = _diffmin % int_min_kankaku;
            if (amari != 0) {
              _goal_day = _goal_day + 1;
            }
          }
          //目標までの日数を保存
          SharedPreferences.getInstance().then((SharedPreferences prefs) {
            prefs.setInt('goal_day', _goal_day);
          });
          //目標までの日数を画面に表示
          _controllergoalday.text = "目標まで後" + _goal_day.toString() + "日";
        } else {
          //目標起床時刻がセットされていれば目標までの日数を非表示にする
          _goalvisible = false;
        }
        //目標睡眠時間の取得
        DateTime _goalsleeptime;
        String? str_goalsleep = prefs.getString('goalsleeptime');
        if (str_goalsleep != null && str_goalsleep != "") {
          _goalsleeptime = DateTime.parse(str_goalsleep);
        } else {
          _goalsleeptime = DateTime.utc(0, 0, 0, 6, 0);
          SharedPreferences.getInstance().then((SharedPreferences prefs) {
            prefs.setString('goalsleeptime', _goalsleeptime.toString());
          });
        }
        ;
        //目標就寝時刻の算出
        //目標睡眠時間 - 明日の起床時刻
        int sleeptime_hour = _goalsleeptime.hour;
        int sleeptime_min = _goalsleeptime.minute;
        _goal_bedin_time = _getuptime
            .subtract(Duration(hours: sleeptime_hour, minutes: sleeptime_min));
        //_goalsleeptime.minute
        //間隔の取得
        if (prefs.getString('kankaku') != null &&
            prefs.getString('kankaku') != "") {
          int_min_kankaku = int.parse(prefs.getString('kankaku')!);
          _text_controller_kankaku.text = prefs.getString('kankaku')!;
        } else {
          int_min_kankaku = 1;
          _text_controller_kankaku.text = "1";
          SharedPreferences.getInstance().then((SharedPreferences prefs) {
            prefs.setString('kankaku', "1");
          });
        }
        ;
      });
    });
  }

  void saveData(String status) async {
    String dbPath = await getDatabasesPath();
    String path = p.join(dbPath, 'rireki.db');
    // String? strStartdate;
    // SharedPreferences.getInstance().then(
    //         (SharedPreferences prefs) {
    //           strStartdate = prefs.getString('startdate');
    //         }
    // );
    String? str_getuptime;
    // str_goalgetuptime = DateFormat('hh:mm').format(_goalgetuptime);
    str_getuptime = _getuptime.toIso8601String();
    String query =
        'INSERT INTO rireki(date,getupstatus, goalgetuptime,realgetuptime,goalbedintime,realbedintime,sleeptime) values("$strStartdate","$status","$str_getuptime",null,null,null,null)';
    // Database database = await openDatabase(path, version: 1,
    //     onCreate: (Database db, int version) async {
    //       await db.execute(
    //           "DROP TABLE mydata;"
    //       );
    //     }
    // );
    Database database = await openDatabase(path, version: 1,
        onCreate: (Database db, int version) async {
      await db.execute(
          "CREATE TABLE IF NOT EXISTS rireki(id INTEGER PRIMARY KEY, date TEXT, getupstatus TEXT, goalgetuptime TEXT, realgetuptime TEXT, goalbedintime TEXT, realbedintime TEXT, sleeptime TEXT)");
    });

    await database.transaction((txn) async {
      int id = await txn.rawInsert(query);
      //   print("insert: $id");
    });
  }
}

class SecondScreen extends StatefulWidget {
  SecondScreen({Key? key}) : super(key: key); //コンストラクタ

  @override
  _SecondScreenState createState() => new _SecondScreenState();
}

/*------------------------------------------------------------------
設定画面(SecondScreen)
 -------------------------------------------------------------------*/
class _SecondScreenState extends State<SecondScreen> {
  List<Widget> _items = <Widget>[];

  final TextStyle styleB = TextStyle(fontSize: 35.0, color: Colors.white);
  DateTime _goalsleeptime = DateTime.utc(0, 0, 0);
  DateTime _getuptime = DateTime.utc(0, 0, 0);
  int int_min_kankaku = 1;

  @override
  void initState() {
    super.initState();
    LoadPref_second();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Setting'),
      ),
      body: SingleChildScrollView(
        child: Form(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.all(20.0),
                ),
                Text(
                  'Setting',
                  style: styleB,
                ),
                Text(
                  '確保したい睡眠時間',
                  style: styleB,
                ),
                TextButton(
                  child: Text(DateFormat.Hm().format(_goalsleeptime),
                      style:
                          const TextStyle(fontSize: 40.0, color: Colors.white)),
                  onPressed: () async {
                    Picker(
                      adapter: DateTimePickerAdapter(
                          type: PickerDateTimeType.kHM,
                          value: _goalsleeptime,
                          customColumnType: [3, 4]),
                      title: Text("Select Time"),
                      onConfirm: (Picker picker, List value) {
                        setState(() => {
                              _goalsleeptime =
                                  DateTime.utc(0, 0, 0, value[0], value[1], 0),
                              _savegoalsleeptimepref(_goalsleeptime),
                            });
                      },
                    ).showModal(context);
                  },
                ),
                Padding(
                  padding: EdgeInsets.all(20.0),
                ),
                Text(
                  '起床時のアラーム音',
                  style: styleB,
                ),
              ]),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black87,
        selectedItemColor: Colors.deepOrange,
        unselectedItemColor: Colors.orangeAccent,
        currentIndex: 1,
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(label: 'ホーム', icon: Icon(Icons.home)),
          BottomNavigationBarItem(label: '設定', icon: Icon(Icons.settings)),
          BottomNavigationBarItem(label: '履歴', icon: Icon(Icons.list)),
        ],
        onTap: (int index) {
          if (index == 0) {
            Navigator.pushNamed(context, '/');
          } else if (index == 2) {
            Navigator.pushNamed(context, '/list');
          }
        },
      ),
    );
  }

/*------------------------------------------------------------------
設定画面(SecondScreen) プライベートメソッド
 -------------------------------------------------------------------*/
  //目標睡眠時間保存
  void _savegoalsleeptimepref(DateTime value) async {
    //目標睡眠時間保存
    SharedPreferences.getInstance().then((SharedPreferences prefs) {
      prefs.setString('goalsleeptime', value.toString());
    });
  }

  void LoadPref_second() async {
    SharedPreferences.getInstance().then((SharedPreferences prefs) {
      setState(() {
        //起床時間の取得
        String? str_getuptime = prefs.getString('getuptime');
        if (str_getuptime != null && str_getuptime != "") {
          _getuptime = DateTime.parse(str_getuptime);
        } else {
          _getuptime = DateTime.utc(0, 0, 0, 6, 0);
          SharedPreferences.getInstance().then((SharedPreferences prefs) {
            prefs.setString('getuptime', _getuptime.toString());
          });
        }
        ;
        //目標睡眠時間の取得
        String? str_goalsleep = prefs.getString('goalsleeptime');
        if (str_goalsleep != null && str_goalsleep != "") {
          _goalsleeptime = DateTime.parse(str_goalsleep);
        } else {
          _goalsleeptime = DateTime.utc(0, 0, 0, 6, 0);
          SharedPreferences.getInstance().then((SharedPreferences prefs) {
            prefs.setString('goalsleeptime', _goalsleeptime.toString());
          });
        }
        ;
      });
    });
  }
}

class ThirdScreen extends StatefulWidget {
  ThirdScreen({Key? key}) : super(key: key); //コンストラクタ
  @override
  _ThirdScreenState createState() => new _ThirdScreenState();
}

class _ThirdScreenState extends State<ThirdScreen> {
  List<Widget> _items = <Widget>[];

  //List<Map> result = [];
  @override
  void initState() {
    super.initState();
    getItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: Text('履歴'),
      // ),
      body: new Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.all(20.0),
          ),
          _listHeader(),
          Expanded(
            child: ListView(
              children: _items,
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black87,
        selectedItemColor: Colors.deepOrange,
        unselectedItemColor: Colors.orangeAccent,
        currentIndex: 2,
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(label: 'ホーム', icon: Icon(Icons.home)),
          BottomNavigationBarItem(label: '設定', icon: Icon(Icons.settings)),
          BottomNavigationBarItem(label: '履歴', icon: Icon(Icons.list)),
        ],
        onTap: (int index) {
          if (index == 0) {
            Navigator.pushNamed(context, '/');
          } else if (index == 1) {
            Navigator.pushNamed(context, '/setting');
          }
        },
      ),
    );
  }

  Widget _listHeader() {
    return Container(
        decoration: new BoxDecoration(
            border:
                new Border(bottom: BorderSide(width: 1.0, color: Colors.grey))),
        child: ListTile(
            title: new Row(children: <Widget>[
          new Expanded(
              child: new Text("日付",
                  style: new TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold))),
          new Expanded(
              child: new Text("時刻",
                  style: new TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold))),
        ])));
  }

  void getItems() async {
    List<Widget> list = <Widget>[];
    String dbpath = await getDatabasesPath();
    String path = p.join(dbpath, "rireki.db");

    Database database = await openDatabase(path, version: 1,
        onCreate: (Database db, int version) async {
      await db.execute(
          "CREATE TABLE IF NOT EXISTS rireki(id INTEGER PRIMARY KEY, date TEXT, getupstatus TEXT, goalgetuptime TEXT, realgetuptime TEXT, goalbedintime TEXT, realbedintime TEXT, sleeptime TEXT)");
    });
    List<Map> result = await database
        .rawQuery('SELECT id,date,getupstatus,goalgetuptime FROM rireki');
    // List<Map> result = await database.rawQuery('SELECT * FROM rireki');
    for (Map item in result) {
      list.add(ListTile(
        tileColor: (item['getupstatus'].toString() == cns_getupstatus_s)
            ? Colors.green
            : Colors.red,
        leading: (item['getupstatus'].toString() == cns_getupstatus_s)
            ? Icon(Icons.thumb_up)
            : Icon(Icons.south),
        subtitle: Text(item['id'].toString() +
            ' ' +
            DateFormat('yyyy/MM/dd').format(DateTime.parse(item['date'])) +
            ' ' +
            DateFormat('HH:MM').format(DateTime.parse(item['goalgetuptime']))),
      ));
    }
    setState(() {
      _items = list;
    });
  }
}
