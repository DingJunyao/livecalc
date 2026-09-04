// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '生计 - 生活成本计算器';

  @override
  String get commonSave => '保存';

  @override
  String get commonCancel => '取消';

  @override
  String get commonUserInitial => '?';

  @override
  String get appBrandShort => '生计';

  @override
  String get appSigningIn => '登录中…';

  @override
  String get authServerUnavailable => '无法连接到服务器。请确认服务器已启动、地址正确，且当前网络可用，然后重试。';

  @override
  String get authLoginTitle => '登录';

  @override
  String get authLoginSubtitle => '请输入账号密码';

  @override
  String get authUsername => '用户名';

  @override
  String get authPassword => '密码';

  @override
  String get authUsernameRequired => '请输入用户名';

  @override
  String get authPasswordRequired => '请输入密码';

  @override
  String get authLoginButton => '登录';

  @override
  String get authNoAccountRegister => '没有账号？去注册';

  @override
  String get authServerNotConfigured => '未配置服务器';

  @override
  String get authChangeServer => '更换服务器';

  @override
  String get authRegisterTitle => '注册';

  @override
  String get authUsernameMinLength => '用户名至少 3 个字符';

  @override
  String get authEmail => '邮箱';

  @override
  String get authEmailRequired => '请输入邮箱';

  @override
  String get authEmailInvalid => '邮箱格式不正确';

  @override
  String get authPhoneOptional => '手机号（可选）';

  @override
  String get authInviteCode => '邀请码';

  @override
  String get authInviteCodeRequired => '请输入邀请码';

  @override
  String get authConfigLoadFailed => '注册配置加载失败，请检查网络后重试';

  @override
  String get authRegisterButton => '注册';

  @override
  String get authHaveAccountLogin => '已有账号？去登录';

  @override
  String get authInviteCodeNowRequired => '注册失败：服务器已开启邀请码注册，请填写邀请码';

  @override
  String get authServerConfigSubtitle => '生活成本计算器';

  @override
  String get authServerAddress => '服务器地址';

  @override
  String get authServerAddressHint => 'https://example.com';

  @override
  String get authServerAddressRequired => '请输入服务器地址';

  @override
  String get authServerAddressHttpRequired => '必须以 http:// 或 https:// 开头';

  @override
  String get authConnectionFailed => '连接失败：';

  @override
  String get authConnect => '连接';

  @override
  String get authCannotConnectServer => '无法连接服务器，请检查地址或网络后重试';

  @override
  String get authLoginInvalidCredentials => '用户名或密码错误';

  @override
  String get authLoginEndpointMissing => '登录接口不存在，请确认服务器版本';

  @override
  String get authServerError => '服务器内部错误，请稍后重试';

  @override
  String get authLoginNetworkError => '登录失败，请检查网络后重试';

  @override
  String get authLoginGenericError => '登录失败，请稍后重试';

  @override
  String authRegisterFailedDetail(Object detail) {
    return '注册失败：$detail';
  }

  @override
  String get authRegisterInvalid => '注册失败，请检查注册信息';

  @override
  String get authRegisterEndpointMissing => '注册接口不存在，请确认服务器版本';

  @override
  String get authRegisterServerError => '注册失败，请稍后重试';

  @override
  String get authRegisterNetworkError => '注册失败，请检查网络后重试';

  @override
  String get authRegisterGenericError => '注册失败，请稍后重试';

  @override
  String get authCropAvatar => '裁剪头像';

  @override
  String get authAvatarUpdated => '头像已更新';

  @override
  String get authAvatarUploadFailed => '头像上传失败，请重试';

  @override
  String get authNoChangesToSave => '没有需要保存的修改';

  @override
  String get authSaved => '已保存';

  @override
  String get authSaveFailedRetry => '保存失败，请重试';

  @override
  String get authSaveFailedCheckInput => '保存失败，请检查输入后重试';

  @override
  String get authEditAccountTitle => '编辑个人信息';

  @override
  String get authTapChangeAvatar => '点击更换头像';

  @override
  String get authUsernameLabel => '用户名 *';

  @override
  String get authUsernameLength => '用户名长度需为 3-50 个字符';

  @override
  String get authNickname => '昵称';

  @override
  String get authNicknameMaxLength => '昵称不能超过 50 个字符';

  @override
  String get authEditEmailInvalid => '请输入有效的邮箱地址';

  @override
  String get authPhoneInvalid => '请输入有效的手机号';

  @override
  String get authRegion => '所在地区';

  @override
  String get authChangePasswordOptional => '修改密码（可选）';

  @override
  String get authCurrentPassword => '当前密码';

  @override
  String get authCurrentPasswordRequired => '修改密码需提供当前密码';

  @override
  String get authNewPassword => '新密码（至少 6 个字符）';

  @override
  String get authNewPasswordMinLength => '新密码至少 6 个字符';

  @override
  String get authConfirmNewPassword => '确认新密码';

  @override
  String get authPasswordsDoNotMatch => '两次输入的新密码不一致';

  @override
  String get authSaving => '保存中...';

  @override
  String get profileTitle => '个人中心';

  @override
  String get profileAnonymousUser => '用户';

  @override
  String get profileSettings => '设置';

  @override
  String get profileLanguage => '语言';

  @override
  String get profileRegionalFormat => '区域格式';

  @override
  String get profileStartupPage => '启动时起始页';

  @override
  String get profileStartupPageHome => '推荐';

  @override
  String get profileStartupPagePrices => '计价';

  @override
  String get profileStartupPageRecipes => '菜谱';

  @override
  String get profileDefaultCurrency => '默认币种';

  @override
  String get profileFollowRegion => '跟随所在地区';

  @override
  String get profileDefaultCalcScope => '默认计算范围';

  @override
  String get profileCalcScopeAll => '全部地区';

  @override
  String get profileCalcScopeCountry => '国家/地区';

  @override
  String get profileCalcScopeProvince => '省份';

  @override
  String get profileCalcScopeCity => '城市';

  @override
  String get profileCalcScopeCounty => '区县';

  @override
  String get profileUnitPreferences => '单位偏好';

  @override
  String get profileNutritionGoals => '营养目标';

  @override
  String get profileMyData => '我的数据';

  @override
  String get profileMyProposals => '我的提议';

  @override
  String get profileMyPlaces => '我的地点';

  @override
  String get profileLogout => '退出登录';

  @override
  String get localeOptionZhCN => '中文 (中国)';

  @override
  String get localeOptionEnUS => 'English (United States)';

  @override
  String get localeOptionAr => 'العربية';

  @override
  String get formatOptionFollowLanguage => 'Follow language';

  @override
  String get formatOptionZhCN => 'Chinese (China)';

  @override
  String get formatOptionZhTW => 'Chinese (Taiwan)';

  @override
  String get formatOptionEnUS => 'English (United States)';

  @override
  String get formatOptionEnGB => 'English (United Kingdom)';

  @override
  String get formatOptionJaJP => 'Japanese (Japan)';

  @override
  String get formatOptionDeDE => 'German (Germany)';

  @override
  String get formatOptionIdID => 'Indonesian (Indonesia)';

  @override
  String get formatOptionArEG => 'Arabic (Egypt)';

  @override
  String get profileCurrencyNameCNY => '人民币';

  @override
  String get profileCurrencyNameUSD => '美元';

  @override
  String get profileCurrencyNameEUR => '欧元';

  @override
  String get profileCurrencyNameGBP => '英镑';

  @override
  String get profileCurrencyNameJPY => '日元';

  @override
  String get profileCurrencyNameHKD => '港币';

  @override
  String get profileCurrencyNameKRW => '韩元';

  @override
  String get profileCurrencyNameSGD => '新加坡元';

  @override
  String get profileCurrencyNameAUD => '澳大利亚元';

  @override
  String get profileCurrencyNameCAD => '加拿大元';

  @override
  String get profileCurrencyNameTWD => '新台币';

  @override
  String get profileCurrencyNameTHB => '泰铢';

  @override
  String get profileCurrencyNameMYR => '马来西亚林吉特';

  @override
  String get profileCurrencyNameVND => '越南盾';

  @override
  String get profileCurrencyNameRUB => '俄罗斯卢布';

  @override
  String get profileCurrencyNameAED => '阿联酋迪拉姆';

  @override
  String get profileCurrencyNameBGN => '保加利亚列弗';

  @override
  String get profileCurrencyNameBRL => '巴西雷亚尔';

  @override
  String get profileCurrencyNameCHF => '瑞士法郎';

  @override
  String get profileCurrencyNameCZK => '捷克克朗';

  @override
  String get profileCurrencyNameDKK => '丹麦克朗';

  @override
  String get profileCurrencyNameHUF => '匈牙利福林';

  @override
  String get profileCurrencyNameIDR => '印度尼西亚盾';

  @override
  String get profileCurrencyNameILS => '以色列新谢克尔';

  @override
  String get profileCurrencyNameINR => '印度卢比';

  @override
  String get profileCurrencyNameISK => '冰岛克朗';

  @override
  String get profileCurrencyNameMXN => '墨西哥比索';

  @override
  String get profileCurrencyNameNOK => '挪威克朗';

  @override
  String get profileCurrencyNameNZD => '新西兰元';

  @override
  String get profileCurrencyNamePHP => '菲律宾比索';

  @override
  String get profileCurrencyNamePLN => '波兰兹罗提';

  @override
  String get profileCurrencyNameRON => '罗马尼亚列伊';

  @override
  String get profileCurrencyNameSEK => '瑞典克朗';

  @override
  String get profileCurrencyNameTRY => '土耳其里拉';

  @override
  String get profileCurrencyNameZAR => '南非兰特';
}
