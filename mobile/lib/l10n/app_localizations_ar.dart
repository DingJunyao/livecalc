// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'لايف كالك - حاسبة تكاليف المعيشة';

  @override
  String get commonSave => 'حفظ';

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get commonUserInitial => '؟';

  @override
  String get appBrandShort => 'لايف كالك';

  @override
  String get appSigningIn => 'جارٍ تسجيل الدخول…';

  @override
  String get authServerUnavailable =>
      'يتعذر الاتصال بالخادم. تحقق من أنه يعمل ومن صحة العنوان وتوفر الشبكة، ثم أعد المحاولة.';

  @override
  String get authLoginTitle => 'تسجيل الدخول';

  @override
  String get authLoginSubtitle => 'أدخل بيانات حسابك';

  @override
  String get authUsername => 'اسم المستخدم';

  @override
  String get authPassword => 'كلمة المرور';

  @override
  String get authUsernameRequired => 'يرجى إدخال اسم المستخدم';

  @override
  String get authPasswordRequired => 'يرجى إدخال كلمة المرور';

  @override
  String get authLoginButton => 'تسجيل الدخول';

  @override
  String get authNoAccountRegister => 'ليس لديك حساب؟ أنشئ حسابًا';

  @override
  String get authServerNotConfigured => 'لم يتم تكوين الخادم';

  @override
  String get authChangeServer => 'تغيير الخادم';

  @override
  String get authRegisterTitle => 'إنشاء حساب';

  @override
  String get authUsernameMinLength => 'يجب ألا يقل اسم المستخدم عن 3 أحرف';

  @override
  String get authEmail => 'البريد الإلكتروني';

  @override
  String get authEmailRequired => 'يرجى إدخال البريد الإلكتروني';

  @override
  String get authEmailInvalid => 'أدخل بريدًا إلكترونيًا صحيحًا';

  @override
  String get authPhoneOptional => 'رقم الهاتف (اختياري)';

  @override
  String get authInviteCode => 'رمز الدعوة';

  @override
  String get authInviteCodeRequired => 'يرجى إدخال رمز الدعوة';

  @override
  String get authConfigLoadFailed =>
      'تعذر تحميل إعدادات التسجيل. تحقق من الشبكة ثم أعد المحاولة.';

  @override
  String get authRegisterButton => 'إنشاء حساب';

  @override
  String get authHaveAccountLogin => 'لديك حساب بالفعل؟ سجّل الدخول';

  @override
  String get authInviteCodeNowRequired =>
      'فشل التسجيل: الخادم يتطلب الآن رمز دعوة';

  @override
  String get authServerConfigSubtitle => 'حاسبة تكاليف المعيشة';

  @override
  String get authServerAddress => 'عنوان الخادم';

  @override
  String get authServerAddressHint => 'https://example.com';

  @override
  String get authServerAddressRequired => 'يرجى إدخال عنوان الخادم';

  @override
  String get authServerAddressHttpRequired =>
      'يجب أن يبدأ بـ http:// أو https://';

  @override
  String get authConnectionFailed => 'فشل الاتصال:';

  @override
  String get authConnect => 'اتصال';

  @override
  String get authCannotConnectServer =>
      'تعذر الاتصال بالخادم. تحقق من العنوان أو الشبكة ثم أعد المحاولة.';

  @override
  String get authLoginInvalidCredentials =>
      'اسم المستخدم أو كلمة المرور غير صحيحة';

  @override
  String get authLoginEndpointMissing =>
      'واجهة تسجيل الدخول غير موجودة. تحقق من إصدار الخادم.';

  @override
  String get authServerError => 'خطأ داخلي في الخادم. أعد المحاولة لاحقًا.';

  @override
  String get authLoginNetworkError =>
      'فشل تسجيل الدخول. تحقق من الشبكة ثم أعد المحاولة.';

  @override
  String get authLoginGenericError => 'فشل تسجيل الدخول. أعد المحاولة لاحقًا.';

  @override
  String authRegisterFailedDetail(Object detail) {
    return 'فشل التسجيل: $detail';
  }

  @override
  String get authRegisterInvalid => 'فشل التسجيل. تحقق من بيانات التسجيل.';

  @override
  String get authRegisterEndpointMissing =>
      'واجهة التسجيل غير موجودة. تحقق من إصدار الخادم.';

  @override
  String get authRegisterServerError => 'فشل التسجيل. أعد المحاولة لاحقًا.';

  @override
  String get authRegisterNetworkError =>
      'فشل التسجيل. تحقق من الشبكة ثم أعد المحاولة.';

  @override
  String get authRegisterGenericError => 'فشل التسجيل. أعد المحاولة لاحقًا.';

  @override
  String get authCropAvatar => 'قص الصورة الرمزية';

  @override
  String get authAvatarUpdated => 'تم تحديث الصورة الرمزية';

  @override
  String get authAvatarUploadFailed => 'فشل رفع الصورة الرمزية. أعد المحاولة.';

  @override
  String get authNoChangesToSave => 'لا توجد تغييرات للحفظ';

  @override
  String get authSaved => 'تم الحفظ';

  @override
  String get authSaveFailedRetry => 'فشل الحفظ. أعد المحاولة.';

  @override
  String get authSaveFailedCheckInput =>
      'فشل الحفظ. تحقق من المدخلات ثم أعد المحاولة.';

  @override
  String get authEditAccountTitle => 'تعديل الحساب';

  @override
  String get authTapChangeAvatar => 'انقر لتغيير الصورة الرمزية';

  @override
  String get authUsernameLabel => 'اسم المستخدم *';

  @override
  String get authUsernameLength => 'يجب أن يكون اسم المستخدم من 3 إلى 50 حرفًا';

  @override
  String get authNickname => 'الاسم المستعار';

  @override
  String get authNicknameMaxLength =>
      'لا يمكن أن يتجاوز الاسم المستعار 50 حرفًا';

  @override
  String get authEditEmailInvalid => 'أدخل بريدًا إلكترونيًا صحيحًا';

  @override
  String get authPhoneInvalid => 'أدخل رقم هاتف صحيحًا';

  @override
  String get authRegion => 'المنطقة';

  @override
  String get authChangePasswordOptional => 'تغيير كلمة المرور (اختياري)';

  @override
  String get authCurrentPassword => 'كلمة المرور الحالية';

  @override
  String get authCurrentPasswordRequired => 'أدخل كلمة المرور الحالية لتغييرها';

  @override
  String get authNewPassword => 'كلمة المرور الجديدة (6 أحرف على الأقل)';

  @override
  String get authNewPasswordMinLength =>
      'يجب ألا تقل كلمة المرور الجديدة عن 6 أحرف';

  @override
  String get authConfirmNewPassword => 'تأكيد كلمة المرور الجديدة';

  @override
  String get authPasswordsDoNotMatch => 'كلمتا المرور الجديدتان غير متطابقتين';

  @override
  String get authSaving => 'جارٍ الحفظ...';

  @override
  String get profileTitle => 'الملف الشخصي';

  @override
  String get profileAnonymousUser => 'المستخدم';

  @override
  String get profileSettings => 'الإعدادات';

  @override
  String get profileLanguage => 'اللغة';

  @override
  String get profileRegionalFormat => 'التنسيق الإقليمي';

  @override
  String get profileStartupPage => 'صفحة البدء';

  @override
  String get profileStartupPageHome => 'التوصيات';

  @override
  String get profileStartupPagePrices => 'التسعير';

  @override
  String get profileStartupPageRecipes => 'الوصفات';

  @override
  String get profileDefaultCurrency => 'العملة الافتراضية';

  @override
  String get profileFollowRegion => 'اتباع منطقتك';

  @override
  String get profileDefaultCalcScope => 'نطاق الحساب الافتراضي';

  @override
  String get profileCalcScopeAll => 'كل المناطق';

  @override
  String get profileCalcScopeCountry => 'البلد/المنطقة';

  @override
  String get profileCalcScopeProvince => 'المقاطعة';

  @override
  String get profileCalcScopeCity => 'المدينة';

  @override
  String get profileCalcScopeCounty => 'الحي';

  @override
  String get profileUnitPreferences => 'تفضيلات الوحدات';

  @override
  String get profileNutritionGoals => 'أهداف التغذية';

  @override
  String get profileMyData => 'بياناتي';

  @override
  String get profileMyProposals => 'اقتراحاتي';

  @override
  String get profileMyPlaces => 'أماكني';

  @override
  String get profileLogout => 'تسجيل الخروج';

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
  String get profileCurrencyNameCNY => 'اليوان الصيني';

  @override
  String get profileCurrencyNameUSD => 'الدولار الأمريكي';

  @override
  String get profileCurrencyNameEUR => 'اليورو';

  @override
  String get profileCurrencyNameGBP => 'الجنيه الإسترليني';

  @override
  String get profileCurrencyNameJPY => 'الين الياباني';

  @override
  String get profileCurrencyNameHKD => 'الدولار الهونغ كونغي';

  @override
  String get profileCurrencyNameKRW => 'الوون الكوري الجنوبي';

  @override
  String get profileCurrencyNameSGD => 'الدولار السنغافوري';

  @override
  String get profileCurrencyNameAUD => 'الدولار الأسترالي';

  @override
  String get profileCurrencyNameCAD => 'الدولار الكندي';

  @override
  String get profileCurrencyNameTWD => 'الدولار التايواني الجديد';

  @override
  String get profileCurrencyNameTHB => 'البات التايلاندي';

  @override
  String get profileCurrencyNameMYR => 'الرينغيت الماليزي';

  @override
  String get profileCurrencyNameVND => 'الدونغ الفيتنامي';

  @override
  String get profileCurrencyNameRUB => 'الروبل الروسي';

  @override
  String get profileCurrencyNameAED => 'الدرهم الإماراتي';

  @override
  String get profileCurrencyNameBGN => 'الليف البلغاري';

  @override
  String get profileCurrencyNameBRL => 'الريال البرازيلي';

  @override
  String get profileCurrencyNameCHF => 'الفرنك السويسري';

  @override
  String get profileCurrencyNameCZK => 'الكورونا التشيكية';

  @override
  String get profileCurrencyNameDKK => 'الكرون الدنماركي';

  @override
  String get profileCurrencyNameHUF => 'الفورنت المجري';

  @override
  String get profileCurrencyNameIDR => 'الروبية الإندونيسية';

  @override
  String get profileCurrencyNameILS => 'الشيكل الإسرائيلي الجديد';

  @override
  String get profileCurrencyNameINR => 'الروبية الهندية';

  @override
  String get profileCurrencyNameISK => 'الكرونة الآيسلندية';

  @override
  String get profileCurrencyNameMXN => 'البيزو المكسيكي';

  @override
  String get profileCurrencyNameNOK => 'الكرونة النرويجية';

  @override
  String get profileCurrencyNameNZD => 'الدولار النيوزيلندي';

  @override
  String get profileCurrencyNamePHP => 'البيزو الفلبيني';

  @override
  String get profileCurrencyNamePLN => 'الزلوتي البولندي';

  @override
  String get profileCurrencyNameRON => 'الليو الروماني';

  @override
  String get profileCurrencyNameSEK => 'الكرونا السويدية';

  @override
  String get profileCurrencyNameTRY => 'الليرة التركية';

  @override
  String get profileCurrencyNameZAR => 'الراند الجنوب أفريقي';

  @override
  String get commonDelete => 'حذف';

  @override
  String get commonEdit => 'تعديل';

  @override
  String get commonRetry => 'إعادة المحاولة';

  @override
  String get commonLoading => 'جارٍ التحميل…';

  @override
  String get commonEmptyTitle => 'لا توجد بيانات بعد';

  @override
  String get commonClose => 'إغلاق';

  @override
  String get commonAdd => 'إضافة';

  @override
  String get commonApply => 'تطبيق';

  @override
  String get commonApplying => 'جارٍ التطبيق...';

  @override
  String get commonReset => 'إعادة تعيين';

  @override
  String get commonDone => 'تم';

  @override
  String get commonSaveFailedRetry => 'فشل الحفظ. أعد المحاولة.';

  @override
  String get commonSubmittedPendingReview =>
      'تم الإرسال. في انتظار مراجعة المسؤول.';

  @override
  String get commonListSeparator => '، ';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navPrices => 'الأسعار';

  @override
  String get navRecipes => 'الوصفات';

  @override
  String get navIngredients => 'المكونات';

  @override
  String get navProducts => 'المنتجات';

  @override
  String get navMerchants => 'المتاجر';

  @override
  String get navProfile => 'الملف الشخصي';

  @override
  String get navMore => 'المزيد';

  @override
  String get aliasAddHelper => 'اضغط + للإضافة';

  @override
  String get aliasAdd => 'إضافة';

  @override
  String get regionSelect => 'اختر';

  @override
  String get regionCountry => 'البلد/المنطقة';

  @override
  String get regionProvince => 'المقاطعة';

  @override
  String get regionCity => 'المدينة';

  @override
  String get regionCounty => 'الحي';

  @override
  String get calcContextTooltip => 'المنطقة / نطاق الحساب / العملة';

  @override
  String get calcContextTitle => 'المنطقة / نطاق الحساب / العملة';

  @override
  String get calcAppliedForSession => 'تم التطبيق لهذه الجلسة';

  @override
  String get calcApplyFailed => 'تعذر التطبيق. أعد المحاولة.';

  @override
  String get calcResetToPersonal => 'إعادة التعيين إلى الإعدادات الشخصية';

  @override
  String pendingModificationReview(Object modifications) {
    return 'تعديل $modifications في انتظار مراجعة المسؤول';
  }

  @override
  String pendingDeletionReview(Object deletions) {
    return 'حذف $deletions في انتظار مراجعة المسؤول';
  }

  @override
  String pendingCombinedReview(Object modifications, Object deletions) {
    return 'في انتظار المراجعة: تعديل $modifications، حذف $deletions';
  }

  @override
  String get merchantPricesTitle => 'أسعار المتاجر';

  @override
  String get merchantLowest => 'الأقل';

  @override
  String get nutritionTitle => 'القيم الغذائية';

  @override
  String nutritionPerBase(Object base) {
    return '(لكل $base)';
  }

  @override
  String get nutritionNoData => 'لا توجد بيانات غذائية';

  @override
  String get nutritionNoDataHint => 'استخدم زر التعديل في أعلى اليمين للإضافة';

  @override
  String get nutritionNutrient => 'العنصر الغذائي';

  @override
  String get nutritionQuantity => 'الكمية';

  @override
  String get nutritionUnit => 'الوحدة';

  @override
  String get nutritionCollapse => 'طي';

  @override
  String nutritionExpand(int count) {
    return 'عرض $count إضافي';
  }

  @override
  String get nutritionNrvExplanation =>
      'NRV = نسبة القيم المرجعية للعناصر الغذائية';

  @override
  String get nutritionEditTitle => 'تعديل القيم الغذائية';

  @override
  String nutritionEditTitleWithName(Object name) {
    return '$name - القيم الغذائية';
  }

  @override
  String get nutritionClearCustom => 'مسح القيم المخصصة';

  @override
  String get nutritionManualEdit => 'تحرير يدوي';

  @override
  String get nutritionConfirmMatch => 'تأكيد المطابقة';

  @override
  String get nutritionConfirmMatchDescription =>
      'سيتم استبدال بيانات التغذية الحالية بالغذاء المحدد من USDA. لا يمكن التراجع عن هذا الإجراء. هل تريد المتابعة؟';

  @override
  String get nutritionConfirmWrite => 'تأكيد الكتابة';

  @override
  String get nutritionUsdaLoadFailed => 'تعذر تحميل بيانات USDA';

  @override
  String get nutritionAtLeastOne => 'أدخل عنصرًا غذائيًا واحدًا على الأقل';

  @override
  String get nutritionBackToList => 'العودة إلى القائمة';

  @override
  String get nutritionSearchLabel => 'بحث (النص الأصلي أو المترجم)';

  @override
  String get nutritionUsdaSearchPrompt =>
      'أدخل كلمات مفتاحية للبحث في أغذية USDA';

  @override
  String nutritionUsdaResultDetail(
      Object description, Object dataType, int nutrientCount) {
    return '$description - $dataType - $nutrientCount عنصرًا غذائيًا';
  }

  @override
  String get nutritionAddNutrient => 'إضافة عنصر غذائي';

  @override
  String get nutritionNutrientEnergy => 'الطاقة';

  @override
  String get nutritionNutrientProtein => 'البروتين';

  @override
  String get nutritionNutrientFat => 'الدهون';

  @override
  String get nutritionNutrientCarbohydrate => 'الكربوهيدرات';

  @override
  String get nutritionNutrientDietaryFiber => 'الألياف الغذائية';

  @override
  String get nutritionNutrientSodium => 'الصوديوم';

  @override
  String get nutritionNutrientPotassium => 'البوتاسيوم';

  @override
  String get nutritionNutrientCalcium => 'الكالسيوم';

  @override
  String get nutritionNutrientIron => 'الحديد';

  @override
  String get nutritionNutrientZinc => 'الزنك';

  @override
  String get nutritionNutrientPhosphorus => 'الفوسفور';

  @override
  String get nutritionNutrientMagnesium => 'المغنيسيوم';

  @override
  String get nutritionNutrientVitaminA => 'فيتامين A';

  @override
  String get nutritionNutrientVitaminC => 'فيتامين C';

  @override
  String get nutritionNutrientVitaminB1 => 'فيتامين B1';

  @override
  String get nutritionNutrientVitaminB2 => 'فيتامين B2';

  @override
  String get nutritionNutrientVitaminB6 => 'فيتامين B6';

  @override
  String get nutritionNutrientVitaminB12 => 'فيتامين B12';

  @override
  String get nutritionNutrientVitaminD => 'فيتامين D';

  @override
  String get nutritionNutrientVitaminE => 'فيتامين E';

  @override
  String get nutritionNutrientVitaminK => 'فيتامين K';

  @override
  String get nutritionNutrientFolate => 'الفولات';

  @override
  String get nutritionNutrientNiacin => 'النياسين';

  @override
  String get nutritionNutrientCholesterol => 'الكوليسترول';

  @override
  String get nutritionNutrientSaturatedFat => 'الدهون المشبعة';

  @override
  String get unitsScreenTitle => 'الوحدات والكثافات';

  @override
  String unitsScreenTitleWithName(Object name) {
    return '$name - الوحدات والكثافات';
  }

  @override
  String get unitsCustomTab => 'الوحدات المخصصة';

  @override
  String get unitsDensityTab => 'الكثافات';

  @override
  String get unitsAddTitle => 'إضافة وحدة';

  @override
  String get unitsEditTitle => 'تعديل الوحدة';

  @override
  String get unitsNameRequired => 'يرجى إدخال اسم الوحدة';

  @override
  String get unitsNameLabel => 'اسم الوحدة *';

  @override
  String get unitsConversionLabel => 'معامل التحويل (1 وحدة = كم وحدة)';

  @override
  String get unitsWeightLabel => 'الوزن (جم/وحدة)';

  @override
  String get unitsSetDefault => 'تعيين كوحدة افتراضية';

  @override
  String get unitsSave => 'حفظ الوحدة';

  @override
  String get unitsUnmappedTitle => 'وحدات بحاجة إلى إعداد (الافتراضي 100 جم)';

  @override
  String unitsUnmappedUsage(Object unit, int count) {
    return '$unit ($count استخدام)';
  }

  @override
  String unitsConversionDetail(Object unit, Object factor) {
    return '1 $unit = $factor وحدة';
  }

  @override
  String unitsWeightDetail(Object weight) {
    return '$weight جم / وحدة';
  }

  @override
  String get unitsDefault => 'افتراضي';

  @override
  String get unitsPendingReview => 'قيد المراجعة';

  @override
  String get unitsDeleteTitle => 'حذف الوحدة';

  @override
  String unitsDeleteMessage(Object unit) {
    return 'هل تريد حذف \"$unit\"؟';
  }

  @override
  String get unitsDensityRequired => 'يرجى إدخال كثافة صالحة';

  @override
  String get densityAddTitle => 'إضافة كثافة';

  @override
  String get densityLabel => 'الكثافة (كجم/م³) *';

  @override
  String get densityConditionLabel => 'وصف الحالة (مثل: مقطع / مسحوق، اختياري)';

  @override
  String get densitySave => 'حفظ الكثافة';

  @override
  String get densityDeleteTitle => 'حذف الكثافة';

  @override
  String get densityDeleteMessage => 'هل تريد حذف سجل الكثافة هذا؟';

  @override
  String get priceEditTitle => 'تعديل سجل السعر';

  @override
  String get priceRecordTitle => 'تسجيل سعر';

  @override
  String get priceMerchantLabel => 'المتجر';

  @override
  String get priceProductLabel => 'المنتج';

  @override
  String get priceLabel => 'السعر';

  @override
  String get priceCurrencyLabel => 'العملة';

  @override
  String get priceQuantityLabel => 'الكمية';

  @override
  String get priceUnitLabel => 'الوحدة';

  @override
  String get priceIncludeInSpending => 'احتسابه في الإنفاق';

  @override
  String get priceIncludeInSpendingDescription =>
      'يمثل هذا السجل شراءً فعليًا وسيُستخدم في حساب الإنفاق';

  @override
  String get priceRecordedAt => 'وقت التسجيل';

  @override
  String get priceNotesLabel => 'ملاحظات';

  @override
  String get priceNotesHint => 'ملاحظات (اختياري)';

  @override
  String get priceValidRequired => 'يرجى إدخال سعر صالح';

  @override
  String get priceQuantityRequired => 'يرجى إدخال كمية صالحة';
}
