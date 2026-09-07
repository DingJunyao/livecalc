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
  String get priceSearchHint => '搜索商品…';

  @override
  String get priceMoreActions => '更多操作';

  @override
  String priceDeleteRecordMessage(Object name, Object price) {
    return '确定删除「$name」$price 的记录吗？';
  }

  @override
  String get priceListEmptySubtitle => '点击右下角按钮记下第一笔价格';

  @override
  String get priceFilterTitle => '筛选条件';

  @override
  String get priceFilterAllMerchants => '全部商家';

  @override
  String get priceFilterRecordType => '记录类型';

  @override
  String get priceRecordTypePurchase => '购买';

  @override
  String get priceRecordTypePrice => '比价';

  @override
  String get priceFilterDateRange => '日期范围';

  @override
  String get priceFilterStart => '开始';

  @override
  String get priceFilterEnd => '结束';

  @override
  String get priceAddRecordTitle => '新增价格记录';

  @override
  String get priceProductNameLabel => '商品名称';

  @override
  String get priceProductNameHint => '搜索或输入新商品名';

  @override
  String get priceScanProductTooltip => '扫码识别商品';

  @override
  String get priceBarcodeNotFoundTitle => '未找到本地商品';

  @override
  String get priceNameLabel => '名称';

  @override
  String get priceBarcodeLookupFailed => '条码查询失败，请重试';

  @override
  String get priceBarcodeSearching => '正在查询商品信息…';

  @override
  String get quickFillTitle => '快速填写';

  @override
  String get quickFillSelectMerchant => '选择商家';

  @override
  String get quickFillMerchantSearchHint => '搜索或选择商家';

  @override
  String get quickFillNoHistoryProducts => '暂无历史商品';

  @override
  String get quickFillNewProduct => '新商品';

  @override
  String get quickFillProductHeader => '商品';

  @override
  String get quickFillUnitPriceHeader => '单价';

  @override
  String get quickFillSaveAll => '保存所有价格';

  @override
  String quickFillSavedCount(Object count) {
    return '已保存 $count 条记录';
  }

  @override
  String get pricePasteImportTooltip => '粘贴导入';

  @override
  String get pricePasteImportTitle => '粘贴导入价格';

  @override
  String get priceCopyTemplate => '复制模板';

  @override
  String get priceTemplateCopied => '已复制模板';

  @override
  String get pricePasteTextLabel => '粘贴价格文本\n（每行一条，格式：名称 价格[/单位]）';

  @override
  String get pricePasteHint => '芹菜 1.88\n芽菇 4/袋\n嫩豆腐 5.18/kg\n土豆粉 2.5/200g';

  @override
  String get priceParseAndMatch => '解析并匹配';

  @override
  String pricePasteSummary(Object matched, Object unmatched, Object invalid) {
    return '已匹配 $matched · 待处理 $unmatched · 无法识别 $invalid';
  }

  @override
  String pricePasteImporting(Object current, Object total) {
    return '正在导入 $current/$total…';
  }

  @override
  String pricePasteImportAll(Object count) {
    return '全部导入（$count 条）';
  }

  @override
  String pricePasteImportComplete(Object success, Object fail) {
    return '导入完成：成功 $success 条，失败 $fail 条';
  }

  @override
  String pricePasteFailures(Object items) {
    return '失败：$items';
  }

  @override
  String get pricePasteErrorEmptyLine => '空行';

  @override
  String get pricePasteErrorCommentLine => '注释行';

  @override
  String get pricePasteErrorUnrecognized => '格式无法识别';

  @override
  String get pricePasteErrorEmptyName => '商品名为空';

  @override
  String get pricePasteErrorInvalidPrice => '价格无效';

  @override
  String pricePasteInvalidLine(Object error) {
    return '（$error）';
  }

  @override
  String pricePasteInvalidNamedLine(Object name, Object error) {
    return '$name（$error）';
  }

  @override
  String get pricePasteLinkExisting => '关联已有商品';

  @override
  String get pricePasteLinkIngredient => '关联到原料';

  @override
  String get pricePasteSearchIngredients => '搜索原料…';

  @override
  String get pricePasteCreateSameIngredientProduct => '创建同名原料 + 商品';

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

  @override
  String get merchantTitle => '商家';

  @override
  String get merchantDetailTitle => '商家详情';

  @override
  String get merchantAddTitle => '添加商家';

  @override
  String get merchantEditTitle => '编辑商家';

  @override
  String get merchantCreateButton => '创建';

  @override
  String get merchantSaved => '已保存';

  @override
  String get merchantCreated => '已创建商家';

  @override
  String merchantSaveFailed(Object error) {
    return '保存失败：$error';
  }

  @override
  String get merchantSearch => '搜索商家...';

  @override
  String get merchantNoAddress => '暂无地址';

  @override
  String get merchantUnnamed => '未命名商家';

  @override
  String get merchantChip => '商家';

  @override
  String get merchantShowMap => '显示地图';

  @override
  String get merchantHideMap => '收起地图';

  @override
  String get merchantShowClosed => '显示已关闭商家';

  @override
  String get merchantShowOtherRegions => '显示其他地区的商家';

  @override
  String get merchantShowOtherRegionsHint => '含全部地区，不受计算范围限制';

  @override
  String get merchantFavoritesOnly => '仅看我的收藏';

  @override
  String get merchantNoMaintainedPrice => '未维护过价格';

  @override
  String get merchantFilterTitle => '筛选条件';

  @override
  String get merchantDeleteTitle => '删除商家';

  @override
  String merchantDeleteMessage(Object name) {
    return '确定删除商家「$name」吗？';
  }

  @override
  String get merchantDeleted => '已删除';

  @override
  String get merchantFavorite => '收藏';

  @override
  String get merchantRemoveFavorite => '取消收藏';

  @override
  String get merchantLocateOnMap => '在地图上定位';

  @override
  String get merchantNoLocationSet => '未设置位置';

  @override
  String get merchantLocation => '位置';

  @override
  String get merchantLocationPickerTitle => '位置（点击地图选择，可选）';

  @override
  String get merchantIsOpen => '营业中';

  @override
  String get merchantOpen => '营业中';

  @override
  String get merchantClosed => '已关闭';

  @override
  String get merchantStatus => '营业状态';

  @override
  String get merchantNoFavoriteMerchants => '暂无收藏商家';

  @override
  String get merchantNoFavoriteMerchantsHint => '收藏的商家会显示在这里';

  @override
  String get merchantNoMerchants => '暂无商家';

  @override
  String get merchantNoMerchantsHint => '点击右下角按钮添加第一个商家';

  @override
  String get merchantName => '名称';

  @override
  String get merchantNameOptional => '商家名称（可留空）';

  @override
  String get merchantAddress => '地址';

  @override
  String get merchantDefaultCurrency => '默认币种';

  @override
  String get merchantCurrencyFollowRegion => '跟随地区';

  @override
  String get merchantProductPrices => '商品价格';

  @override
  String get merchantNoProductPrices => '该商家暂无价格记录';

  @override
  String get mapLayerSwitch => '切换底图';

  @override
  String get mapLayerStandard => '标准';

  @override
  String get mapLayerSatellite => '卫星';

  @override
  String get mapLayerAmap => '高德';

  @override
  String get mapLayerTencent => '腾讯';

  @override
  String get mapLayerOsm => 'OSM';

  @override
  String get mapAllMerchants => '全部商家';

  @override
  String get mapChooseSavedPlace => '选择常用地点';

  @override
  String get mapClearLocation => '清除定位';

  @override
  String get mapLocateCurrentLocation => '定位当前位置';

  @override
  String get mapLocateAndChoose => '定位并选择当前位置';

  @override
  String get mapNoMerchantLocations => '暂无商家位置';

  @override
  String get mapNoMerchantLocationsHint => '商家缺少坐标信息时无法在地图显示';

  @override
  String get mapLatitude => '纬度';

  @override
  String get mapLongitude => '经度';

  @override
  String get mapTapToPickLocation => '点击地图选择位置';

  @override
  String get mapLocationServiceDisabled => '定位服务未开启，请在系统设置中打开';

  @override
  String get mapLocationPermissionDenied => '位置权限被拒绝';

  @override
  String get mapLocationPermissionDeniedForever => '位置权限已被永久拒绝，请到系统设置中开启';

  @override
  String get mapLocationTimeout => '定位超时，请重试';

  @override
  String get mapLocationFailed => '定位失败，请重试';

  @override
  String get mapMerchantClosedSuffix => '（已关闭）';

  @override
  String get commonGotIt => '知道了';

  @override
  String get homeTodayTitle => '今日推荐';

  @override
  String get homeGenerating => '正在生成今日推荐，AI 正在为你搭配食谱…';

  @override
  String get homeEmpty => '暂无推荐，点击刷新按钮生成今日推荐';

  @override
  String get homeSwapAll => '换一换';

  @override
  String get homeNotSet => '未设置';

  @override
  String get homeBreakfast => '早餐';

  @override
  String get homeLunch => '午餐';

  @override
  String get homeDinner => '晚餐';

  @override
  String get homeProtein => '蛋白';

  @override
  String get homeCarbs => '碳水';

  @override
  String get homeFat => '脂肪';

  @override
  String get homeSwap => '换一个';

  @override
  String get homeConnectionTimeout => '网络连接超时，请检查网络后重试';

  @override
  String get homeConnectionFailed => '网络连接失败，请检查网络后重试';

  @override
  String get homeServerBusy => '服务器繁忙，请稍后重试';

  @override
  String get homeResourceNotFound => '请求的资源不存在';

  @override
  String get homeLoadFailed => '加载失败，请稍后重试';

  @override
  String get homeGeneratingTimeout => '推荐正在生成中，请稍后刷新查看';

  @override
  String get homeSwapLimit => '今天这餐换得太多次了，明天再来吧';

  @override
  String get homeSwapFailed => '换菜失败，请稍后重试';

  @override
  String get homeSwapTimeout => '换菜超时，请稍后重试';

  @override
  String get homeSwapAllLimit => '今天换得太多次了，明天再来吧';

  @override
  String get homeRefreshFailed => '刷新失败，请稍后重试';

  @override
  String get homeRefreshTimeout => '刷新超时，请稍后重试';

  @override
  String get recipeTitle => '菜谱';

  @override
  String get recipeDetailTitle => '菜谱详情';

  @override
  String get recipeAnalysisTitle => '菜谱分析';

  @override
  String get recipeAnalysisChip => '分析';

  @override
  String get recipeSearch => '搜索菜谱...';

  @override
  String get recipeCreateTooltip => '创建菜谱';

  @override
  String get recipeLoading => '加载菜谱...';

  @override
  String get recipeEmptyTitle => '暂无菜谱';

  @override
  String get recipeEmptySubtitle => '点击右下角创建第一个菜谱';

  @override
  String get recipeCategory => '分类';

  @override
  String get recipeDifficulty => '难度';

  @override
  String get recipeUsedIngredients => '所用食材';

  @override
  String get recipeSearchIngredientsHint => '搜索食材（可多选）';

  @override
  String get recipeSpecialConditions => '特殊条件';

  @override
  String get recipeConditionUnpriced => '存在原料没有维护价格';

  @override
  String get recipeConditionUnnourished => '存在原料没有维护营养成分';

  @override
  String recipeServingsCount(Object count) {
    return '$count 人份';
  }

  @override
  String recipeCostPerServings(Object amount, Object count) {
    return '$amount / $count 人份';
  }

  @override
  String recipeCaloriesPerServing(Object amount) {
    return '$amount kcal/份';
  }

  @override
  String get recipeCategoryMeatDish => '荤菜';

  @override
  String get recipeCategoryVegetableDish => '素菜';

  @override
  String get recipeCategorySeafood => '水产';

  @override
  String get recipeCategoryStaple => '主食';

  @override
  String get recipeCategorySoupPorridge => '汤与粥';

  @override
  String get recipeCategoryBreakfast => '早餐';

  @override
  String get recipeCategoryDessert => '甜品';

  @override
  String get recipeCategorySeasoning => '调料';

  @override
  String get recipeCategorySemiFinished => '半成品';

  @override
  String get recipeCategorySnack => '小食';

  @override
  String get recipeDifficultySimple => '简单';

  @override
  String get recipeDifficultyEasy => '容易';

  @override
  String get recipeDifficultyMedium => '中等';

  @override
  String get recipeDifficultyHard => '困难';

  @override
  String get recipeDifficultyExpert => '专家';

  @override
  String get recipePublish => '发布菜谱';

  @override
  String get recipeDelete => '删除菜谱';

  @override
  String get recipePublishTitle => '发布菜谱';

  @override
  String get recipePublishDescription => '发布后菜谱将对其他用户公开。普通用户提交后需管理员审核。';

  @override
  String get recipeConfirmPublish => '提交发布';

  @override
  String get recipePublishPending => '发布已提交，待管理员审核';

  @override
  String get recipePublished => '菜谱已发布';

  @override
  String get recipeDeleteConfirm => '确定要删除这个菜谱吗？';

  @override
  String get recipeDeleted => '菜谱已删除';

  @override
  String get recipeUnpublished => '未发布';

  @override
  String get recipeBasicInfoTitle => '基本信息';

  @override
  String get recipeEditBasicInfo => '编辑基本信息';

  @override
  String get recipeCostEstimate => '成本估算';

  @override
  String get recipeNoCostData => '暂无成本数据';

  @override
  String get recipeIngredients => '原料';

  @override
  String get recipeEditIngredients => '编辑原料';

  @override
  String get recipeNoIngredients => '暂无原料';

  @override
  String get recipeOptional => '可选';

  @override
  String get recipeCalculatedFromIngredientsCost => '根据以下食材计算成本：';

  @override
  String get recipeGotIt => '知道了';

  @override
  String recipeRecommendedQuantity(Object quantity, Object unit) {
    return '推荐 $quantity $unit';
  }

  @override
  String get recipeSteps => '做法步骤';

  @override
  String get recipeEditSteps => '编辑做法';

  @override
  String get recipeNoSteps => '暂无步骤';

  @override
  String recipeStepMinutes(Object count) {
    return '$count 分钟';
  }

  @override
  String get recipeNutritionPerServing => '营养成分（每份）';

  @override
  String get recipeTips => '小贴士';

  @override
  String get recipeEditTips => '编辑小贴士';

  @override
  String get recipeNoTips => '暂无小贴士';

  @override
  String get recipePreviousImage => '上一张';

  @override
  String get recipeNextImage => '下一张';

  @override
  String get recipeCreateTitle => '创建菜谱';

  @override
  String get recipeEditTitle => '编辑菜谱';

  @override
  String get recipeName => '菜谱名称';

  @override
  String get recipeIntroduction => '简介';

  @override
  String get recipeServingsField => '份数';

  @override
  String get recipeTotalTimeMinutes => '总时间（分钟）';

  @override
  String get recipeResultIngredient => '成品产出原料';

  @override
  String get recipeImageManager => '配图管理';

  @override
  String get recipeUpload => '上传';

  @override
  String get recipeCoverHint => '第一张图片为封面。';

  @override
  String get recipeCover => '封面';

  @override
  String get recipeDeleteImage => '删除图片';

  @override
  String get recipeDragToReorder => '拖动排序';

  @override
  String get recipeUnitUnspecified => '不指定';

  @override
  String get recipeIngredientField => '原料';

  @override
  String get recipeAddIngredient => '添加原料';

  @override
  String get recipeMoveUp => '上移';

  @override
  String get recipeMoveDown => '下移';

  @override
  String get recipeQuantityNumeric => '数值';

  @override
  String get recipeQuantityToTaste => '适量';

  @override
  String get recipeQuantitySmall => '少许';

  @override
  String get recipeRecommendedAmount => '推荐量';

  @override
  String get recipeMinimum => '最小';

  @override
  String get recipeMaximum => '最大';

  @override
  String get recipeNote => '备注';

  @override
  String recipeStepNumberLabel(Object index) {
    return '步骤 $index';
  }

  @override
  String get recipeStepContent => '内容';

  @override
  String get recipeStepDuration => '耗时（分钟）';

  @override
  String get recipeStepTips => '步骤提示';

  @override
  String get recipeAddStep => '添加步骤';

  @override
  String get recipeAddTip => '添加小贴士';

  @override
  String get recipeSaveChanges => '保存修改';

  @override
  String get recipeNoSectionChanges => '当前部分没有修改';

  @override
  String get recipeNameRequired => '请输入菜谱名称';

  @override
  String get recipeLoadFailedError => '菜谱加载失败，请重试';

  @override
  String get recipeImagePickFailed => '选择图片失败，请重试';

  @override
  String get recipeImageUploaded => '图片已上传，保存后生效';

  @override
  String get recipeImageUploadFailed => '图片上传失败，请重试';

  @override
  String recipeIngredientQuantityIncomplete(Object row) {
    return '第 $row 行原料的用量组合不完整：仅支持推荐值、推荐值+区间或仅区间';
  }

  @override
  String recipeIngredientFallbackName(Object id) {
    return '原料 #$id';
  }

  @override
  String get recipeSaveSuccess => '保存成功';

  @override
  String get recipeCostShare => '食材成本占比';

  @override
  String get recipeUnknownIngredient => '未知食材';

  @override
  String get recipeOther => '其他';

  @override
  String get recipeCostTrend => '成本趋势';

  @override
  String get recipeNoCostTrend => '暂无成本历史数据';

  @override
  String get recipeNoStackedCostTrend => '暂无成本趋势数据';

  @override
  String get recipeWeek => '周';

  @override
  String get recipeMonth => '月';

  @override
  String get recipeQuarter => '季';

  @override
  String get recipeYear => '年';

  @override
  String get recipeAll => '全部';

  @override
  String get recipeAverageLabel => '均价';

  @override
  String get recipeRangeLabel => '区间';

  @override
  String get recipeTotalLabel => '合计';

  @override
  String get recipeMerchantCostEstimate => '按商家预估成本';

  @override
  String get recipeNoMerchantPriceData => '暂无商家价格数据';

  @override
  String get recipeBestValue => '最实惠 ✓';

  @override
  String recipeCoveredCount(Object covered, Object total) {
    return '覆盖 $covered/$total 种食材';
  }

  @override
  String recipeInStore(Object amount) {
    return '本店 $amount';
  }

  @override
  String recipeExternal(Object amount) {
    return '外部 $amount';
  }

  @override
  String recipeMissingIngredients(Object ingredients) {
    return '⚠ 需外购 $ingredients';
  }

  @override
  String recipeMerchantFallbackName(Object id) {
    return '商家 #$id';
  }

  @override
  String get recipeMerchantPriceRecommendation => '商家比价推荐';

  @override
  String get recipeNoMerchantComparisonData => '暂无比价数据';

  @override
  String get recipeIngredientAndAmount => '食材 / 用量';

  @override
  String get recipeNutritionSources => '营养贡献溯源';

  @override
  String get recipeNrvMetrics => 'NRV 指标';

  @override
  String get recipeAllNutrients => '全部';

  @override
  String get recipeDisplayRange => '显示范围';

  @override
  String get recipeSource => '来源';

  @override
  String get recipeTags => '标签';

  @override
  String get recipeTotalTime => '总时间';

  @override
  String get recipeImages => '配图';

  @override
  String get recipeCalculatedFromIngredientsPrice => '根据以下食材计算价格：';

  @override
  String get nutritionNutrientCopper => '铜';

  @override
  String get nutritionNutrientManganese => '锰';

  @override
  String get nutritionNutrientSelenium => '硒';
}
