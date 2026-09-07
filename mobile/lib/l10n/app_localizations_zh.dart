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

  @override
  String get commonDelete => '删除';

  @override
  String get commonEdit => '编辑';

  @override
  String get commonRetry => '重试';

  @override
  String get commonLoading => '加载中...';

  @override
  String get commonEmptyTitle => '暂无数据';

  @override
  String get commonClose => '关闭';

  @override
  String get commonAdd => '添加';

  @override
  String get commonApply => '应用';

  @override
  String get commonApplying => '应用中...';

  @override
  String get commonReset => '重置';

  @override
  String get commonDone => '完成';

  @override
  String get commonSaveFailedRetry => '保存失败，请重试';

  @override
  String get commonSaving => '保存中...';

  @override
  String get commonSubmittedPendingReview => '已提交，待管理员审核';

  @override
  String get commonListSeparator => '、';

  @override
  String get navHome => '推荐';

  @override
  String get navPrices => '计价';

  @override
  String get navRecipes => '菜谱';

  @override
  String get navIngredients => '原料';

  @override
  String get navProducts => '商品';

  @override
  String get navMerchants => '商家';

  @override
  String get navProfile => '我的';

  @override
  String get navMore => '更多';

  @override
  String get aliasAddHelper => '输入后点击 + 添加';

  @override
  String get aliasAdd => '添加';

  @override
  String get regionSelect => '请选择';

  @override
  String get regionCountry => '国家/地区';

  @override
  String get regionProvince => '省份';

  @override
  String get regionCity => '城市';

  @override
  String get regionCounty => '区县';

  @override
  String get calcContextTooltip => '地区/计算范围/币种';

  @override
  String get calcContextTitle => '地区 / 计算范围 / 币种';

  @override
  String get calcAppliedForSession => '已应用（当前会话生效）';

  @override
  String get calcApplyFailed => '应用失败，请重试';

  @override
  String get calcResetToPersonal => '重置为个人配置';

  @override
  String pendingModificationReview(Object modifications) {
    return '修改待管理员审核：$modifications';
  }

  @override
  String pendingDeletionReview(Object deletions) {
    return '删除待管理员审核：$deletions';
  }

  @override
  String pendingCombinedReview(Object modifications, Object deletions) {
    return '待管理员审核：修改$modifications、删除$deletions';
  }

  @override
  String get merchantPricesTitle => '各商家价格';

  @override
  String get merchantLowest => '最低';

  @override
  String get nutritionTitle => '营养成分';

  @override
  String nutritionPerBase(Object base) {
    return '（每$base）';
  }

  @override
  String get nutritionNoData => '暂无营养数据';

  @override
  String get nutritionNoDataHint => '点击右上角「编辑」添加';

  @override
  String get nutritionNutrient => '营养素';

  @override
  String get nutritionQuantity => '数量';

  @override
  String get nutritionUnit => '单位';

  @override
  String get nutritionCollapse => '收起';

  @override
  String nutritionExpand(int count) {
    return '展开 +$count 项';
  }

  @override
  String get nutritionNrvExplanation => 'NRV = 营养素参考值百分比';

  @override
  String get nutritionEditTitle => '编辑营养成分';

  @override
  String nutritionEditTitleWithName(Object name) {
    return '$name · 营养';
  }

  @override
  String get nutritionClearCustom => '清空自定义';

  @override
  String get nutritionManualEdit => '手动编辑';

  @override
  String get nutritionConfirmMatch => '确认匹配';

  @override
  String get nutritionConfirmMatchDescription =>
      '将清空当前营养数据并写入所选 USDA 食材的营养数据，此操作不可撤销。是否继续？';

  @override
  String get nutritionConfirmWrite => '确认写入';

  @override
  String get nutritionUsdaLoadFailed => 'USDA 数据加载失败';

  @override
  String get nutritionAtLeastOne => '请至少填写一项营养素';

  @override
  String get nutritionBackToList => '返回列表';

  @override
  String get nutritionSearchLabel => '搜索（原文/译文任意命中）';

  @override
  String get nutritionUsdaSearchPrompt => '输入关键词搜索 USDA 食材';

  @override
  String nutritionUsdaResultDetail(
      Object description, Object dataType, int nutrientCount) {
    return '$description · $dataType · $nutrientCount 项营养素';
  }

  @override
  String get nutritionAddNutrient => '添加营养素';

  @override
  String get nutritionNutrientEnergy => '能量';

  @override
  String get nutritionNutrientProtein => '蛋白质';

  @override
  String get nutritionNutrientFat => '脂肪';

  @override
  String get nutritionNutrientCarbohydrate => '碳水化合物';

  @override
  String get nutritionNutrientDietaryFiber => '膳食纤维';

  @override
  String get nutritionNutrientSodium => '钠';

  @override
  String get nutritionNutrientPotassium => '钾';

  @override
  String get nutritionNutrientCalcium => '钙';

  @override
  String get nutritionNutrientIron => '铁';

  @override
  String get nutritionNutrientZinc => '锌';

  @override
  String get nutritionNutrientPhosphorus => '磷';

  @override
  String get nutritionNutrientMagnesium => '镁';

  @override
  String get nutritionNutrientVitaminA => '维生素A';

  @override
  String get nutritionNutrientVitaminC => '维生素C';

  @override
  String get nutritionNutrientVitaminB1 => '维生素B1';

  @override
  String get nutritionNutrientVitaminB2 => '维生素B2';

  @override
  String get nutritionNutrientVitaminB6 => '维生素B6';

  @override
  String get nutritionNutrientVitaminB12 => '维生素B12';

  @override
  String get nutritionNutrientVitaminD => '维生素D';

  @override
  String get nutritionNutrientVitaminE => '维生素E';

  @override
  String get nutritionNutrientVitaminK => '维生素K';

  @override
  String get nutritionNutrientFolate => '叶酸';

  @override
  String get nutritionNutrientNiacin => '烟酸';

  @override
  String get nutritionNutrientCholesterol => '胆固醇';

  @override
  String get nutritionNutrientSaturatedFat => '饱和脂肪';

  @override
  String get unitsScreenTitle => '单位与密度';

  @override
  String unitsScreenTitleWithName(Object name) {
    return '$name · 单位密度';
  }

  @override
  String get unitsCustomTab => '自定义单位';

  @override
  String get unitsDensityTab => '密度';

  @override
  String get unitsAddTitle => '添加单位';

  @override
  String get unitsEditTitle => '编辑单位';

  @override
  String get unitsNameRequired => '请输入单位名称';

  @override
  String get unitsNameLabel => '单位名称 *';

  @override
  String get unitsConversionLabel => '换算系数（1单位 = ? 个）';

  @override
  String get unitsWeightLabel => '单重（g/个）';

  @override
  String get unitsSetDefault => '设为默认单位';

  @override
  String get unitsSave => '保存单位';

  @override
  String get unitsUnmappedTitle => '待配置单位（默认 100 g）';

  @override
  String unitsUnmappedUsage(Object unit, int count) {
    return '$unit（$count次）';
  }

  @override
  String unitsConversionDetail(Object unit, Object factor) {
    return '1 $unit = $factor 个';
  }

  @override
  String unitsWeightDetail(Object weight) {
    return '$weight g / 个';
  }

  @override
  String get unitsDefault => '默认';

  @override
  String get unitsPendingReview => '待审';

  @override
  String get unitsDeleteTitle => '删除单位';

  @override
  String unitsDeleteMessage(Object unit) {
    return '确定删除「$unit」吗？';
  }

  @override
  String get unitsDensityRequired => '请输入有效密度';

  @override
  String get densityAddTitle => '添加密度';

  @override
  String get densityLabel => '密度（kg/m³）*';

  @override
  String get densityConditionLabel => '状态描述（如：切块 / 压碎，可选）';

  @override
  String get densitySave => '保存密度';

  @override
  String get densityDeleteTitle => '删除密度';

  @override
  String get densityDeleteMessage => '确定删除该密度记录吗？';

  @override
  String get priceEditTitle => '编辑价格记录';

  @override
  String get priceRecordTitle => '记录价格';

  @override
  String get priceMerchantLabel => '商家';

  @override
  String get priceProductLabel => '商品';

  @override
  String get priceLabel => '价格';

  @override
  String get priceCurrencyLabel => '币种';

  @override
  String get priceQuantityLabel => '数量';

  @override
  String get priceUnitLabel => '单位';

  @override
  String get priceIncludeInSpending => '计入支出';

  @override
  String get priceIncludeInSpendingDescription => '表示此价格记录来自实际购买，将用于支出计算';

  @override
  String get priceRecordedAt => '记录时间';

  @override
  String get priceNotesLabel => '备注';

  @override
  String get priceNotesHint => '备注（可选）';

  @override
  String get priceValidRequired => '请输入有效的价格';

  @override
  String get priceQuantityRequired => '请输入有效的数量';

  @override
  String get ingredientCategoryGrains => '谷物';

  @override
  String get ingredientCategoryVegetables => '蔬菜';

  @override
  String get ingredientCategoryFruits => '水果';

  @override
  String get ingredientCategoryMeat => '肉类';

  @override
  String get ingredientCategorySeafood => '海鲜';

  @override
  String get ingredientCategoryEggs => '蛋类';

  @override
  String get ingredientCategoryDairy => '乳制品';

  @override
  String get ingredientCategorySoy => '豆制品';

  @override
  String get ingredientCategorySeasoning => '调味品';

  @override
  String get ingredientCategoryOil => '油脂';

  @override
  String get ingredientCategoryNuts => '坚果';

  @override
  String get ingredientCategoryBeverages => '饮品';

  @override
  String get ingredientCategoryOthers => '其他';

  @override
  String get journeyFilters => '筛选';

  @override
  String get journeyConfirm => '确定';

  @override
  String get journeyClear => '清除';

  @override
  String get journeyRefresh => '刷新';

  @override
  String get journeyRecordPrice => '记录价格';

  @override
  String get journeyLoadMore => '加载更多';

  @override
  String get journeyUnknownMerchant => '未知商家';

  @override
  String get journeyBasicInformation => '基本信息';

  @override
  String get journeyLatestPrice => '最新价格';

  @override
  String get journeyNoPriceData => '暂无价格数据';

  @override
  String get journeyPriceRecords => '价格记录';

  @override
  String get journeyAddRecord => '添加记录';

  @override
  String get journeyNoPriceRecords => '暂无价格记录';

  @override
  String get journeyCreatedAt => '创建时间';

  @override
  String get journeyUpdated => '已更新';

  @override
  String get journeyUpdateFailed => '更新失败，请重试';

  @override
  String get journeyDeleted => '已删除';

  @override
  String get journeyDeleteFailed => '删除失败，请重试';

  @override
  String get journeyDeleteRecordTitle => '删除记录';

  @override
  String journeyDeleteRecordMessage(Object name) {
    return '确定删除「$name」这条价格记录吗？';
  }

  @override
  String get journeyDeleteThisRecordMessage => '确定删除这条价格记录吗？';

  @override
  String get journeyDeleteProductTitle => '删除商品';

  @override
  String journeyDeleteProductMessage(Object name) {
    return '确定删除商品「$name」吗？';
  }

  @override
  String get journeyDeleteProposalSubmitted => '删除提议已提交，待管理员审核';

  @override
  String get journeyProductDeleted => '商品已删除';

  @override
  String get journeyPendingNutrition => '营养成分';

  @override
  String get journeyPendingCustomUnits => '自定义单位';

  @override
  String get journeyPendingDensity => '密度';

  @override
  String get journeyPendingHierarchy => '层级关系';

  @override
  String get journeyBasicInfoSaved => '基本信息已保存';

  @override
  String get journeyEditSubmitted => '修改已提交，待管理员审核';

  @override
  String get journeyRelatedProducts => '关联商品';

  @override
  String get journeyNoRelatedProducts => '暂无关联商品';

  @override
  String get journeyRelatedRecipes => '相关菜谱';

  @override
  String get journeyNoRelatedRecipes => '暂无相关菜谱';

  @override
  String journeyUsage(Object usage) {
    return '用量 $usage';
  }

  @override
  String journeyServings(int count) {
    return '$count 份';
  }

  @override
  String get journeyNoHierarchy => '暂无层级关系';

  @override
  String journeyRelationStrength(int value) {
    return '强度：$value';
  }

  @override
  String get journeyAdjustStrength => '调整强度';

  @override
  String get ingredientDetailTitle => '原料详情';

  @override
  String get ingredientPendingName => '名称';

  @override
  String get ingredientPendingCategory => '分类';

  @override
  String get ingredientPendingAliases => '别名';

  @override
  String get ingredientTitle => '原料';

  @override
  String get ingredientSearch => '搜索原料...';

  @override
  String get ingredientEmptyTitle => '暂无原料';

  @override
  String get ingredientEmptySubtitle => '点击右下角按钮添加第一个原料';

  @override
  String get ingredientNoLinkedProducts => '该原料暂无关联商品，请先添加商品';

  @override
  String get ingredientPriceRecorded => '价格已记录';

  @override
  String get ingredientRecordPriceFailed => '记录失败，请重试';

  @override
  String get ingredientCategory => '分类';

  @override
  String get ingredientNoCategories => '暂无分类';

  @override
  String get ingredientSpecialConditions => '特殊条件';

  @override
  String get ingredientConditionNoPrice => '没有维护过价格';

  @override
  String get ingredientConditionNoNutrition => '未配置营养成分';

  @override
  String get ingredientConditionSinglePrice => '仅有一条价格记录';

  @override
  String get ingredientConditionSingleMerchant => '仅有一家商家有其价格';

  @override
  String get ingredientConditionNoRecipe => '无相关菜谱';

  @override
  String get ingredientConditionNoProduct => '无下属商品';

  @override
  String get ingredientChip => '原料';

  @override
  String get ingredientMakingSource => '制作来源';

  @override
  String ingredientMadeFrom(Object name) {
    return '由「$name」制作';
  }

  @override
  String get ingredientAddTitle => '添加原料';

  @override
  String get ingredientEditTitle => '编辑原料';

  @override
  String get ingredientName => '原料名称';

  @override
  String get ingredientAliases => '别名';

  @override
  String get ingredientUncategorized => '未分类';

  @override
  String get ingredientCategoriesLoading => '分类加载中...';

  @override
  String get ingredientCategoriesLoadFailed => '分类加载失败';

  @override
  String get ingredientLoadFailed => '原料加载失败，请重试';

  @override
  String get ingredientNameRequired => '请输入原料名称';

  @override
  String get ingredientCreated => '已创建原料';

  @override
  String get ingredientManageRelations => '关联原料关系';

  @override
  String get ingredientRelationGraph => '关系图';

  @override
  String get ingredientRelationList => '关系列表';

  @override
  String get ingredientDeleteRelation => '删除关系';

  @override
  String get ingredientDeleteRelationMessage => '确定删除这个层级关系吗？';

  @override
  String get ingredientSelectRelation => '请选择关联原料';

  @override
  String get ingredientAddRelation => '添加层级关系';

  @override
  String get ingredientAdjustRelationStrength => '调整关系强度';

  @override
  String get ingredientChangeToAddRelation => '改为添加关系';

  @override
  String get ingredientSearchRelation => '搜索关联原料 *';

  @override
  String get ingredientRelationType => '关系类型';

  @override
  String get ingredientSaveRelation => '保存关系';

  @override
  String get ingredientRelationContains => '包含';

  @override
  String get ingredientRelationSubstitutable => '可替代';

  @override
  String get ingredientRelationFallback => '回退';

  @override
  String ingredientRelationFallbackName(int id) {
    return '原料 #$id';
  }

  @override
  String get productTitle => '商品';

  @override
  String get productSearch => '搜索商品...';

  @override
  String get productEmptyTitle => '暂无商品';

  @override
  String get productEmptySubtitle => '点击右下角按钮添加第一个商品';

  @override
  String get productNoBrand => '无品牌';

  @override
  String get productPriceRecorded => '价格已记录';

  @override
  String get productLinkedIngredient => '关联原料';

  @override
  String get productIngredientCategory => '原料分类';

  @override
  String get productBrand => '品牌';

  @override
  String get productSpecialConditions => '特殊条件';

  @override
  String get productAllIngredients => '全部原料';

  @override
  String get productAllBrands => '全部品牌';

  @override
  String get productChip => '商品';

  @override
  String get productEditBasicInfo => '编辑基本信息';

  @override
  String get productAddTitle => '添加商品';

  @override
  String get productEditTitle => '编辑商品';

  @override
  String get productName => '商品名称 *';

  @override
  String get productSearchIngredient => '搜索并选择关联原料 *';

  @override
  String get productCreateSameName => '新建同名原料';

  @override
  String get productCreateSameNameHint => '开启后将自动创建与商品同名的原料';

  @override
  String get productBarcode => '条码';

  @override
  String get productScanBarcode => '扫码输入条码';

  @override
  String get productTags => '标签';

  @override
  String get productLookupLoading => '正在查询商品信息…';

  @override
  String get productLoadFailed => '商品加载失败，请重试';

  @override
  String get productNameRequired => '请输入商品名称';

  @override
  String get productSelectIngredientOrCreate => '请选择关联的原料，或开启“新建同名原料”';

  @override
  String get productCreateIngredientFailed => '创建原料失败';

  @override
  String get productCreated => '已创建商品';

  @override
  String get productDetailTitle => '商品详情';

  @override
  String get productPendingName => '名称';

  @override
  String get productPendingBrand => '品牌';

  @override
  String get productPendingBarcode => '条码';

  @override
  String get productPendingLinkedIngredient => '关联原料';

  @override
  String get productPendingAliases => '别名';

  @override
  String get productPendingTags => '标签';
}
