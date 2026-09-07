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
  String get commonSaving => 'جارٍ الحفظ...';

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

  @override
  String get ingredientCategoryGrains => 'الحبوب';

  @override
  String get ingredientCategoryVegetables => 'الخضروات';

  @override
  String get ingredientCategoryFruits => 'الفواكه';

  @override
  String get ingredientCategoryMeat => 'اللحوم';

  @override
  String get ingredientCategorySeafood => 'المأكولات البحرية';

  @override
  String get ingredientCategoryEggs => 'البيض';

  @override
  String get ingredientCategoryDairy => 'الألبان';

  @override
  String get ingredientCategorySoy => 'الصويا';

  @override
  String get ingredientCategorySeasoning => 'التوابل';

  @override
  String get ingredientCategoryOil => 'الزيوت';

  @override
  String get ingredientCategoryNuts => 'المكسرات';

  @override
  String get ingredientCategoryBeverages => 'المشروبات';

  @override
  String get ingredientCategoryOthers => 'أخرى';

  @override
  String get journeyFilters => 'الفلاتر';

  @override
  String get journeyConfirm => 'موافق';

  @override
  String get journeyClear => 'مسح';

  @override
  String get journeyRefresh => 'تحديث';

  @override
  String get journeyRecordPrice => 'تسجيل سعر';

  @override
  String get journeyLoadMore => 'تحميل المزيد';

  @override
  String get journeyUnknownMerchant => 'متجر غير معروف';

  @override
  String get journeyBasicInformation => 'المعلومات الأساسية';

  @override
  String get journeyLatestPrice => 'أحدث سعر';

  @override
  String get journeyNoPriceData => 'لا توجد بيانات أسعار';

  @override
  String get journeyPriceRecords => 'سجلات الأسعار';

  @override
  String get journeyAddRecord => 'إضافة سجل';

  @override
  String get journeyNoPriceRecords => 'لا توجد سجلات أسعار';

  @override
  String get journeyCreatedAt => 'وقت الإنشاء';

  @override
  String get journeyUpdated => 'تم التحديث';

  @override
  String get journeyUpdateFailed => 'فشل التحديث. حاول مجددًا.';

  @override
  String get journeyDeleted => 'تم الحذف';

  @override
  String get journeyDeleteFailed => 'فشل الحذف. حاول مجددًا.';

  @override
  String get journeyDeleteRecordTitle => 'حذف السجل';

  @override
  String journeyDeleteRecordMessage(Object name) {
    return 'حذف سجل السعر لـ \"$name\"؟';
  }

  @override
  String get journeyDeleteThisRecordMessage => 'حذف سجل السعر هذا؟';

  @override
  String get journeyDeleteProductTitle => 'حذف المنتج';

  @override
  String journeyDeleteProductMessage(Object name) {
    return 'حذف المنتج \"$name\"؟';
  }

  @override
  String get journeyDeleteProposalSubmitted =>
      'تم إرسال اقتراح الحذف بانتظار مراجعة المسؤول';

  @override
  String get journeyProductDeleted => 'تم حذف المنتج';

  @override
  String get journeyPendingNutrition => 'التغذية';

  @override
  String get journeyPendingCustomUnits => 'وحدات مخصصة';

  @override
  String get journeyPendingDensity => 'الكثافة';

  @override
  String get journeyPendingHierarchy => 'التسلسل الهرمي';

  @override
  String get journeyBasicInfoSaved => 'تم حفظ المعلومات الأساسية';

  @override
  String get journeyEditSubmitted => 'تم إرسال التعديل بانتظار مراجعة المسؤول';

  @override
  String get journeyRelatedProducts => 'المنتجات المرتبطة';

  @override
  String get journeyNoRelatedProducts => 'لا توجد منتجات مرتبطة';

  @override
  String get journeyRelatedRecipes => 'الوصفات المرتبطة';

  @override
  String get journeyNoRelatedRecipes => 'لا توجد وصفات مرتبطة';

  @override
  String journeyUsage(Object usage) {
    return 'الاستخدام $usage';
  }

  @override
  String journeyServings(int count) {
    return '$count حصة';
  }

  @override
  String get journeyNoHierarchy => 'لا يوجد تسلسل هرمي';

  @override
  String journeyRelationStrength(int value) {
    return 'القوة: $value';
  }

  @override
  String get journeyAdjustStrength => 'تعديل القوة';

  @override
  String get ingredientDetailTitle => 'تفاصيل المكوّن';

  @override
  String get ingredientPendingName => 'الاسم';

  @override
  String get ingredientPendingCategory => 'الفئة';

  @override
  String get ingredientPendingAliases => 'الأسماء البديلة';

  @override
  String get ingredientTitle => 'المكوّنات';

  @override
  String get ingredientSearch => 'ابحث عن المكوّنات...';

  @override
  String get ingredientEmptyTitle => 'لا توجد مكوّنات';

  @override
  String get ingredientEmptySubtitle =>
      'انقر على الزر في الركن السفلي الأيمن لإضافة أول مكوّن';

  @override
  String get ingredientNoLinkedProducts =>
      'لا يوجد منتج مرتبط بهذا المكوّن. أضف منتجًا أولاً.';

  @override
  String get ingredientPriceRecorded => 'تم تسجيل السعر';

  @override
  String get ingredientRecordPriceFailed => 'تعذر تسجيل السعر. حاول مجددًا.';

  @override
  String get ingredientCategory => 'الفئة';

  @override
  String get ingredientNoCategories => 'لا توجد فئات';

  @override
  String get ingredientSpecialConditions => 'شروط خاصة';

  @override
  String get ingredientConditionNoPrice => 'لا يوجد سعر مُصان';

  @override
  String get ingredientConditionNoNutrition => 'لا توجد بيانات تغذية مُعدة';

  @override
  String get ingredientConditionSinglePrice => 'سجل سعر واحد فقط';

  @override
  String get ingredientConditionSingleMerchant => 'متجر واحد فقط لديه أسعار';

  @override
  String get ingredientConditionNoRecipe => 'لا توجد وصفة مرتبطة';

  @override
  String get ingredientConditionNoProduct => 'لا يوجد منتج فرعي';

  @override
  String get ingredientChip => 'مكوّن';

  @override
  String get ingredientMakingSource => 'مصدر التحضير';

  @override
  String ingredientMadeFrom(Object name) {
    return 'مُحضّر من \"$name\"';
  }

  @override
  String get ingredientAddTitle => 'إضافة مكوّن';

  @override
  String get ingredientEditTitle => 'تعديل المكوّن';

  @override
  String get ingredientName => 'اسم المكوّن';

  @override
  String get ingredientAliases => 'الأسماء البديلة';

  @override
  String get ingredientUncategorized => 'غير مصنف';

  @override
  String get ingredientCategoriesLoading => 'جارٍ تحميل الفئات...';

  @override
  String get ingredientCategoriesLoadFailed => 'تعذر تحميل الفئات';

  @override
  String get ingredientLoadFailed => 'تعذر تحميل المكوّن. حاول مجددًا.';

  @override
  String get ingredientNameRequired => 'اسم المكوّن مطلوب';

  @override
  String get ingredientCreated => 'تم إنشاء المكوّن';

  @override
  String get ingredientManageRelations => 'إدارة علاقات المكوّنات';

  @override
  String get ingredientRelationGraph => 'مخطط العلاقات';

  @override
  String get ingredientRelationList => 'قائمة العلاقات';

  @override
  String get ingredientDeleteRelation => 'حذف العلاقة';

  @override
  String get ingredientDeleteRelationMessage => 'حذف علاقة التسلسل الهرمي هذه؟';

  @override
  String get ingredientSelectRelation => 'اختر مكوّنًا';

  @override
  String get ingredientAddRelation => 'إضافة علاقة تسلسل هرمي';

  @override
  String get ingredientAdjustRelationStrength => 'تعديل قوة العلاقة';

  @override
  String get ingredientChangeToAddRelation => 'التبديل إلى إضافة علاقة';

  @override
  String get ingredientSearchRelation => 'ابحث عن مكوّن *';

  @override
  String get ingredientRelationType => 'نوع العلاقة';

  @override
  String get ingredientSaveRelation => 'حفظ العلاقة';

  @override
  String get ingredientRelationContains => 'يحتوي';

  @override
  String get ingredientRelationSubstitutable => 'قابل للتبديل';

  @override
  String get ingredientRelationFallback => 'بديل عند الغياب';

  @override
  String ingredientRelationFallbackName(int id) {
    return 'مكوّن #$id';
  }

  @override
  String get productTitle => 'المنتجات';

  @override
  String get productSearch => 'ابحث عن المنتجات...';

  @override
  String get productEmptyTitle => 'لا توجد منتجات';

  @override
  String get productEmptySubtitle =>
      'انقر على الزر في الركن السفلي الأيمن لإضافة أول منتج';

  @override
  String get productNoBrand => 'بدون علامة تجارية';

  @override
  String get productPriceRecorded => 'تم تسجيل السعر';

  @override
  String get productLinkedIngredient => 'المكوّن المرتبط';

  @override
  String get productIngredientCategory => 'فئة المكوّن';

  @override
  String get productBrand => 'العلامة التجارية';

  @override
  String get productSpecialConditions => 'شروط خاصة';

  @override
  String get productAllIngredients => 'كل المكوّنات';

  @override
  String get productAllBrands => 'كل العلامات التجارية';

  @override
  String get productChip => 'منتج';

  @override
  String get productEditBasicInfo => 'تعديل المعلومات الأساسية';

  @override
  String get productAddTitle => 'إضافة منتج';

  @override
  String get productEditTitle => 'تعديل المنتج';

  @override
  String get productName => 'اسم المنتج *';

  @override
  String get productSearchIngredient => 'ابحث واختر مكوّنًا مرتبطًا *';

  @override
  String get productCreateSameName => 'إنشاء مكوّن بنفس الاسم';

  @override
  String get productCreateSameNameHint =>
      'سيتم إنشاء مكوّن بنفس اسم هذا المنتج تلقائيًا';

  @override
  String get productBarcode => 'الرمز الشريطي';

  @override
  String get productScanBarcode => 'مسح الرمز الشريطي';

  @override
  String get productTags => 'الوسوم';

  @override
  String get productLookupLoading => 'جارٍ البحث عن معلومات المنتج...';

  @override
  String get productLoadFailed => 'تعذر تحميل المنتج. حاول مجددًا.';

  @override
  String get productNameRequired => 'اسم المنتج مطلوب';

  @override
  String get productSelectIngredientOrCreate =>
      'اختر مكوّنًا مرتبطًا أو فعّل \"إنشاء مكوّن بنفس الاسم\".';

  @override
  String get productCreateIngredientFailed => 'فشل إنشاء المكوّن';

  @override
  String get productCreated => 'تم إنشاء المنتج';

  @override
  String get productDetailTitle => 'تفاصيل المنتج';

  @override
  String get productPendingName => 'الاسم';

  @override
  String get productPendingBrand => 'العلامة التجارية';

  @override
  String get productPendingBarcode => 'الرمز الشريطي';

  @override
  String get productPendingLinkedIngredient => 'المكوّن المرتبط';

  @override
  String get productPendingAliases => 'الأسماء البديلة';

  @override
  String get productPendingTags => 'الوسوم';

  @override
  String get merchantTitle => 'المتاجر';

  @override
  String get merchantDetailTitle => 'تفاصيل المتجر';

  @override
  String get merchantAddTitle => 'إضافة متجر';

  @override
  String get merchantEditTitle => 'تعديل المتجر';

  @override
  String get merchantCreateButton => 'إنشاء';

  @override
  String get merchantSaved => 'تم حفظ المتجر';

  @override
  String get merchantCreated => 'تم إنشاء المتجر';

  @override
  String merchantSaveFailed(Object error) {
    return 'فشل الحفظ: $error';
  }

  @override
  String get merchantSearch => 'ابحث عن المتاجر...';

  @override
  String get merchantNoAddress => 'لا يوجد عنوان';

  @override
  String get merchantUnnamed => 'متجر بدون اسم';

  @override
  String get merchantChip => 'متجر';

  @override
  String get merchantShowMap => 'عرض الخريطة';

  @override
  String get merchantHideMap => 'إخفاء الخريطة';

  @override
  String get merchantShowClosed => 'عرض المتاجر المغلقة';

  @override
  String get merchantShowOtherRegions => 'عرض متاجر المناطق الأخرى';

  @override
  String get merchantShowOtherRegionsHint =>
      'يشمل جميع المناطق ولا يتأثر بنطاق الحساب';

  @override
  String get merchantFavoritesOnly => 'المفضلة فقط';

  @override
  String get merchantNoMaintainedPrice => 'لا يوجد سعر مُصان';

  @override
  String get merchantFilterTitle => 'خيارات التصفية';

  @override
  String get merchantDeleteTitle => 'حذف المتجر';

  @override
  String merchantDeleteMessage(Object name) {
    return 'هل تريد حذف المتجر \"$name\"؟';
  }

  @override
  String get merchantDeleted => 'تم حذف المتجر';

  @override
  String get merchantFavorite => 'إضافة إلى المفضلة';

  @override
  String get merchantRemoveFavorite => 'إزالة من المفضلة';

  @override
  String get merchantLocateOnMap => 'تحديد الموقع على الخريطة';

  @override
  String get merchantNoLocationSet => 'لا يوجد موقع محدد';

  @override
  String get merchantLocation => 'الموقع';

  @override
  String get merchantLocationPickerTitle =>
      'الموقع (انقر على الخريطة للاختيار، اختياري)';

  @override
  String get merchantIsOpen => 'مفتوح';

  @override
  String get merchantOpen => 'مفتوح';

  @override
  String get merchantClosed => 'مغلق';

  @override
  String get merchantStatus => 'حالة العمل';

  @override
  String get merchantNoFavoriteMerchants => 'لا توجد متاجر مفضلة';

  @override
  String get merchantNoFavoriteMerchantsHint => 'ستظهر المتاجر المفضلة هنا';

  @override
  String get merchantNoMerchants => 'لا توجد متاجر';

  @override
  String get merchantNoMerchantsHint =>
      'انقر على الزر في الركن السفلي الأيمن لإضافة أول متجر';

  @override
  String get merchantName => 'الاسم';

  @override
  String get merchantNameOptional => 'اسم المتجر (اختياري)';

  @override
  String get merchantAddress => 'العنوان';

  @override
  String get merchantDefaultCurrency => 'العملة الافتراضية';

  @override
  String get merchantCurrencyFollowRegion => 'متابعة المنطقة';

  @override
  String get merchantProductPrices => 'أسعار المنتجات';

  @override
  String get merchantNoProductPrices => 'لا توجد أسعار منتجات لهذا المتجر بعد';

  @override
  String get mapLayerSwitch => 'تبديل نمط الخريطة';

  @override
  String get mapLayerStandard => 'قياسي';

  @override
  String get mapLayerSatellite => 'قمر صناعي';

  @override
  String get mapLayerAmap => 'أماب';

  @override
  String get mapLayerTencent => 'تنسنت';

  @override
  String get mapLayerOsm => 'OSM';

  @override
  String get mapAllMerchants => 'كل المتاجر';

  @override
  String get mapChooseSavedPlace => 'اختر مكانًا محفوظًا';

  @override
  String get mapClearLocation => 'مسح الموقع';

  @override
  String get mapLocateCurrentLocation => 'تحديد الموقع الحالي';

  @override
  String get mapLocateAndChoose => 'حدد الموقع الحالي واختره';

  @override
  String get mapNoMerchantLocations => 'لا توجد مواقع متاجر';

  @override
  String get mapNoMerchantLocationsHint =>
      'لا يمكن عرض المتاجر بدون إحداثيات على الخريطة';

  @override
  String get mapLatitude => 'خط العرض';

  @override
  String get mapLongitude => 'خط الطول';

  @override
  String get mapTapToPickLocation => 'انقر على الخريطة لتحديد الموقع';

  @override
  String get mapLocationServiceDisabled =>
      'خدمة الموقع معطلة. فعّلها في إعدادات النظام.';

  @override
  String get mapLocationPermissionDenied => 'تم رفض إذن الموقع';

  @override
  String get mapLocationPermissionDeniedForever =>
      'إذن الموقع محظور بشكل دائم. فعّله في إعدادات النظام.';

  @override
  String get mapLocationTimeout => 'انتهت مهلة تحديد الموقع. حاول مجددًا.';

  @override
  String get mapLocationFailed => 'تعذر تحديد الموقع. حاول مجددًا.';

  @override
  String get mapMerchantClosedSuffix => ' (مغلق)';
}
