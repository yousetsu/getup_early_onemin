import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/services.dart';
import 'package:flutter_picker/flutter_picker.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import "package:intl/intl.dart";
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:ui';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/cupertino.dart';
import 'package:rxdart/subjects.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'dart:io';
import 'package:fluttertoast/fluttertoast.dart';

import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

import 'package:file_picker/file_picker.dart';

late AudioPlayer _player;
String strSePath = "";

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

const int helloAlarmID = 19820822;
const String cnsGetupStatusS = '1';
const String cnsGetupStatusF = '0';
const bool cnsAlarmOn = true;
const bool cnsAlarmOff = false;
bool flgFirstRun = true;
//SQL
const String strCnsSqlCreateSetting ="CREATE TABLE IF NOT EXISTS setting(id INTEGER PRIMARY KEY, firstrun TEXT,getuptime TEXT,alarmon TEXT,kankaku INTEGER,goalgetuptime TEXT,goalsleeptime TEXT,rewardcnt INTEGER,sleepalarmtime TEXT,goalday INTEGER,mpath TEXT)";
const String strCnsSqlInsDefSetting = "INSERT INTO setting(firstrun,getuptime,alarmon,kankaku,goalgetuptime,goalsleeptime,rewardcnt,sleepalarmtime,goalday,mpath) values('X' ,'2016-05-01 07:00:00.000Z','',1,'2016-05-01 06:00:00.000Z','2016-05-01 07:30:00.000Z',0,'',0,'mpath/test')";

const String strCnsSqlCreateRireki ="CREATE TABLE IF NOT EXISTS rireki(id INTEGER PRIMARY KEY, date TEXT, getupstatus TEXT, goalgetuptime TEXT, realgetuptime TEXT, goalbedintime TEXT, realbedintime TEXT, sleeptime TEXT)";
const String strCnsRadDefSound = "DefaultSound";
const String strCnsRadSelMusic = "SelectMusic";


//広告ID
//test
const String strCnsBannerID = 'ca-app-pub-3940256099942544/6300978111'; //Banner
const String strCnsRewardID = 'ca-app-pub-3940256099942544/5224354917'; //Reward
//本番
//const String strCnsBannerID = 'ca-app-pub-8759269867859745/2745032231'; //banner
//const String strCnsRewardID = 'ca-app-pub-8759269867859745/8740337207'; //Reward
RewardedAd? _rewardedAd;
int _numRewardedLoadAttempts = 0;
/*------------------------------------------------------------------
起動
 -------------------------------------------------------------------*/
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _configureLocalTimeZone();
  final NotificationAppLaunchDetails? notificationAppLaunchDetails = !kIsWeb &&
          Platform.isLinux
      ? null
      : await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
  if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
    selectedNotificationPayload = notificationAppLaunchDetails!.payload;
  }
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings,
      onSelectNotification: (String? payload) async {
    if (payload != null) {
      debugPrint('notification payload: $payload');
    }
    selectedNotificationPayload = payload;
    selectNotificationSubject.add(payload);
  });
  //広告初期化
  WidgetsFlutterBinding.ensureInitialized();
  //final initFuture = MobileAds.instance.initialize();
  MobileAds.instance.initialize();
  runApp(const MyApp());
  //初回DB登録
  _firstrun();

}
/*------------------------------------------------------------------
全共通のメソッド
 -------------------------------------------------------------------*/
Future<void> _configureLocalTimeZone() async {
  if (kIsWeb || Platform.isLinux) {
    return;
  }
  tz.initializeTimeZones();
  final String timeZoneName = await FlutterNativeTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(timeZoneName));
}
//初回起動分の処理
Future<void> _firstrun() async {
  String dbpath = await getDatabasesPath();
  //履歴テーブル作成
  String path = p.join(dbpath, "rireki.db");
  Database database = await openDatabase(path, version: 1,
      onCreate: (Database db, int version) async {
        await db.execute(strCnsSqlCreateRireki);
      });
  //設定テーブル作成
  path = p.join(dbpath, "setting.db");
  database = await openDatabase(path, version: 1,
      onCreate: (Database db, int version) async {
        await db.execute(strCnsSqlCreateSetting);
      });
  List<Map> result = await database.rawQuery('SELECT mpath FROM setting where id =1');
  if (result.isEmpty){
    //設定テーブル初期値設定
    String query = strCnsSqlInsDefSetting;
    await database.transaction((txn) async {
      //int id = await txn.rawInsert(query);
      await txn.rawInsert(query);
    });
  }
}
void _createRewardedAd() {
  RewardedAd.load(
      adUnitId: strCnsRewardID,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
        //  print('$ad loaded.');
          _rewardedAd = ad;
          _numRewardedLoadAttempts = 0;
        },
        onAdFailedToLoad: (LoadAdError error) {
        //  print('RewardedAd failed to load: $error');
          _rewardedAd = null;
          _numRewardedLoadAttempts += 1;
          if (_numRewardedLoadAttempts < maxFailedLoadAttempts) {
            _createRewardedAd();
          }
        },
      ));
}
//-------------------------------------------------------------
//   DB処理
//-------------------------------------------------------------
//設定テーブルにデータ保存
void _saveStrSetting(String field ,String value) async {
  String dbPath = await getDatabasesPath();
  String path = p.join(dbPath, 'setting.db');
  Database database = await openDatabase(path, version: 1,
      onCreate: (Database db, int version) async {
        await db.execute(strCnsSqlCreateSetting);
      });
  String query = "UPDATE setting set $field = '$value' where id = 1 ";
  await database.transaction((txn) async {
    //int id = await txn.rawInsert(query);
    await txn.rawInsert(query);
    //   print("insert: $id");
  });
}
void _saveIntSetting(String field ,int value) async {
  String dbPath = await getDatabasesPath();
  String path = p.join(dbPath, 'setting.db');
  Database database = await openDatabase(path, version: 1,
      onCreate: (Database db, int version) async {
        await db.execute(strCnsSqlCreateSetting);
      });
  String query = "UPDATE setting set $field = '$value' where id = 1 ";
  await database.transaction((txn) async {
    //int id = await txn.rawInsert(query);
    await txn.rawInsert(query);
    //   print("insert: $id");
  });
}
Future<String?> _loadStrSetting(String field) async{
  String? strValue = "";
  String dbPath = await getDatabasesPath();
  String path = p.join(dbPath, 'setting.db');
  Database database = await openDatabase(path, version: 1,
      onCreate: (Database db, int version) async {
        await db.execute(strCnsSqlCreateSetting);
      });
  List<Map> result = await database.rawQuery("SELECT $field From setting where id = 1 ");
  for (Map item in result) {
    strValue = item[field].toString();
  }
  return strValue;
}
Future<int?> _loadIntSetting(String field) async{
  int? intValue = 0;
  String dbPath = await getDatabasesPath();
  String path = p.join(dbPath, 'setting.db');
  Database database = await openDatabase(path, version: 1,
      onCreate: (Database db, int version) async {
        await db.execute(strCnsSqlCreateSetting);
      });
  List<Map> result = await database.rawQuery("SELECT $field From setting where id = 1 ");
  for (Map item in result) {
    intValue = item[field];
  }
  return intValue;
}
/*------------------------------------------------------------------
第メイン画面(MainScreen)
 -------------------------------------------------------------------*/
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Generated App',
      theme: ThemeData(
        primaryColor: const Color(0xFF2196f3),
        hintColor: const Color(0xFF2196f3),
        canvasColor: const Color(0xFF515254),
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.blue).copyWith(secondary: const Color(0xFF2196f3)),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const FirstScreen(),
        '/setting': (context) => const SecondScreen(),
        '/list': (context) => const ThirdScreen(),
      },
    );
  }
}
/*------------------------------------------------------------------
第一画面(FirstScreen)
 -------------------------------------------------------------------*/
class FirstScreen extends StatefulWidget {
  const FirstScreen({Key? key}) : super(key: key); //コンストラクタ
  @override
  State<FirstScreen> createState() =>  _FirstScreenState();
}
class _FirstScreenState extends State<FirstScreen> {
  final _controllerTitle = TextEditingController();
  final _controllergoalday = TextEditingController();
  final _textControllerKankaku = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  DateTime _getuptime = DateTime.utc(0, 0, 0);
  DateTime _goalgetuptime = DateTime.utc(0, 0, 0);
  DateTime _goal_bedin_time = DateTime.utc(0, 0, 0);
  int intMinKankaku = 1;
  int _goal_day = 0;
  bool alarm_flg = false;
  MaterialColor primaryColor = Colors.orange;
  String strStarstop = '開始';

  //現在日付
  final TextStyle styleA = const TextStyle(fontSize: 28.0, color: Colors.white,);
  final TextStyle styleB = const TextStyle(fontSize: 15.0, color: Colors.white);
  @override
  void initState() {
   // _getuptime = DateTime.now();
    super.initState();
    AndroidAlarmManager.initialize();
    loadPref();
  }
  stopTheSound() async {
    await flutterLocalNotificationsPlugin.cancel(helloAlarmID);
    await AndroidAlarmManager.oneShot(
        const Duration(seconds: 0), helloAlarmID, stopSound,
        exact: true, wakeup: true, alarmClock: true, allowWhileIdle: true);
  }
  static stopSound() async {
    _player.stop();
  }
  // The callback for our alarm
  static Future<void> callSoundStart() async {
    String? strSePath = null;
    strSePath = await _loadStrSetting('mpath');

    _player = AudioPlayer();
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    await _player.setLoopMode(LoopMode.all);
    if(strSePath != null && strSePath != "") {
      await _player.setFilePath(strSePath);
    }else{
      await _player.setAsset('assets/alarm.mp3');
    }
    await _player.play();
  }
  //アラームのセット
  Future<void> alramset() async {
    DateTime nowtime;
    DateTime getupalarmtime;
    int hour;
    int minute;
    int second;
    int diffSecond = 0;
    int hourNow;
    int minuteNow;
    int secondNow;
    String strNowtime;
    String strGetuptime;
    String strDate;
    String strDatePlusone;
    strDate = '2022-01-16 ';
    strDatePlusone = '2022-01-17 ';
    //現在時間の算出
    hourNow = DateTime.now().hour;
    minuteNow = DateTime.now().minute;
    secondNow = DateTime.now().second;
    strNowtime = '$strDate${hourNow.toString().padLeft(2, '0')}:${minuteNow.toString().padLeft(2, '0')}:${secondNow.toString().padLeft(2, '0')}.0';
    nowtime = DateTime.parse(strNowtime);
    //起床したい時刻の算出
    hour = _getuptime.hour;
    minute = _getuptime.minute;
    second = _getuptime.second;
    strGetuptime = '$strDate${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:${second.toString().padLeft(2, '0')}.0';
    getupalarmtime = DateTime.parse(strGetuptime);
    //起床したい時刻 - 現時刻
    diffSecond = getupalarmtime.difference(nowtime).inSeconds;
    if (diffSecond >= 0) {
      //現時刻が起床日当日になっている場合はそのままでOK
      //(ほとんどありえないケース)
    } else {
      //現時刻が起床日前日になっている場合(ほとんどこのケース)
      strGetuptime = '$strDatePlusone${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2,'0')}:${second.toString().padLeft(2, '0')}.0';
      getupalarmtime = DateTime.parse(strGetuptime);
      diffSecond = getupalarmtime.difference(nowtime).inSeconds;
    }
    await AndroidAlarmManager.oneShot(
      Duration(seconds: diffSecond),
      helloAlarmID,
      callSoundStart,
      alarmClock: true,
      allowWhileIdle: true,
      exact: true,
      wakeup: true,
    );
    await flutterLocalNotificationsPlugin.zonedSchedule(
        helloAlarmID,
        'Baby steps early get up!',
        'it\' s morning!',
        tz.TZDateTime.now(tz.local).add(Duration(seconds: diffSecond)),
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
    int intHour;
    int intHourAmariSec;
    int intMinute;
    int intSecond;
    intHour = (diffSecond / 3600).floor();
    intHourAmariSec = (diffSecond % 3600).floor();
    intMinute = (intHourAmariSec / 60).floor();
    intSecond = (intHourAmariSec % 60).floor();
    Fluttertoast.showToast(msg: '${intHour.toString()}hours${intMinute.toString()}minutes${intSecond.toString()}alarm set');
  }
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controllerTitle,
          textAlign: TextAlign.center,
          readOnly: true,
          enabled: false,
          style: const TextStyle(fontSize: 20.0, color: Colors.white, decoration: TextDecoration.none),
        ),
        automaticallyImplyLeading: false, //戻るボタン非表示
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Container(
              margin: const EdgeInsets.all(20.0),
              padding: const EdgeInsets.all(15.0),
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
                        const Icon(Icons.alarm, color: Colors.white, size: 35),
                        Text('TOMMOROW GET UP TIME', style: styleB),
                      ]),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(primary: Colors.lightBlueAccent, onPrimary: Colors.white, padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 80),),
                    onPressed: () async {
                      Picker(
                        adapter: DateTimePickerAdapter(
                            type: PickerDateTimeType.kHM,
                            value: DateTime.parse(_getuptime.toString()),
                            customColumnType: [3, 4]),
                        title: const Text("Select Time"),
                        onConfirm: (Picker picker, List value) {
                          setState(() => {
                                _getuptime = DateTime.utc(2016, 5, 1, value[0], value[1], 0),
                            _saveStrSetting('getuptime',_getuptime.toString()),
                                loadPref(),
                              });
                        },
                      ).showModal(context);
                    },
                    child: Text(DateFormat.Hm().format(_getuptime), style: const TextStyle(fontSize: 35),)
                  ),
                  ///INTERVAL
                  const Padding(padding: EdgeInsets.all(5.0),),
                  Row(mainAxisAlignment: MainAxisAlignment.start,
                      children: <Widget>[const Icon(Icons.watch_later, color: Colors.white, size: 35), Text('INTERVAL(Minutes)', style: styleB),]),
                  Container(
                    padding: const EdgeInsets.all(5.0),
                    alignment: Alignment.bottomCenter,
                    width: 150.0,
                    height: 70,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.lightBlueAccent),
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.lightBlueAccent,
                    ),
                    child:Form(
                      key: _formKey,
                    child: TextFormField(
                      controller: _textControllerKankaku,
                      //ここに初期値
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value != null && value.isEmpty) {
                          return 'Please Interval';
                        }else if(int.parse(value!) > 180){
                          return 'Please input 1 - 180';
                        }
                        return null;
                      },
                     // decoration: InputDecoration(hintText: "1~180"),
                      style: const TextStyle(fontSize: 25, color: Colors.white,),
                      textAlign: TextAlign.center,
                      onFieldSubmitted: (String value) {
                        if (_formKey.currentState?.validate() != null &&
                            _formKey.currentState?.validate() == true) {
                          _saveIntSetting('kankaku',int.parse(value));
                          loadPref();
                        }
                      },
                      maxLength: 3,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    ),
                  ),
                  ///GOAL GET UP TIME
                  const Padding(padding: EdgeInsets.all(5),),
                  Row(mainAxisAlignment: MainAxisAlignment.start,
                      children: <Widget>[const Icon(Icons.emoji_events, color: Colors.white, size: 35), Text('GOAL GET UP TIME', style: styleB),
                      ]),
                  ///GOAL GET UP TIME BUTTON
                  ElevatedButton(
                    child: Text(DateFormat.Hm().format(_goalgetuptime), style: TextStyle(fontSize: 35),),
                    style: ElevatedButton.styleFrom(primary: Colors.lightBlueAccent, onPrimary: Colors.white, padding: EdgeInsets.symmetric(vertical: 8, horizontal: 80),),
                    onPressed: () async {
                      Picker(
                        adapter: DateTimePickerAdapter(
                            type: PickerDateTimeType.kHM,
                            value: _goalgetuptime,
                            customColumnType: [3, 4]),
                        title: const Text("Select Time"),
                        onConfirm: (Picker picker, List value) {
                          setState(() => {
                            _goalgetuptime = DateTime.utc(2016, 5, 1, value[0], value[1], 0),
                            _saveStrSetting('goalgetuptime',_goalgetuptime.toString()),
                            loadPref(),
                              });
                        },
                        onSelect: (Picker picker, int index, List<int> selected){
                          _goalgetuptime = DateTime.utc(2016, 5, 1, selected[0], selected[1], 0);
                        }
                      ).showModal(context);
                    },
                  ),
                ],
              ),
            ),
            ///Until the goal is achieved 〇 days
            Row(
                mainAxisAlignment: MainAxisAlignment.start, children: <Widget>[
              const Padding(padding: EdgeInsets.all(20),),
              const Icon(Icons.calendar_month, color: Colors.red, size: 35),
              const Padding(padding: EdgeInsets.all(10),),
                   SizedBox(width: 50, child: TextField(controller: _controllergoalday,
                       readOnly: true,
                       enabled: false,
                       style: const TextStyle(fontSize: 30.0, color: Colors.white, decoration: TextDecoration.none),
                ),
              ),
              Text('  DAYS TO GO', style: styleB,),
            ]),
             const Divider(color: Colors.white, thickness: 1.0,),
            ///Recommended bedtime
      Row(
        mainAxisAlignment: MainAxisAlignment.start, children: <Widget>[
          const Padding(padding: EdgeInsets.all(20),),
        const Icon(Icons.bedtime, color: Colors.yellow, size: 35),
        const Padding(padding: EdgeInsets.all(10),),
            Text('Recommended Bedtime', style: styleB,),
            ]),
            //ここに目標就寝時刻を表示
            Text(DateFormat.Hm().format(_goal_bedin_time), style: const TextStyle(fontSize: 35.0, color: Colors.white)),
            const Padding(padding: EdgeInsets.all(5.0),),
            const Divider(color: Colors.white, thickness: 1.0,),
            //開始ボタン
            SizedBox(
              width: 200, height: 70,
              child: ElevatedButton(
                child: Text( strStarstop, style: const TextStyle(fontSize: 35.0, color: Colors.white,),),
                style: ElevatedButton.styleFrom(primary: primaryColor, onPrimary: Colors.white, shape: const StadiumBorder(), elevation: 16,),
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
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(label: 'Home', icon: Icon(Icons.home)),
          BottomNavigationBarItem(label: 'Setting', icon: Icon(Icons.settings)),
          BottomNavigationBarItem(label: 'History', icon: Icon(Icons.list)),
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
      primaryColor = alarm_flg ?  Colors.blue:Colors.orange;
      strStarstop = alarm_flg ?  'STOP':'START';
    });
    if (alarm_flg == cnsAlarmOn) {
      _saveStrSetting('alarmon','X');
      await alramset();
    } else {
      stopTheSound();
      _saveStrSetting('alarmon','');
      showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
                title: const Text("Confirm"),
                content: const Text("Did you wake up at your target time?"),
                actions: <Widget>[
                  TextButton(
                      child: const Text('Yes'),
                      onPressed: () => Navigator.pop<String>(context, 'Yes')),
                  TextButton(
                      child: const Text('No'),
                      onPressed: () => Navigator.pop<String>(context, 'No')),
                  TextButton(
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
          showDialog(context: context,
              builder: (BuildContext context) => AlertDialog(
                    title: const Text("Confirm"),
                    content: const Text("Move forward tomorrow's wake-up time"),
                    actions: <Widget>[
                      TextButton(
                          child: const Text('OK'),
                          onPressed: () => Navigator.pop<String>(context, 'Ok')),
                    ],
                  )).then<void>((value) => resultSuccess(value));
          break;
        case 'No':
          showDialog(context: context,
              builder: (BuildContext context) => AlertDialog(title: const Text("Confirm"),
                    content: const Text("Re-challenge tomorrow at the same time!"),
                    actions: <Widget>[
                      TextButton(
                          child: const Text('OK'),
                          onPressed: () => Navigator.pop<String>(context, 'Ok')),
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
    String? strGetuptime;
    strGetuptime = _getuptime.toIso8601String();
    saveData(cnsGetupStatusS,strGetuptime);
    //明日の起床時間を算出・セット
    //本日の目標就寝時刻を算出
    setState(() {
      _getuptime = _getuptime.subtract(Duration(minutes: intMinKankaku));
      _goal_bedin_time = _goal_bedin_time.subtract(Duration(minutes: intMinKankaku));
    });
    _saveStrSetting( 'goalgetuptime',_goalgetuptime.toString());
    //目標までの日数を-1
    setState(() {_goal_day = _goal_day - 1;});
    //目標までの日数を保存
    _saveIntSetting('goalday',_goal_day);

    //目標までの日数を画面に表示
    setState(() {_controllergoalday.text = 'Until the goal is achieved"${_goal_day.toString()}days';});
  }
  //早起き失敗
  void resultFailure(String value) {
    String? strGetuptime;
    strGetuptime = _getuptime.toIso8601String();
    //履歴テーブルに失敗情報をセット
    saveData(cnsGetupStatusF,strGetuptime);
  }
  /*------------------------------------------------------------------
第一画面ロード(FirstScreen)
 -------------------------------------------------------------------*/
  void loadPref() async {
    //起床時間
    String? strGetuptime = await _loadStrSetting('getuptime');
    if (strGetuptime != null && strGetuptime != "") {
      setState(()  {_getuptime = DateTime.parse(strGetuptime);});
    }
    //間隔の取得
    int? intKankaku = await _loadIntSetting("kankaku");
    setState(()  {
      intMinKankaku = intKankaku!;
      _textControllerKankaku.text = intMinKankaku.toString();
      _controllerTitle.text = 'Get up early by $intMinKankaku minute every day';
    });
    //アラーム
    String? strAlarmon = await _loadStrSetting("alarmon");
    setState(()  {
      if (strAlarmon != null && strAlarmon.compareTo("X") == 0) {
        alarm_flg = true;
      } else {
        alarm_flg = false;
      }
    });
    setState(()  {
      primaryColor = alarm_flg ? Colors.blue : Colors.orange;
      strStarstop = alarm_flg ? 'STOP' : 'START';
    });
      //目標起床時間
      String? strGoalgetuptime = await _loadStrSetting("goalgetuptime");
      if (strGoalgetuptime != null && strGoalgetuptime != "") {
        setState(()  {_goalgetuptime = DateTime.parse(strGoalgetuptime);});
      }
       int amari = 0;
       int diffmin;
      if (_goalgetuptime != DateTime.utc(0, 0, 0, 0, 0)) {
        //目標起床時間 - 現在起床時間
        diffmin = _getuptime.difference(_goalgetuptime).inMinutes;
        //目標までの時間（分）を間隔（分）で割、目標までの日数を計算する
        if (intMinKankaku != 0) {
          setState(()  {_goal_day = diffmin ~/ intMinKankaku;});
          amari = diffmin % intMinKankaku;
          if (amari != 0) {
            setState(()  {_goal_day = _goal_day + 1;});
          }
        }
        //目標までの日数を保存
        _saveIntSetting('goalday', _goal_day);
        //目標までの日数を画面に表示
        setState(() {_controllergoalday.text = _goal_day.toString();});
      }
      //目標睡眠時間の取得
      DateTime goalsleeptime = DateTime.utc(0, 0, 0, 0, 0);
      String? strGoalsleep = await _loadStrSetting("goalsleeptime");
      if (strGoalsleep != null && strGoalsleep != "") {
        goalsleeptime = DateTime.parse(strGoalsleep);
      }
      //目標就寝時刻の算出
      //目標睡眠時間 - 明日の起床時刻
      int sleeptimeHour = goalsleeptime.hour;
      int sleeptimeMin = goalsleeptime.minute;
      setState(() {
      _goal_bedin_time = _getuptime.subtract(Duration(hours: sleeptimeHour, minutes: sleeptimeMin));
      });
  }
/*------------------------------------------------------------------
データベースへの保存
 -------------------------------------------------------------------*/
  void saveData(String status ,String strGetuptime) async {
    String dbPath = await getDatabasesPath();
    String path = p.join(dbPath, 'rireki.db');
    String strnowdate = DateTime.now().toIso8601String();

    Database database = await openDatabase(path, version: 1,
        onCreate: (Database db, int version) async {
      await db.execute(strCnsSqlCreateRireki);
    });
    String query =
        'INSERT INTO rireki(date,getupstatus, goalgetuptime,realgetuptime,goalbedintime,realbedintime,sleeptime) values("$strnowdate","$status","$strGetuptime",null,null,null,null)';

    await database.transaction((txn) async {
//      int id = await txn.rawInsert(query);
        await txn.rawInsert(query);
      //   print("insert: $id");
    });
  }
}
class SecondScreen extends StatefulWidget {
  const SecondScreen({Key? key}) : super(key: key); //コンストラクタ
  @override
  State<SecondScreen> createState() =>  _SecondScreenState();
  //_SecondScreenState createState() =>  _SecondScreenState();
}
/*------------------------------------------------------------------
設定画面(SecondScreen)
 -------------------------------------------------------------------*/
class _SecondScreenState extends State<SecondScreen> {
  final TextStyle styleA = const TextStyle(fontSize: 20.0, color: Colors.white);
  final TextStyle styleB = const TextStyle(fontSize: 15.0, color: Colors.white);
  DateTime _goalsleeptime = DateTime.utc(0, 0, 0);
  DateTime _getuptime = DateTime.utc(0, 0, 0);
  String? strSelectMusicName = "";
  bool isEnable = false;
  String? _type = '';

  //バナー広告初期化
  final BannerAd myBanner = BannerAd(
    adUnitId : strCnsBannerID,
    size: AdSize.banner,
    request: const AdRequest(),
    listener: BannerAdListener(
      onAdLoaded: (Ad ad) => print('バナー広告がロードされました'),
      // Called when an ad request failed.
      onAdFailedToLoad: (Ad ad, LoadAdError error) {
        // Dispose the ad here to free resources.
        ad.dispose();
        print('バナー広告の読み込みが次の理由で失敗しました: $error');
      },
      // Called when an ad opens an overlay that covers the screen.
      onAdOpened: (Ad ad) => print('バナー広告が開かれました'),
      // Called when an ad removes an overlay that covers the screen.
      onAdClosed: (Ad ad) => print('バナー広告が閉じられました'),
      // Called when an impression occurs on the ad.
      onAdImpression: (Ad ad) => print('Ad impression.'),
    ),
  );
  void _showRewardedAdMusic() {
     if (_rewardedAd == null) {
        // print('Warning: attempt to show rewarded before loaded.');
        return;
      }
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (RewardedAd ad) =>
            print('ad onAdShowedFullScreenContent.'),
        onAdDismissedFullScreenContent: (RewardedAd ad) {
          print('$ad onAdDismissedFullScreenContent.');
          ad.dispose();
          _createRewardedAd();
        },
        onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
          print('$ad onAdFailedToShowFullScreenContent: $error');
          ad.dispose();
          _createRewardedAd();
        },
      );
      _rewardedAd!.setImmersiveMode(true);
      _rewardedAd!.show(
          onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
            print('$ad with reward $RewardItem(${reward.amount}, ${reward
                .type})');
          });
      _rewardedAd = null;
  }
  @override
  void initState() {
    super.initState();
    loadPrefSecond();
    _createRewardedAd();
    loadMusicName();
  }
  @override
  Widget build(BuildContext context) {
    //動画バナーロード
    myBanner.load();
    final AdWidget adWidget = AdWidget(ad: myBanner);
    final Container adContainer = Container(
      alignment: Alignment.center,
      width: myBanner.size.width.toDouble(),
      height: myBanner.size.height.toDouble(),
      child: adWidget,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Setting'),),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            const Padding(padding: EdgeInsets.all(20.0),),
            const Divider(color: Colors.white, thickness: 1.0,),
            Row(
              mainAxisAlignment: MainAxisAlignment.start, children: <Widget>[
                const Padding(padding: EdgeInsets.all(20),),
              const Icon(Icons.schedule, color: Colors.white, size: 30),
              Text('SLEEP TIME', style: styleA,),
            ],),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(primary: Colors.lightBlueAccent, onPrimary: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 80),),
                  onPressed: () async {
                    Picker(
                      adapter: DateTimePickerAdapter(
                          type: PickerDateTimeType.kHM,
                          value: _goalsleeptime,
                          customColumnType: [3, 4]),
                      title: const Text("Select Time"),
                      onConfirm: (Picker picker, List value) {
                        setState(() => {
                              _goalsleeptime = DateTime.utc(2016, 5, 1, value[0], value[1], 0),
                          _saveStrSetting('goalsleeptime',_goalsleeptime.toString()),
                            });
                      },
                    ).showModal(context);
                  },
                  child: Text(style: const TextStyle(fontSize: 40),DateFormat.Hm().format(_goalsleeptime) ),
                ),
                const Padding(padding: EdgeInsets.all(20.0),),
                const Divider(color: Colors.white, thickness: 1.0,),
                //アラーム選択ボタン
                Row(
                    mainAxisAlignment: MainAxisAlignment.start, children: <Widget>[
                      const Padding(padding: EdgeInsets.all(20),),
                  const Icon(Icons.music_note, color: Colors.white, size: 30),
                  Text('Alarm Sound', style: styleA,),
                ]),
            Row(
              mainAxisAlignment: MainAxisAlignment.start, children: <Widget>[
              const Padding(padding: EdgeInsets.only(left:50.0),),
             Radio(
              activeColor: Colors.blue,
              value: strCnsRadDefSound,
              groupValue: _type,
              onChanged: _handleRadio,
              autofocus:true,
            ),
              Text('Defualt Alarm Sound', style: styleB,),
            ]),
      Row(
        mainAxisAlignment: MainAxisAlignment.start, children: <Widget>[
        const Padding(padding: EdgeInsets.only(left:50.0),),
             Radio(
              activeColor: Colors.blue,
              value: strCnsRadSelMusic,
              groupValue: _type,
              onChanged: _handleRadio,
            ),
        Text('Alarm Select', style: styleB,),
      ]),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(primary: Colors.lightBlueAccent, onPrimary: Colors.white, padding:const  EdgeInsets.symmetric(vertical: 10, horizontal: 60),),
                   onPressed: !isEnable ? null :() async {alarmfileselect();},
                  child: const Text('Alarm Select', style: TextStyle(fontSize: 25),),
                ),
               const Padding(padding: EdgeInsets.all(10.0),),
                //アラーム選択ファイル
            Row(
                mainAxisAlignment: MainAxisAlignment.start, children: <Widget>[
                  const Padding(padding: EdgeInsets.only(left:60.0),),
              Text('Select Music：', style: styleA),
            ]),
            Row(
                mainAxisAlignment: MainAxisAlignment.start, children: <Widget>[
              const Padding(padding: EdgeInsets.only(left:90.0),),
              Text('$strSelectMusicName', style: styleB),
            ]),
                const Divider(color: Colors.white, thickness: 1.0,),
                //広告
                adContainer,
              ],
          ),
        ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black87,
        selectedItemColor: Colors.deepOrange,
        unselectedItemColor: Colors.orangeAccent,
        currentIndex: 1,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(label: 'Home', icon: Icon(Icons.home)),
          BottomNavigationBarItem(label: 'Setting', icon: Icon(Icons.settings)),
          BottomNavigationBarItem(label: 'History', icon: Icon(Icons.list)),
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
  void loadMusicName() async{
    String? strMusicPath = "";
    String? strMusicName = "";
    String dbpath =  await getDatabasesPath();
    String path = p.join(dbpath, "setting.db");
    Database database = await openDatabase(path, version: 1,
        onCreate: (Database db, int version) async {
          await db.execute(strCnsSqlCreateSetting);});
    List<Map> result = await database
        .rawQuery('select mpath from setting  where id = 1');
    for (Map item in result) {
      strMusicPath = item['mpath'].toString();
    }
    final reg = RegExp('[^//]+\$');
    if(strMusicPath != null && strMusicPath !="") {
      strMusicName = reg.firstMatch(strMusicPath)?.group(0);
      _handleRadio(strCnsRadSelMusic);
    }else{
      _handleRadio(strCnsRadDefSound);
    }
    setState(() {strSelectMusicName = strMusicName;});
  }
  //ラジオボタン選択時の処理
  void _handleRadio(String? e){
    setState(() {
      _type = e;
      if(e == strCnsRadDefSound){
        isEnable = false;
        _saveAlarmMusic("");
        strSelectMusicName = "Defualt Sound";
      }else{
        isEnable = true;
      }
    });
  }
  //アラームファイル選択
  void alarmfileselect() async {
    String srtName ="";
    //広告再生
    _showRewardedAdMusic();
    //ファイル選択
    FilePickerResult? result = null;
    result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Please Play Music File'
        , type: FileType.audio
    );
    if (result != null) {
      try {
        File file = File(result.files.single.path!);
        strSePath = file.path.toString();
        srtName = result.files.single.name;
        setState(() {
          strSelectMusicName = srtName;
        });
        _saveAlarmMusic(strSePath);
      } catch (e) {
        print(e);
      }
    }
  }
  //音楽ファイルパスを保存
  void _saveAlarmMusic(String value) async {
    String dbPath = await getDatabasesPath();
    String path = p.join(dbPath, 'setting.db');
    Database database = await openDatabase(path, version: 1,
        onCreate: (Database db, int version) async {
          await db.execute(strCnsSqlCreateSetting);
        });
    String query = 'UPDATE setting set mpath = "$value" where id = 1 ';
    await database.transaction((txn) async {
      //int id = await txn.rawInsert(query);
      await txn.rawInsert(query);
      //   print("insert: $id");
    });
  }
  void loadPrefSecond() async {
    //起床時間の取得
    String? strGetuptime = await _loadStrSetting('getuptime');
    if (strGetuptime != null && strGetuptime != "") {
      setState(()  {_getuptime = DateTime.parse(strGetuptime);});
    }
    //目標睡眠時間の取得
    String? strGoalsleep = await _loadStrSetting('goalsleeptime');
    if (strGoalsleep != null && strGoalsleep != "") {
      setState(()  {_goalsleeptime = DateTime.parse(strGoalsleep);});
    }
  }
}
/*------------------------------------------------------------------
3.履歴画面(Third Screen)
 -------------------------------------------------------------------*/
//リワード広告失敗した時の試行回数
const int maxFailedLoadAttempts = 3;

class ThirdScreen extends StatefulWidget {
  const ThirdScreen({Key? key}) : super(key: key); //コンストラクタ
  @override
  State<ThirdScreen> createState() =>  _ThirdScreenState();

}
class _ThirdScreenState extends State<ThirdScreen> {
  List<Widget> _items = <Widget>[];
  //広告カウント
  int cntReward = 0;
  @override
  void initState() {
    super.initState();
    getItems();
    _createRewardedAd();
    _loadPrefRewardCnt();
  }
  void _showRewardedAd() {
    cntReward = cntReward + 1;
    _saveIntSetting('rewardcnt', cntReward);
    if (cntReward >= 5) {
      _saveIntSetting('rewardcnt', 0);
      if (_rewardedAd == null) {
       // print('Warning: attempt to show rewarded before loaded.');
        return;
      }
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (RewardedAd ad) =>
            print('ad onAdShowedFullScreenContent.'),
        onAdDismissedFullScreenContent: (RewardedAd ad) {
          print('$ad onAdDismissedFullScreenContent.');
          ad.dispose();
          _createRewardedAd();
        },
        onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
          print('$ad onAdFailedToShowFullScreenContent: $error');
          ad.dispose();
          _createRewardedAd();
        },
      );
      _rewardedAd!.setImmersiveMode(true);
      _rewardedAd!.show(
          onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
            print('$ad with reward $RewardItem(${reward.amount}, ${reward
                .type})');
          });
      _rewardedAd = null;
    }
  }
  void _loadPrefRewardCnt() async {
    cntReward = await _loadIntSetting('rewardcnt') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
       appBar: AppBar(title: const Text('Get up history'),),
      body:  Column(
        children: <Widget>[
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
        items:const  <BottomNavigationBarItem>[
          BottomNavigationBarItem(label: 'Home', icon: Icon(Icons.home)),
          BottomNavigationBarItem(label: 'Setting', icon: Icon(Icons.settings)),
          BottomNavigationBarItem(label: 'History', icon: Icon(Icons.list)),
        ],
        onTap: (int index) {
          if (index == 0) {
            Navigator.pushNamed(context, '/');
            _showRewardedAd();
          } else if (index == 1) {
            Navigator.pushNamed(context, '/setting');
            _showRewardedAd();
          }
        },
      ),
    );
  }
  Widget _listHeader() {
    return Container(
        decoration:  const BoxDecoration(
            border: Border(bottom: BorderSide(width: 1.0, color: Colors.grey))),
        child: ListTile(
            title:  Row(children: const <Widget>[
              Expanded(child:  Text("STATUS", style:  TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
               Expanded(child:  Text("DATE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
               Expanded(child:  Text("TARGET TIME", style:  TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        ])));
  }
  void getItems() async {
    List<Widget> list = <Widget>[];
    String dbpath = await getDatabasesPath();
    String path = p.join(dbpath, "rireki.db");
    Database database = await openDatabase(path, version: 1,
        onCreate: (Database db, int version) async {
      await db.execute(strCnsSqlCreateRireki);
    });
    List<Map> result = await database
        .rawQuery('SELECT id,date,getupstatus,goalgetuptime FROM rireki order by id desc');
    for (Map item in result) {
      list.add(ListTile(
        tileColor: (item['getupstatus'].toString() == cnsGetupStatusS)
            ? Colors.green
            : Colors.grey,
        leading: (item['getupstatus'].toString() == cnsGetupStatusS)
            ? const Icon(Icons.thumb_up)
            : const Icon(Icons.redo),
        title:Text('      ${DateFormat('yyyy/MM/dd').format(DateTime.parse(item['date']))}             ${DateFormat('HH:mm').format(DateTime.parse(item['goalgetuptime']))}',
        style: const TextStyle(color: Colors.white,fontSize: 20),),
        dense: true,
      ));
    }
    setState(() {
      _items = list;
    });
  }

}

