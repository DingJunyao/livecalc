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
