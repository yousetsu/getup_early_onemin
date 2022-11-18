



const int helloAlarmID = 19820822;
const String cnsGetupStatusS = '1';
const String cnsGetupStatusF = '0';
const bool cnsAlarmOn = true;
const bool cnsAlarmOff = false;
//SQL
const String strCnsSqlCreateSetting ="CREATE TABLE IF NOT EXISTS setting(id INTEGER PRIMARY KEY, firstrun TEXT,getuptime TEXT,alarmon TEXT,kankaku INTEGER,goalgetuptime TEXT,goalsleeptime TEXT,rewardcnt INTEGER,sleepalarmtime TEXT,goalday INTEGER,mpath TEXT)";
const String strCnsSqlInsDefSetting = "INSERT INTO setting(firstrun,getuptime,alarmon,kankaku,goalgetuptime,goalsleeptime,rewardcnt,sleepalarmtime,goalday,mpath) values('X' ,'2016-05-01 07:00:00.000Z','',1,'2016-05-01 06:00:00.000Z','2016-05-01 07:30:00.000Z',0,'',0,'')";
const String strCnsSqlCreateRireki ="CREATE TABLE IF NOT EXISTS rireki(id INTEGER PRIMARY KEY, date TEXT, getupstatus TEXT, goalgetuptime TEXT, realgetuptime TEXT, goalbedintime TEXT, realbedintime TEXT, sleeptime TEXT)";
const String strCnsRadDefSound = "DefaultSound";
const String strCnsRadSelMusic = "SelectMusic";

//広告ID
//test
//const String strCnsBannerID = 'ca-app-pub-3940256099942544/6300978111'; //Banner
//const String strCnsRewardID = 'ca-app-pub-3940256099942544/5224354917'; //Reward
//本番
const String strCnsBannerID = 'ca-app-pub-8759269867859745/2745032231'; //banner
const String strCnsRewardID = 'ca-app-pub-8759269867859745/8740337207'; //Reward