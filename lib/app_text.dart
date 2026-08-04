/// 全局文字常量：集中管理界面文案，避免散落的硬编码字符串。
class AppText {
  AppText._();

  // 首页
  static const String searchHint = '寻觅往昔……';
  static const String emptyDiary = '今日无事，唯有清风。';
  static const String wanderEmpty = '暂无日记，先去写一篇吧';

  // 时间轴
  static const String timelineEmpty = '暂无往昔';
  static const String jumpToday = '今天';
  static const String jumpMonth = '一月';
  static const String jumpThreeMonths = '三月';
  static const String jumpYear = '一年';

  // 统计
  static const String statsTitle = '文辞';
  static const String backHint = '上滑返回';
  static const String statEntries = '篇数';
  static const String statWords = '字数';
  static const String statDays = '天数';
  static const String statDaily = '日均';
  static const String unitEntries = '篇';
  static const String unitWords = '字';
  static const String unitDays = '天';
  static const String unitDaily = '字/天';
  static const String wordCloudEmpty = '暂无词云';

  // 设置
  static const String fontSettingTitle = '正文字体';
  static const String fontSotyr = '仿宋';
  static const String fontKaishu = '楷书';

  // 自动备份引导
  static const String backupDialogTitle = '开启自动备份';
  static const String backupDialogContent =
      '为了保护您的日记数据安全，我们强烈建议您开启自动备份。\n\n请授权选择一个手机上的外部文件夹（如 Documents），日记将会在每次修改后自动且静默地备份到该目录。';
  static const String backupLater = '稍后再说';
  static const String backupChoose = '授权选择文件夹';

  // 备份加密
  static const String backupEncryption = '备份加密';
  static const String setBackupPassword = '设置备份密码';
  static const String changeBackupPassword = '修改备份密码';
}
