// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'LiveCalc - Living Cost Calculator';

  @override
  String get commonSave => 'Save';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonUserInitial => '?';

  @override
  String get appBrandShort => 'LiveCalc';

  @override
  String get appSigningIn => 'Signing in...';

  @override
  String get authServerUnavailable =>
      'Unable to connect to the server. Check that it is running, the address is correct, and your network is available, then try again.';

  @override
  String get authLoginTitle => 'Sign in';

  @override
  String get authLoginSubtitle => 'Enter your account details';

  @override
  String get authUsername => 'Username';

  @override
  String get authPassword => 'Password';

  @override
  String get authUsernameRequired => 'Enter a username';

  @override
  String get authPasswordRequired => 'Enter a password';

  @override
  String get authLoginButton => 'Sign in';

  @override
  String get authNoAccountRegister => 'No account? Create one';

  @override
  String get authServerNotConfigured => 'No server configured';

  @override
  String get authChangeServer => 'Change server';

  @override
  String get authRegisterTitle => 'Create account';

  @override
  String get authUsernameMinLength => 'Username must be at least 3 characters';

  @override
  String get authEmail => 'Email';

  @override
  String get authEmailRequired => 'Enter an email address';

  @override
  String get authEmailInvalid => 'Enter a valid email address';

  @override
  String get authPhoneOptional => 'Phone (optional)';

  @override
  String get authInviteCode => 'Invite code';

  @override
  String get authInviteCodeRequired => 'Enter an invite code';

  @override
  String get authConfigLoadFailed =>
      'Could not load registration settings. Check your network and try again.';

  @override
  String get authRegisterButton => 'Create account';

  @override
  String get authHaveAccountLogin => 'Already have an account? Sign in';

  @override
  String get authInviteCodeNowRequired =>
      'Registration failed: the server now requires an invite code';

  @override
  String get authServerConfigSubtitle => 'Living Cost Calculator';

  @override
  String get authServerAddress => 'Server address';

  @override
  String get authServerAddressHint => 'https://example.com';

  @override
  String get authServerAddressRequired => 'Enter a server address';

  @override
  String get authServerAddressHttpRequired =>
      'Must start with http:// or https://';

  @override
  String get authConnectionFailed => 'Connection failed:';

  @override
  String get authConnect => 'Connect';

  @override
  String get authCannotConnectServer =>
      'Could not connect to the server. Check the address or network and try again.';

  @override
  String get authLoginInvalidCredentials => 'Incorrect username or password';

  @override
  String get authLoginEndpointMissing =>
      'The login endpoint does not exist. Check the server version.';

  @override
  String get authServerError => 'Internal server error. Try again later.';

  @override
  String get authLoginNetworkError =>
      'Sign-in failed. Check your network and try again.';

  @override
  String get authLoginGenericError => 'Sign-in failed. Try again later.';

  @override
  String authRegisterFailedDetail(Object detail) {
    return 'Registration failed: $detail';
  }

  @override
  String get authRegisterInvalid =>
      'Registration failed. Check your registration details.';

  @override
  String get authRegisterEndpointMissing =>
      'The registration endpoint does not exist. Check the server version.';

  @override
  String get authRegisterServerError => 'Registration failed. Try again later.';

  @override
  String get authRegisterNetworkError =>
      'Registration failed. Check your network and try again.';

  @override
  String get authRegisterGenericError =>
      'Registration failed. Try again later.';

  @override
  String get authCropAvatar => 'Crop avatar';

  @override
  String get authAvatarUpdated => 'Avatar updated';

  @override
  String get authAvatarUploadFailed => 'Avatar upload failed. Try again.';

  @override
  String get authNoChangesToSave => 'No changes to save';

  @override
  String get authSaved => 'Saved';

  @override
  String get authSaveFailedRetry => 'Save failed. Try again.';

  @override
  String get authSaveFailedCheckInput =>
      'Save failed. Check your input and try again.';

  @override
  String get authEditAccountTitle => 'Edit account';

  @override
  String get authTapChangeAvatar => 'Tap to change avatar';

  @override
  String get authUsernameLabel => 'Username *';

  @override
  String get authUsernameLength => 'Username must be 3-50 characters';

  @override
  String get authNickname => 'Nickname';

  @override
  String get authNicknameMaxLength => 'Nickname cannot exceed 50 characters';

  @override
  String get authEditEmailInvalid => 'Enter a valid email address';

  @override
  String get authPhoneInvalid => 'Enter a valid phone number';

  @override
  String get authRegion => 'Region';

  @override
  String get authChangePasswordOptional => 'Change password (optional)';

  @override
  String get authCurrentPassword => 'Current password';

  @override
  String get authCurrentPasswordRequired =>
      'Provide your current password to change passwords';

  @override
  String get authNewPassword => 'New password (at least 6 characters)';

  @override
  String get authNewPasswordMinLength =>
      'New password must be at least 6 characters';

  @override
  String get authConfirmNewPassword => 'Confirm new password';

  @override
  String get authPasswordsDoNotMatch => 'The new passwords do not match';

  @override
  String get authSaving => 'Saving...';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileAnonymousUser => 'User';

  @override
  String get profileSettings => 'Settings';

  @override
  String get profileLanguage => 'Language';

  @override
  String get profileRegionalFormat => 'Regional format';

  @override
  String get profileStartupPage => 'Startup page';

  @override
  String get profileStartupPageHome => 'Recommendations';

  @override
  String get profileStartupPagePrices => 'Pricing';

  @override
  String get profileStartupPageRecipes => 'Recipes';

  @override
  String get profileDefaultCurrency => 'Default currency';

  @override
  String get profileFollowRegion => 'Follow your region';

  @override
  String get profileDefaultCalcScope => 'Default calculation scope';

  @override
  String get profileCalcScopeAll => 'All regions';

  @override
  String get profileCalcScopeCountry => 'Country/region';

  @override
  String get profileCalcScopeProvince => 'Province';

  @override
  String get profileCalcScopeCity => 'City';

  @override
  String get profileCalcScopeCounty => 'County';

  @override
  String get profileUnitPreferences => 'Unit preferences';

  @override
  String get profileNutritionGoals => 'Nutrition goals';

  @override
  String get profileMyData => 'My data';

  @override
  String get profileMyProposals => 'My proposals';

  @override
  String get profileMyPlaces => 'My places';

  @override
  String get profileLogout => 'Sign out';

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
  String get profileCurrencyNameCNY => 'Chinese yuan';

  @override
  String get profileCurrencyNameUSD => 'US dollar';

  @override
  String get profileCurrencyNameEUR => 'Euro';

  @override
  String get profileCurrencyNameGBP => 'British pound';

  @override
  String get profileCurrencyNameJPY => 'Japanese yen';

  @override
  String get profileCurrencyNameHKD => 'Hong Kong dollar';

  @override
  String get profileCurrencyNameKRW => 'South Korean won';

  @override
  String get profileCurrencyNameSGD => 'Singapore dollar';

  @override
  String get profileCurrencyNameAUD => 'Australian dollar';

  @override
  String get profileCurrencyNameCAD => 'Canadian dollar';

  @override
  String get profileCurrencyNameTWD => 'New Taiwan dollar';

  @override
  String get profileCurrencyNameTHB => 'Thai baht';

  @override
  String get profileCurrencyNameMYR => 'Malaysian ringgit';

  @override
  String get profileCurrencyNameVND => 'Vietnamese dong';

  @override
  String get profileCurrencyNameRUB => 'Russian ruble';

  @override
  String get profileCurrencyNameAED => 'UAE dirham';

  @override
  String get profileCurrencyNameBGN => 'Bulgarian lev';

  @override
  String get profileCurrencyNameBRL => 'Brazilian real';

  @override
  String get profileCurrencyNameCHF => 'Swiss franc';

  @override
  String get profileCurrencyNameCZK => 'Czech koruna';

  @override
  String get profileCurrencyNameDKK => 'Danish krone';

  @override
  String get profileCurrencyNameHUF => 'Hungarian forint';

  @override
  String get profileCurrencyNameIDR => 'Indonesian rupiah';

  @override
  String get profileCurrencyNameILS => 'Israeli new shekel';

  @override
  String get profileCurrencyNameINR => 'Indian rupee';

  @override
  String get profileCurrencyNameISK => 'Icelandic króna';

  @override
  String get profileCurrencyNameMXN => 'Mexican peso';

  @override
  String get profileCurrencyNameNOK => 'Norwegian krone';

  @override
  String get profileCurrencyNameNZD => 'New Zealand dollar';

  @override
  String get profileCurrencyNamePHP => 'Philippine peso';

  @override
  String get profileCurrencyNamePLN => 'Polish złoty';

  @override
  String get profileCurrencyNameRON => 'Romanian leu';

  @override
  String get profileCurrencyNameSEK => 'Swedish krona';

  @override
  String get profileCurrencyNameTRY => 'Turkish lira';

  @override
  String get profileCurrencyNameZAR => 'South African rand';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonEmptyTitle => 'Nothing here yet';

  @override
  String get commonClose => 'Close';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonApply => 'Apply';

  @override
  String get commonApplying => 'Applying...';

  @override
  String get commonReset => 'Reset';

  @override
  String get commonDone => 'Done';

  @override
  String get commonSaveFailedRetry => 'Save failed. Try again.';

  @override
  String get commonSaving => 'Saving...';

  @override
  String get commonSubmittedPendingReview =>
      'Submitted. Pending administrator review.';

  @override
  String get commonListSeparator => ', ';

  @override
  String get navHome => 'Home';

  @override
  String get navPrices => 'Prices';

  @override
  String get navRecipes => 'Recipes';

  @override
  String get navIngredients => 'Ingredients';

  @override
  String get navProducts => 'Products';

  @override
  String get navMerchants => 'Merchants';

  @override
  String get navProfile => 'Profile';

  @override
  String get navMore => 'More';

  @override
  String get aliasAddHelper => 'Press + to add';

  @override
  String get aliasAdd => 'Add';

  @override
  String get regionSelect => 'Select';

  @override
  String get regionCountry => 'Country/region';

  @override
  String get regionProvince => 'Province';

  @override
  String get regionCity => 'City';

  @override
  String get regionCounty => 'County';

  @override
  String get calcContextTooltip => 'Region / calculation scope / currency';

  @override
  String get calcContextTitle => 'Region / calculation scope / currency';

  @override
  String get calcAppliedForSession => 'Applied for this session';

  @override
  String get calcApplyFailed => 'Could not apply. Try again.';

  @override
  String get calcResetToPersonal => 'Reset to personal settings';

  @override
  String pendingModificationReview(Object modifications) {
    return 'Pending administrator review: edit $modifications';
  }

  @override
  String pendingDeletionReview(Object deletions) {
    return 'Pending administrator review: delete $deletions';
  }

  @override
  String pendingCombinedReview(Object modifications, Object deletions) {
    return 'Pending review: edit $modifications, delete $deletions';
  }

  @override
  String get merchantPricesTitle => 'Merchant prices';

  @override
  String get merchantLowest => 'Lowest';

  @override
  String get nutritionTitle => 'Nutrition';

  @override
  String nutritionPerBase(Object base) {
    return '(per $base)';
  }

  @override
  String get nutritionNoData => 'No nutrition data';

  @override
  String get nutritionNoDataHint =>
      'Use Edit in the top-right corner to add it';

  @override
  String get nutritionNutrient => 'Nutrient';

  @override
  String get nutritionQuantity => 'Quantity';

  @override
  String get nutritionUnit => 'Unit';

  @override
  String get nutritionCollapse => 'Collapse';

  @override
  String nutritionExpand(int count) {
    return 'Show $count more';
  }

  @override
  String get nutritionNrvExplanation =>
      'NRV = percent of nutrient reference values';

  @override
  String get nutritionEditTitle => 'Edit nutrition';

  @override
  String nutritionEditTitleWithName(Object name) {
    return '$name - Nutrition';
  }

  @override
  String get nutritionClearCustom => 'Clear custom nutrition';

  @override
  String get nutritionManualEdit => 'Manual edit';

  @override
  String get nutritionConfirmMatch => 'Confirm match';

  @override
  String get nutritionConfirmMatchDescription =>
      'This will replace the current nutrition data with the selected USDA food. This cannot be undone. Continue?';

  @override
  String get nutritionConfirmWrite => 'Confirm write';

  @override
  String get nutritionUsdaLoadFailed => 'Could not load USDA data';

  @override
  String get nutritionAtLeastOne => 'Enter at least one nutrient';

  @override
  String get nutritionBackToList => 'Back to list';

  @override
  String get nutritionSearchLabel => 'Search (original or translated text)';

  @override
  String get nutritionUsdaSearchPrompt => 'Enter keywords to search USDA foods';

  @override
  String nutritionUsdaResultDetail(
      Object description, Object dataType, int nutrientCount) {
    return '$description - $dataType - $nutrientCount nutrients';
  }

  @override
  String get nutritionAddNutrient => 'Add nutrient';

  @override
  String get nutritionNutrientEnergy => 'Energy';

  @override
  String get nutritionNutrientProtein => 'Protein';

  @override
  String get nutritionNutrientFat => 'Fat';

  @override
  String get nutritionNutrientCarbohydrate => 'Carbohydrates';

  @override
  String get nutritionNutrientDietaryFiber => 'Dietary fiber';

  @override
  String get nutritionNutrientSodium => 'Sodium';

  @override
  String get nutritionNutrientPotassium => 'Potassium';

  @override
  String get nutritionNutrientCalcium => 'Calcium';

  @override
  String get nutritionNutrientIron => 'Iron';

  @override
  String get nutritionNutrientZinc => 'Zinc';

  @override
  String get nutritionNutrientPhosphorus => 'Phosphorus';

  @override
  String get nutritionNutrientMagnesium => 'Magnesium';

  @override
  String get nutritionNutrientVitaminA => 'Vitamin A';

  @override
  String get nutritionNutrientVitaminC => 'Vitamin C';

  @override
  String get nutritionNutrientVitaminB1 => 'Vitamin B1';

  @override
  String get nutritionNutrientVitaminB2 => 'Vitamin B2';

  @override
  String get nutritionNutrientVitaminB6 => 'Vitamin B6';

  @override
  String get nutritionNutrientVitaminB12 => 'Vitamin B12';

  @override
  String get nutritionNutrientVitaminD => 'Vitamin D';

  @override
  String get nutritionNutrientVitaminE => 'Vitamin E';

  @override
  String get nutritionNutrientVitaminK => 'Vitamin K';

  @override
  String get nutritionNutrientFolate => 'Folate';

  @override
  String get nutritionNutrientNiacin => 'Niacin';

  @override
  String get nutritionNutrientCholesterol => 'Cholesterol';

  @override
  String get nutritionNutrientSaturatedFat => 'Saturated fat';

  @override
  String get unitsScreenTitle => 'Units & densities';

  @override
  String unitsScreenTitleWithName(Object name) {
    return '$name - Units & densities';
  }

  @override
  String get unitsCustomTab => 'Custom units';

  @override
  String get unitsDensityTab => 'Densities';

  @override
  String get unitsAddTitle => 'Add unit';

  @override
  String get unitsEditTitle => 'Edit unit';

  @override
  String get unitsNameRequired => 'Enter a unit name';

  @override
  String get unitsNameLabel => 'Unit name *';

  @override
  String get unitsConversionLabel => 'Conversion (1 unit = ? each)';

  @override
  String get unitsWeightLabel => 'Weight (g/each)';

  @override
  String get unitsSetDefault => 'Set as default unit';

  @override
  String get unitsSave => 'Save unit';

  @override
  String get unitsUnmappedTitle => 'Units to configure (default 100 g)';

  @override
  String unitsUnmappedUsage(Object unit, int count) {
    return '$unit ($count uses)';
  }

  @override
  String unitsConversionDetail(Object unit, Object factor) {
    return '1 $unit = $factor each';
  }

  @override
  String unitsWeightDetail(Object weight) {
    return '$weight g / each';
  }

  @override
  String get unitsDefault => 'Default';

  @override
  String get unitsPendingReview => 'Pending';

  @override
  String get unitsDeleteTitle => 'Delete unit';

  @override
  String unitsDeleteMessage(Object unit) {
    return 'Delete \"$unit\"?';
  }

  @override
  String get unitsDensityRequired => 'Enter a valid density';

  @override
  String get densityAddTitle => 'Add density';

  @override
  String get densityLabel => 'Density (kg/m³) *';

  @override
  String get densityConditionLabel =>
      'Condition (for example: diced / crushed, optional)';

  @override
  String get densitySave => 'Save density';

  @override
  String get densityDeleteTitle => 'Delete density';

  @override
  String get densityDeleteMessage => 'Delete this density record?';

  @override
  String get priceEditTitle => 'Edit price record';

  @override
  String get priceRecordTitle => 'Record price';

  @override
  String get priceMerchantLabel => 'Merchant';

  @override
  String get priceProductLabel => 'Product';

  @override
  String get priceLabel => 'Price';

  @override
  String get priceCurrencyLabel => 'Currency';

  @override
  String get priceQuantityLabel => 'Quantity';

  @override
  String get priceUnitLabel => 'Unit';

  @override
  String get priceIncludeInSpending => 'Include in spending';

  @override
  String get priceIncludeInSpendingDescription =>
      'This price record came from an actual purchase and will be used in spending calculations';

  @override
  String get priceRecordedAt => 'Recorded at';

  @override
  String get priceNotesLabel => 'Notes';

  @override
  String get priceNotesHint => 'Notes (optional)';

  @override
  String get priceValidRequired => 'Enter a valid price';

  @override
  String get priceQuantityRequired => 'Enter a valid quantity';

  @override
  String get priceSearchHint => 'Search products...';

  @override
  String get priceMoreActions => 'More actions';

  @override
  String priceDeleteRecordMessage(Object name, Object price) {
    return 'Delete the price record for \"$name\" ($price)?';
  }

  @override
  String get priceListEmptySubtitle =>
      'Tap the button in the lower-right corner to record the first price';

  @override
  String get priceFilterTitle => 'Filter options';

  @override
  String get priceFilterAllMerchants => 'All merchants';

  @override
  String get priceFilterRecordType => 'Record type';

  @override
  String get priceRecordTypePurchase => 'Purchase';

  @override
  String get priceRecordTypePrice => 'Comparison';

  @override
  String get priceFilterDateRange => 'Date range';

  @override
  String get priceFilterStart => 'Start';

  @override
  String get priceFilterEnd => 'End';

  @override
  String get priceAddRecordTitle => 'Add price record';

  @override
  String get priceProductNameLabel => 'Product name';

  @override
  String get priceProductNameHint => 'Search or enter a new product name';

  @override
  String get priceScanProductTooltip => 'Scan product';

  @override
  String get priceBarcodeNotFoundTitle => 'Local product not found';

  @override
  String get priceNameLabel => 'Name';

  @override
  String get priceBarcodeLookupFailed => 'Barcode lookup failed. Try again.';

  @override
  String get priceBarcodeSearching => 'Looking up product info...';

  @override
  String get quickFillTitle => 'Quick fill';

  @override
  String get quickFillSelectMerchant => 'Select merchant';

  @override
  String get quickFillMerchantSearchHint => 'Search or select a merchant';

  @override
  String get quickFillNoHistoryProducts => 'No historical products yet';

  @override
  String get quickFillNewProduct => 'New product';

  @override
  String get quickFillProductHeader => 'Product';

  @override
  String get quickFillUnitPriceHeader => 'Unit price';

  @override
  String get quickFillSaveAll => 'Save all prices';

  @override
  String quickFillSavedCount(Object count) {
    return 'Saved $count records';
  }

  @override
  String get pricePasteImportTooltip => 'Paste import';

  @override
  String get pricePasteImportTitle => 'Paste price import';

  @override
  String get priceCopyTemplate => 'Copy template';

  @override
  String get priceTemplateCopied => 'Template copied';

  @override
  String get pricePasteTextLabel =>
      'Paste price text\n(one per line, format: name price[/unit])';

  @override
  String get pricePasteHint =>
      'Celery 1.88\nMushrooms 4/bag\nTofu 5.18/kg\nPotato starch 2.5/200g';

  @override
  String get priceParseAndMatch => 'Parse and match';

  @override
  String pricePasteSummary(Object matched, Object unmatched, Object invalid) {
    return 'Matched $matched · Pending $unmatched · Unrecognized $invalid';
  }

  @override
  String pricePasteImporting(Object current, Object total) {
    return 'Importing $current/$total...';
  }

  @override
  String pricePasteImportAll(Object count) {
    return 'Import all ($count records)';
  }

  @override
  String pricePasteImportComplete(Object success, Object fail) {
    return 'Import complete: $success succeeded, $fail failed';
  }

  @override
  String pricePasteFailures(Object items) {
    return 'Failed: $items';
  }

  @override
  String get pricePasteErrorEmptyLine => 'Empty line';

  @override
  String get pricePasteErrorCommentLine => 'Comment line';

  @override
  String get pricePasteErrorUnrecognized => 'Unrecognized format';

  @override
  String get pricePasteErrorEmptyName => 'Product name is empty';

  @override
  String get pricePasteErrorInvalidPrice => 'Invalid price';

  @override
  String pricePasteInvalidLine(Object error) {
    return '($error)';
  }

  @override
  String pricePasteInvalidNamedLine(Object name, Object error) {
    return '$name ($error)';
  }

  @override
  String get pricePasteLinkExisting => 'Link an existing product';

  @override
  String get pricePasteLinkIngredient => 'Link to ingredient';

  @override
  String get pricePasteSearchIngredients => 'Search ingredients...';

  @override
  String get pricePasteCreateSameIngredientProduct =>
      'Create same-named ingredient + product';

  @override
  String get ingredientCategoryGrains => 'Grains';

  @override
  String get ingredientCategoryVegetables => 'Vegetables';

  @override
  String get ingredientCategoryFruits => 'Fruits';

  @override
  String get ingredientCategoryMeat => 'Meat';

  @override
  String get ingredientCategorySeafood => 'Seafood';

  @override
  String get ingredientCategoryEggs => 'Eggs';

  @override
  String get ingredientCategoryDairy => 'Dairy';

  @override
  String get ingredientCategorySoy => 'Soy';

  @override
  String get ingredientCategorySeasoning => 'Seasoning';

  @override
  String get ingredientCategoryOil => 'Oil';

  @override
  String get ingredientCategoryNuts => 'Nuts';

  @override
  String get ingredientCategoryBeverages => 'Beverages';

  @override
  String get ingredientCategoryOthers => 'Others';

  @override
  String get journeyFilters => 'Filters';

  @override
  String get journeyConfirm => 'Confirm';

  @override
  String get journeyClear => 'Clear';

  @override
  String get journeyRefresh => 'Refresh';

  @override
  String get journeyRecordPrice => 'Record price';

  @override
  String get journeyLoadMore => 'Load more';

  @override
  String get journeyUnknownMerchant => 'Unknown merchant';

  @override
  String get journeyBasicInformation => 'Basic information';

  @override
  String get journeyLatestPrice => 'Latest price';

  @override
  String get journeyNoPriceData => 'No price data';

  @override
  String get journeyPriceRecords => 'Price records';

  @override
  String get journeyAddRecord => 'Add record';

  @override
  String get journeyNoPriceRecords => 'No price records';

  @override
  String get journeyCreatedAt => 'Created at';

  @override
  String get journeyUpdated => 'Updated';

  @override
  String get journeyUpdateFailed => 'Update failed. Try again.';

  @override
  String get journeyDeleted => 'Deleted';

  @override
  String get journeyDeleteFailed => 'Delete failed. Try again.';

  @override
  String get journeyDeleteRecordTitle => 'Delete record';

  @override
  String journeyDeleteRecordMessage(Object name) {
    return 'Delete the price record for \"$name\"?';
  }

  @override
  String get journeyDeleteThisRecordMessage => 'Delete this price record?';

  @override
  String get journeyDeleteProductTitle => 'Delete product';

  @override
  String journeyDeleteProductMessage(Object name) {
    return 'Delete product \"$name\"?';
  }

  @override
  String get journeyDeleteProposalSubmitted =>
      'Delete proposal submitted and awaiting administrator review';

  @override
  String get journeyProductDeleted => 'Product deleted';

  @override
  String get journeyPendingNutrition => 'Nutrition';

  @override
  String get journeyPendingCustomUnits => 'Custom units';

  @override
  String get journeyPendingDensity => 'Density';

  @override
  String get journeyPendingHierarchy => 'Hierarchy';

  @override
  String get journeyBasicInfoSaved => 'Basic information saved';

  @override
  String get journeyEditSubmitted =>
      'Edit submitted and awaiting administrator review';

  @override
  String get journeyRelatedProducts => 'Related products';

  @override
  String get journeyNoRelatedProducts => 'No related products';

  @override
  String get journeyRelatedRecipes => 'Related recipes';

  @override
  String get journeyNoRelatedRecipes => 'No related recipes';

  @override
  String journeyUsage(Object usage) {
    return 'Usage $usage';
  }

  @override
  String journeyServings(int count) {
    return '$count servings';
  }

  @override
  String get journeyNoHierarchy => 'No hierarchy';

  @override
  String journeyRelationStrength(int value) {
    return 'Strength: $value';
  }

  @override
  String get journeyAdjustStrength => 'Adjust strength';

  @override
  String get ingredientDetailTitle => 'Ingredient details';

  @override
  String get ingredientPendingName => 'Name';

  @override
  String get ingredientPendingCategory => 'Category';

  @override
  String get ingredientPendingAliases => 'Aliases';

  @override
  String get ingredientTitle => 'Ingredients';

  @override
  String get ingredientSearch => 'Search ingredients...';

  @override
  String get ingredientEmptyTitle => 'No ingredients';

  @override
  String get ingredientEmptySubtitle =>
      'Tap the button in the lower-right corner to add the first ingredient';

  @override
  String get ingredientNoLinkedProducts =>
      'This ingredient has no linked product. Add a product first.';

  @override
  String get ingredientPriceRecorded => 'Price recorded';

  @override
  String get ingredientRecordPriceFailed =>
      'Could not record the price. Try again.';

  @override
  String get ingredientCategory => 'Category';

  @override
  String get ingredientNoCategories => 'No categories';

  @override
  String get ingredientSpecialConditions => 'Special conditions';

  @override
  String get ingredientConditionNoPrice => 'No maintained price';

  @override
  String get ingredientConditionNoNutrition => 'No nutrition data configured';

  @override
  String get ingredientConditionSinglePrice => 'Only one price record';

  @override
  String get ingredientConditionSingleMerchant =>
      'Only one merchant has prices';

  @override
  String get ingredientConditionNoRecipe => 'No related recipe';

  @override
  String get ingredientConditionNoProduct => 'No child product';

  @override
  String get ingredientChip => 'Ingredient';

  @override
  String get ingredientMakingSource => 'Made from';

  @override
  String ingredientMadeFrom(Object name) {
    return 'Made from \"$name\"';
  }

  @override
  String get ingredientAddTitle => 'Add ingredient';

  @override
  String get ingredientEditTitle => 'Edit ingredient';

  @override
  String get ingredientName => 'Ingredient name';

  @override
  String get ingredientAliases => 'Aliases';

  @override
  String get ingredientUncategorized => 'Uncategorized';

  @override
  String get ingredientCategoriesLoading => 'Loading categories...';

  @override
  String get ingredientCategoriesLoadFailed => 'Could not load categories';

  @override
  String get ingredientLoadFailed =>
      'Could not load the ingredient. Try again.';

  @override
  String get ingredientNameRequired => 'Ingredient name is required';

  @override
  String get ingredientCreated => 'Ingredient created';

  @override
  String get ingredientManageRelations => 'Manage ingredient relations';

  @override
  String get ingredientRelationGraph => 'Relation graph';

  @override
  String get ingredientRelationList => 'Relation list';

  @override
  String get ingredientDeleteRelation => 'Delete relation';

  @override
  String get ingredientDeleteRelationMessage =>
      'Delete this hierarchy relation?';

  @override
  String get ingredientSelectRelation => 'Select an ingredient';

  @override
  String get ingredientAddRelation => 'Add hierarchy relation';

  @override
  String get ingredientAdjustRelationStrength => 'Adjust relation strength';

  @override
  String get ingredientChangeToAddRelation => 'Change to add relation';

  @override
  String get ingredientSearchRelation => 'Search ingredient *';

  @override
  String get ingredientRelationType => 'Relation type';

  @override
  String get ingredientSaveRelation => 'Save relation';

  @override
  String get ingredientRelationContains => 'Contains';

  @override
  String get ingredientRelationSubstitutable => 'Substitute';

  @override
  String get ingredientRelationFallback => 'Fallback';

  @override
  String ingredientRelationFallbackName(int id) {
    return 'Ingredient #$id';
  }

  @override
  String get productTitle => 'Products';

  @override
  String get productSearch => 'Search products...';

  @override
  String get productEmptyTitle => 'No products';

  @override
  String get productEmptySubtitle =>
      'Tap the button in the lower-right corner to add the first product';

  @override
  String get productNoBrand => 'No brand';

  @override
  String get productPriceRecorded => 'Price recorded';

  @override
  String get productLinkedIngredient => 'Linked ingredient';

  @override
  String get productIngredientCategory => 'Ingredient category';

  @override
  String get productBrand => 'Brand';

  @override
  String get productSpecialConditions => 'Special conditions';

  @override
  String get productAllIngredients => 'All ingredients';

  @override
  String get productAllBrands => 'All brands';

  @override
  String get productChip => 'Product';

  @override
  String get productEditBasicInfo => 'Edit basic information';

  @override
  String get productAddTitle => 'Add product';

  @override
  String get productEditTitle => 'Edit product';

  @override
  String get productName => 'Product name *';

  @override
  String get productSearchIngredient =>
      'Search and select a linked ingredient *';

  @override
  String get productCreateSameName => 'Create ingredient with the same name';

  @override
  String get productCreateSameNameHint =>
      'Automatically creates an ingredient with the same name as this product';

  @override
  String get productBarcode => 'Barcode';

  @override
  String get productScanBarcode => 'Scan barcode';

  @override
  String get productTags => 'Tags';

  @override
  String get productLookupLoading => 'Looking up product information...';

  @override
  String get productLoadFailed => 'Could not load the product. Try again.';

  @override
  String get productNameRequired => 'Product name is required';

  @override
  String get productSelectIngredientOrCreate =>
      'Select a linked ingredient or enable \"Create ingredient with the same name\".';

  @override
  String get productCreateIngredientFailed => 'Failed to create ingredient';

  @override
  String get productCreated => 'Product created';

  @override
  String get productDetailTitle => 'Product details';

  @override
  String get productPendingName => 'Name';

  @override
  String get productPendingBrand => 'Brand';

  @override
  String get productPendingBarcode => 'Barcode';

  @override
  String get productPendingLinkedIngredient => 'Linked ingredient';

  @override
  String get productPendingAliases => 'Aliases';

  @override
  String get productPendingTags => 'Tags';

  @override
  String get merchantTitle => 'Merchants';

  @override
  String get merchantDetailTitle => 'Merchant details';

  @override
  String get merchantAddTitle => 'Add merchant';

  @override
  String get merchantEditTitle => 'Edit merchant';

  @override
  String get merchantCreateButton => 'Create';

  @override
  String get merchantSaved => 'Merchant saved';

  @override
  String get merchantCreated => 'Merchant created';

  @override
  String merchantSaveFailed(Object error) {
    return 'Save failed: $error';
  }

  @override
  String get merchantSearch => 'Search merchants...';

  @override
  String get merchantNoAddress => 'No address';

  @override
  String get merchantUnnamed => 'Unnamed merchant';

  @override
  String get merchantChip => 'Merchant';

  @override
  String get merchantShowMap => 'Show map';

  @override
  String get merchantHideMap => 'Hide map';

  @override
  String get merchantShowClosed => 'Show closed merchants';

  @override
  String get merchantShowOtherRegions => 'Show merchants from other regions';

  @override
  String get merchantShowOtherRegionsHint =>
      'Includes all regions, unaffected by calculation scope';

  @override
  String get merchantFavoritesOnly => 'Favorites only';

  @override
  String get merchantNoMaintainedPrice => 'No maintained price';

  @override
  String get merchantFilterTitle => 'Filter options';

  @override
  String get merchantDeleteTitle => 'Delete merchant';

  @override
  String merchantDeleteMessage(Object name) {
    return 'Delete merchant \"$name\"?';
  }

  @override
  String get merchantDeleted => 'Merchant deleted';

  @override
  String get merchantFavorite => 'Add to favorites';

  @override
  String get merchantRemoveFavorite => 'Remove from favorites';

  @override
  String get merchantLocateOnMap => 'Locate on map';

  @override
  String get merchantNoLocationSet => 'No location set';

  @override
  String get merchantLocation => 'Location';

  @override
  String get merchantLocationPickerTitle =>
      'Location (tap the map to choose, optional)';

  @override
  String get merchantIsOpen => 'Open';

  @override
  String get merchantOpen => 'Open';

  @override
  String get merchantClosed => 'Closed';

  @override
  String get merchantStatus => 'Business status';

  @override
  String get merchantNoFavoriteMerchants => 'No favorite merchants';

  @override
  String get merchantNoFavoriteMerchantsHint =>
      'Favorite merchants will appear here';

  @override
  String get merchantNoMerchants => 'No merchants';

  @override
  String get merchantNoMerchantsHint =>
      'Tap the button in the lower-right corner to add the first merchant';

  @override
  String get merchantName => 'Name';

  @override
  String get merchantNameOptional => 'Merchant name (optional)';

  @override
  String get merchantAddress => 'Address';

  @override
  String get merchantDefaultCurrency => 'Default currency';

  @override
  String get merchantCurrencyFollowRegion => 'Follow region';

  @override
  String get merchantProductPrices => 'Product prices';

  @override
  String get merchantNoProductPrices =>
      'This merchant has no product prices yet';

  @override
  String get mapLayerSwitch => 'Switch map style';

  @override
  String get mapLayerStandard => 'Standard';

  @override
  String get mapLayerSatellite => 'Satellite';

  @override
  String get mapLayerAmap => 'AMap';

  @override
  String get mapLayerTencent => 'Tencent';

  @override
  String get mapLayerOsm => 'OSM';

  @override
  String get mapAllMerchants => 'All merchants';

  @override
  String get mapChooseSavedPlace => 'Choose a saved place';

  @override
  String get mapClearLocation => 'Clear location';

  @override
  String get mapLocateCurrentLocation => 'Locate current location';

  @override
  String get mapLocateAndChoose => 'Locate and choose current location';

  @override
  String get mapNoMerchantLocations => 'No merchant locations';

  @override
  String get mapNoMerchantLocationsHint =>
      'Merchants without coordinates cannot be shown on the map';

  @override
  String get mapLatitude => 'Latitude';

  @override
  String get mapLongitude => 'Longitude';

  @override
  String get mapTapToPickLocation => 'Tap the map to choose a location';

  @override
  String get mapLocationServiceDisabled =>
      'Location services are off. Turn them on in system settings.';

  @override
  String get mapLocationPermissionDenied => 'Location permission denied';

  @override
  String get mapLocationPermissionDeniedForever =>
      'Location permission is permanently denied. Enable it in system settings.';

  @override
  String get mapLocationTimeout => 'Location timed out. Try again.';

  @override
  String get mapLocationFailed => 'Could not locate. Try again.';

  @override
  String get mapMerchantClosedSuffix => ' (closed)';

  @override
  String get commonGotIt => 'Got it';

  @override
  String get homeTodayTitle => 'Today\'s recommendations';

  @override
  String get homeGenerating =>
      'Generating today\'s recommendations. AI is planning your meals…';

  @override
  String get homeEmpty =>
      'No recommendations yet. Tap refresh to generate today\'s recommendations.';

  @override
  String get homeSwapAll => 'Swap all';

  @override
  String get homeNotSet => 'Not set';

  @override
  String get homeBreakfast => 'Breakfast';

  @override
  String get homeLunch => 'Lunch';

  @override
  String get homeDinner => 'Dinner';

  @override
  String get homeProtein => 'Protein';

  @override
  String get homeCarbs => 'Carbs';

  @override
  String get homeFat => 'Fat';

  @override
  String get homeSwap => 'Swap';

  @override
  String get homeConnectionTimeout =>
      'Network timed out. Check your connection and try again.';

  @override
  String get homeConnectionFailed =>
      'Network connection failed. Check your connection and try again.';

  @override
  String get homeServerBusy => 'Server is busy. Try again later.';

  @override
  String get homeResourceNotFound => 'The requested resource was not found.';

  @override
  String get homeLoadFailed =>
      'Could not load recommendations. Try again later.';

  @override
  String get homeGeneratingTimeout =>
      'Recommendations are still generating. Refresh later to view them.';

  @override
  String get homeSwapLimit =>
      'You have swapped this meal too many times today. Try again tomorrow.';

  @override
  String get homeSwapFailed => 'Could not swap the meal. Try again later.';

  @override
  String get homeSwapTimeout => 'Swapping the meal timed out. Try again later.';

  @override
  String get homeSwapAllLimit =>
      'You have swapped too many times today. Try again tomorrow.';

  @override
  String get homeRefreshFailed =>
      'Could not refresh recommendations. Try again later.';

  @override
  String get homeRefreshTimeout =>
      'Refreshing recommendations timed out. Try again later.';

  @override
  String get recipeTitle => 'Recipes';

  @override
  String get recipeDetailTitle => 'Recipe details';

  @override
  String get recipeAnalysisTitle => 'Recipe analysis';

  @override
  String get recipeAnalysisChip => 'Analysis';

  @override
  String get recipeSearch => 'Search recipes...';

  @override
  String get recipeCreateTooltip => 'Create recipe';

  @override
  String get recipeLoading => 'Loading recipes...';

  @override
  String get recipeEmptyTitle => 'No recipes yet';

  @override
  String get recipeEmptySubtitle =>
      'Tap the button in the lower-right corner to create the first recipe.';

  @override
  String get recipeCategory => 'Category';

  @override
  String get recipeDifficulty => 'Difficulty';

  @override
  String get recipeUsedIngredients => 'Ingredients used';

  @override
  String get recipeSearchIngredientsHint =>
      'Search ingredients (select multiple)';

  @override
  String get recipeSpecialConditions => 'Special conditions';

  @override
  String get recipeConditionUnpriced =>
      'Has ingredients without maintained prices';

  @override
  String get recipeConditionUnnourished =>
      'Has ingredients without nutrition data';

  @override
  String recipeServingsCount(Object count) {
    return '$count servings';
  }

  @override
  String recipeCostPerServings(Object amount, Object count) {
    return '$amount / $count servings';
  }

  @override
  String recipeCaloriesPerServing(Object amount) {
    return '$amount kcal / serving';
  }

  @override
  String get recipeCategoryMeatDish => 'Meat dish';

  @override
  String get recipeCategoryVegetableDish => 'Vegetable dish';

  @override
  String get recipeCategorySeafood => 'Seafood';

  @override
  String get recipeCategoryStaple => 'Staple food';

  @override
  String get recipeCategorySoupPorridge => 'Soup or porridge';

  @override
  String get recipeCategoryBreakfast => 'Breakfast';

  @override
  String get recipeCategoryDessert => 'Dessert';

  @override
  String get recipeCategorySeasoning => 'Seasoning';

  @override
  String get recipeCategorySemiFinished => 'Semi-finished';

  @override
  String get recipeCategorySnack => 'Snack';

  @override
  String get recipeDifficultySimple => 'Very easy';

  @override
  String get recipeDifficultyEasy => 'Easy';

  @override
  String get recipeDifficultyMedium => 'Medium';

  @override
  String get recipeDifficultyHard => 'Hard';

  @override
  String get recipeDifficultyExpert => 'Expert';

  @override
  String get recipePublish => 'Publish recipe';

  @override
  String get recipeDelete => 'Delete recipe';

  @override
  String get recipePublishTitle => 'Publish recipe';

  @override
  String get recipePublishDescription =>
      'After publishing, this recipe will be visible to other users. Standard users must wait for administrator review.';

  @override
  String get recipeConfirmPublish => 'Confirm publish';

  @override
  String get recipePublishPending =>
      'Publish submitted. Pending administrator review.';

  @override
  String get recipePublished => 'Recipe published';

  @override
  String get recipeDeleteConfirm => 'Delete this recipe?';

  @override
  String get recipeDeleted => 'Recipe deleted';

  @override
  String get recipeUnpublished => 'Unpublished';

  @override
  String get recipeBasicInfoTitle => 'Basic information';

  @override
  String get recipeEditBasicInfo => 'Edit basic information';

  @override
  String get recipeCostEstimate => 'Cost estimate';

  @override
  String get recipeNoCostData => 'No cost data';

  @override
  String get recipeIngredients => 'Ingredients';

  @override
  String get recipeEditIngredients => 'Edit ingredients';

  @override
  String get recipeNoIngredients => 'No ingredients';

  @override
  String get recipeOptional => 'Optional';

  @override
  String get recipeCalculatedFromIngredientsCost =>
      'Calculated from ingredient costs:';

  @override
  String get recipeGotIt => 'Got it';

  @override
  String recipeRecommendedQuantity(Object quantity, Object unit) {
    return 'Recommended $quantity $unit';
  }

  @override
  String get recipeSteps => 'Steps';

  @override
  String get recipeEditSteps => 'Edit steps';

  @override
  String get recipeNoSteps => 'No steps';

  @override
  String recipeStepMinutes(Object count) {
    return '$count min';
  }

  @override
  String get recipeNutritionPerServing => 'Nutrition (per serving)';

  @override
  String get recipeTips => 'Tips';

  @override
  String get recipeEditTips => 'Edit tips';

  @override
  String get recipeNoTips => 'No tips';

  @override
  String get recipePreviousImage => 'Previous image';

  @override
  String get recipeNextImage => 'Next image';

  @override
  String get recipeCreateTitle => 'Create recipe';

  @override
  String get recipeEditTitle => 'Edit recipe';

  @override
  String get recipeName => 'Recipe name';

  @override
  String get recipeIntroduction => 'Introduction';

  @override
  String get recipeServingsField => 'Servings';

  @override
  String get recipeTotalTimeMinutes => 'Total time (minutes)';

  @override
  String get recipeResultIngredient => 'Result ingredient';

  @override
  String get recipeImageManager => 'Image management';

  @override
  String get recipeUpload => 'Upload';

  @override
  String get recipeCoverHint => 'The first image is the cover.';

  @override
  String get recipeCover => 'Cover';

  @override
  String get recipeDeleteImage => 'Delete image';

  @override
  String get recipeDragToReorder => 'Drag to reorder';

  @override
  String get recipeUnitUnspecified => 'Not specified';

  @override
  String get recipeIngredientField => 'Ingredient';

  @override
  String get recipeAddIngredient => 'Add ingredient';

  @override
  String get recipeMoveUp => 'Move up';

  @override
  String get recipeMoveDown => 'Move down';

  @override
  String get recipeQuantityNumeric => 'Amount';

  @override
  String get recipeQuantityToTaste => 'To taste';

  @override
  String get recipeQuantitySmall => 'A little';

  @override
  String get recipeRecommendedAmount => 'Recommended amount';

  @override
  String get recipeMinimum => 'Minimum';

  @override
  String get recipeMaximum => 'Maximum';

  @override
  String get recipeNote => 'Note';

  @override
  String recipeStepNumberLabel(Object index) {
    return 'Step $index';
  }

  @override
  String get recipeStepContent => 'Content';

  @override
  String get recipeStepDuration => 'Duration (minutes)';

  @override
  String get recipeStepTips => 'Step tips';

  @override
  String get recipeAddStep => 'Add step';

  @override
  String get recipeAddTip => 'Add tip';

  @override
  String get recipeSaveChanges => 'Save changes';

  @override
  String get recipeNoSectionChanges => 'This section has no changes';

  @override
  String get recipeNameRequired => 'Enter a recipe name';

  @override
  String get recipeLoadFailedError => 'Could not load the recipe. Try again.';

  @override
  String get recipeImagePickFailed => 'Could not select an image. Try again.';

  @override
  String get recipeImageUploaded =>
      'Image uploaded. It will take effect after saving.';

  @override
  String get recipeImageUploadFailed =>
      'Could not upload the image. Try again.';

  @override
  String recipeIngredientQuantityIncomplete(Object row) {
    return 'Ingredient row $row has an incomplete quantity: enter a recommended amount, a recommended amount plus a range, or a range only.';
  }

  @override
  String recipeIngredientFallbackName(Object id) {
    return 'Ingredient #$id';
  }

  @override
  String get recipeSaveSuccess => 'Saved';

  @override
  String get recipeCostShare => 'Ingredient cost share';

  @override
  String get recipeUnknownIngredient => 'Unknown ingredient';

  @override
  String get recipeOther => 'Other';

  @override
  String get recipeCostTrend => 'Cost trend';

  @override
  String get recipeNoCostTrend => 'No cost trend data';

  @override
  String get recipeNoStackedCostTrend => 'No cost trend data';

  @override
  String get recipeWeek => 'Week';

  @override
  String get recipeMonth => 'Month';

  @override
  String get recipeQuarter => 'Quarter';

  @override
  String get recipeYear => 'Year';

  @override
  String get recipeAll => 'All';

  @override
  String get recipeAverageLabel => 'Average';

  @override
  String get recipeRangeLabel => 'Range';

  @override
  String get recipeTotalLabel => 'Total';

  @override
  String get recipeMerchantCostEstimate => 'Merchant cost estimates';

  @override
  String get recipeNoMerchantPriceData => 'No merchant price data';

  @override
  String get recipeBestValue => 'Best value';

  @override
  String recipeCoveredCount(Object covered, Object total) {
    return '$covered/$total ingredients covered';
  }

  @override
  String recipeInStore(Object amount) {
    return 'In store $amount';
  }

  @override
  String recipeExternal(Object amount) {
    return 'External $amount';
  }

  @override
  String recipeMissingIngredients(Object ingredients) {
    return 'Missing ingredients: $ingredients';
  }

  @override
  String recipeMerchantFallbackName(Object id) {
    return 'Merchant #$id';
  }

  @override
  String get recipeMerchantPriceRecommendation =>
      'Merchant price recommendations';

  @override
  String get recipeNoMerchantComparisonData => 'No merchant comparison data';

  @override
  String get recipeIngredientAndAmount => 'Ingredient / amount';

  @override
  String get recipeNutritionSources => 'Nutrition sources';

  @override
  String get recipeNrvMetrics => 'NRV metrics';

  @override
  String get recipeAllNutrients => 'All';

  @override
  String get recipeDisplayRange => 'Show scope';

  @override
  String get recipeSource => 'Source';

  @override
  String get recipeTags => 'Tags';

  @override
  String get recipeTotalTime => 'Total time';

  @override
  String get recipeImages => 'Images';

  @override
  String get recipeCalculatedFromIngredientsPrice =>
      'Calculated from ingredient prices:';

  @override
  String get nutritionNutrientCopper => 'Copper';

  @override
  String get nutritionNutrientManganese => 'Manganese';

  @override
  String get nutritionNutrientSelenium => 'Selenium';

  @override
  String get barcodeScannerTitle => 'Scan barcode';

  @override
  String get entityUnitsMaintain => 'Maintain';

  @override
  String get entityUnitsNoCustomUnits => 'No custom units';

  @override
  String get entityUnitsUnmappedTitle =>
      'Units to configure (from recipes, default 100 g)';

  @override
  String get entityUnitsSourceAuto => 'Auto';

  @override
  String get entityUnitsSourceManual => 'Manual';

  @override
  String get entityUnitsDensityInfo => 'Density information';

  @override
  String get entityUnitsNoDensityData => 'No density data';

  @override
  String get placeKindHome => 'Home';

  @override
  String get placeKindWork => 'Work';

  @override
  String get placeKindOther => 'Other';

  @override
  String get placeAdd => 'Add place';

  @override
  String get placeDeleteTitle => 'Delete place';

  @override
  String placeDeleteMessage(Object name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get placeAdded => 'Place added';

  @override
  String get placeSaved => 'Place saved';

  @override
  String get placeEmptyTitle => 'No saved places';

  @override
  String get placeEmptySubtitle =>
      'Tap + in the lower-right corner to add one (Home, Work, etc.)';

  @override
  String get placeMoreActions => 'More actions';

  @override
  String get placeSetDefault => 'Set as default';

  @override
  String placeSubtitle(Object kind, int radius, Object coordinates) {
    return '$kind · Range $radius km · $coordinates';
  }

  @override
  String get placeMapFeatureDisabled =>
      'Map features are disabled, so saved places cannot be maintained.';

  @override
  String get placeOperationFailedRetry => 'Operation failed. Try again.';

  @override
  String get placeSelectOnMapRequired => 'Select a location on the map';

  @override
  String get placeNameRequired => 'Enter a place name';

  @override
  String get userPlaceEditTitle => 'Edit place';

  @override
  String get userPlaceNameLabel => 'Name (for example: Home, Work)';

  @override
  String get userPlaceTypeLabel => 'Type';

  @override
  String get userPlaceRadiusLabel => 'Map view range (zoom when focused)';

  @override
  String get userPlaceAddressLabel => 'Address (optional)';

  @override
  String get userPlacePositionLabel => 'Location (tap the map to choose)';

  @override
  String get nutritionGoalsDescription =>
      'Set daily nutrition goals for meal recommendations.';

  @override
  String nutritionGoalEnergyLabel(Object unit) {
    return 'Daily calories ($unit)';
  }

  @override
  String get nutritionGoalProteinLabel => 'Protein (g)';

  @override
  String get nutritionGoalCarbLabel => 'Carbs (g)';

  @override
  String get nutritionGoalFatLabel => 'Fat (g)';

  @override
  String get nutritionGoalCalorieRange =>
      'Daily calories must be between 500 and 5000 kcal';

  @override
  String get nutritionGoalProteinRange =>
      'Protein must be between 10 and 300 g';

  @override
  String get nutritionGoalCarbRange => 'Carbs must be between 50 and 600 g';

  @override
  String get nutritionGoalFatRange => 'Fat must be between 10 and 200 g';

  @override
  String get unitPreferencesDescription =>
      'Set your default units; every page will display and fill amounts with them.';

  @override
  String get unitPreferencesEnergyUnit => 'Energy unit';

  @override
  String get unitPreferencesMassUnit => 'Default mass unit';

  @override
  String get unitPreferencesVolumeUnit => 'Default volume unit';

  @override
  String get unitPreferencesPriceUnit =>
      'Default pricing unit (including each / pack / bottle)';

  @override
  String get unitPreferencesKilocalories => 'Kilocalories (kcal)';

  @override
  String get unitPreferencesKilojoules => 'Kilojoules (kJ)';

  @override
  String get unitPreferencesMassHint => 'Grams (g)';

  @override
  String get unitPreferencesVolumeHint => 'Milliliters (ml)';

  @override
  String get unitPreferencesPriceHint => 'Each';

  @override
  String get unitPreferencesNone => 'Not set';

  @override
  String unitPreferencesAbbreviation(Object abbreviation) {
    return '($abbreviation)';
  }

  @override
  String get unitPreferencesLoadFailed =>
      'Could not load the unit list. Try again.';

  @override
  String get proposalStatusApproved => 'Applied';

  @override
  String get proposalStatusRejected => 'Rejected';

  @override
  String get proposalStatusPending => 'Pending';

  @override
  String get proposalTypeIngredient => 'Ingredient';

  @override
  String get proposalTypeNutrition => 'Nutrition';

  @override
  String get proposalTypeUnit => 'Unit';

  @override
  String get proposalTypeMerchant => 'Merchant';

  @override
  String get proposalTypeMerchantMerge => 'Merchant merge';

  @override
  String get proposalTypeProduct => 'Product';

  @override
  String get proposalTypeRecipe => 'Recipe';

  @override
  String get proposalTypeUsdaMatch => 'USDA match';

  @override
  String get proposalTypeUnknown => 'Unknown';

  @override
  String get proposalActionCreate => 'New';

  @override
  String get proposalActionUpdate => 'Modified';

  @override
  String get proposalActionMerge => 'Merge';

  @override
  String get proposalActionPublish => 'Publish';

  @override
  String get proposalActionUnknown => 'Unknown';

  @override
  String proposalDetailTitle(int id) {
    return 'Proposal #$id';
  }

  @override
  String proposalEntityId(Object id) {
    return 'Entity ID: $id';
  }

  @override
  String get proposalReviewComment => 'Review comment';

  @override
  String get proposalChanges => 'Changes';

  @override
  String get proposalNoDetails => 'No details';

  @override
  String get proposalValueNone => 'None';

  @override
  String get proposalEmptyTitle => 'No proposals';

  @override
  String get proposalEmptySubtitle =>
      'Your edits to shared data will appear here';
}
