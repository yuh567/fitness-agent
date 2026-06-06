import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'database/db_helper.dart';

class KimiApiService {
  static const String _baseUrl = 'https://api.moonshot.cn/v1/chat/completions';

  /// 获取已保存的 API Key
  Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('kimi_api_key');
  }

  /// 保存 API Key
  Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('kimi_api_key', key);
  }

  /// 请求 AI 生成完整训练计划
  Future<Map<String, dynamic>?> requestPlanGeneration(
    UserProfile profile,
    FitnessGoals goals,
    TrainingHistory history,
    List<UserEquipment> equipment,
  ) async {
    final key = await getApiKey();
    if (key == null || key.isEmpty) {
      throw Exception('未设置 API Key，请先在设置页填入');
    }

    final prompt = '''
你是一位专业健身教练和运动科学专家。用户正在使用「铁匠铺」健身App，请根据以下信息生成一个4周完整训练计划，以JSON格式返回。

用户信息：
- 昵称：${profile.name}
- 身高：${profile.height ?? '未设置'}cm
- 体重：${profile.weight ?? '未设置'}kg
- 体脂率：${profile.bodyFat ?? '未设置'}%
- 训练经验：${profile.experienceLevel ?? '未知'}
- 总训练容量：${history.totalVolume.toStringAsFixed(0)}kg
- 总训练次数：${history.totalWorkouts}次
- 训练年限：${history.years}年

目标信息：
- 目标类型：${goals.type}
- 目标数值：${goals.targetValue}${goals.unit != null ? goals.unit : ''}
- 当前进度：${goals.currentValue ?? '未知'}
- 期限：${goals.deadline ?? '未设置'}

可用器材：${equipment.map((e) => '${e.name}(最大${e.maxWeight ?? '无限制'}kg)').join(', ')}

要求：
1. 根据用户水平和可用器材设计分化方案（Push/Pull/Legs 或 Upper/Lower 或全身）
2. 每周4-6天训练，包含具体动作、组数、次数、建议重量、RPE范围
3. 包含渐进超负荷策略（每周如何加重/加组）
4. 如有减脂目标，加入有氧建议和饮食提示
5. 返回严格合法JSON格式，不要包含markdown代码块标记：{"plan_name":"...","split":"...","weeks":[{"week":1,"days":[{"day_type":"...","exercises":[{"name":"...","sets":0,"reps":"...","weight":0,"rpe":"...","notes":"..."}]}]}],"notes":"..."}
'''
        .trim();

    return _makeRequest(prompt, model: 'moonshot-v1-8k');
  }

  /// 请求 AI 分析训练数据并给出调整建议
  Future<Map<String, dynamic>?> requestTrainingAnalysis(
    List<WorkoutLog> logs,
    List<BodyMetrics> metrics,
    List<DailyStatus> statuses,
  ) async {
    final key = await getApiKey();
    if (key == null || key.isEmpty) {
      throw Exception('未设置 API Key，请先在设置页填入');
    }

    final db = DBHelper();
    final absenceRecords = await db.query('absence_records', orderBy: 'date DESC', limit: 10);

    final prompt = '''
你是一位专业健身教练和运动科学专家。请分析用户最近训练数据并给出调整建议，以JSON格式返回。

最近训练记录（最近20条）：
${logs.take(20).map((l) => '- ${l.completedAt ?? '未知'}: 动作ID${l.exerciseId}, ${l.weight}kg × ${l.sets}组, 次数${l.reps}, RPE${l.rpe ?? '无'}').join('\n')}

最近身体数据：
${metrics.take(10).map((m) => '- ${m.date ?? '未知'}: 体重${m.weight ?? '未知'}kg, 体脂${m.bodyFat ?? '未知'}%').join('\n')}

最近状态记录：
${statuses.take(10).map((s) => '- ${s.date ?? '未知'}: 睡眠${s.sleepHours ?? '未知'}h, 疲劳度${s.fatigueLevel ?? '未知'}/10, 心情${s.mood ?? '未知'}').join('\n')}

请假记录：
${absenceRecords.map((a) => '- ${a['date']}: ${a['reason']}').join('\n')}

要求：
1. 分析训练频率、容量、RPE趋势
2. 识别平台期或过度训练信号
3. 给出具体调整建议（动作替换、容量调整、休息安排）
4. 如有请假记录，建议恢复策略
5. 返回严格合法JSON格式，不要包含markdown代码块标记：{"analysis":"...","trends":"...","recommendations":["..."],"deload_needed":false,"notes":"..."}
'''
        .trim();

    return _makeRequest(prompt, model: 'moonshot-v1-32k');
  }

  /// 请求 AI 根据当前状态调整今日计划
  Future<Map<String, dynamic>?> requestPlanAdjustment(
    WorkoutPlan currentPlan,
    DailyStatus todayStatus,
    List<WorkoutLog> recentLogs,
  ) async {
    final key = await getApiKey();
    if (key == null || key.isEmpty) {
      throw Exception('未设置 API Key，请先在设置页填入');
    }

    final prompt = '''
你是一位专业健身教练。用户今日原计划如下，请根据用户当前状态调整今日训练计划，以JSON格式返回。

当前计划：
- 日期：${currentPlan.date ?? '未知'}
- 类型：${currentPlan.dayType ?? '未知'}
- 动作列表：${currentPlan.exercises ?? '未知'}

今日状态：
- 睡眠：${todayStatus.sleepHours ?? '未知'}小时
- 疲劳度：${todayStatus.fatigueLevel ?? '未知'}/10
- 心情：${todayStatus.mood ?? '未知'}
- 体重：${todayStatus.bodyWeight ?? '未知'}kg

最近训练记录：
${recentLogs.take(5).map((l) => '- ${l.completedAt ?? '未知'}: ${l.weight}kg × ${l.sets}组').join('\n')}

要求：
1. 如疲劳度高（≥8），建议减量或改为恢复训练
2. 如状态好，可适当增加容量或尝试新动作
3. 保持原分化方向，调整具体动作、组数、次数
4. 返回严格合法JSON格式，不要包含markdown代码块标记：{"adjusted":true,"day_type":"...","exercises":[{"name":"...","sets":0,"reps":"...","weight":0,"rpe":"...","notes":"..."}],"reason":"...","notes":"..."}
'''
        .trim();

    return _makeRequest(prompt, model: 'moonshot-v1-8k');
  }

  /// 兼容旧版调用：深度调整分析
  Future<Map<String, dynamic>?> requestDeepAdjustment() async {
    final db = DBHelper();
    final logs = await db.query('workout_logs', orderBy: 'completed_at DESC', limit: 20);
    final metrics = await db.query('body_metrics', orderBy: 'date DESC', limit: 10);
    final logModels = logs.map((l) => WorkoutLog.fromMap(l)).toList();
    final metricModels = metrics.map((m) => BodyMetrics.fromMap(m)).toList();
    return requestTrainingAnalysis(logModels, metricModels, []);
  }

  /// 通用请求方法
  Future<Map<String, dynamic>?> _makeRequest(String prompt, {String model = 'moonshot-v1-8k'}) async {
    final key = await getApiKey();
    if (key == null || key.isEmpty) return null;

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $key',
      },
      body: jsonEncode({
        'model': model,
        'messages': [
          {
            'role': 'system',
            'content': '你是专业健身教练，精通NSCA和ACSM标准。所有回复必须是严格合法的JSON格式，不要包含markdown代码块标记（```json）。'
          },
          {'role': 'user', 'content': prompt}
        ],
        'temperature': 0.3,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final content = data['choices'][0]['message']['content'] as String;
      // 清理可能的 markdown 代码块标记
      final cleanContent = content
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();
      return jsonDecode(cleanContent) as Map<String, dynamic>;
    } else {
      throw Exception('API错误: ${response.statusCode} - ${response.body}');
    }
  }
}
