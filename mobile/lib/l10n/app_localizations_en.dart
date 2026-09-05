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
}
