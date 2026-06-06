
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  static Database? _database;
  factory DBHelper() => _instance;
  DBHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'fitness_agent.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE user_profile (
        id INTEGER PRIMARY KEY,
        name TEXT,
        height REAL,
        weight REAL,
        body_fat REAL,
        goal TEXT,
        experience_level TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE environments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        location_type TEXT,
        equipment_list TEXT,
        default_weights TEXT,
        is_default INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        target_muscle TEXT,
        equipment_type TEXT,
        difficulty INTEGER,
        description TEXT,
        svg_data TEXT,
        local_video_path TEXT,
        alternative_ids TEXT,
        default_weight REAL,
        default_sets INTEGER,
        default_reps INTEGER,
        rest_seconds INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE training_plans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        day_type TEXT,
        location_id INTEGER,
        exercises TEXT,
        status TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE workout_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_id INTEGER,
        exercise_id INTEGER,
        location_id INTEGER,
        weight REAL,
        sets INTEGER,
        reps TEXT,
        rpe REAL,
        notes TEXT,
        completed_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE body_metrics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        weight REAL,
        body_fat REAL,
        chest REAL,
        arm REAL,
        waist REAL,
        thigh REAL,
        resting_hr INTEGER,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE absence_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        reason TEXT,
        planned_day_type TEXT,
        auto_flag INTEGER
      )
    ''');

    await _seedExercises(db);
    await _seedDefaultEnv(db);
  }

  Future _seedExercises(Database db) async {
    final exercises = [
      // ========== 胸部 12个 ==========
      {'name':'杠铃卧推','target_muscle':'胸大肌','equipment_type':'gym','difficulty':3,
       'description':'平躺卧推凳，双脚踩实地面，肩胛骨后缩下沉贴紧凳面，握距略宽于肩，下放时杠铃轻触胸骨下端，推起时肘关节不要锁死，全程控制离心速度2秒。',
       'svg_data':'<svg viewBox="0 0 100 100"><rect x="20" y="45" width="60" height="8" fill="#888" rx="2"/><circle cx="25" cy="49" r="4" fill="#333"/><circle cx="75" cy="49" r="4" fill="#333"/><rect x="45" y="55" width="10" height="25" fill="#666"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">杠铃卧推</text></svg>',
       'local_video_path':'','alternative_ids':'2,3,5','default_weight':60,'default_sets':5,'default_reps':5,'rest_seconds':180},

      {'name':'哑铃卧推','target_muscle':'胸大肌','equipment_type':'dumbbell','difficulty':2,
       'description':'平躺瑜伽垫或地板，大臂与躯干约45度角（不要完全打开成90度），推起时哑铃不相碰，保持一拳距离，控制离心阶段2-3秒。',
       'svg_data':'<svg viewBox="0 0 100 100"><rect x="35" y="40" width="8" height="20" fill="#888" rx="2"/><rect x="57" y="40" width="8" height="20" fill="#888" rx="2"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">哑铃卧推</text></svg>',
       'local_video_path':'','alternative_ids':'3,5,11','default_weight':20,'default_sets':4,'default_reps':10,'rest_seconds':120},

      {'name':'俯卧撑','target_muscle':'胸大肌','equipment_type':'bodyweight','difficulty':1,
       'description':'双手略宽于肩撑地，身体呈一条直线，核心收紧不塌腰，胸部贴近地面后推起，肘关节自然外展约45度，不要过度外展伤肩。',
       'svg_data':'<svg viewBox="0 0 100 100"><circle cx="30" cy="70" r="4" fill="#333"/><circle cx="70" cy="70" r="4" fill="#333"/><line x1="30" y1="70" x2="70" y2="70" stroke="#666" stroke-width="3"/><circle cx="50" cy="50" r="8" fill="#888"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">俯卧撑</text></svg>',
       'local_video_path':'','alternative_ids':'6,12','default_weight':0,'default_sets':4,'default_reps':15,'rest_seconds':90},

      {'name':'上斜杠铃卧推','target_muscle':'胸大肌上部','equipment_type':'gym','difficulty':3,
       'description':'卧推凳调至30-45度，杠铃下放至锁骨下方，推起方向略向头部上方，重点刺激上胸。',
       'svg_data':'<svg viewBox="0 0 100 100"><rect x="20" y="40" width="60" height="8" fill="#888" rx="2" transform="rotate(-10 50 44)"/><circle cx="25" cy="42" r="4" fill="#333"/><circle cx="75" cy="46" r="4" fill="#333"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">上斜卧推</text></svg>',
       'local_video_path':'','alternative_ids':'5,2','default_weight':50,'default_sets':4,'default_reps':8,'rest_seconds':150},

      {'name':'上斜哑铃卧推','target_muscle':'胸大肌上部','equipment_type':'dumbbell','difficulty':2,
       'description':'上斜30度，哑铃从胸部两侧推起，顶端轻微内旋哑铃（小指略高于拇指），挤压上胸。',
       'svg_data':'<svg viewBox="0 0 100 100"><rect x="35" y="38" width="8" height="18" fill="#888" rx="2" transform="rotate(-10 39 47)"/><rect x="57" y="38" width="8" height="18" fill="#888" rx="2" transform="rotate(10 61 47)"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">上斜哑铃推</text></svg>',
       'local_video_path':'','alternative_ids':'6,3','default_weight':18,'default_sets':4,'default_reps':10,'rest_seconds':120},

      {'name':'上斜俯卧撑','target_muscle':'胸大肌上部','equipment_type':'bodyweight','difficulty':1,
       'description':'双手撑在凳子或床沿，身体呈直线，下放时胸部靠近支撑物，重点刺激上胸。',
       'svg_data':'<svg viewBox="0 0 100 100"><rect x="20" y="60" width="60" height="8" fill="#555"/><circle cx="30" cy="56" r="4" fill="#333"/><circle cx="70" cy="56" r="4" fill="#333"/><circle cx="50" cy="40" r="8" fill="#888"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">上斜俯卧撑</text></svg>',
       'local_video_path':'','alternative_ids':'3','default_weight':0,'default_sets':4,'default_reps':12,'rest_seconds':90},

      {'name':'哑铃飞鸟','target_muscle':'胸大肌','equipment_type':'dumbbell','difficulty':2,
       'description':'平躺，大臂微屈固定角度（肘关节约150度），像抱大树一样向两侧打开，感受胸肌拉伸，合拢时挤压胸肌1秒。',
       'svg_data':'<svg viewBox="0 0 100 100"><path d="M30 50 Q50 70 70 50" stroke="#888" stroke-width="4" fill="none"/><circle cx="30" cy="50" r="5" fill="#666"/><circle cx="70" cy="50" r="5" fill="#666"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">哑铃飞鸟</text></svg>',
       'local_video_path':'','alternative_ids':'8,2','default_weight':12,'default_sets':3,'default_reps':12,'rest_seconds':90},

      {'name':'绳索夹胸','target_muscle':'胸大肌','equipment_type':'gym','difficulty':2,
       'description':'龙门架滑轮调至高位，弓步站立，双手抓绳索从高处向体前下方交叉，顶峰收缩挤压胸肌2秒。',
       'svg_data':'<svg viewBox="0 0 100 100"><line x1="20" y1="10" x2="50" y2="50" stroke="#888" stroke-width="3"/><line x1="80" y1="10" x2="50" y2="50" stroke="#888" stroke-width="3"/><circle cx="50" cy="50" r="6" fill="#666"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">绳索夹胸</text></svg>',
       'local_video_path':'','alternative_ids':'7,2','default_weight':15,'default_sets':3,'default_reps':15,'rest_seconds':90},

      {'name':'双杠臂屈伸','target_muscle':'胸大肌下部','equipment_type':'bodyweight','difficulty':3,
       'description':'双杠支撑，身体前倾约30度（练胸），屈肘下放至大臂平行地面，推起时保持前倾角度。',
       'svg_data':'<svg viewBox="0 0 100 100"><line x1="30" y1="10" x2="30" y2="70" stroke="#555" stroke-width="4"/><line x1="70" y1="10" x2="70" y2="70" stroke="#555" stroke-width="4"/><circle cx="50" cy="50" r="8" fill="#888"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">双杠臂屈伸</text></svg>',
       'local_video_path':'','alternative_ids':'3,10','default_weight':0,'default_sets':4,'default_reps':10,'rest_seconds':120},

      {'name':'史密斯机卧推','target_muscle':'胸大肌','equipment_type':'gym','difficulty':2,
       'description':'史密斯机固定轨迹，适合 solo 训练力竭时安全逃脱，握距与杠铃卧推相同，下放触胸。',
       'svg_data':'<svg viewBox="0 0 100 100"><line x1="30" y1="10" x2="30" y2="90" stroke="#555" stroke-width="3"/><line x1="70" y1="10" x2="70" y2="90" stroke="#555" stroke-width="3"/><rect x="25" y="45" width="50" height="8" fill="#888" rx="2"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">史密斯卧推</text></svg>',
       'local_video_path':'','alternative_ids':'1,2','default_weight':60,'default_sets':4,'default_reps':8,'rest_seconds':150},

      {'name':'地板哑铃卧推','target_muscle':'胸大肌','equipment_type':'dumbbell','difficulty':1,
       'description':'躺平地板，大臂触地后推起，行程比卧推凳短，但对肩更友好，适合无卧推凳时。',
       'svg_data':'<svg viewBox="0 0 100 100"><rect x="35" y="55" width="8" height="15" fill="#888" rx="2"/><rect x="57" y="55" width="8" height="15" fill="#888" rx="2"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">地板哑铃推</text></svg>',
       'local_video_path':'','alternative_ids':'2,3','default_weight':18,'default_sets':4,'default_reps':12,'rest_seconds':120},

      {'name':'宽距俯卧撑','target_muscle':'胸大肌','equipment_type':'bodyweight','difficulty':2,
       'description':'双手间距1.5倍肩宽，更侧重胸肌外侧，下放时胸部充分拉伸。',
       'svg_data':'<svg viewBox="0 0 100 100"><circle cx="20" cy="70" r="4" fill="#333"/><circle cx="80" cy="70" r="4" fill="#333"/><line x1="20" y1="70" x2="80" y2="70" stroke="#666" stroke-width="3"/><circle cx="50" cy="50" r="8" fill="#888"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">宽距俯卧撑</text></svg>',
       'local_video_path':'','alternative_ids':'3','default_weight':0,'default_sets':4,'default_reps':12,'rest_seconds':90},

      // ========== 背部 12个 ==========
      {'name':'杠铃划船','target_muscle':'背阔肌','equipment_type':'gym','difficulty':3,
       'description':'俯身约45度，背部挺直核心收紧，杠铃沿大腿拉向腹部，肩胛骨后收，顶峰收缩1秒，不要挺腰借力。',
       'svg_data':'<svg viewBox="0 0 100 100"><rect x="20" y="45" width="60" height="8" fill="#888" rx="2"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">杠铃划船</text></svg>',
       'local_video_path':'','alternative_ids':'15,19,21','default_weight':50,'default_sets':4,'default_reps':8,'rest_seconds':150},

      {'name':'哑铃单臂划船','target_muscle':'背阔肌','equipment_type':'dumbbell','difficulty':2,
       'description':'一手撑凳，一手持哑铃，背部平直如桌面，哑铃沿大腿拉向髋部，顶峰收缩1秒，控制下放。',
       'svg_data':'<svg viewBox="0 0 100 100"><rect x="45" y="30" width="10" height="30" fill="#888" rx="2"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">单臂划船</text></svg>',
       'local_video_path':'','alternative_ids':'21,19','default_weight':15,'default_sets':4,'default_reps':12,'rest_seconds':120},

      {'name':'引体向上','target_muscle':'背阔肌','equipment_type':'bodyweight','difficulty':3,
       'description':'正握单杠（略宽于肩），启动时想象用肘部向下后方拉，下巴过杠，控制下放至手臂伸直，不要摆动借力。',
       'svg_data':'<svg viewBox="0 0 100 100"><line x1="20" y1="15" x2="80" y2="15" stroke="#555" stroke-width="4"/><circle cx="50" cy="50" r="8" fill="#888"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">引体向上</text></svg>',
       'local_video_path':'','alternative_ids':'19,22','default_weight':0,'default_sets':4,'default_reps':8,'rest_seconds':120},

      {'name':'高位下拉','target_muscle':'背阔肌','equipment_type':'gym','difficulty':2,
       'description':'宽握横杆，身体稍后仰，下拉至横杆触胸上沿，肘部向下后方走，回放时控制速度。',
       'svg_data':'<svg viewBox="0 0 100 100"><line x1="30" y1="10" x2="30" y2="50" stroke="#888" stroke-width="3"/><line x1="70" y1="10" x2="70" y2="50" stroke="#888" stroke-width="3"/><rect x="25" y="10" width="50" height="6" fill="#666" rx="2"/><circle cx="50" cy="55" r="8" fill="#888"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">高位下拉</text></svg>',
       'local_video_path':'','alternative_ids':'15,19','default_weight':40,'default_sets':4,'default_reps':10,'rest_seconds':120},

      {'name':'坐姿绳索划船','target_muscle':'背阔肌','equipment_type':'gym','difficulty':2,
       'description':'坐姿双脚蹬踏板，躯干稍后仰，拉手柄向腹部，肩胛骨后收，回放时躯干跟随前移，保持张力。',
       'svg_data':'<svg viewBox="0 0 100 100"><line x1="80" y1="30" x2="50" y2="50" stroke="#888" stroke-width="3"/><circle cx="50" cy="50" r="6" fill="#666"/><rect x="40" y="60" width="20" height="15" fill="#555" rx="3"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">坐姿划船</text></svg>',
       'local_video_path':'','alternative_ids':'13,18','default_weight':45,'default_sets':4,'default_reps':12,'rest_seconds':120},

      {'name':'T杠划船','target_muscle':'背阔肌','equipment_type':'gym','difficulty':3,
       'description':'T杠一端固定，俯身抓握把手，拉向腹部，轨迹更固定，适合上重量。',
       'svg_data':'<svg viewBox="0 0 100 100"><line x1="50" y1="80" x2="50" y2="40" stroke="#555" stroke-width="4"/><rect x="20" y="40" width="60" height="8" fill="#888" rx="2"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">T杠划船</text></svg>',
       'local_video_path':'','alternative_ids':'13,21','default_weight':60,'default_sets':4,'default_reps':8,'rest_seconds':150},

      {'name':'反向划船','target_muscle':'背阔肌','equipment_type':'bodyweight','difficulty':2,
       'description':'低杠或桌底，身体仰卧，胸部拉向杠，难度可通过脚的位置调整（直腿难，屈膝易）。',
       'svg_data':'<svg viewBox="0 0 100 100"><line x1="20" y1="20" x2="80" y2="20" stroke="#555" stroke-width="4"/><circle cx="50" cy="50" r="8" fill="#888"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">反向划船</text></svg>',
       'local_video_path':'','alternative_ids':'15,22','default_weight':0,'default_sets':4,'default_reps':10,'rest_seconds':90},

      {'name':'直臂下压','target_muscle':'背阔肌','equipment_type':'gym','difficulty':2,
       'description':'龙门架直杆，手臂微屈固定，用背阔肌发力将杆压向大腿，顶峰收缩，适合收尾。',
       'svg_data':'<svg viewBox="0 0 100 100"><line x1="50" y1="10" x2="50" y2="60" stroke="#888" stroke-width="3"/><rect x="40" y="60" width="20" height="6" fill="#666" rx="2"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">直臂下压</text></svg>',
       'local_video_path':'','alternative_ids':'13,16','default_weight':20,'default_sets':3,'default_reps':15,'rest_seconds':90},

      {'name':'哑铃俯身划船','target_muscle':'背阔肌','equipment_type':'dumbbell','difficulty':2,
       'description':'双手各持哑铃，俯身约45度，哑铃沿大腿拉向髋部，可同时刺激两侧背阔肌。',
       'svg_data':'<svg viewBox="0 0 100 100"><rect x="30" y="45" width="8" height="20" fill="#888" rx="2"/><rect x="62" y="45" width="8" height="20" fill="#888" rx="2"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">俯身划船</text></svg>',
       'local_video_path':'','alternative_ids':'14,21','default_weight':14,'default_sets':4,'default_reps':10,'rest_seconds':120},

      {'name':'超人式','target_muscle':'竖脊肌','equipment_type':'bodyweight','difficulty':1,
       'description':'俯卧，同时抬起双手双脚，像超人飞行，顶峰收缩2秒，强化下背和竖脊肌。',
       'svg_data':'<svg viewBox="0 0 100 100"><circle cx="50" cy="50" r="6" fill="#888"/><line x1="30" y1="50" x2="10" y2="40" stroke="#666" stroke-width="3"/><line x1="70" y1="50" x2="90" y2="40" stroke="#666" stroke-width="3"/><line x1="45" y1="56" x2="35" y2="80" stroke="#666" stroke-width="3"/><line x1="55" y1="56" x2="65" y2="80" stroke="#666" stroke-width="3"/><text x="50" y="95" text-anchor="middle" font-size="8" fill="#aaa">超人式</text></svg>',
       'local_video_path':'','alternative_ids':'22','default_weight':0,'default_sets':3,'default_reps':15,'rest_seconds':60},

      {'name':'单臂绳索划船','target_muscle':'背阔肌','equipment_type':'gym','difficulty':2,
       'description':'单手握D型把手，身体旋转增加行程，顶峰收缩时躯干略微旋转挤压背阔肌。',
       'svg_data':'<svg viewBox="0 0 100 100"><line x1="80" y1="20" x2="50" y2="50" stroke="#888" stroke-width="3"/><circle cx="50" cy="50" r="6" fill="#666"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">单臂绳索划</text></svg>',
       'local_video_path':'','alternative_ids':'14,18','default_weight':25,'default_sets':3,'default_reps':12,'rest_seconds':90},

      {'name':'门框划船','target_muscle':'背阔肌','equipment_type':'bodyweight','difficulty':1,
       'description':'双手抓门框，身体后仰，胸部拉向门框，难度通过脚的位置调整，适合居家。',
       'svg_data':'<svg viewBox="0 0 100 100"><rect x="45" y="10" width="10" height="80" fill="#555"/><circle cx="50" cy="50" r="8" fill="#888"/><text x="50" y="95" text-anchor="middle" font-size="8" fill="#aaa">门框划船</text></svg>',
       'local_video_path':'','alternative_ids':'19,15','default_weight':0,'default_sets':4,'default_reps':12,'rest_seconds':90},

      // ========== 腿部-前侧 8个 ==========
      {'name':'杠铃深蹲','target_muscle':'股四头肌','equipment_type':'gym','difficulty':4,
       'description':'双脚与肩同宽或略宽，脚尖微外展，杠铃置于斜方肌上部，核心收紧，臀部向后坐至大腿至少平行地面，膝盖始终对准脚尖方向，不要内扣。',
       'svg_data':'<svg viewBox="0 0 100 100"><rect x="30" y="25" width="40" height="8" fill="#888" rx="2"/><line x1="50" y1="33" x2="50" y2="60" stroke="#666" stroke-width="4"/><line x1="40" y1="60" x2="40" y2="85" stroke="#666" stroke-width="4"/><line x1="60" y1="60" x2="60" y2="85" stroke="#666" stroke-width="4"/><text x="50" y="95" text-anchor="middle" font-size="8" fill="#aaa">杠铃深蹲</text></svg>',
       'local_video_path':'','alternative_ids':'27,29,30','default_weight':80,'default_sets':5,'default_reps':5,'rest_seconds':240},

      {'name':'哑铃高脚杯深蹲','target_muscle':'股四头肌','equipment_type':'dumbbell','difficulty':2,
       'description':'双手捧哑铃一端于胸前，手肘内收贴身体，下蹲至大腿平行，背部挺直，膝盖外展，起身时臀部夹紧。',
       'svg_data':'<svg viewBox="0 0 100 100"><circle cx="50" cy="35" r="8" fill="#888"/><line x1="50" y1="43" x2="50" y2="65" stroke="#666" stroke-width="4"/><line x1="40" y1="65" x2="40" y2="90" stroke="#666" stroke-width="4"/><line x1="60" y1="65" x2="60" y2="90" stroke="#666" stroke-width="4"/><text x="50" y="95" text-anchor="middle" font-size="8" fill="#aaa">高脚杯深蹲</text></svg>',
       'local_video_path':'','alternative_ids':'27,29','default_weight':20,'default_sets':4,'default_reps':12,'rest_seconds':180},

      {'name':'保加利亚分腿蹲','target_muscle':'股四头肌','equipment_type':'bodyweight','difficulty':3,
       'description':'后脚放凳/床沿，前脚向前一步，身体垂直下蹲至后膝轻触地，重心在前脚脚跟，前膝不超过脚尖过多。',
       'svg_data':'<svg viewBox="0 0 100 100"><rect x="60" y="20" width="20" height="10" fill="#555" rx="2"/><line x1="40" y1="70" x2="40" y2="45" stroke="#666" stroke-width="4"/><line x1="65" y1="70" x2="65" y2="50" stroke="#666" stroke-width="4"/><text x="50" y="95" text-anchor="middle" font-size="8" fill="#aaa">分腿蹲</text></svg>',
       'local_video_path':'','alternative_ids':'29','default_weight':0,'default_sets':4,'default_reps':12,'rest_seconds':120},

      {'name':'腿举','target_muscle':'股四头肌','equipment_type':'gym','difficulty':2,
       'description':'倒蹬机，双脚放踏板中部，下放至膝盖接近胸部（不要弹震腰部），蹬起时膝盖微屈不锁死。',
       'svg_data':'<svg viewBox="0 0 100 100"><rect x="20" y="20" width="60" height="8" fill="#555" rx="2"/><line x1="40" y1="70" x2="40" y2="35" stroke="#666" stroke-width="4"/><line x1="60" y1="70" x2="60" y2="35" stroke="#666" stroke-width="4"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">腿举</text></svg>',
       'local_video_path':'','alternative_ids':'26,30','default_weight':120,'default_sets':4,'default_reps':10,'rest_seconds':180},

      {'name':'箭步蹲','target_muscle':'股四头肌','equipment_type':'dumbbell','difficulty':2,
       'description':'双手持哑铃，一步向前，下蹲至双膝约90度，后膝接近地面，起身时前脚蹬地，可原地或行走。',
       'svg_data':'<svg viewBox="0 0 100 100"><rect x="30" y="40" width="8" height="15" fill="#888" rx="2"/><rect x="62" y="40" width="8" height="15" fill="#888" rx="2"/><line x1="45" y1="70" x2="45" y2="50" stroke="#666" stroke-width="4"/><line x1="65" y1="70" x2="65" y2="55" stroke="#666" stroke-width="4"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">箭步蹲</text></svg>',
       'local_video_path':'','alternative_ids':'27,28','default_weight':14,'default_sets':3,'default_reps':12,'rest_seconds':120},

      {'name':'哈克深蹲','target_muscle':'股四头肌','equipment_type':'gym','difficulty':3,
       'description':'哈克机，背部贴紧靠垫，双脚放踏板低位（侧重股四），下蹲至大腿平行，轨迹固定安全。',
       'svg_data':'<svg viewBox="0 0 100 100"><rect x="30" y="15" width="40" height="50" fill="#555" rx="4" opacity="0.5"/><line x1="40" y1="70" x2="40" y2="50" stroke="#666" stroke-width="4"/><line x1="60" y1="70" x2="60" y2="50" stroke="#666" stroke-width="4"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">哈克深蹲</text></svg>',
       'local_video_path':'','alternative_ids':'26,30','default_weight':100,'default_sets':4,'default_reps':8,'rest_seconds':180},

      {'name':'深蹲跳','target_muscle':'股四头肌','equipment_type':'bodyweight','difficulty':2,
       'description':'深蹲至大腿平行，爆发向上跳起，落地缓冲立刻接下一次，强化爆发力，注意膝盖缓冲。',
       'svg_data':'<svg viewBox="0 0 100 100"><line x1="40" y1="60" x2="40" y2="85" stroke="#666" stroke-width="4"/><line x1="60" y1="60" x2="60" y2="85" stroke="#666" stroke-width="4"/><line x1="45" y1="45" x2="55" y2="35" stroke="#888" stroke-width="3"/><text x="50" y="95" text-anchor="middle" font-size="8" fill="#aaa">深蹲跳</text></svg>',
       'local_video_path':'','alternative_ids':'27','default_weight':0,'default_sets':4,'default_reps':10,'rest_seconds':120},

      {'name':'侧箭步蹲','target_muscle':'股四头肌','equipment_type':'dumbbell','difficulty':2,
       'description':'向侧方跨步，下蹲时重心在跨出腿，另一腿伸直，刺激股四和臀中肌，改善侧向稳定性。',
       'svg_data':'<svg viewBox="0 0 100 100"><line x1="50" y1="60" x2="50" y2="85" stroke="#666" stroke-width="4"/><line x1="70" y1="60" x2="70" y2="85" stroke="#666" stroke-width="4"/><line x1="50" y1="60" x2="70" y2="60" stroke="#888" stroke-width="3"/><text x="50" y="95" text-anchor="middle" font-size="8" fill="#aaa">侧箭步蹲</text></svg>',
       'local_video_path':'','alternative_ids':'28,29','default_weight':12,'default_sets':3,'default_reps':12,'rest_seconds':90},

      // ========== 腿部-后侧/臀 8个 ==========
      {'name':'罗马尼亚硬拉','target_muscle':'腘绳肌','equipment_type':'gym','difficulty':3,
       'description':'双脚与髋同宽，杠铃贴近小腿下放，臀部向后推，膝盖微屈固定，感受腘绳肌拉伸至极限，用臀和腘绳拉起。',
       'svg_data':'<svg viewBox="0 0 100 100"><rect x="20" y="55" width="60" height="8" fill="#888" rx="2"/><line x1="40" y1="55" x2="40" y2="85" stroke="#666" stroke-width="4"/><line x1="60" y1="55" x2="60" y2="85" stroke="#666" stroke-width="4"/><text x="50" y="95" text-anchor="middle" font-size="8" fill="#aaa">罗马尼亚硬拉</text></svg>',
       'local_video_path':'','alternative_ids':'35,36','default_weight':60,'default_sets':4,'default_reps':8,'rest_seconds':150},

      {'name':'哑铃罗马尼亚硬拉','target_muscle':'腘绳肌','equipment_type':'dumbbell','difficulty':2,
       'description':'双手持哑铃，轨迹与杠铃版相同，哑铃更靠近身体，对握力要求较低，适合居家。',
       'svg_data':'<svg viewBox="0 0 100 100"><rect x="30" y="55" width="8" height="15" fill="#888" rx="2"/><rect x="62" y="55" width="8" height="15" fill="#888" rx="2"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">哑铃RDL</text></svg>',
       'local_video_path':'','alternative_ids':'34,35','default_weight':16,'default_sets':4,'default_reps':10,'rest_seconds':120},

      {'name':'单腿罗马尼亚硬拉','target_muscle':'腘绳肌','equipment_type':'dumbbell','difficulty':3,
       'description':'单手持哑铃，对侧腿支撑，另一腿向后伸直，身体前倾成T字形，极难，强化平衡和单侧力量。',
       'svg_data':'<svg viewBox="0 0 100 100"><rect x="45" y="45" width="10" height="20" fill="#888" rx="2"/><line x1="50" y1="65" x2="50" y2="85" stroke="#666" stroke-width="4"/><line x1="70" y1="50" x2="70" y2="80" stroke="#666" stroke-width="4" opacity="0.5"/><text x="50" y="95" text-anchor="middle" font-size="8" fill="#aaa">单腿RDL</text></svg>',
       'local_video_path':'','alternative_ids':'34','default_weight':10,'default_sets':3,'default_reps':10,'rest_seconds':120},

      {'name':'腿弯举','target_muscle':'腘绳肌','equipment_type':'gym','difficulty':2,
       'description':'俯卧腿弯举机，脚跟向臀部卷起，顶峰收缩2秒，控制回放，孤立刺激腘绳肌。',
       'svg_data':'<svg viewBox="0 0 100 100"><rect x="20" y="60" width="60" height="8" fill="#888" rx="2"/><line x1="40" y1="60" x2="40" y2="85" stroke="#666" stroke-width="4"/><line x1="60" y1="60" x2="60" y2="85" stroke="#666" stroke-width="4"/><text x="50" y="95" text-anchor="middle" font-size="8" fill="#aaa">腿弯举</text></svg>',
       'local_video_path':'','alternative_ids':'34,37','default_weight':30,'default_sets':3,'default_reps':12,'rest_seconds':90},

      {'name':'北欧腿弯举','target_muscle':'腘绳肌','equipment_type':'bodyweight','difficulty':4,
       'description':'跪姿，脚踝固定，身体向前倾倒，用腘绳肌控制下落，双手撑地辅助，极难，是腘绳肌徒手终极动作。',
       'svg_data':'<svg viewBox="0 0 100 100"><line x1="50" y1="80" x2="50" y2="50" stroke="#666" stroke-width="4"/><line x1="50" y1="50" x2="70" y2="30" stroke="#666" stroke-width="4"/><line x1="70" y1="30" x2="85" y2="45" stroke="#888" stroke-width="3"/><text x="50" y="95" text-anchor="middle" font-size="8" fill="#aaa">北欧腿弯举</text></svg>',
       'local_video_path':'','alternative_ids':'34','default_weight':0,'default_sets':3,'default_reps':6,'rest_seconds':120},

      {'name':'臀推','target_muscle':'臀大肌','equipment_type':'gym','difficulty':3,
       'description':'上背靠在卧推凳，杠铃放髋部，双脚踩实，下巴收向胸部，用臀部力量顶起至身体平行，顶峰收缩3秒。',
       'svg_data':'<svg viewBox="0 0 100 100"><rect x="20" y="55" width="60" height="8" fill="#888" rx="2"/><rect x="10" y="50" width="15" height="20" fill="#555" rx="2"/><line x1="40" y1="63" x2="40" y2="85" stroke="#666" stroke-width="4"/><line x1="60" y1="63" x2="60" y2="85" stroke="#666" stroke-width="4"/><text x="50" y="95" text-anchor="middle" font-size="8" fill="#aaa">臀推</text></svg>',
       'local_video_path':'','alternative_ids':'39,40','default_weight':80,'default_sets':4,'default_reps':8,'rest_seconds':150},

      {'name':'单腿臀推','target_muscle':'臀大肌','equipment_type':'dumbbell','difficulty':2,
       'description':'单脚支撑，另一腿伸直，哑铃放髋部，单侧臀推改善左右不平衡，难度低于杠铃臀推。',
       'svg_data':'<svg viewBox="0 0 100 100"><rect x="45" y="50" width="10" height="15" fill="#888" rx="2"/><line x1="50" y1="65" x2="50" y2="85" stroke="#666" stroke-width="4"/><line x1="70" y1="65" x2="70" y2="85" stroke="#666" stroke-width="4" opacity="0.4"/><text x="50" y="95" text-anchor="middle" font-size="8" fill="#aaa">单腿臀推</text></svg>',
       'local_video_path':'','alternative_ids':'38','default_weight':20,'default_sets':3,'default_reps':12,'rest_seconds':120},

      {'name':'壶铃摆荡','target_muscle':'臀大肌','equipment_type':'dumbbell','difficulty':2,
       'description':'双手持哑铃（替代壶铃），双脚宽站，屈髋向后（不是下蹲），利用臀部爆发力向前摆起哑铃至眼平，核心收紧。',
       'svg_data':'<svg viewBox="0 0 100 100"><circle cx="50" cy="35" r="8" fill="#888"/><line x1="50" y1="43" x2="50" y2="65" stroke="#666" stroke-width="4"/><line x1="40" y1="65" x2="40" y2="85" stroke="#666" stroke-width="4"/><line x1="60" y1="65" x2="60" y2="85" stroke="#666" stroke-width="4"/><text x="50" y="95" text-anchor="middle" font-size="8" fill="#aaa">壶铃摆荡</text></svg>',
       'local_video_path':'','alternative_ids':'38','default_weight':16,'default_sets':4,'default_reps':15,'rest_seconds':120},

      // ========== 小腿 4个 ==========
      {'name':'站姿杠铃提踵','target_muscle':'小腿腓肠肌','equipment_type':'gym','difficulty':2,
       'description':'杠铃放斜方肌，双脚掌站在踏板边缘，脚跟下放至最低，用小腿力量提起至最高，顶峰收缩2秒。',
       'svg_data':'<svg viewBox="0 0 100 100"><rect x="30" y="25" width="40" height="8" fill="#888" rx="2"/><line x1="40" y1="60" x2="40" y2="85" stroke="#666" stroke-width="4"/><line x1="60" y1="60" x2="60" y2="85" stroke="#666" stroke-width="4"/><rect x="35" y="85" width="30" height="5" fill="#555"/><text x="50" y="95" text-anchor="middle" font-size="8" fill="#aaa">站姿提踵</text></svg>',
       'local_video_path':'','alternative_ids':'42,43','default_weight':60,'default_sets':4,'default_reps':12,'rest_seconds':90},

      {'name':'站姿哑铃提踵','target_muscle':'小腿腓肠肌','equipment_type':'dumbbell','difficulty':1,
       'description':'双手持哑铃，单脚或双脚站在台阶边缘，同样顶峰收缩，哑铃提供额外负重。',
       'svg_data':'<svg viewBox="0 0 100 100"><rect x="35" y="40" width="8" height="15" fill="#888" rx="2"/><rect x="57" y="40" width="8" height="15" fill="#888" rx="2"/><line x1="50" y1="60" x2="50" y2="85" stroke="#666" stroke-width="4"/><rect x="40" y="85" width="20" height="5" fill="#555"/><text x="50" y="95" text-anchor="middle" font-size="8" fill="#aaa">哑铃提踵</text></svg>',
       'local_video_path':'','alternative_ids':'43','default_weight':20,'default_sets':4,'default_reps':15,'rest_seconds':60},

      {'name':'单腿提踵','target_muscle':'小腿腓肠肌','equipment_type':'bodyweight','difficulty':1,
       'description':'单脚站在台阶，另一脚悬空，单手扶墙保持平衡，极慢速下放和提起，强化单侧小腿。',
       'svg_data':'<svg viewBox="0 0 100 100"><line x1="50" y1="60" x2="50" y2="85" stroke="#666" stroke-width="4"/><line x1="70" y1="60" x2="70" y2="80" stroke="#666" stroke-width="4" opacity="0.4"/><rect x="40" y="85" width="20" height="5" fill="#555"/><text x="50" y="95" text-anchor="middle" font-size="8" fill="#aaa">单腿提踵</text></svg>',
       'local_video_path':'','alternative_ids':'42','default_weight':0,'default_sets':4,'default_reps':20,'rest_seconds':60},

      {'name':'坐姿提踵','target_muscle':'小腿比目鱼肌','equipment_type':'gym','difficulty':1,
       'description':'坐姿提踵机，大腿固定，小腿发力提起，侧重比目鱼肌（坐姿时腓肠肌放松），建议与站姿搭配。',
       'svg_data':'<svg viewBox="0 0 100 100"><rect x="20" y="50" width="60" height="20" fill="#555" rx="3" opacity="0.5"/><line x1="40" y1="70" x2="40" y2="85" stroke="#666" stroke-width="4"/><line x1="60" y1="70" x2="60" y2="85" stroke="#666" stroke-width="4"/><text x="50" y="95" text-anchor="middle" font-size="8" fill="#aaa">坐姿提踵</text></svg>',
       'local_video_path':'','alternative_ids':'42','default_weight':40,'default_sets':3,'default_reps':15,'rest_seconds':60},

      // ========== 肩部 10个 ==========
      {'name':'杠铃推举','target_muscle':'三角肌前束','equipment_type':'gym','difficulty':3,
       'description':'站姿或坐姿，杠铃从锁骨位置垂直推起至肘关节伸直，核心收紧不反弓腰部，下放至下巴。',
       'svg_data':'<svg viewBox="0 0 100 100"><rect x="30" y="20" width="40" height="8" fill="#888" rx="2"/><line x1="50" y1="28" x2="50" y2="60" stroke="#666" stroke-width="4"/><line x1="40" y1="60" x2="40" y2="85" stroke="#666" stroke-width="4"/><line x1="60" y1="60" x2="60" y2="85" stroke="#666" stroke-width="4"/><text x="50" y="95" text-anchor="middle" font-size="8" fill="#aaa">杠铃推举</text></svg>',
       'local_video_path':'','alternative_ids':'47,52','default_weight':40,'default_sets':4,'default_reps':8,'rest_seconds':150},

      {'name':'哑铃推举','target_muscle':'三角肌前束','equipment_type':'dumbbell','difficulty':2,
       'description':'坐姿，大臂与地面平行，小臂垂直，推起时哑铃在顶端轻微内旋，不要碰撞。',
       'svg_data':'<svg viewBox="0 0 100 100"><rect x="35" y="25" width="8" height="18" fill="#888" rx="2"/><rect x="57" y="25" width="8" height="18" fill="#888" rx="2"/><line x1="50" y1="43" x2="50" y2="60" stroke="#666" stroke-width="4"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">哑铃推举</text></svg>',
       'local_video_path':'','alternative_ids':'46,52','default_weight':16,'default_sets':4,'default_reps':10,'rest_seconds':120},

      {'name':'哑铃侧平举','target_muscle':'三角肌中束','equipment_type':'dumbbell','difficulty':2,
       'description':'微屈肘，哑铃从体侧向两侧抬起至肩平，像倒水一样小指略高于拇指，顶峰收缩1秒，控制下放。',
       'svg_data':'<svg viewBox="0 0 100 100"><rect x="20" y="50" width="15" height="6" fill="#888" rx="2" transform="rotate(-20 27 53)"/><rect x="65" y="50" width="15" height="6" fill="#888" rx="2" transform="rotate(20 72 53)"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">侧平举</text></svg>',
       'local_video_path':'','alternative_ids':'53','default_weight':8,'default_sets':4,'default_reps':15,'rest_seconds':90},

      {'name':'哑铃前平举','target_muscle':'三角肌前束','equipment_type':'dumbbell','difficulty':1,
       'description':'交替或同时，哑铃从大腿前侧抬起至眼平，控制下放，不要摆动借力。',
       'svg_data':'<svg viewBox="0 0 100 100"><rect x="25" y="40" width="20" height="6" fill="#888" rx="2" transform="rotate(-30 35 43)"/><rect x="55" y="40" width="20" height="6" fill="#888" rx="2" transform="rotate(30 65 43)"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">前平举</text></svg>',
       'local_video_path':'','alternative_ids':'47','default_weight':8,'default_sets':3,'default_reps':12,'rest_seconds':90},

      {'name':'面拉','target_muscle':'三角肌后束','equipment_type':'gym','difficulty':2,
       'description':'龙门架滑轮调至面部高度，绳索拉向面部两侧，肘部高于肩部，外旋手臂，顶峰收缩挤压后束。',
       'svg_data':'<svg viewBox="0 0 100 100"><line x1="50" y1="10" x2="50" y2="40" stroke="#888" stroke-width="3"/><line x1="30" y1="40" x2="50" y2="50" stroke="#888" stroke-width="3"/><line x1="70" y1="40" x2="50" y2="50" stroke="#888" stroke-width="3"/><circle cx="50" cy="50" r="6" fill="#666"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">面拉</text></svg>',
       'local_video_path':'','alternative_ids':'50,54','default_weight':15,'default_sets':4,'default_reps':15,'rest_seconds':90},

      {'name':'哑铃俯身飞鸟','target_muscle':'三角肌后束','equipment_type':'dumbbell','difficulty':1,
       'description':'俯身约45度，大臂微屈，哑铃向两侧打开，挤压后束，回放时控制。',
       'svg_data':'<svg viewBox="0 0 100 100"><rect x="20" y="45" width="15" height="6" fill="#888" rx="2" transform="rotate(10 27 48)"/><rect x="65" y="45" width="15" height="6" fill="#888" rx="2" transform="rotate(-10 72 48)"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">俯身飞鸟</text></svg>',
       'local_video_path':'','alternative_ids':'49,54','default_weight':6,'default_sets':4,'default_reps':15,'rest_seconds':90},

      {'name':'倒立撑','target_muscle':'三角肌前束','equipment_type':'bodyweight','difficulty':4,
       'description':'靠墙倒立，屈肘下放至头顶轻触地面，推起，极难，肩部徒手终极动作，需循序渐进。',
       'svg_data':'<svg viewBox="0 0 100 100"><line x1="50" y1="80" x2="50" y2="40" stroke="#666" stroke-width="4"/><line x1="40" y1="40" x2="60" y2="40" stroke="#888" stroke-width="3"/><circle cx="50" cy="30" r="8" fill="#888"/><text x="50" y="95" text-anchor="middle" font-size="8" fill="#aaa">倒立撑</text></svg>',
       'local_video_path':'','alternative_ids':'46','default_weight':0,'default_sets':4,'default_reps':6,'rest_seconds':120},

      {'name':'阿诺德推举','target_muscle':'三角肌前束','equipment_type':'dumbbell','difficulty':3,
       'description':'坐姿，哑铃从胸前开始，边推起边外旋手臂，顶端掌心朝前，全程控制，对前束刺激极大。',
       'svg_data':'<svg viewBox="0 0 100 100"><rect x="35" y="35" width="8" height="18" fill="#888" rx="2" transform="rotate(-30 39 44)"/><rect x="57" y="35" width="8" height="18" fill="#888" rx="2" transform="rotate(30 61 44)"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">阿诺德推举</text></svg>',
       'local_video_path':'','alternative_ids':'47,46','default_weight':12,'default_sets':3,'default_reps':10,'rest_seconds':120},

      {'name':'绳索侧平举','target_muscle':'三角肌中束','equipment_type':'gym','difficulty':2,
       'description':'龙门架低位，绳索提供持续张力，比哑铃侧平举全程张力更好，顶峰收缩更强烈。',
       'svg_data':'<svg viewBox="0 0 100 100"><line x1="50" y1="10" x2="50" y2="40" stroke="#888" stroke-width="3"/><line x1="50" y1="40" x2="30" y2="50" stroke="#888" stroke-width="3"/><circle cx="30" cy="50" r="5" fill="#666"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">绳索侧平举</text></svg>',
       'local_video_path':'','alternative_ids':'48','default_weight':10,'default_sets':3,'default_reps':15,'rest_seconds':90},

      {'name':'壶铃上举','target_muscle':'三角肌前束','equipment_type':'dumbbell','difficulty':2,
       'description':'单手持哑铃（替代壶铃），从肩部翻起至头顶，核心收紧，防止腰部反弓，全身协调动作。',
       'svg_data':'<svg viewBox="0 0 100 100"><circle cx="50" cy="25" r="8" fill="#888"/><line x1="50" y1="33" x2="50" y2="60" stroke="#666" stroke-width="4"/><line x1="40" y1="60" x2="40" y2="85" stroke="#666" stroke-width="4"/><text x="50" y="95" text-anchor="middle" font-size="8" fill="#aaa">壶铃上举</text></svg>',
       'local_video_path':'','alternative_ids':'46,47','default_weight':12,'default_sets':3,'default_reps':10,'rest_seconds':120},

      // ========== 二头肌 6个 ==========
      {'name':'杠铃弯举','target_muscle':'肱二头肌','equipment_type':'gym','difficulty':2,
       'description':'站姿，大臂贴紧身体两侧固定，杠铃从大腿前侧弯举至锁骨，顶峰收缩1秒，不要前后晃动借力。',
       'svg_data':'<svg viewBox="0 0 100 100"><rect x="20" y="45" width="60" height="8" fill="#888" rx="2"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">杠铃弯举</text></svg>',
       'local_video_path':'','alternative_ids':'57,58','default_weight':25,'default_sets':4,'default_reps':10,'rest_seconds':90},

      {'name':'哑铃弯举','target_muscle':'肱二头肌','equipment_type':'dumbbell','difficulty':1,
       'description':'站姿或坐姿，大臂固定，掌心朝前，哑铃弯举至肩平，可交替或同时，控制离心。',
       'svg_data':'<svg viewBox="0 0 100 100"><rect x="35" y="40" width="8" height="18" fill="#888" rx="2"/><rect x="57" y="40" width="8" height="18" fill="#888" rx="2"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">哑铃弯举</text></svg>',
       'local_video_path':'','alternative_ids':'58,57','default_weight':10,'default_sets':4,'default_reps':12,'rest_seconds':90},

      {'name':'锤式弯举','target_muscle':'肱肌/肱桡肌','equipment_type':'dumbbell','difficulty':1,
       'description':'掌心相对（中立握），哑铃像锤子一样弯举，重点刺激肱肌和肱桡肌，增加手臂厚度。',
       'svg_data':'<svg viewBox="0 0 100 100"><rect x="35" y="40" width="8" height="18" fill="#888" rx="2" transform="rotate(10 39 49)"/><rect x="57" y="40" width="8" height="18" fill="#888" rx="2" transform="rotate(-10 61 49)"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">锤式弯举</text></svg>',
       'local_video_path':'','alternative_ids':'57,56','default_weight':10,'default_sets':4,'default_reps':12,'rest_seconds':90},

      {'name':'集中弯举','target_muscle':'肱二头肌','equipment_type':'dumbbell','difficulty':2,
       'description':'坐姿，大臂内侧贴紧大腿内侧，孤立弯举，顶峰收缩2秒，极孤立，适合收尾。',
       'svg_data':'<svg viewBox="0 0 100 100"><rect x="45" y="40" width="8" height="20" fill="#888" rx="2"/><rect x="35" y="65" width="30" height="10" fill="#555" rx="2"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">集中弯举</text></svg>',
       'local_video_path':'','alternative_ids':'56','default_weight':8,'default_sets':3,'default_reps':12,'rest_seconds':60},

      {'name':'反向弯举','target_muscle':'肱桡肌/前臂','equipment_type':'gym','difficulty':2,
       'description':'反握杠铃（掌心向下），弯举幅度较小，重点刺激前臂伸肌和肱桡肌，增强握力。',
       'svg_data':'<svg viewBox="0 0 100 100"><rect x="20" y="45" width="60" height="8" fill="#888" rx="2" transform="rotate(180 50 49)"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">反向弯举</text></svg>',
       'local_video_path':'','alternative_ids':'56','default_weight':20,'default_sets':3,'default_reps':12,'rest_seconds':90},

      {'name':'斜板弯举','target_muscle':'肱二头肌','equipment_type':'dumbbell','difficulty':2,
       'description':'上斜凳调至45-60度，躺姿，大臂自然下垂，哑铃弯举，长头拉伸更充分，增加二头峰高度。',
       'svg_data':'<svg viewBox="0 0 100 100"><rect x="35" y="35" width="8" height="18" fill="#888" rx="2" transform="rotate(-20 39 44)"/><rect x="57" y="35" width="8" height="18" fill="#888" rx="2" transform="rotate(20 61 44)"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">斜板弯举</text></svg>',
       'local_video_path':'','alternative_ids':'56,58','default_weight':8,'default_sets':3,'default_reps':10,'rest_seconds':90},

      // ========== 三头肌 6个 ==========
      {'name':'绳索下压','target_muscle':'肱三头肌','equipment_type':'gym','difficulty':2,
       'description':'龙门架直杆或绳索，大臂贴紧身体两侧固定，肘关节为轴下压至手臂伸直，顶峰收缩1秒，回放时控制。',
       'svg_data':'<svg viewBox="0 0 100 100"><line x1="50" y1="10" x2="50" y2="40" stroke="#888" stroke-width="3"/><rect x="40" y="40" width="20" height="6" fill="#666" rx="2"/><line x1="45" y1="46" x2="35" y2="60" stroke="#666" stroke-width="3"/><line x1="55" y1="46" x2="65" y2="60" stroke="#666" stroke-width="3"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">绳索下压</text></svg>',
       'local_video_path':'','alternative_ids':'63,65','default_weight':20,'default_sets':4,'default_reps':12,'rest_seconds':90},

      {'name':'哑铃颈后臂屈伸','target_muscle':'肱三头肌','equipment_type':'dumbbell','difficulty':2,
       'description':'双手或单手，哑铃举过头顶，屈肘下放至后脑，肘关节朝前固定，三头肌发力伸直。',
       'svg_data':'<svg viewBox="0 0 100 100"><circle cx="50" cy="25" r="8" fill="#888"/><line x1="50" y1="33" x2="50" y2="55" stroke="#666" stroke-width="4"/><line x1="40" y1="55" x2="30" y2="70" stroke="#666" stroke-width="3"/><line x1="60" y1="55" x2="70" y2="70" stroke="#666" stroke-width="3"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">颈后臂屈伸</text></svg>',
       'local_video_path':'','alternative_ids':'63,64','default_weight':12,'default_sets':3,'default_reps':12,'rest_seconds':90},

      {'name':'窄距卧推','target_muscle':'肱三头肌','equipment_type':'gym','difficulty':3,
       'description':'握距与肩同宽或更窄，下放至胸下部，肘关节贴近身体，推起时三头肌主导发力。',
       'svg_data':'<svg viewBox="0 0 100 100"><rect x="30" y="45" width="40" height="8" fill="#888" rx="2"/><circle cx="35" cy="49" r="4" fill="#333"/><circle cx="65" cy="49" r="4" fill="#333"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">窄距卧推</text></svg>',
       'local_video_path':'','alternative_ids':'62,65','default_weight':50,'default_sets':4,'default_reps':8,'rest_seconds':150},

      {'name':'板凳臂屈伸','target_muscle':'肱三头肌','equipment_type':'bodyweight','difficulty':1,
       'description':'双手撑在卧推凳或椅子边缘，双腿伸直或屈膝，屈肘下放至大臂平行地面，三头肌推起。',
       'svg_data':'<svg viewBox="0 0 100 100"><rect x="20" y="50" width="60" height="10" fill="#555" rx="2"/><line x1="35" y1="50" x2="35" y2="80" stroke="#666" stroke-width="4"/><line x1="65" y1="50" x2="65" y2="80" stroke="#666" stroke-width="4"/><line x1="50" y1="80" x2="50" y2="90" stroke="#666" stroke-width="4"/><text x="50" y="95" text-anchor="middle" font-size="8" fill="#aaa">板凳臂屈伸</text></svg>',
       'local_video_path':'','alternative_ids':'64','default_weight':0,'default_sets':4,'default_reps':15,'rest_seconds':90},

      {'name':'仰卧臂屈伸','target_muscle':'肱三头肌','equipment_type':'gym','difficulty':2,
       'description':'平躺，曲杆或直杆从额头位置屈肘下放至耳侧，肘关节固定，三头肌发力伸直，不要外展。',
       'svg_data':'<svg viewBox="0 0 100 100"><rect x="20" y="35" width="60" height="8" fill="#888" rx="2"/><circle cx="25" cy="39" r="4" fill="#333"/><circle cx="75" cy="39" r="4" fill="#333"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">仰卧臂屈伸</text></svg>',
       'local_video_path':'','alternative_ids':'62,63','default_weight':25,'default_sets':4,'default_reps':10,'rest_seconds':120},

      {'name':'哑铃俯身臂屈伸','target_muscle':'肱三头肌','equipment_type':'dumbbell','difficulty':1,
       'description':'俯身，大臂贴紧身体后侧，哑铃向后上方伸直，顶峰收缩，单侧交替。',
       'svg_data':'<svg viewBox="0 0 100 100"><rect x="45" y="35" width="8" height="18" fill="#888" rx="2" transform="rotate(-45 49 44)"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">俯身臂屈伸</text></svg>',
       'local_video_path':'','alternative_ids':'62','default_weight':8,'default_sets':3,'default_reps':15,'rest_seconds':60},

      // ========== 核心 10个 ==========
      {'name':'平板支撑','target_muscle':'腹横肌','equipment_type':'bodyweight','difficulty':1,
       'description':'肘关节支撑，身体呈一条直线，核心收紧不塌腰，臀部夹紧，正常呼吸不憋气，时间逐步递增。',
       'svg_data':'<svg viewBox="0 0 100 100"><line x1="30" y1="70" x2="70" y2="70" stroke="#666" stroke-width="4"/><line x1="35" y1="70" x2="35" y2="50" stroke="#666" stroke-width="4"/><line x1="65" y1="70" x2="65" y2="50" stroke="#666" stroke-width="4"/><line x1="35" y1="50" x2="65" y2="50" stroke="#888" stroke-width="3"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">平板支撑</text></svg>',
       'local_video_path':'','alternative_ids':'','default_weight':0,'default_sets':3,'default_reps':60,'rest_seconds':60},

      {'name':'卷腹','target_muscle':'腹直肌上部','equipment_type':'bodyweight','difficulty':1,
       'description':'仰卧屈膝，双手放耳侧（不抱头），腹部发力卷起肩胛骨离地，腰部始终贴地，不要全起坐伤腰。',
       'svg_data':'<svg viewBox="0 0 100 100"><line x1="30" y1="60" x2="70" y2="60" stroke="#666" stroke-width="4"/><line x1="50" y1="60" x2="50" y2="40" stroke="#666" stroke-width="4"/><circle cx="50" cy="35" r="6" fill="#888"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">卷腹</text></svg>',
       'local_video_path':'','alternative_ids':'','default_weight':0,'default_sets':4,'default_reps':20,'rest_seconds':60},

      {'name':'悬垂举腿','target_muscle':'腹直肌下部','equipment_type':'gym','difficulty':3,
       'description':'单杠悬垂，骨盆后倾（不是单纯抬腿），用下腹力量将膝盖抬向胸部，控制回放，避免摆动。',
       'svg_data':'<svg viewBox="0 0 100 100"><line x1="50" y1="10" x2="50" y2="30" stroke="#888" stroke-width="3"/><circle cx="50" cy="35" r="6" fill="#888"/><line x1="45" y1="41" x2="45" y2="60" stroke="#666" stroke-width="4"/><line x1="55" y1="41" x2="55" y2="60" stroke="#666" stroke-width="4"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">悬垂举腿</text></svg>',
       'local_video_path':'','alternative_ids':'','default_weight':0,'default_sets':4,'default_reps':12,'rest_seconds':90},

      {'name':'俄罗斯转体','target_muscle':'腹斜肌','equipment_type':'dumbbell','difficulty':2,
       'description':'坐姿屈膝，脚可离地，双手持哑铃或空手，躯干左右旋转触地，核心控制平衡，不要用手臂摆动。',
       'svg_data':'<svg viewBox="0 0 100 100"><circle cx="50" cy="50" r="8" fill="#888"/><rect x="30" y="48" width="15" height="6" fill="#666" rx="2" transform="rotate(-20 37 51)"/><rect x="55" y="48" width="15" height="6" fill="#666" rx="2" transform="rotate(20 62 51)"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">俄罗斯转体</text></svg>',
       'local_video_path':'','alternative_ids':'','default_weight':6,'default_sets':3,'default_reps':20,'rest_seconds':60},

      {'name':'死虫','target_muscle':'腹横肌','equipment_type':'bodyweight','difficulty':1,
       'description':'仰卧，手臂和大腿垂直抬起，对侧手脚同时缓慢下放至接近地面，腰部始终贴地，核心稳定。',
       'svg_data':'<svg viewBox="0 0 100 100"><circle cx="50" cy="50" r="6" fill="#888"/><line x1="30" y1="40" x2="50" y2="50" stroke="#666" stroke-width="3"/><line x1="70" y1="40" x2="50" y2="50" stroke="#666" stroke-width="3"/><line x1="40" y1="60" x2="50" y2="50" stroke="#666" stroke-width="3"/><line x1="60" y1="60" x2="50" y2="50" stroke="#666" stroke-width="3"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">死虫</text></svg>',
       'local_video_path':'','alternative_ids':'','default_weight':0,'default_sets':3,'default_reps':12,'rest_seconds':60},

      {'name':'登山跑','target_muscle':'腹直肌','equipment_type':'bodyweight','difficulty':2,
       'description':'平板支撑起始位，交替将膝盖提向胸部，像跑步一样，保持核心稳定不塌腰，速度快。',
       'svg_data':'<svg viewBox="0 0 100 100"><line x1="30" y1="70" x2="70" y2="70" stroke="#666" stroke-width="3"/><circle cx="50" cy="50" r="6" fill="#888"/><line x1="50" y1="56" x2="40" y2="70" stroke="#666" stroke-width="3"/><line x1="50" y1="56" x2="60" y2="65" stroke="#666" stroke-width="3"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">登山跑</text></svg>',
       'local_video_path':'','alternative_ids':'','default_weight':0,'default_sets':4,'default_reps':30,'rest_seconds':60},

      {'name':'侧平板支撑','target_muscle':'腹斜肌','equipment_type':'bodyweight','difficulty':2,
       'description':'侧卧，肘关节支撑，身体呈直线，臀部抬起不触地，可上侧腿抬高增加难度，每侧分别计时。',
       'svg_data':'<svg viewBox="0 0 100 100"><line x1="50" y1="70" x2="80" y2="70" stroke="#666" stroke-width="4"/><line x1="50" y1="70" x2="50" y2="40" stroke="#666" stroke-width="4"/><line x1="50" y1="40" x2="80" y2="40" stroke="#888" stroke-width="3"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">侧平板</text></svg>',
       'local_video_path':'','alternative_ids':'','default_weight':0,'default_sets':3,'default_reps':45,'rest_seconds':60},

      {'name':'反向卷腹','target_muscle':'腹直肌下部','equipment_type':'bodyweight','difficulty':2,
       'description':'仰卧，双腿屈膝抬起，用下腹力量将骨盆抬离地面，膝盖向胸部卷，不要靠腿部摆动惯性。',
       'svg_data':'<svg viewBox="0 0 100 100"><line x1="30" y1="60" x2="70" y2="60" stroke="#666" stroke-width="4"/><line x1="50" y1="60" x2="50" y2="40" stroke="#666" stroke-width="4"/><circle cx="50" cy="35" r="6" fill="#888"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">反向卷腹</text></svg>',
       'local_video_path':'','alternative_ids':'','default_weight':0,'default_sets':4,'default_reps':15,'rest_seconds':60},

      {'name':'健腹轮','target_muscle':'腹直肌','equipment_type':'gym','difficulty':4,
       'description':'跪姿，双手握轮，缓慢向前推出至身体接近地面，核心收紧拉回，极难，初学者可推半程。',
       'svg_data':'<svg viewBox="0 0 100 100"><circle cx="50" cy="75" r="8" fill="#888"/><line x1="50" y1="67" x2="50" y2="45" stroke="#666" stroke-width="4"/><line x1="40" y1="45" x2="60" y2="45" stroke="#666" stroke-width="3"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">健腹轮</text></svg>',
       'local_video_path':'','alternative_ids':'','default_weight':0,'default_sets':3,'default_reps':8,'rest_seconds':90},

      {'name':'鸟狗式','target_muscle':'竖脊肌/核心稳定','equipment_type':'bodyweight','difficulty':1,
       'description':'四足跪姿，对侧手脚同时伸直，身体保持水平不旋转，核心收紧，每侧保持5-10秒。',
       'svg_data':'<svg viewBox="0 0 100 100"><line x1="40" y1="60" x2="60" y2="60" stroke="#666" stroke-width="4"/><line x1="40" y1="60" x2="25" y2="45" stroke="#666" stroke-width="3"/><line x1="60" y1="60" x2="75" y2="75" stroke="#666" stroke-width="3"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">鸟狗式</text></svg>',
       'local_video_path':'','alternative_ids':'','default_weight':0,'default_sets':3,'default_reps':10,'rest_seconds':60},

      // ========== 全身/功能性 8个 ==========
      {'name':'波比跳','target_muscle':'全身','equipment_type':'bodyweight','difficulty':3,
       'description':'站立→深蹲手撑地→双脚后跳成平板→俯卧撑（可选）→双脚跳回→垂直跳起，全身爆发，心肺杀手。',
       'svg_data':'<svg viewBox="0 0 100 100"><circle cx="50" cy="30" r="6" fill="#888"/><line x1="45" y1="36" x2="35" y2="55" stroke="#666" stroke-width="3"/><line x1="55" y1="36" x2="65" y2="55" stroke="#666" stroke-width="3"/><line x1="35" y1="55" x2="65" y2="55" stroke="#888" stroke-width="3"/><line x1="40" y1="55" x2="40" y2="80" stroke="#666" stroke-width="3"/><line x1="60" y1="55" x2="60" y2="80" stroke="#666" stroke-width="3"/><text x="50" y="95" text-anchor="middle" font-size="8" fill="#aaa">波比跳</text></svg>',
       'local_video_path':'','alternative_ids':'','default_weight':0,'default_sets':4,'default_reps':10,'rest_seconds':120},

      {'name':'壶铃摇摆','target_muscle':'臀大肌/全身','equipment_type':'dumbbell','difficulty':2,
       'description':'双手持哑铃，宽站屈髋，臀部爆发力向前摆起哑铃至眼平，核心收紧，是髋铰链模式最佳训练。',
       'svg_data':'<svg viewBox="0 0 100 100"><circle cx="50" cy="30" r="8" fill="#888"/><line x1="50" y1="38" x2="50" y2="60" stroke="#666" stroke-width="4"/><line x1="40" y1="60" x2="40" y2="85" stroke="#666" stroke-width="4"/><line x1="60" y1="60" x2="60" y2="85" stroke="#666" stroke-width="4"/><text x="50" y="95" text-anchor="middle" font-size="8" fill="#aaa">壶铃摇摆</text></svg>',
       'local_video_path':'','alternative_ids':'','default_weight':16,'default_sets':4,'default_reps':15,'rest_seconds':120},

      {'name':'药球砸地','target_muscle':'全身爆发力','equipment_type':'gym','difficulty':2,
       'description':'双手举药球过顶，用全身力量砸向地面，接住反弹，强化爆发力，注意地面材质。',
       'svg_data':'<svg viewBox="0 0 100 100"><circle cx="50" cy="25" r="8" fill="#888"/><line x1="50" y1="33" x2="50" y2="70" stroke="#666" stroke-width="4"/><rect x="40" y="70" width="20" height="10" fill="#555" rx="3"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">药球砸地</text></svg>',
       'local_video_path':'','alternative_ids':'','default_weight':6,'default_sets':4,'default_reps':12,'rest_seconds':120},

      {'name':'战绳','target_muscle':'全身/心肺','equipment_type':'gym','difficulty':3,
       'description':'双手各握绳端，快速交替上下甩动，保持核心稳定，30秒为一组，极强心肺刺激。',
       'svg_data':'<svg viewBox="0 0 100 100"><path d="M20 30 Q30 50 20 70" stroke="#888" stroke-width="4" fill="none"/><path d="M80 30 Q70 50 80 70" stroke="#888" stroke-width="4" fill="none"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">战绳</text></svg>',
       'local_video_path':'','alternative_ids':'','default_weight':0,'default_sets':6,'default_reps':30,'rest_seconds':60},

      {'name':'农夫行走','target_muscle':'握力/斜方肌','equipment_type':'dumbbell','difficulty':2,
       'description':'双手各持重哑铃，挺胸肩胛下沉，直线行走指定距离，强化握力、核心稳定和斜方肌。',
       'svg_data':'<svg viewBox="0 0 100 100"><rect x="30" y="40" width="8" height="20" fill="#888" rx="2"/><rect x="62" y="40" width="8" height="20" fill="#888" rx="2"/><line x1="34" y1="60" x2="34" y2="85" stroke="#666" stroke-width="4"/><line x1="66" y1="60" x2="66" y2="85" stroke="#666" stroke-width="4"/><text x="50" y="95" text-anchor="middle" font-size="8" fill="#aaa">农夫行走</text></svg>',
       'local_video_path':'','alternative_ids':'','default_weight':24,'default_sets':3,'default_reps':40,'rest_seconds':120},

      {'name':'土耳其起立','target_muscle':'全身稳定','equipment_type':'dumbbell','difficulty':4,
       'description':'平躺一手举哑铃，从躺到站到躺，全程手臂伸直不弯曲，极难全身稳定动作，需分解学习。',
       'svg_data':'<svg viewBox="0 0 100 100"><circle cx="50" cy="25" r="8" fill="#888"/><line x1="50" y1="33" x2="50" y2="60" stroke="#666" stroke-width="4"/><line x1="40" y1="60" x2="40" y2="85" stroke="#666" stroke-width="4"/><line x1="60" y1="60" x2="60" y2="85" stroke="#666" stroke-width="4"/><text x="50" y="95" text-anchor="middle" font-size="8" fill="#aaa">土耳其起立</text></svg>',
       'local_video_path':'','alternative_ids':'','default_weight':12,'default_sets':3,'default_reps':5,'rest_seconds':180},

      {'name':'跳绳','target_muscle':'小腿/心肺','equipment_type':'bodyweight','difficulty':1,
       'description':'双脚或交替跳，手腕摇绳不是手臂，前脚掌着地，膝盖微屈缓冲，极佳热身和有氧。',
       'svg_data':'<svg viewBox="0 0 100 100"><path d="M20 30 Q50 70 80 30" stroke="#888" stroke-width="3" fill="none"/><circle cx="20" cy="30" r="4" fill="#666"/><circle cx="80" cy="30" r="4" fill="#666"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">跳绳</text></svg>',
       'local_video_path':'','alternative_ids':'','default_weight':0,'default_sets':5,'default_reps':100,'rest_seconds':60},

      {'name':'开合跳','target_muscle':'全身/心肺','equipment_type':'bodyweight','difficulty':1,
       'description':'站立跳起双脚分开双手头上击掌，再跳回，全身热身动作，简单高效。',
       'svg_data':'<svg viewBox="0 0 100 100"><line x1="30" y1="40" x2="50" y2="20" stroke="#666" stroke-width="3"/><line x1="70" y1="40" x2="50" y2="20" stroke="#666" stroke-width="3"/><line x1="40" y1="60" x2="60" y2="60" stroke="#666" stroke-width="3"/><line x1="40" y1="60" x2="40" y2="85" stroke="#666" stroke-width="3"/><line x1="60" y1="60" x2="60" y2="85" stroke="#666" stroke-width="3"/><text x="50" y="95" text-anchor="middle" font-size="8" fill="#aaa">开合跳</text></svg>',
       'local_video_path':'','alternative_ids':'','default_weight':0,'default_sets':4,'default_reps':50,'rest_seconds':60},

      // ========== 有氧器械 4个 ==========
      {'name':'跑步机','target_muscle':'心肺/下肢','equipment_type':'gym','difficulty':1,
       'description':'可调节坡度和速度，建议坡度1-2%模拟户外跑，对膝盖冲击小于户外水泥地，适合热身和有氧。',
       'svg_data':'<svg viewBox="0 0 100 100"><rect x="10" y="60" width="80" height="20" fill="#555" rx="2" transform="rotate(-10 50 70)"/><line x1="40" y1="50" x2="40" y2="70" stroke="#666" stroke-width="4"/><line x1="60" y1="50" x2="60" y2="70" stroke="#666" stroke-width="4"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">跑步机</text></svg>',
       'local_video_path':'','alternative_ids':'','default_weight':0,'default_sets':1,'default_reps':20,'rest_seconds':0},

      {'name':'椭圆机','target_muscle':'心肺/全身','equipment_type':'gym','difficulty':1,
       'description':'低冲击有氧，手脚协调，适合膝盖不好或大体重人群，可反向踩刺激臀肌。',
       'svg_data':'<svg viewBox="0 0 100 100"><ellipse cx="50" cy="50" rx="30" ry="20" stroke="#888" stroke-width="3" fill="none"/><line x1="35" y1="50" x2="35" y2="80" stroke="#666" stroke-width="4"/><line x1="65" y1="50" x2="65" y2="80" stroke="#666" stroke-width="4"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">椭圆机</text></svg>',
       'local_video_path':'','alternative_ids':'','default_weight':0,'default_sets':1,'default_reps':20,'rest_seconds':0},

      {'name':'划船机','target_muscle':'心肺/背腿','equipment_type':'gym','difficulty':2,
       'description':'全身参与有氧，腿蹬手拉，轨迹固定，热量消耗极高，对膝盖友好。',
       'svg_data':'<svg viewBox="0 0 100 100"><rect x="20" y="60" width="60" height="10" fill="#555" rx="2"/><line x1="50" y1="60" x2="50" y2="40" stroke="#666" stroke-width="4"/><line x1="40" y1="40" x2="60" y2="40" stroke="#888" stroke-width="3"/><text x="50" y="90" text-anchor="middle" font-size="8" fill="#aaa">划船机</text></svg>',
       'local_video_path':'','alternative_ids':'','default_weight':0,'default_sets':1,'default_reps':15,'rest_seconds':0},

      {'name':'自行车','target_muscle':'心肺/下肢','equipment_type':'bodyweight','difficulty':1,
       'description':'户外或动感单车，低冲击有氧，可调节阻力，适合长时间有氧和恢复日。',
       'svg_data':'<svg viewBox="0 0 100 100"><circle cx="30" cy="70" r="15" stroke="#888" stroke-width="3" fill="none"/><circle cx="70" cy="70" r="15" stroke="#888" stroke-width="3" fill="none"/><line x1="30" y1="70" x2="70" y2="70" stroke="#666" stroke-width="3"/><line x1="50" y1="70" x2="50" y2="40" stroke="#666" stroke-width="3"/><text x="50" y="95" text-anchor="middle" font-size="8" fill="#aaa">自行车</text></svg>',
       'local_video_path':'','alternative_ids':'','default_weight':0,'default_sets':1,'default_reps':30,'rest_seconds':0},
    ];

    for (var e in exercises) {
      await db.insert('exercises', e);
    }
  }

  Future _seedDefaultEnv(Database db) async {
    await db.insert('environments', {
      'name': '健身房',
      'location_type': 'gym',
      'equipment_list': '["gym","dumbbell","bodyweight"]',
      'default_weights': '{"杠铃卧推":60,"哑铃卧推":20,"俯卧撑":0,"上斜杠铃卧推":50,"上斜哑铃卧推":18,"哑铃飞鸟":12,"绳索夹胸":15,"双杠臂屈伸":0,"史密斯机卧推":60,"地板哑铃卧推":18,"宽距俯卧撑":0,"杠铃划船":50,"哑铃单臂划船":15,"引体向上":0,"高位下拉":40,"坐姿绳索划船":45,"T杠划船":60,"反向划船":0,"直臂下压":20,"哑铃俯身划船":14,"超人式":0,"单臂绳索划船":25,"门框划船":0,"杠铃深蹲":80,"哑铃高脚杯深蹲":20,"保加利亚分腿蹲":0,"腿举":120,"箭步蹲":14,"哈克深蹲":100,"深蹲跳":0,"侧箭步蹲":12,"罗马尼亚硬拉":60,"哑铃罗马尼亚硬拉":16,"单腿罗马尼亚硬拉":10,"腿弯举":30,"北欧腿弯举":0,"臀推":80,"单腿臀推":20,"壶铃摆荡":16,"站姿杠铃提踵":60,"站姿哑铃提踵":20,"单腿提踵":0,"坐姿提踵":40,"杠铃推举":40,"哑铃推举":16,"哑铃侧平举":8,"哑铃前平举":8,"面拉":15,"哑铃俯身飞鸟":6,"倒立撑":0,"阿诺德推举":12,"绳索侧平举":10,"壶铃上举":12,"杠铃弯举":25,"哑铃弯举":10,"锤式弯举":10,"集中弯举":8,"反向弯举":20,"斜板弯举":8,"绳索下压":20,"哑铃颈后臂屈伸":12,"窄距卧推":50,"板凳臂屈伸":0,"仰卧臂屈伸":25,"哑铃俯身臂屈伸":8,"平板支撑":0,"卷腹":0,"悬垂举腿":0,"俄罗斯转体":6,"死虫":0,"登山跑":0,"侧平板支撑":0,"反向卷腹":0,"健腹轮":0,"鸟狗式":0,"波比跳":0,"壶铃摇摆":16,"药球砸地":6,"战绳":0,"农夫行走":24,"土耳其起立":12,"跳绳":0,"开合跳":0,"跑步机":0,"椭圆机":0,"划船机":0,"自行车":0}',
      'is_default': 1
    });
    await db.insert('environments', {
      'name': '家',
      'location_type': 'home',
      'equipment_list': '["dumbbell","bodyweight"]',
      'default_weights': '{"哑铃卧推":20,"俯卧撑":0,"上斜哑铃卧推":18,"哑铃飞鸟":12,"哑铃单臂划船":15,"引体向上":0,"反向划船":0,"哑铃俯身划船":14,"超人式":0,"门框划船":0,"哑铃高脚杯深蹲":20,"保加利亚分腿蹲":0,"箭步蹲":14,"深蹲跳":0,"侧箭步蹲":12,"哑铃罗马尼亚硬拉":16,"单腿罗马尼亚硬拉":10,"北欧腿弯举":0,"单腿臀推":20,"壶铃摆荡":16,"站姿哑铃提踵":20,"单腿提踵":0,"哑铃推举":16,"哑铃侧平举":8,"哑铃前平举":8,"哑铃俯身飞鸟":6,"阿诺德推举":12,"壶铃上举":12,"哑铃弯举":10,"锤式弯举":10,"集中弯举":8,"斜板弯举":8,"哑铃颈后臂屈伸":12,"板凳臂屈伸":0,"哑铃俯身臂屈伸":8,"平板支撑":0,"卷腹":0,"俄罗斯转体":6,"死虫":0,"登山跑":0,"侧平板支撑":0,"反向卷腹":0,"鸟狗式":0,"波比跳":0,"壶铃摇摆":16,"农夫行走":24,"跳绳":0,"开合跳":0,"自行车":0}',
      'is_default': 0
    });
    await db.insert('environments', {
      'name': '出差/酒店',
      'location_type': 'hotel',
      'equipment_list': '["bodyweight"]',
      'default_weights': '{"俯卧撑":0,"上斜俯卧撑":0,"双杠臂屈伸":0,"深蹲跳":0,"保加利亚分腿蹲":0,"侧箭步蹲":0,"单腿提踵":0,"倒立撑":0,"板凳臂屈伸":0,"平板支撑":0,"卷腹":0,"死虫":0,"登山跑":0,"侧平板支撑":0,"反向卷腹":0,"鸟狗式":0,"波比跳":0,"跳绳":0,"开合跳":0,"自行车":0}',
      'is_default': 0
    });
  }

  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(table, data);
  }

  Future<List<Map<String, dynamic>>> query(String table, {String? where, List<dynamic>? whereArgs, String? orderBy}) async {
    final db = await database;
    return await db.query(table, where: where, whereArgs: whereArgs, orderBy: orderBy);
  }

  Future<int> update(String table, Map<String, dynamic> data, String where, List<dynamic> whereArgs) async {
    final db = await database;
    return await db.update(table, data, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(String table, String where, List<dynamic> whereArgs) async {
    final db = await database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<void> rawQuery(String sql) async {
    final db = await database;
    await db.execute(sql);
  }
}
