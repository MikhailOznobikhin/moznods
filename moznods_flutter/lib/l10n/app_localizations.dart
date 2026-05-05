import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'MOznoDS'**
  String get appTitle;

  /// No description provided for @welcomeToMoznods.
  ///
  /// In en, this message translates to:
  /// **'Welcome to MOznoDS'**
  String get welcomeToMoznods;

  /// No description provided for @signInToContinue.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get signInToContinue;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayName;

  /// No description provided for @rememberMe.
  ///
  /// In en, this message translates to:
  /// **'Remember me'**
  String get rememberMe;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @joinMoznodsToday.
  ///
  /// In en, this message translates to:
  /// **'Join MOznoDS today'**
  String get joinMoznodsToday;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @noAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get noAccount;

  /// No description provided for @enterUsername.
  ///
  /// In en, this message translates to:
  /// **'Please enter your username'**
  String get enterUsername;

  /// No description provided for @usernameMinLength.
  ///
  /// In en, this message translates to:
  /// **'Username must be at least 3 characters'**
  String get usernameMinLength;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get enterPassword;

  /// No description provided for @passwordMinLength6.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordMinLength6;

  /// No description provided for @passwordMinLength8.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get passwordMinLength8;

  /// No description provided for @enterEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter an email'**
  String get enterEmail;

  /// No description provided for @enterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get enterValidEmail;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @registrationSuccess.
  ///
  /// In en, this message translates to:
  /// **'Registration successful! Please login.'**
  String get registrationSuccess;

  /// No description provided for @registrationFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed. Please try again.'**
  String get registrationFailed;

  /// No description provided for @invalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid username or password'**
  String get invalidCredentials;

  /// No description provided for @fixHighlightedFields.
  ///
  /// In en, this message translates to:
  /// **'Please fix the highlighted fields and try again.'**
  String get fixHighlightedFields;

  /// No description provided for @unexpectedError.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred.'**
  String get unexpectedError;

  /// No description provided for @downloadAndroidApp.
  ///
  /// In en, this message translates to:
  /// **'Download the Android app'**
  String get downloadAndroidApp;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @discover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get discover;

  /// No description provided for @downloadApk.
  ///
  /// In en, this message translates to:
  /// **'Download APK'**
  String get downloadApk;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @sendMessage.
  ///
  /// In en, this message translates to:
  /// **'Send Message'**
  String get sendMessage;

  /// No description provided for @displayNameEmpty.
  ///
  /// In en, this message translates to:
  /// **'Display name cannot be empty'**
  String get displayNameEmpty;

  /// No description provided for @displayNameTooLong.
  ///
  /// In en, this message translates to:
  /// **'Display name is too long'**
  String get displayNameTooLong;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get profileUpdated;

  /// No description provided for @updateFailed.
  ///
  /// In en, this message translates to:
  /// **'Update failed'**
  String get updateFailed;

  /// No description provided for @selectChannelToStart.
  ///
  /// In en, this message translates to:
  /// **'Select a channel to start chatting'**
  String get selectChannelToStart;

  /// No description provided for @youCanPostInChannel.
  ///
  /// In en, this message translates to:
  /// **'You can post in this channel'**
  String get youCanPostInChannel;

  /// No description provided for @onlyAdminsCanPost.
  ///
  /// In en, this message translates to:
  /// **'Only admins can post in this channel'**
  String get onlyAdminsCanPost;

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesYet;

  /// No description provided for @beTheFirstToSay.
  ///
  /// In en, this message translates to:
  /// **'Be the first to say something!'**
  String get beTheFirstToSay;

  /// No description provided for @replyingTo.
  ///
  /// In en, this message translates to:
  /// **'Replying to'**
  String get replyingTo;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @participants.
  ///
  /// In en, this message translates to:
  /// **'Participants'**
  String get participants;

  /// No description provided for @participantsWithCount.
  ///
  /// In en, this message translates to:
  /// **'Participants — {count}'**
  String participantsWithCount(int count);

  /// No description provided for @bannedUsers.
  ///
  /// In en, this message translates to:
  /// **'Banned users'**
  String get bannedUsers;

  /// No description provided for @bans.
  ///
  /// In en, this message translates to:
  /// **'Bans'**
  String get bans;

  /// No description provided for @noBans.
  ///
  /// In en, this message translates to:
  /// **'No bans'**
  String get noBans;

  /// No description provided for @noReason.
  ///
  /// In en, this message translates to:
  /// **'No reason'**
  String get noReason;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @member.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get member;

  /// No description provided for @makeAdmin.
  ///
  /// In en, this message translates to:
  /// **'Make admin'**
  String get makeAdmin;

  /// No description provided for @makeMember.
  ///
  /// In en, this message translates to:
  /// **'Make member'**
  String get makeMember;

  /// No description provided for @banUser.
  ///
  /// In en, this message translates to:
  /// **'Ban user'**
  String get banUser;

  /// No description provided for @removeFromRoom.
  ///
  /// In en, this message translates to:
  /// **'Remove from room'**
  String get removeFromRoom;

  /// No description provided for @addReaction.
  ///
  /// In en, this message translates to:
  /// **'Add reaction'**
  String get addReaction;

  /// No description provided for @reply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get reply;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @attachFile.
  ///
  /// In en, this message translates to:
  /// **'Attach file'**
  String get attachFile;

  /// No description provided for @emojiTooltip.
  ///
  /// In en, this message translates to:
  /// **'Emoji'**
  String get emojiTooltip;

  /// No description provided for @sendTooltip.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get sendTooltip;

  /// No description provided for @messageHint.
  ///
  /// In en, this message translates to:
  /// **'Message #{room}'**
  String messageHint(String room);

  /// No description provided for @couldNotReadFile.
  ///
  /// In en, this message translates to:
  /// **'Could not read selected file'**
  String get couldNotReadFile;

  /// No description provided for @failedToUpload.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload file'**
  String get failedToUpload;

  /// No description provided for @attachImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get attachImage;

  /// No description provided for @attachFileItem.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get attachFileItem;

  /// No description provided for @codeSnippet.
  ///
  /// In en, this message translates to:
  /// **'Code snippet'**
  String get codeSnippet;

  /// No description provided for @quickEmoji.
  ///
  /// In en, this message translates to:
  /// **'Quick emoji'**
  String get quickEmoji;

  /// No description provided for @disconnectedReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Disconnected. Reconnecting...'**
  String get disconnectedReconnecting;

  /// No description provided for @searchPublicRooms.
  ///
  /// In en, this message translates to:
  /// **'Search public rooms'**
  String get searchPublicRooms;

  /// No description provided for @noPublicRoomsFound.
  ///
  /// In en, this message translates to:
  /// **'No public rooms found'**
  String get noPublicRoomsFound;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterRooms.
  ///
  /// In en, this message translates to:
  /// **'Rooms'**
  String get filterRooms;

  /// No description provided for @filterChannels.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get filterChannels;

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @pushNotifications.
  ///
  /// In en, this message translates to:
  /// **'Push Notifications'**
  String get pushNotifications;

  /// No description provided for @pushNotificationsDesc.
  ///
  /// In en, this message translates to:
  /// **'Receive push notifications for new messages'**
  String get pushNotificationsDesc;

  /// No description provided for @sound.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get sound;

  /// No description provided for @soundDesc.
  ///
  /// In en, this message translates to:
  /// **'Play sound for notifications'**
  String get soundDesc;

  /// No description provided for @vibration.
  ///
  /// In en, this message translates to:
  /// **'Vibration'**
  String get vibration;

  /// No description provided for @vibrationDesc.
  ///
  /// In en, this message translates to:
  /// **'Vibrate for notifications'**
  String get vibrationDesc;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @darkModeDesc.
  ///
  /// In en, this message translates to:
  /// **'Use dark theme'**
  String get darkModeDesc;

  /// No description provided for @audio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get audio;

  /// No description provided for @masterVolume.
  ///
  /// In en, this message translates to:
  /// **'Master Volume'**
  String get masterVolume;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @logoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get logoutConfirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @russianLanguage.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get russianLanguage;

  /// No description provided for @englishLanguage.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get englishLanguage;

  /// No description provided for @createRoom.
  ///
  /// In en, this message translates to:
  /// **'Create Room'**
  String get createRoom;

  /// No description provided for @roomName.
  ///
  /// In en, this message translates to:
  /// **'Room name'**
  String get roomName;

  /// No description provided for @roomNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Room name is required'**
  String get roomNameRequired;

  /// No description provided for @roomNameMinLength.
  ///
  /// In en, this message translates to:
  /// **'Room name must be at least 2 characters'**
  String get roomNameMinLength;

  /// No description provided for @publicRoom.
  ///
  /// In en, this message translates to:
  /// **'Public room'**
  String get publicRoom;

  /// No description provided for @channelMode.
  ///
  /// In en, this message translates to:
  /// **'Channel mode (admins post only)'**
  String get channelMode;

  /// No description provided for @publicUsernameHint.
  ///
  /// In en, this message translates to:
  /// **'Public username (without @)'**
  String get publicUsernameHint;

  /// No description provided for @publicUsernameRequired.
  ///
  /// In en, this message translates to:
  /// **'Username is required for public rooms'**
  String get publicUsernameRequired;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @addMembers.
  ///
  /// In en, this message translates to:
  /// **'Add Members'**
  String get addMembers;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get noResults;

  /// No description provided for @searchUsersHint.
  ///
  /// In en, this message translates to:
  /// **'Search users...'**
  String get searchUsersHint;

  /// No description provided for @noUsersFound.
  ///
  /// In en, this message translates to:
  /// **'No users found'**
  String get noUsersFound;

  /// No description provided for @startTypingToSearch.
  ///
  /// In en, this message translates to:
  /// **'Start typing to search'**
  String get startTypingToSearch;

  /// No description provided for @membersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} members'**
  String membersCount(int count);

  /// No description provided for @voiceChannel.
  ///
  /// In en, this message translates to:
  /// **'Voice Channel'**
  String get voiceChannel;

  /// No description provided for @connectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connectedLabel;

  /// No description provided for @muteAction.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get muteAction;

  /// No description provided for @unmuteAction.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get unmuteAction;

  /// No description provided for @startVideo.
  ///
  /// In en, this message translates to:
  /// **'Start Video'**
  String get startVideo;

  /// No description provided for @stopVideo.
  ///
  /// In en, this message translates to:
  /// **'Stop Video'**
  String get stopVideo;

  /// No description provided for @leaveCall.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leaveCall;

  /// No description provided for @chatLabel.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatLabel;

  /// No description provided for @inviteLabel.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get inviteLabel;

  /// No description provided for @activeCall.
  ///
  /// In en, this message translates to:
  /// **'Active Call'**
  String get activeCall;

  /// No description provided for @youLabel.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get youLabel;

  /// No description provided for @userPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'User {id}'**
  String userPlaceholder(int id);

  /// No description provided for @noActiveVideoStreams.
  ///
  /// In en, this message translates to:
  /// **'No active video streams'**
  String get noActiveVideoStreams;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get connecting;

  /// No description provided for @disconnectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get disconnectedLabel;

  /// No description provided for @downloadTitle.
  ///
  /// In en, this message translates to:
  /// **'Download MOznoDS'**
  String get downloadTitle;

  /// No description provided for @downloadDescription.
  ///
  /// In en, this message translates to:
  /// **'Get the Android app to use MOznoDS on your phone. Web version works in any browser.'**
  String get downloadDescription;

  /// No description provided for @downloadApkAction.
  ///
  /// In en, this message translates to:
  /// **'Download APK'**
  String get downloadApkAction;

  /// No description provided for @apkUnavailable.
  ///
  /// In en, this message translates to:
  /// **'APK is not available right now. Please come back later.'**
  String get apkUnavailable;

  /// No description provided for @versionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get versionLabel;

  /// No description provided for @sizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get sizeLabel;

  /// No description provided for @updatedLabel.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get updatedLabel;

  /// No description provided for @backToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to login'**
  String get backToLogin;

  /// No description provided for @openInBrowser.
  ///
  /// In en, this message translates to:
  /// **'Open the web version'**
  String get openInBrowser;

  /// No description provided for @installInstructionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Installation'**
  String get installInstructionsTitle;

  /// No description provided for @installInstructions.
  ///
  /// In en, this message translates to:
  /// **'After downloading, allow installation from unknown sources in Android settings, then open the file to install.'**
  String get installInstructions;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'MOznoDS v1.0.0'**
  String get appVersion;
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
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
