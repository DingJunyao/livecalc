import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'生计 - 生活成本计算器'**
  String get appTitle;

  /// No description provided for @commonSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get commonSave;

  /// No description provided for @commonCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get commonCancel;

  /// No description provided for @commonUserInitial.
  ///
  /// In zh, this message translates to:
  /// **'?'**
  String get commonUserInitial;

  /// No description provided for @appBrandShort.
  ///
  /// In zh, this message translates to:
  /// **'生计'**
  String get appBrandShort;

  /// No description provided for @appSigningIn.
  ///
  /// In zh, this message translates to:
  /// **'登录中…'**
  String get appSigningIn;

  /// No description provided for @authServerUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'无法连接到服务器。请确认服务器已启动、地址正确，且当前网络可用，然后重试。'**
  String get authServerUnavailable;

  /// No description provided for @authLoginTitle.
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get authLoginTitle;

  /// No description provided for @authLoginSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'请输入账号密码'**
  String get authLoginSubtitle;

  /// No description provided for @authUsername.
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get authUsername;

  /// No description provided for @authPassword.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get authPassword;

  /// No description provided for @authUsernameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入用户名'**
  String get authUsernameRequired;

  /// No description provided for @authPasswordRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入密码'**
  String get authPasswordRequired;

  /// No description provided for @authLoginButton.
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get authLoginButton;

  /// No description provided for @authNoAccountRegister.
  ///
  /// In zh, this message translates to:
  /// **'没有账号？去注册'**
  String get authNoAccountRegister;

  /// No description provided for @authServerNotConfigured.
  ///
  /// In zh, this message translates to:
  /// **'未配置服务器'**
  String get authServerNotConfigured;

  /// No description provided for @authChangeServer.
  ///
  /// In zh, this message translates to:
  /// **'更换服务器'**
  String get authChangeServer;

  /// No description provided for @authRegisterTitle.
  ///
  /// In zh, this message translates to:
  /// **'注册'**
  String get authRegisterTitle;

  /// No description provided for @authUsernameMinLength.
  ///
  /// In zh, this message translates to:
  /// **'用户名至少 3 个字符'**
  String get authUsernameMinLength;

  /// No description provided for @authEmail.
  ///
  /// In zh, this message translates to:
  /// **'邮箱'**
  String get authEmail;

  /// No description provided for @authEmailRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入邮箱'**
  String get authEmailRequired;

  /// No description provided for @authEmailInvalid.
  ///
  /// In zh, this message translates to:
  /// **'邮箱格式不正确'**
  String get authEmailInvalid;

  /// No description provided for @authPhoneOptional.
  ///
  /// In zh, this message translates to:
  /// **'手机号（可选）'**
  String get authPhoneOptional;

  /// No description provided for @authInviteCode.
  ///
  /// In zh, this message translates to:
  /// **'邀请码'**
  String get authInviteCode;

  /// No description provided for @authInviteCodeRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入邀请码'**
  String get authInviteCodeRequired;

  /// No description provided for @authConfigLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'注册配置加载失败，请检查网络后重试'**
  String get authConfigLoadFailed;

  /// No description provided for @authRegisterButton.
  ///
  /// In zh, this message translates to:
  /// **'注册'**
  String get authRegisterButton;

  /// No description provided for @authHaveAccountLogin.
  ///
  /// In zh, this message translates to:
  /// **'已有账号？去登录'**
  String get authHaveAccountLogin;

  /// No description provided for @authInviteCodeNowRequired.
  ///
  /// In zh, this message translates to:
  /// **'注册失败：服务器已开启邀请码注册，请填写邀请码'**
  String get authInviteCodeNowRequired;

  /// No description provided for @authServerConfigSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'生活成本计算器'**
  String get authServerConfigSubtitle;

  /// No description provided for @authServerAddress.
  ///
  /// In zh, this message translates to:
  /// **'服务器地址'**
  String get authServerAddress;

  /// No description provided for @authServerAddressHint.
  ///
  /// In zh, this message translates to:
  /// **'https://example.com'**
  String get authServerAddressHint;

  /// No description provided for @authServerAddressRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入服务器地址'**
  String get authServerAddressRequired;

  /// No description provided for @authServerAddressHttpRequired.
  ///
  /// In zh, this message translates to:
  /// **'必须以 http:// 或 https:// 开头'**
  String get authServerAddressHttpRequired;

  /// No description provided for @authConnectionFailed.
  ///
  /// In zh, this message translates to:
  /// **'连接失败：'**
  String get authConnectionFailed;

  /// No description provided for @authConnect.
  ///
  /// In zh, this message translates to:
  /// **'连接'**
  String get authConnect;

  /// No description provided for @authCannotConnectServer.
  ///
  /// In zh, this message translates to:
  /// **'无法连接服务器，请检查地址或网络后重试'**
  String get authCannotConnectServer;

  /// No description provided for @authLoginInvalidCredentials.
  ///
  /// In zh, this message translates to:
  /// **'用户名或密码错误'**
  String get authLoginInvalidCredentials;

  /// No description provided for @authLoginEndpointMissing.
  ///
  /// In zh, this message translates to:
  /// **'登录接口不存在，请确认服务器版本'**
  String get authLoginEndpointMissing;

  /// No description provided for @authServerError.
  ///
  /// In zh, this message translates to:
  /// **'服务器内部错误，请稍后重试'**
  String get authServerError;

  /// No description provided for @authLoginNetworkError.
  ///
  /// In zh, this message translates to:
  /// **'登录失败，请检查网络后重试'**
  String get authLoginNetworkError;

  /// No description provided for @authLoginGenericError.
  ///
  /// In zh, this message translates to:
  /// **'登录失败，请稍后重试'**
  String get authLoginGenericError;

  /// No description provided for @authRegisterFailedDetail.
  ///
  /// In zh, this message translates to:
  /// **'注册失败：{detail}'**
  String authRegisterFailedDetail(Object detail);

  /// No description provided for @authRegisterInvalid.
  ///
  /// In zh, this message translates to:
  /// **'注册失败，请检查注册信息'**
  String get authRegisterInvalid;

  /// No description provided for @authRegisterEndpointMissing.
  ///
  /// In zh, this message translates to:
  /// **'注册接口不存在，请确认服务器版本'**
  String get authRegisterEndpointMissing;

  /// No description provided for @authRegisterServerError.
  ///
  /// In zh, this message translates to:
  /// **'注册失败，请稍后重试'**
  String get authRegisterServerError;

  /// No description provided for @authRegisterNetworkError.
  ///
  /// In zh, this message translates to:
  /// **'注册失败，请检查网络后重试'**
  String get authRegisterNetworkError;

  /// No description provided for @authRegisterGenericError.
  ///
  /// In zh, this message translates to:
  /// **'注册失败，请稍后重试'**
  String get authRegisterGenericError;

  /// No description provided for @authCropAvatar.
  ///
  /// In zh, this message translates to:
  /// **'裁剪头像'**
  String get authCropAvatar;

  /// No description provided for @authAvatarUpdated.
  ///
  /// In zh, this message translates to:
  /// **'头像已更新'**
  String get authAvatarUpdated;

  /// No description provided for @authAvatarUploadFailed.
  ///
  /// In zh, this message translates to:
  /// **'头像上传失败，请重试'**
  String get authAvatarUploadFailed;

  /// No description provided for @authNoChangesToSave.
  ///
  /// In zh, this message translates to:
  /// **'没有需要保存的修改'**
  String get authNoChangesToSave;

  /// No description provided for @authSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get authSaved;

  /// No description provided for @authSaveFailedRetry.
  ///
  /// In zh, this message translates to:
  /// **'保存失败，请重试'**
  String get authSaveFailedRetry;

  /// No description provided for @authSaveFailedCheckInput.
  ///
  /// In zh, this message translates to:
  /// **'保存失败，请检查输入后重试'**
  String get authSaveFailedCheckInput;

  /// No description provided for @authEditAccountTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑个人信息'**
  String get authEditAccountTitle;

  /// No description provided for @authTapChangeAvatar.
  ///
  /// In zh, this message translates to:
  /// **'点击更换头像'**
  String get authTapChangeAvatar;

  /// No description provided for @authUsernameLabel.
  ///
  /// In zh, this message translates to:
  /// **'用户名 *'**
  String get authUsernameLabel;

  /// No description provided for @authUsernameLength.
  ///
  /// In zh, this message translates to:
  /// **'用户名长度需为 3-50 个字符'**
  String get authUsernameLength;

  /// No description provided for @authNickname.
  ///
  /// In zh, this message translates to:
  /// **'昵称'**
  String get authNickname;

  /// No description provided for @authNicknameMaxLength.
  ///
  /// In zh, this message translates to:
  /// **'昵称不能超过 50 个字符'**
  String get authNicknameMaxLength;

  /// No description provided for @authEditEmailInvalid.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效的邮箱地址'**
  String get authEditEmailInvalid;

  /// No description provided for @authPhoneInvalid.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效的手机号'**
  String get authPhoneInvalid;

  /// No description provided for @authRegion.
  ///
  /// In zh, this message translates to:
  /// **'所在地区'**
  String get authRegion;

  /// No description provided for @authChangePasswordOptional.
  ///
  /// In zh, this message translates to:
  /// **'修改密码（可选）'**
  String get authChangePasswordOptional;

  /// No description provided for @authCurrentPassword.
  ///
  /// In zh, this message translates to:
  /// **'当前密码'**
  String get authCurrentPassword;

  /// No description provided for @authCurrentPasswordRequired.
  ///
  /// In zh, this message translates to:
  /// **'修改密码需提供当前密码'**
  String get authCurrentPasswordRequired;

  /// No description provided for @authNewPassword.
  ///
  /// In zh, this message translates to:
  /// **'新密码（至少 6 个字符）'**
  String get authNewPassword;

  /// No description provided for @authNewPasswordMinLength.
  ///
  /// In zh, this message translates to:
  /// **'新密码至少 6 个字符'**
  String get authNewPasswordMinLength;

  /// No description provided for @authConfirmNewPassword.
  ///
  /// In zh, this message translates to:
  /// **'确认新密码'**
  String get authConfirmNewPassword;

  /// No description provided for @authPasswordsDoNotMatch.
  ///
  /// In zh, this message translates to:
  /// **'两次输入的新密码不一致'**
  String get authPasswordsDoNotMatch;

  /// No description provided for @authSaving.
  ///
  /// In zh, this message translates to:
  /// **'保存中...'**
  String get authSaving;

  /// No description provided for @profileTitle.
  ///
  /// In zh, this message translates to:
  /// **'个人中心'**
  String get profileTitle;

  /// No description provided for @profileAnonymousUser.
  ///
  /// In zh, this message translates to:
  /// **'用户'**
  String get profileAnonymousUser;

  /// No description provided for @profileSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get profileSettings;

  /// No description provided for @profileLanguage.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get profileLanguage;

  /// No description provided for @profileRegionalFormat.
  ///
  /// In zh, this message translates to:
  /// **'区域格式'**
  String get profileRegionalFormat;

  /// No description provided for @profileStartupPage.
  ///
  /// In zh, this message translates to:
  /// **'启动时起始页'**
  String get profileStartupPage;

  /// No description provided for @profileStartupPageHome.
  ///
  /// In zh, this message translates to:
  /// **'推荐'**
  String get profileStartupPageHome;

  /// No description provided for @profileStartupPagePrices.
  ///
  /// In zh, this message translates to:
  /// **'计价'**
  String get profileStartupPagePrices;

  /// No description provided for @profileStartupPageRecipes.
  ///
  /// In zh, this message translates to:
  /// **'菜谱'**
  String get profileStartupPageRecipes;

  /// No description provided for @profileDefaultCurrency.
  ///
  /// In zh, this message translates to:
  /// **'默认币种'**
  String get profileDefaultCurrency;

  /// No description provided for @profileFollowRegion.
  ///
  /// In zh, this message translates to:
  /// **'跟随所在地区'**
  String get profileFollowRegion;

  /// No description provided for @profileDefaultCalcScope.
  ///
  /// In zh, this message translates to:
  /// **'默认计算范围'**
  String get profileDefaultCalcScope;

  /// No description provided for @profileCalcScopeAll.
  ///
  /// In zh, this message translates to:
  /// **'全部地区'**
  String get profileCalcScopeAll;

  /// No description provided for @profileCalcScopeCountry.
  ///
  /// In zh, this message translates to:
  /// **'国家/地区'**
  String get profileCalcScopeCountry;

  /// No description provided for @profileCalcScopeProvince.
  ///
  /// In zh, this message translates to:
  /// **'省份'**
  String get profileCalcScopeProvince;

  /// No description provided for @profileCalcScopeCity.
  ///
  /// In zh, this message translates to:
  /// **'城市'**
  String get profileCalcScopeCity;

  /// No description provided for @profileCalcScopeCounty.
  ///
  /// In zh, this message translates to:
  /// **'区县'**
  String get profileCalcScopeCounty;

  /// No description provided for @profileUnitPreferences.
  ///
  /// In zh, this message translates to:
  /// **'单位偏好'**
  String get profileUnitPreferences;

  /// No description provided for @profileNutritionGoals.
  ///
  /// In zh, this message translates to:
  /// **'营养目标'**
  String get profileNutritionGoals;

  /// No description provided for @profileMyData.
  ///
  /// In zh, this message translates to:
  /// **'我的数据'**
  String get profileMyData;

  /// No description provided for @profileMyProposals.
  ///
  /// In zh, this message translates to:
  /// **'我的提议'**
  String get profileMyProposals;

  /// No description provided for @profileMyPlaces.
  ///
  /// In zh, this message translates to:
  /// **'我的地点'**
  String get profileMyPlaces;

  /// No description provided for @profileLogout.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get profileLogout;

  /// No description provided for @localeOptionZhCN.
  ///
  /// In zh, this message translates to:
  /// **'中文 (中国)'**
  String get localeOptionZhCN;

  /// No description provided for @localeOptionEnUS.
  ///
  /// In zh, this message translates to:
  /// **'English (United States)'**
  String get localeOptionEnUS;

  /// No description provided for @localeOptionAr.
  ///
  /// In zh, this message translates to:
  /// **'العربية'**
  String get localeOptionAr;

  /// No description provided for @formatOptionFollowLanguage.
  ///
  /// In zh, this message translates to:
  /// **'Follow language'**
  String get formatOptionFollowLanguage;

  /// No description provided for @formatOptionZhCN.
  ///
  /// In zh, this message translates to:
  /// **'Chinese (China)'**
  String get formatOptionZhCN;

  /// No description provided for @formatOptionZhTW.
  ///
  /// In zh, this message translates to:
  /// **'Chinese (Taiwan)'**
  String get formatOptionZhTW;

  /// No description provided for @formatOptionEnUS.
  ///
  /// In zh, this message translates to:
  /// **'English (United States)'**
  String get formatOptionEnUS;

  /// No description provided for @formatOptionEnGB.
  ///
  /// In zh, this message translates to:
  /// **'English (United Kingdom)'**
  String get formatOptionEnGB;

  /// No description provided for @formatOptionJaJP.
  ///
  /// In zh, this message translates to:
  /// **'Japanese (Japan)'**
  String get formatOptionJaJP;

  /// No description provided for @formatOptionDeDE.
  ///
  /// In zh, this message translates to:
  /// **'German (Germany)'**
  String get formatOptionDeDE;

  /// No description provided for @formatOptionIdID.
  ///
  /// In zh, this message translates to:
  /// **'Indonesian (Indonesia)'**
  String get formatOptionIdID;

  /// No description provided for @formatOptionArEG.
  ///
  /// In zh, this message translates to:
  /// **'Arabic (Egypt)'**
  String get formatOptionArEG;

  /// No description provided for @profileCurrencyNameCNY.
  ///
  /// In zh, this message translates to:
  /// **'人民币'**
  String get profileCurrencyNameCNY;

  /// No description provided for @profileCurrencyNameUSD.
  ///
  /// In zh, this message translates to:
  /// **'美元'**
  String get profileCurrencyNameUSD;

  /// No description provided for @profileCurrencyNameEUR.
  ///
  /// In zh, this message translates to:
  /// **'欧元'**
  String get profileCurrencyNameEUR;

  /// No description provided for @profileCurrencyNameGBP.
  ///
  /// In zh, this message translates to:
  /// **'英镑'**
  String get profileCurrencyNameGBP;

  /// No description provided for @profileCurrencyNameJPY.
  ///
  /// In zh, this message translates to:
  /// **'日元'**
  String get profileCurrencyNameJPY;

  /// No description provided for @profileCurrencyNameHKD.
  ///
  /// In zh, this message translates to:
  /// **'港币'**
  String get profileCurrencyNameHKD;

  /// No description provided for @profileCurrencyNameKRW.
  ///
  /// In zh, this message translates to:
  /// **'韩元'**
  String get profileCurrencyNameKRW;

  /// No description provided for @profileCurrencyNameSGD.
  ///
  /// In zh, this message translates to:
  /// **'新加坡元'**
  String get profileCurrencyNameSGD;

  /// No description provided for @profileCurrencyNameAUD.
  ///
  /// In zh, this message translates to:
  /// **'澳大利亚元'**
  String get profileCurrencyNameAUD;

  /// No description provided for @profileCurrencyNameCAD.
  ///
  /// In zh, this message translates to:
  /// **'加拿大元'**
  String get profileCurrencyNameCAD;

  /// No description provided for @profileCurrencyNameTWD.
  ///
  /// In zh, this message translates to:
  /// **'新台币'**
  String get profileCurrencyNameTWD;

  /// No description provided for @profileCurrencyNameTHB.
  ///
  /// In zh, this message translates to:
  /// **'泰铢'**
  String get profileCurrencyNameTHB;

  /// No description provided for @profileCurrencyNameMYR.
  ///
  /// In zh, this message translates to:
  /// **'马来西亚林吉特'**
  String get profileCurrencyNameMYR;

  /// No description provided for @profileCurrencyNameVND.
  ///
  /// In zh, this message translates to:
  /// **'越南盾'**
  String get profileCurrencyNameVND;

  /// No description provided for @profileCurrencyNameRUB.
  ///
  /// In zh, this message translates to:
  /// **'俄罗斯卢布'**
  String get profileCurrencyNameRUB;

  /// No description provided for @profileCurrencyNameAED.
  ///
  /// In zh, this message translates to:
  /// **'阿联酋迪拉姆'**
  String get profileCurrencyNameAED;

  /// No description provided for @profileCurrencyNameBGN.
  ///
  /// In zh, this message translates to:
  /// **'保加利亚列弗'**
  String get profileCurrencyNameBGN;

  /// No description provided for @profileCurrencyNameBRL.
  ///
  /// In zh, this message translates to:
  /// **'巴西雷亚尔'**
  String get profileCurrencyNameBRL;

  /// No description provided for @profileCurrencyNameCHF.
  ///
  /// In zh, this message translates to:
  /// **'瑞士法郎'**
  String get profileCurrencyNameCHF;

  /// No description provided for @profileCurrencyNameCZK.
  ///
  /// In zh, this message translates to:
  /// **'捷克克朗'**
  String get profileCurrencyNameCZK;

  /// No description provided for @profileCurrencyNameDKK.
  ///
  /// In zh, this message translates to:
  /// **'丹麦克朗'**
  String get profileCurrencyNameDKK;

  /// No description provided for @profileCurrencyNameHUF.
  ///
  /// In zh, this message translates to:
  /// **'匈牙利福林'**
  String get profileCurrencyNameHUF;

  /// No description provided for @profileCurrencyNameIDR.
  ///
  /// In zh, this message translates to:
  /// **'印度尼西亚盾'**
  String get profileCurrencyNameIDR;

  /// No description provided for @profileCurrencyNameILS.
  ///
  /// In zh, this message translates to:
  /// **'以色列新谢克尔'**
  String get profileCurrencyNameILS;

  /// No description provided for @profileCurrencyNameINR.
  ///
  /// In zh, this message translates to:
  /// **'印度卢比'**
  String get profileCurrencyNameINR;

  /// No description provided for @profileCurrencyNameISK.
  ///
  /// In zh, this message translates to:
  /// **'冰岛克朗'**
  String get profileCurrencyNameISK;

  /// No description provided for @profileCurrencyNameMXN.
  ///
  /// In zh, this message translates to:
  /// **'墨西哥比索'**
  String get profileCurrencyNameMXN;

  /// No description provided for @profileCurrencyNameNOK.
  ///
  /// In zh, this message translates to:
  /// **'挪威克朗'**
  String get profileCurrencyNameNOK;

  /// No description provided for @profileCurrencyNameNZD.
  ///
  /// In zh, this message translates to:
  /// **'新西兰元'**
  String get profileCurrencyNameNZD;

  /// No description provided for @profileCurrencyNamePHP.
  ///
  /// In zh, this message translates to:
  /// **'菲律宾比索'**
  String get profileCurrencyNamePHP;

  /// No description provided for @profileCurrencyNamePLN.
  ///
  /// In zh, this message translates to:
  /// **'波兰兹罗提'**
  String get profileCurrencyNamePLN;

  /// No description provided for @profileCurrencyNameRON.
  ///
  /// In zh, this message translates to:
  /// **'罗马尼亚列伊'**
  String get profileCurrencyNameRON;

  /// No description provided for @profileCurrencyNameSEK.
  ///
  /// In zh, this message translates to:
  /// **'瑞典克朗'**
  String get profileCurrencyNameSEK;

  /// No description provided for @profileCurrencyNameTRY.
  ///
  /// In zh, this message translates to:
  /// **'土耳其里拉'**
  String get profileCurrencyNameTRY;

  /// No description provided for @profileCurrencyNameZAR.
  ///
  /// In zh, this message translates to:
  /// **'南非兰特'**
  String get profileCurrencyNameZAR;

  /// No description provided for @commonDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get commonDelete;

  /// No description provided for @commonEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get commonEdit;

  /// No description provided for @commonRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get commonRetry;

  /// No description provided for @commonLoading.
  ///
  /// In zh, this message translates to:
  /// **'加载中...'**
  String get commonLoading;

  /// No description provided for @commonEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'暂无数据'**
  String get commonEmptyTitle;

  /// No description provided for @commonClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get commonClose;

  /// No description provided for @commonAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get commonAdd;

  /// No description provided for @commonApply.
  ///
  /// In zh, this message translates to:
  /// **'应用'**
  String get commonApply;

  /// No description provided for @commonApplying.
  ///
  /// In zh, this message translates to:
  /// **'应用中...'**
  String get commonApplying;

  /// No description provided for @commonReset.
  ///
  /// In zh, this message translates to:
  /// **'重置'**
  String get commonReset;

  /// No description provided for @commonDone.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get commonDone;

  /// No description provided for @commonSaveFailedRetry.
  ///
  /// In zh, this message translates to:
  /// **'保存失败，请重试'**
  String get commonSaveFailedRetry;

  /// No description provided for @commonSaving.
  ///
  /// In zh, this message translates to:
  /// **'保存中...'**
  String get commonSaving;

  /// No description provided for @commonSubmittedPendingReview.
  ///
  /// In zh, this message translates to:
  /// **'已提交，待管理员审核'**
  String get commonSubmittedPendingReview;

  /// No description provided for @commonListSeparator.
  ///
  /// In zh, this message translates to:
  /// **'、'**
  String get commonListSeparator;

  /// No description provided for @navHome.
  ///
  /// In zh, this message translates to:
  /// **'推荐'**
  String get navHome;

  /// No description provided for @navPrices.
  ///
  /// In zh, this message translates to:
  /// **'计价'**
  String get navPrices;

  /// No description provided for @navRecipes.
  ///
  /// In zh, this message translates to:
  /// **'菜谱'**
  String get navRecipes;

  /// No description provided for @navIngredients.
  ///
  /// In zh, this message translates to:
  /// **'原料'**
  String get navIngredients;

  /// No description provided for @navProducts.
  ///
  /// In zh, this message translates to:
  /// **'商品'**
  String get navProducts;

  /// No description provided for @navMerchants.
  ///
  /// In zh, this message translates to:
  /// **'商家'**
  String get navMerchants;

  /// No description provided for @navProfile.
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get navProfile;

  /// No description provided for @navMore.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get navMore;

  /// No description provided for @aliasAddHelper.
  ///
  /// In zh, this message translates to:
  /// **'输入后点击 + 添加'**
  String get aliasAddHelper;

  /// No description provided for @aliasAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get aliasAdd;

  /// No description provided for @regionSelect.
  ///
  /// In zh, this message translates to:
  /// **'请选择'**
  String get regionSelect;

  /// No description provided for @regionCountry.
  ///
  /// In zh, this message translates to:
  /// **'国家/地区'**
  String get regionCountry;

  /// No description provided for @regionProvince.
  ///
  /// In zh, this message translates to:
  /// **'省份'**
  String get regionProvince;

  /// No description provided for @regionCity.
  ///
  /// In zh, this message translates to:
  /// **'城市'**
  String get regionCity;

  /// No description provided for @regionCounty.
  ///
  /// In zh, this message translates to:
  /// **'区县'**
  String get regionCounty;

  /// No description provided for @calcContextTooltip.
  ///
  /// In zh, this message translates to:
  /// **'地区/计算范围/币种'**
  String get calcContextTooltip;

  /// No description provided for @calcContextTitle.
  ///
  /// In zh, this message translates to:
  /// **'地区 / 计算范围 / 币种'**
  String get calcContextTitle;

  /// No description provided for @calcAppliedForSession.
  ///
  /// In zh, this message translates to:
  /// **'已应用（当前会话生效）'**
  String get calcAppliedForSession;

  /// No description provided for @calcApplyFailed.
  ///
  /// In zh, this message translates to:
  /// **'应用失败，请重试'**
  String get calcApplyFailed;

  /// No description provided for @calcResetToPersonal.
  ///
  /// In zh, this message translates to:
  /// **'重置为个人配置'**
  String get calcResetToPersonal;

  /// No description provided for @pendingModificationReview.
  ///
  /// In zh, this message translates to:
  /// **'修改待管理员审核：{modifications}'**
  String pendingModificationReview(Object modifications);

  /// No description provided for @pendingDeletionReview.
  ///
  /// In zh, this message translates to:
  /// **'删除待管理员审核：{deletions}'**
  String pendingDeletionReview(Object deletions);

  /// No description provided for @pendingCombinedReview.
  ///
  /// In zh, this message translates to:
  /// **'待管理员审核：修改{modifications}、删除{deletions}'**
  String pendingCombinedReview(Object modifications, Object deletions);

  /// No description provided for @merchantPricesTitle.
  ///
  /// In zh, this message translates to:
  /// **'各商家价格'**
  String get merchantPricesTitle;

  /// No description provided for @merchantLowest.
  ///
  /// In zh, this message translates to:
  /// **'最低'**
  String get merchantLowest;

  /// No description provided for @nutritionTitle.
  ///
  /// In zh, this message translates to:
  /// **'营养成分'**
  String get nutritionTitle;

  /// No description provided for @nutritionPerBase.
  ///
  /// In zh, this message translates to:
  /// **'（每{base}）'**
  String nutritionPerBase(Object base);

  /// No description provided for @nutritionNoData.
  ///
  /// In zh, this message translates to:
  /// **'暂无营养数据'**
  String get nutritionNoData;

  /// No description provided for @nutritionNoDataHint.
  ///
  /// In zh, this message translates to:
  /// **'点击右上角「编辑」添加'**
  String get nutritionNoDataHint;

  /// No description provided for @nutritionNutrient.
  ///
  /// In zh, this message translates to:
  /// **'营养素'**
  String get nutritionNutrient;

  /// No description provided for @nutritionQuantity.
  ///
  /// In zh, this message translates to:
  /// **'数量'**
  String get nutritionQuantity;

  /// No description provided for @nutritionUnit.
  ///
  /// In zh, this message translates to:
  /// **'单位'**
  String get nutritionUnit;

  /// No description provided for @nutritionCollapse.
  ///
  /// In zh, this message translates to:
  /// **'收起'**
  String get nutritionCollapse;

  /// No description provided for @nutritionExpand.
  ///
  /// In zh, this message translates to:
  /// **'展开 +{count} 项'**
  String nutritionExpand(int count);

  /// No description provided for @nutritionNrvExplanation.
  ///
  /// In zh, this message translates to:
  /// **'NRV = 营养素参考值百分比'**
  String get nutritionNrvExplanation;

  /// No description provided for @nutritionEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑营养成分'**
  String get nutritionEditTitle;

  /// No description provided for @nutritionEditTitleWithName.
  ///
  /// In zh, this message translates to:
  /// **'{name} · 营养'**
  String nutritionEditTitleWithName(Object name);

  /// No description provided for @nutritionClearCustom.
  ///
  /// In zh, this message translates to:
  /// **'清空自定义'**
  String get nutritionClearCustom;

  /// No description provided for @nutritionManualEdit.
  ///
  /// In zh, this message translates to:
  /// **'手动编辑'**
  String get nutritionManualEdit;

  /// No description provided for @nutritionConfirmMatch.
  ///
  /// In zh, this message translates to:
  /// **'确认匹配'**
  String get nutritionConfirmMatch;

  /// No description provided for @nutritionConfirmMatchDescription.
  ///
  /// In zh, this message translates to:
  /// **'将清空当前营养数据并写入所选 USDA 食材的营养数据，此操作不可撤销。是否继续？'**
  String get nutritionConfirmMatchDescription;

  /// No description provided for @nutritionConfirmWrite.
  ///
  /// In zh, this message translates to:
  /// **'确认写入'**
  String get nutritionConfirmWrite;

  /// No description provided for @nutritionUsdaLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'USDA 数据加载失败'**
  String get nutritionUsdaLoadFailed;

  /// No description provided for @nutritionAtLeastOne.
  ///
  /// In zh, this message translates to:
  /// **'请至少填写一项营养素'**
  String get nutritionAtLeastOne;

  /// No description provided for @nutritionBackToList.
  ///
  /// In zh, this message translates to:
  /// **'返回列表'**
  String get nutritionBackToList;

  /// No description provided for @nutritionSearchLabel.
  ///
  /// In zh, this message translates to:
  /// **'搜索（原文/译文任意命中）'**
  String get nutritionSearchLabel;

  /// No description provided for @nutritionUsdaSearchPrompt.
  ///
  /// In zh, this message translates to:
  /// **'输入关键词搜索 USDA 食材'**
  String get nutritionUsdaSearchPrompt;

  /// No description provided for @nutritionUsdaResultDetail.
  ///
  /// In zh, this message translates to:
  /// **'{description} · {dataType} · {nutrientCount} 项营养素'**
  String nutritionUsdaResultDetail(
      Object description, Object dataType, int nutrientCount);

  /// No description provided for @nutritionAddNutrient.
  ///
  /// In zh, this message translates to:
  /// **'添加营养素'**
  String get nutritionAddNutrient;

  /// No description provided for @nutritionNutrientEnergy.
  ///
  /// In zh, this message translates to:
  /// **'能量'**
  String get nutritionNutrientEnergy;

  /// No description provided for @nutritionNutrientProtein.
  ///
  /// In zh, this message translates to:
  /// **'蛋白质'**
  String get nutritionNutrientProtein;

  /// No description provided for @nutritionNutrientFat.
  ///
  /// In zh, this message translates to:
  /// **'脂肪'**
  String get nutritionNutrientFat;

  /// No description provided for @nutritionNutrientCarbohydrate.
  ///
  /// In zh, this message translates to:
  /// **'碳水化合物'**
  String get nutritionNutrientCarbohydrate;

  /// No description provided for @nutritionNutrientDietaryFiber.
  ///
  /// In zh, this message translates to:
  /// **'膳食纤维'**
  String get nutritionNutrientDietaryFiber;

  /// No description provided for @nutritionNutrientSodium.
  ///
  /// In zh, this message translates to:
  /// **'钠'**
  String get nutritionNutrientSodium;

  /// No description provided for @nutritionNutrientPotassium.
  ///
  /// In zh, this message translates to:
  /// **'钾'**
  String get nutritionNutrientPotassium;

  /// No description provided for @nutritionNutrientCalcium.
  ///
  /// In zh, this message translates to:
  /// **'钙'**
  String get nutritionNutrientCalcium;

  /// No description provided for @nutritionNutrientIron.
  ///
  /// In zh, this message translates to:
  /// **'铁'**
  String get nutritionNutrientIron;

  /// No description provided for @nutritionNutrientZinc.
  ///
  /// In zh, this message translates to:
  /// **'锌'**
  String get nutritionNutrientZinc;

  /// No description provided for @nutritionNutrientPhosphorus.
  ///
  /// In zh, this message translates to:
  /// **'磷'**
  String get nutritionNutrientPhosphorus;

  /// No description provided for @nutritionNutrientMagnesium.
  ///
  /// In zh, this message translates to:
  /// **'镁'**
  String get nutritionNutrientMagnesium;

  /// No description provided for @nutritionNutrientVitaminA.
  ///
  /// In zh, this message translates to:
  /// **'维生素A'**
  String get nutritionNutrientVitaminA;

  /// No description provided for @nutritionNutrientVitaminC.
  ///
  /// In zh, this message translates to:
  /// **'维生素C'**
  String get nutritionNutrientVitaminC;

  /// No description provided for @nutritionNutrientVitaminB1.
  ///
  /// In zh, this message translates to:
  /// **'维生素B1'**
  String get nutritionNutrientVitaminB1;

  /// No description provided for @nutritionNutrientVitaminB2.
  ///
  /// In zh, this message translates to:
  /// **'维生素B2'**
  String get nutritionNutrientVitaminB2;

  /// No description provided for @nutritionNutrientVitaminB6.
  ///
  /// In zh, this message translates to:
  /// **'维生素B6'**
  String get nutritionNutrientVitaminB6;

  /// No description provided for @nutritionNutrientVitaminB12.
  ///
  /// In zh, this message translates to:
  /// **'维生素B12'**
  String get nutritionNutrientVitaminB12;

  /// No description provided for @nutritionNutrientVitaminD.
  ///
  /// In zh, this message translates to:
  /// **'维生素D'**
  String get nutritionNutrientVitaminD;

  /// No description provided for @nutritionNutrientVitaminE.
  ///
  /// In zh, this message translates to:
  /// **'维生素E'**
  String get nutritionNutrientVitaminE;

  /// No description provided for @nutritionNutrientVitaminK.
  ///
  /// In zh, this message translates to:
  /// **'维生素K'**
  String get nutritionNutrientVitaminK;

  /// No description provided for @nutritionNutrientFolate.
  ///
  /// In zh, this message translates to:
  /// **'叶酸'**
  String get nutritionNutrientFolate;

  /// No description provided for @nutritionNutrientNiacin.
  ///
  /// In zh, this message translates to:
  /// **'烟酸'**
  String get nutritionNutrientNiacin;

  /// No description provided for @nutritionNutrientCholesterol.
  ///
  /// In zh, this message translates to:
  /// **'胆固醇'**
  String get nutritionNutrientCholesterol;

  /// No description provided for @nutritionNutrientSaturatedFat.
  ///
  /// In zh, this message translates to:
  /// **'饱和脂肪'**
  String get nutritionNutrientSaturatedFat;

  /// No description provided for @unitsScreenTitle.
  ///
  /// In zh, this message translates to:
  /// **'单位与密度'**
  String get unitsScreenTitle;

  /// No description provided for @unitsScreenTitleWithName.
  ///
  /// In zh, this message translates to:
  /// **'{name} · 单位密度'**
  String unitsScreenTitleWithName(Object name);

  /// No description provided for @unitsCustomTab.
  ///
  /// In zh, this message translates to:
  /// **'自定义单位'**
  String get unitsCustomTab;

  /// No description provided for @unitsDensityTab.
  ///
  /// In zh, this message translates to:
  /// **'密度'**
  String get unitsDensityTab;

  /// No description provided for @unitsAddTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加单位'**
  String get unitsAddTitle;

  /// No description provided for @unitsEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑单位'**
  String get unitsEditTitle;

  /// No description provided for @unitsNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入单位名称'**
  String get unitsNameRequired;

  /// No description provided for @unitsNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'单位名称 *'**
  String get unitsNameLabel;

  /// No description provided for @unitsConversionLabel.
  ///
  /// In zh, this message translates to:
  /// **'换算系数（1单位 = ? 个）'**
  String get unitsConversionLabel;

  /// No description provided for @unitsWeightLabel.
  ///
  /// In zh, this message translates to:
  /// **'单重（g/个）'**
  String get unitsWeightLabel;

  /// No description provided for @unitsSetDefault.
  ///
  /// In zh, this message translates to:
  /// **'设为默认单位'**
  String get unitsSetDefault;

  /// No description provided for @unitsSave.
  ///
  /// In zh, this message translates to:
  /// **'保存单位'**
  String get unitsSave;

  /// No description provided for @unitsUnmappedTitle.
  ///
  /// In zh, this message translates to:
  /// **'待配置单位（默认 100 g）'**
  String get unitsUnmappedTitle;

  /// No description provided for @unitsUnmappedUsage.
  ///
  /// In zh, this message translates to:
  /// **'{unit}（{count}次）'**
  String unitsUnmappedUsage(Object unit, int count);

  /// No description provided for @unitsConversionDetail.
  ///
  /// In zh, this message translates to:
  /// **'1 {unit} = {factor} 个'**
  String unitsConversionDetail(Object unit, Object factor);

  /// No description provided for @unitsWeightDetail.
  ///
  /// In zh, this message translates to:
  /// **'{weight} g / 个'**
  String unitsWeightDetail(Object weight);

  /// No description provided for @unitsDefault.
  ///
  /// In zh, this message translates to:
  /// **'默认'**
  String get unitsDefault;

  /// No description provided for @unitsPendingReview.
  ///
  /// In zh, this message translates to:
  /// **'待审'**
  String get unitsPendingReview;

  /// No description provided for @unitsDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除单位'**
  String get unitsDeleteTitle;

  /// No description provided for @unitsDeleteMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定删除「{unit}」吗？'**
  String unitsDeleteMessage(Object unit);

  /// No description provided for @unitsDensityRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效密度'**
  String get unitsDensityRequired;

  /// No description provided for @densityAddTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加密度'**
  String get densityAddTitle;

  /// No description provided for @densityLabel.
  ///
  /// In zh, this message translates to:
  /// **'密度（kg/m³）*'**
  String get densityLabel;

  /// No description provided for @densityConditionLabel.
  ///
  /// In zh, this message translates to:
  /// **'状态描述（如：切块 / 压碎，可选）'**
  String get densityConditionLabel;

  /// No description provided for @densitySave.
  ///
  /// In zh, this message translates to:
  /// **'保存密度'**
  String get densitySave;

  /// No description provided for @densityDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除密度'**
  String get densityDeleteTitle;

  /// No description provided for @densityDeleteMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定删除该密度记录吗？'**
  String get densityDeleteMessage;

  /// No description provided for @priceEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑价格记录'**
  String get priceEditTitle;

  /// No description provided for @priceRecordTitle.
  ///
  /// In zh, this message translates to:
  /// **'记录价格'**
  String get priceRecordTitle;

  /// No description provided for @priceMerchantLabel.
  ///
  /// In zh, this message translates to:
  /// **'商家'**
  String get priceMerchantLabel;

  /// No description provided for @priceProductLabel.
  ///
  /// In zh, this message translates to:
  /// **'商品'**
  String get priceProductLabel;

  /// No description provided for @priceLabel.
  ///
  /// In zh, this message translates to:
  /// **'价格'**
  String get priceLabel;

  /// No description provided for @priceCurrencyLabel.
  ///
  /// In zh, this message translates to:
  /// **'币种'**
  String get priceCurrencyLabel;

  /// No description provided for @priceQuantityLabel.
  ///
  /// In zh, this message translates to:
  /// **'数量'**
  String get priceQuantityLabel;

  /// No description provided for @priceUnitLabel.
  ///
  /// In zh, this message translates to:
  /// **'单位'**
  String get priceUnitLabel;

  /// No description provided for @priceIncludeInSpending.
  ///
  /// In zh, this message translates to:
  /// **'计入支出'**
  String get priceIncludeInSpending;

  /// No description provided for @priceIncludeInSpendingDescription.
  ///
  /// In zh, this message translates to:
  /// **'表示此价格记录来自实际购买，将用于支出计算'**
  String get priceIncludeInSpendingDescription;

  /// No description provided for @priceRecordedAt.
  ///
  /// In zh, this message translates to:
  /// **'记录时间'**
  String get priceRecordedAt;

  /// No description provided for @priceNotesLabel.
  ///
  /// In zh, this message translates to:
  /// **'备注'**
  String get priceNotesLabel;

  /// No description provided for @priceNotesHint.
  ///
  /// In zh, this message translates to:
  /// **'备注（可选）'**
  String get priceNotesHint;

  /// No description provided for @priceValidRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效的价格'**
  String get priceValidRequired;

  /// No description provided for @priceQuantityRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效的数量'**
  String get priceQuantityRequired;

  /// No description provided for @ingredientCategoryGrains.
  ///
  /// In zh, this message translates to:
  /// **'谷物'**
  String get ingredientCategoryGrains;

  /// No description provided for @ingredientCategoryVegetables.
  ///
  /// In zh, this message translates to:
  /// **'蔬菜'**
  String get ingredientCategoryVegetables;

  /// No description provided for @ingredientCategoryFruits.
  ///
  /// In zh, this message translates to:
  /// **'水果'**
  String get ingredientCategoryFruits;

  /// No description provided for @ingredientCategoryMeat.
  ///
  /// In zh, this message translates to:
  /// **'肉类'**
  String get ingredientCategoryMeat;

  /// No description provided for @ingredientCategorySeafood.
  ///
  /// In zh, this message translates to:
  /// **'海鲜'**
  String get ingredientCategorySeafood;

  /// No description provided for @ingredientCategoryEggs.
  ///
  /// In zh, this message translates to:
  /// **'蛋类'**
  String get ingredientCategoryEggs;

  /// No description provided for @ingredientCategoryDairy.
  ///
  /// In zh, this message translates to:
  /// **'乳制品'**
  String get ingredientCategoryDairy;

  /// No description provided for @ingredientCategorySoy.
  ///
  /// In zh, this message translates to:
  /// **'豆制品'**
  String get ingredientCategorySoy;

  /// No description provided for @ingredientCategorySeasoning.
  ///
  /// In zh, this message translates to:
  /// **'调味品'**
  String get ingredientCategorySeasoning;

  /// No description provided for @ingredientCategoryOil.
  ///
  /// In zh, this message translates to:
  /// **'油脂'**
  String get ingredientCategoryOil;

  /// No description provided for @ingredientCategoryNuts.
  ///
  /// In zh, this message translates to:
  /// **'坚果'**
  String get ingredientCategoryNuts;

  /// No description provided for @ingredientCategoryBeverages.
  ///
  /// In zh, this message translates to:
  /// **'饮品'**
  String get ingredientCategoryBeverages;

  /// No description provided for @ingredientCategoryOthers.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get ingredientCategoryOthers;

  /// No description provided for @journeyFilters.
  ///
  /// In zh, this message translates to:
  /// **'筛选'**
  String get journeyFilters;

  /// No description provided for @journeyConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get journeyConfirm;

  /// No description provided for @journeyClear.
  ///
  /// In zh, this message translates to:
  /// **'清除'**
  String get journeyClear;

  /// No description provided for @journeyRefresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get journeyRefresh;

  /// No description provided for @journeyRecordPrice.
  ///
  /// In zh, this message translates to:
  /// **'记录价格'**
  String get journeyRecordPrice;

  /// No description provided for @journeyLoadMore.
  ///
  /// In zh, this message translates to:
  /// **'加载更多'**
  String get journeyLoadMore;

  /// No description provided for @journeyUnknownMerchant.
  ///
  /// In zh, this message translates to:
  /// **'未知商家'**
  String get journeyUnknownMerchant;

  /// No description provided for @journeyBasicInformation.
  ///
  /// In zh, this message translates to:
  /// **'基本信息'**
  String get journeyBasicInformation;

  /// No description provided for @journeyLatestPrice.
  ///
  /// In zh, this message translates to:
  /// **'最新价格'**
  String get journeyLatestPrice;

  /// No description provided for @journeyNoPriceData.
  ///
  /// In zh, this message translates to:
  /// **'暂无价格数据'**
  String get journeyNoPriceData;

  /// No description provided for @journeyPriceRecords.
  ///
  /// In zh, this message translates to:
  /// **'价格记录'**
  String get journeyPriceRecords;

  /// No description provided for @journeyAddRecord.
  ///
  /// In zh, this message translates to:
  /// **'添加记录'**
  String get journeyAddRecord;

  /// No description provided for @journeyNoPriceRecords.
  ///
  /// In zh, this message translates to:
  /// **'暂无价格记录'**
  String get journeyNoPriceRecords;

  /// No description provided for @journeyCreatedAt.
  ///
  /// In zh, this message translates to:
  /// **'创建时间'**
  String get journeyCreatedAt;

  /// No description provided for @journeyUpdated.
  ///
  /// In zh, this message translates to:
  /// **'已更新'**
  String get journeyUpdated;

  /// No description provided for @journeyUpdateFailed.
  ///
  /// In zh, this message translates to:
  /// **'更新失败，请重试'**
  String get journeyUpdateFailed;

  /// No description provided for @journeyDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除'**
  String get journeyDeleted;

  /// No description provided for @journeyDeleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除失败，请重试'**
  String get journeyDeleteFailed;

  /// No description provided for @journeyDeleteRecordTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除记录'**
  String get journeyDeleteRecordTitle;

  /// No description provided for @journeyDeleteRecordMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定删除「{name}」这条价格记录吗？'**
  String journeyDeleteRecordMessage(Object name);

  /// No description provided for @journeyDeleteThisRecordMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定删除这条价格记录吗？'**
  String get journeyDeleteThisRecordMessage;

  /// No description provided for @journeyDeleteProductTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除商品'**
  String get journeyDeleteProductTitle;

  /// No description provided for @journeyDeleteProductMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定删除商品「{name}」吗？'**
  String journeyDeleteProductMessage(Object name);

  /// No description provided for @journeyDeleteProposalSubmitted.
  ///
  /// In zh, this message translates to:
  /// **'删除提议已提交，待管理员审核'**
  String get journeyDeleteProposalSubmitted;

  /// No description provided for @journeyProductDeleted.
  ///
  /// In zh, this message translates to:
  /// **'商品已删除'**
  String get journeyProductDeleted;

  /// No description provided for @journeyPendingNutrition.
  ///
  /// In zh, this message translates to:
  /// **'营养成分'**
  String get journeyPendingNutrition;

  /// No description provided for @journeyPendingCustomUnits.
  ///
  /// In zh, this message translates to:
  /// **'自定义单位'**
  String get journeyPendingCustomUnits;

  /// No description provided for @journeyPendingDensity.
  ///
  /// In zh, this message translates to:
  /// **'密度'**
  String get journeyPendingDensity;

  /// No description provided for @journeyPendingHierarchy.
  ///
  /// In zh, this message translates to:
  /// **'层级关系'**
  String get journeyPendingHierarchy;

  /// No description provided for @journeyBasicInfoSaved.
  ///
  /// In zh, this message translates to:
  /// **'基本信息已保存'**
  String get journeyBasicInfoSaved;

  /// No description provided for @journeyEditSubmitted.
  ///
  /// In zh, this message translates to:
  /// **'修改已提交，待管理员审核'**
  String get journeyEditSubmitted;

  /// No description provided for @journeyRelatedProducts.
  ///
  /// In zh, this message translates to:
  /// **'关联商品'**
  String get journeyRelatedProducts;

  /// No description provided for @journeyNoRelatedProducts.
  ///
  /// In zh, this message translates to:
  /// **'暂无关联商品'**
  String get journeyNoRelatedProducts;

  /// No description provided for @journeyRelatedRecipes.
  ///
  /// In zh, this message translates to:
  /// **'相关菜谱'**
  String get journeyRelatedRecipes;

  /// No description provided for @journeyNoRelatedRecipes.
  ///
  /// In zh, this message translates to:
  /// **'暂无相关菜谱'**
  String get journeyNoRelatedRecipes;

  /// No description provided for @journeyUsage.
  ///
  /// In zh, this message translates to:
  /// **'用量 {usage}'**
  String journeyUsage(Object usage);

  /// No description provided for @journeyServings.
  ///
  /// In zh, this message translates to:
  /// **'{count} 份'**
  String journeyServings(int count);

  /// No description provided for @journeyNoHierarchy.
  ///
  /// In zh, this message translates to:
  /// **'暂无层级关系'**
  String get journeyNoHierarchy;

  /// No description provided for @journeyRelationStrength.
  ///
  /// In zh, this message translates to:
  /// **'强度：{value}'**
  String journeyRelationStrength(int value);

  /// No description provided for @journeyAdjustStrength.
  ///
  /// In zh, this message translates to:
  /// **'调整强度'**
  String get journeyAdjustStrength;

  /// No description provided for @ingredientDetailTitle.
  ///
  /// In zh, this message translates to:
  /// **'原料详情'**
  String get ingredientDetailTitle;

  /// No description provided for @ingredientPendingName.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get ingredientPendingName;

  /// No description provided for @ingredientPendingCategory.
  ///
  /// In zh, this message translates to:
  /// **'分类'**
  String get ingredientPendingCategory;

  /// No description provided for @ingredientPendingAliases.
  ///
  /// In zh, this message translates to:
  /// **'别名'**
  String get ingredientPendingAliases;

  /// No description provided for @ingredientTitle.
  ///
  /// In zh, this message translates to:
  /// **'原料'**
  String get ingredientTitle;

  /// No description provided for @ingredientSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索原料...'**
  String get ingredientSearch;

  /// No description provided for @ingredientEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'暂无原料'**
  String get ingredientEmptyTitle;

  /// No description provided for @ingredientEmptySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'点击右下角按钮添加第一个原料'**
  String get ingredientEmptySubtitle;

  /// No description provided for @ingredientNoLinkedProducts.
  ///
  /// In zh, this message translates to:
  /// **'该原料暂无关联商品，请先添加商品'**
  String get ingredientNoLinkedProducts;

  /// No description provided for @ingredientPriceRecorded.
  ///
  /// In zh, this message translates to:
  /// **'价格已记录'**
  String get ingredientPriceRecorded;

  /// No description provided for @ingredientRecordPriceFailed.
  ///
  /// In zh, this message translates to:
  /// **'记录失败，请重试'**
  String get ingredientRecordPriceFailed;

  /// No description provided for @ingredientCategory.
  ///
  /// In zh, this message translates to:
  /// **'分类'**
  String get ingredientCategory;

  /// No description provided for @ingredientNoCategories.
  ///
  /// In zh, this message translates to:
  /// **'暂无分类'**
  String get ingredientNoCategories;

  /// No description provided for @ingredientSpecialConditions.
  ///
  /// In zh, this message translates to:
  /// **'特殊条件'**
  String get ingredientSpecialConditions;

  /// No description provided for @ingredientConditionNoPrice.
  ///
  /// In zh, this message translates to:
  /// **'没有维护过价格'**
  String get ingredientConditionNoPrice;

  /// No description provided for @ingredientConditionNoNutrition.
  ///
  /// In zh, this message translates to:
  /// **'未配置营养成分'**
  String get ingredientConditionNoNutrition;

  /// No description provided for @ingredientConditionSinglePrice.
  ///
  /// In zh, this message translates to:
  /// **'仅有一条价格记录'**
  String get ingredientConditionSinglePrice;

  /// No description provided for @ingredientConditionSingleMerchant.
  ///
  /// In zh, this message translates to:
  /// **'仅有一家商家有其价格'**
  String get ingredientConditionSingleMerchant;

  /// No description provided for @ingredientConditionNoRecipe.
  ///
  /// In zh, this message translates to:
  /// **'无相关菜谱'**
  String get ingredientConditionNoRecipe;

  /// No description provided for @ingredientConditionNoProduct.
  ///
  /// In zh, this message translates to:
  /// **'无下属商品'**
  String get ingredientConditionNoProduct;

  /// No description provided for @ingredientChip.
  ///
  /// In zh, this message translates to:
  /// **'原料'**
  String get ingredientChip;

  /// No description provided for @ingredientMakingSource.
  ///
  /// In zh, this message translates to:
  /// **'制作来源'**
  String get ingredientMakingSource;

  /// No description provided for @ingredientMadeFrom.
  ///
  /// In zh, this message translates to:
  /// **'由「{name}」制作'**
  String ingredientMadeFrom(Object name);

  /// No description provided for @ingredientAddTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加原料'**
  String get ingredientAddTitle;

  /// No description provided for @ingredientEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑原料'**
  String get ingredientEditTitle;

  /// No description provided for @ingredientName.
  ///
  /// In zh, this message translates to:
  /// **'原料名称'**
  String get ingredientName;

  /// No description provided for @ingredientAliases.
  ///
  /// In zh, this message translates to:
  /// **'别名'**
  String get ingredientAliases;

  /// No description provided for @ingredientUncategorized.
  ///
  /// In zh, this message translates to:
  /// **'未分类'**
  String get ingredientUncategorized;

  /// No description provided for @ingredientCategoriesLoading.
  ///
  /// In zh, this message translates to:
  /// **'分类加载中...'**
  String get ingredientCategoriesLoading;

  /// No description provided for @ingredientCategoriesLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'分类加载失败'**
  String get ingredientCategoriesLoadFailed;

  /// No description provided for @ingredientLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'原料加载失败，请重试'**
  String get ingredientLoadFailed;

  /// No description provided for @ingredientNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入原料名称'**
  String get ingredientNameRequired;

  /// No description provided for @ingredientCreated.
  ///
  /// In zh, this message translates to:
  /// **'已创建原料'**
  String get ingredientCreated;

  /// No description provided for @ingredientManageRelations.
  ///
  /// In zh, this message translates to:
  /// **'关联原料关系'**
  String get ingredientManageRelations;

  /// No description provided for @ingredientRelationGraph.
  ///
  /// In zh, this message translates to:
  /// **'关系图'**
  String get ingredientRelationGraph;

  /// No description provided for @ingredientRelationList.
  ///
  /// In zh, this message translates to:
  /// **'关系列表'**
  String get ingredientRelationList;

  /// No description provided for @ingredientDeleteRelation.
  ///
  /// In zh, this message translates to:
  /// **'删除关系'**
  String get ingredientDeleteRelation;

  /// No description provided for @ingredientDeleteRelationMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定删除这个层级关系吗？'**
  String get ingredientDeleteRelationMessage;

  /// No description provided for @ingredientSelectRelation.
  ///
  /// In zh, this message translates to:
  /// **'请选择关联原料'**
  String get ingredientSelectRelation;

  /// No description provided for @ingredientAddRelation.
  ///
  /// In zh, this message translates to:
  /// **'添加层级关系'**
  String get ingredientAddRelation;

  /// No description provided for @ingredientAdjustRelationStrength.
  ///
  /// In zh, this message translates to:
  /// **'调整关系强度'**
  String get ingredientAdjustRelationStrength;

  /// No description provided for @ingredientChangeToAddRelation.
  ///
  /// In zh, this message translates to:
  /// **'改为添加关系'**
  String get ingredientChangeToAddRelation;

  /// No description provided for @ingredientSearchRelation.
  ///
  /// In zh, this message translates to:
  /// **'搜索关联原料 *'**
  String get ingredientSearchRelation;

  /// No description provided for @ingredientRelationType.
  ///
  /// In zh, this message translates to:
  /// **'关系类型'**
  String get ingredientRelationType;

  /// No description provided for @ingredientSaveRelation.
  ///
  /// In zh, this message translates to:
  /// **'保存关系'**
  String get ingredientSaveRelation;

  /// No description provided for @ingredientRelationContains.
  ///
  /// In zh, this message translates to:
  /// **'包含'**
  String get ingredientRelationContains;

  /// No description provided for @ingredientRelationSubstitutable.
  ///
  /// In zh, this message translates to:
  /// **'可替代'**
  String get ingredientRelationSubstitutable;

  /// No description provided for @ingredientRelationFallback.
  ///
  /// In zh, this message translates to:
  /// **'回退'**
  String get ingredientRelationFallback;

  /// No description provided for @productTitle.
  ///
  /// In zh, this message translates to:
  /// **'商品'**
  String get productTitle;

  /// No description provided for @productSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索商品...'**
  String get productSearch;

  /// No description provided for @productEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'暂无商品'**
  String get productEmptyTitle;

  /// No description provided for @productEmptySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'点击右下角按钮添加第一个商品'**
  String get productEmptySubtitle;

  /// No description provided for @productNoBrand.
  ///
  /// In zh, this message translates to:
  /// **'无品牌'**
  String get productNoBrand;

  /// No description provided for @productPriceRecorded.
  ///
  /// In zh, this message translates to:
  /// **'价格已记录'**
  String get productPriceRecorded;

  /// No description provided for @productLinkedIngredient.
  ///
  /// In zh, this message translates to:
  /// **'关联原料'**
  String get productLinkedIngredient;

  /// No description provided for @productIngredientCategory.
  ///
  /// In zh, this message translates to:
  /// **'原料分类'**
  String get productIngredientCategory;

  /// No description provided for @productBrand.
  ///
  /// In zh, this message translates to:
  /// **'品牌'**
  String get productBrand;

  /// No description provided for @productSpecialConditions.
  ///
  /// In zh, this message translates to:
  /// **'特殊条件'**
  String get productSpecialConditions;

  /// No description provided for @productAllIngredients.
  ///
  /// In zh, this message translates to:
  /// **'全部原料'**
  String get productAllIngredients;

  /// No description provided for @productAllBrands.
  ///
  /// In zh, this message translates to:
  /// **'全部品牌'**
  String get productAllBrands;

  /// No description provided for @productChip.
  ///
  /// In zh, this message translates to:
  /// **'商品'**
  String get productChip;

  /// No description provided for @productEditBasicInfo.
  ///
  /// In zh, this message translates to:
  /// **'编辑基本信息'**
  String get productEditBasicInfo;

  /// No description provided for @productAddTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加商品'**
  String get productAddTitle;

  /// No description provided for @productEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑商品'**
  String get productEditTitle;

  /// No description provided for @productName.
  ///
  /// In zh, this message translates to:
  /// **'商品名称 *'**
  String get productName;

  /// No description provided for @productSearchIngredient.
  ///
  /// In zh, this message translates to:
  /// **'搜索并选择关联原料 *'**
  String get productSearchIngredient;

  /// No description provided for @productCreateSameName.
  ///
  /// In zh, this message translates to:
  /// **'新建同名原料'**
  String get productCreateSameName;

  /// No description provided for @productCreateSameNameHint.
  ///
  /// In zh, this message translates to:
  /// **'开启后将自动创建与商品同名的原料'**
  String get productCreateSameNameHint;

  /// No description provided for @productBarcode.
  ///
  /// In zh, this message translates to:
  /// **'条码'**
  String get productBarcode;

  /// No description provided for @productScanBarcode.
  ///
  /// In zh, this message translates to:
  /// **'扫码输入条码'**
  String get productScanBarcode;

  /// No description provided for @productTags.
  ///
  /// In zh, this message translates to:
  /// **'标签'**
  String get productTags;

  /// No description provided for @productLookupLoading.
  ///
  /// In zh, this message translates to:
  /// **'正在查询商品信息…'**
  String get productLookupLoading;

  /// No description provided for @productLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'商品加载失败，请重试'**
  String get productLoadFailed;

  /// No description provided for @productNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入商品名称'**
  String get productNameRequired;

  /// No description provided for @productSelectIngredientOrCreate.
  ///
  /// In zh, this message translates to:
  /// **'请选择关联的原料，或开启“新建同名原料”'**
  String get productSelectIngredientOrCreate;

  /// No description provided for @productCreateIngredientFailed.
  ///
  /// In zh, this message translates to:
  /// **'创建原料失败'**
  String get productCreateIngredientFailed;

  /// No description provided for @productCreated.
  ///
  /// In zh, this message translates to:
  /// **'已创建商品'**
  String get productCreated;

  /// No description provided for @productDetailTitle.
  ///
  /// In zh, this message translates to:
  /// **'商品详情'**
  String get productDetailTitle;

  /// No description provided for @productPendingName.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get productPendingName;

  /// No description provided for @productPendingBrand.
  ///
  /// In zh, this message translates to:
  /// **'品牌'**
  String get productPendingBrand;

  /// No description provided for @productPendingBarcode.
  ///
  /// In zh, this message translates to:
  /// **'条码'**
  String get productPendingBarcode;

  /// No description provided for @productPendingLinkedIngredient.
  ///
  /// In zh, this message translates to:
  /// **'关联原料'**
  String get productPendingLinkedIngredient;

  /// No description provided for @productPendingAliases.
  ///
  /// In zh, this message translates to:
  /// **'别名'**
  String get productPendingAliases;

  /// No description provided for @productPendingTags.
  ///
  /// In zh, this message translates to:
  /// **'标签'**
  String get productPendingTags;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
