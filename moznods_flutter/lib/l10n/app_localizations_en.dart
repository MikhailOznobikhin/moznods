// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'MOznoDS';

  @override
  String get welcomeToMoznods => 'Welcome to MOznoDS';

  @override
  String get signInToContinue => 'Sign in to continue';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get email => 'Email';

  @override
  String get displayName => 'Display name';

  @override
  String get rememberMe => 'Remember me';

  @override
  String get signIn => 'Sign In';

  @override
  String get register => 'Register';

  @override
  String get createAccount => 'Create Account';

  @override
  String get joinMoznodsToday => 'Join MOznoDS today';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get noAccount => 'Don\'t have an account?';

  @override
  String get enterUsername => 'Please enter your username';

  @override
  String get usernameMinLength => 'Username must be at least 3 characters';

  @override
  String get enterPassword => 'Please enter your password';

  @override
  String get passwordMinLength6 => 'Password must be at least 6 characters';

  @override
  String get passwordMinLength8 => 'Password must be at least 8 characters';

  @override
  String get enterEmail => 'Please enter an email';

  @override
  String get enterValidEmail => 'Please enter a valid email';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get registrationSuccess => 'Registration successful! Please login.';

  @override
  String get registrationFailed => 'Registration failed. Please try again.';

  @override
  String get invalidCredentials => 'Invalid username or password';

  @override
  String get fixHighlightedFields =>
      'Please fix the highlighted fields and try again.';

  @override
  String get unexpectedError => 'An unexpected error occurred.';

  @override
  String get downloadAndroidApp => 'Download the Android app';

  @override
  String get profile => 'Profile';

  @override
  String get settings => 'Settings';

  @override
  String get logout => 'Logout';

  @override
  String get discover => 'Discover';

  @override
  String get downloadApk => 'Download APK';

  @override
  String get online => 'Online';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get sendMessage => 'Send Message';

  @override
  String get displayNameEmpty => 'Display name cannot be empty';

  @override
  String get displayNameTooLong => 'Display name is too long';

  @override
  String get save => 'Save';

  @override
  String get profileUpdated => 'Profile updated';

  @override
  String get updateFailed => 'Update failed';

  @override
  String get selectChannelToStart => 'Select a channel to start chatting';

  @override
  String get youCanPostInChannel => 'You can post in this channel';

  @override
  String get onlyAdminsCanPost => 'Only admins can post in this channel';

  @override
  String get noMessagesYet => 'No messages yet';

  @override
  String get beTheFirstToSay => 'Be the first to say something!';

  @override
  String get replyingTo => 'Replying to';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get participants => 'Participants';

  @override
  String participantsWithCount(int count) {
    return 'Participants — $count';
  }

  @override
  String get bannedUsers => 'Banned users';

  @override
  String get bans => 'Bans';

  @override
  String get noBans => 'No bans';

  @override
  String get noReason => 'No reason';

  @override
  String get admin => 'Admin';

  @override
  String get member => 'Member';

  @override
  String get makeAdmin => 'Make admin';

  @override
  String get makeMember => 'Make member';

  @override
  String get banUser => 'Ban user';

  @override
  String get removeFromRoom => 'Remove from room';

  @override
  String get addReaction => 'Add reaction';

  @override
  String get reply => 'Reply';

  @override
  String get delete => 'Delete';

  @override
  String get attachFile => 'Attach file';

  @override
  String get emojiTooltip => 'Emoji';

  @override
  String get sendTooltip => 'Send';

  @override
  String messageHint(String room) {
    return 'Message #$room';
  }

  @override
  String get couldNotReadFile => 'Could not read selected file';

  @override
  String get failedToUpload => 'Failed to upload file';

  @override
  String get attachImage => 'Image';

  @override
  String get attachFileItem => 'File';

  @override
  String get codeSnippet => 'Code snippet';

  @override
  String get quickEmoji => 'Quick emoji';

  @override
  String get disconnectedReconnecting => 'Disconnected. Reconnecting...';

  @override
  String get searchPublicRooms => 'Search public rooms';

  @override
  String get noPublicRoomsFound => 'No public rooms found';

  @override
  String get filterAll => 'All';

  @override
  String get filterRooms => 'Rooms';

  @override
  String get filterChannels => 'Channels';

  @override
  String get join => 'Join';

  @override
  String get notifications => 'Notifications';

  @override
  String get pushNotifications => 'Push Notifications';

  @override
  String get pushNotificationsDesc =>
      'Receive push notifications for new messages';

  @override
  String get sound => 'Sound';

  @override
  String get soundDesc => 'Play sound for notifications';

  @override
  String get vibration => 'Vibration';

  @override
  String get vibrationDesc => 'Vibrate for notifications';

  @override
  String get appearance => 'Appearance';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get darkModeDesc => 'Use dark theme';

  @override
  String get audio => 'Audio';

  @override
  String get masterVolume => 'Master Volume';

  @override
  String get account => 'Account';

  @override
  String get changePassword => 'Change Password';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get logoutConfirm => 'Are you sure you want to logout?';

  @override
  String get cancel => 'Cancel';

  @override
  String get language => 'Language';

  @override
  String get russianLanguage => 'Russian';

  @override
  String get englishLanguage => 'English';

  @override
  String get createRoom => 'Create Room';

  @override
  String get roomName => 'Room name';

  @override
  String get roomNameRequired => 'Room name is required';

  @override
  String get roomNameMinLength => 'Room name must be at least 2 characters';

  @override
  String get publicRoom => 'Public room';

  @override
  String get channelMode => 'Channel mode (admins post only)';

  @override
  String get publicUsernameHint => 'Public username (without @)';

  @override
  String get publicUsernameRequired => 'Username is required for public rooms';

  @override
  String get create => 'Create';

  @override
  String get addMembers => 'Add Members';

  @override
  String get search => 'Search';

  @override
  String get noResults => 'No results';

  @override
  String get searchUsersHint => 'Search users...';

  @override
  String get noUsersFound => 'No users found';

  @override
  String get startTypingToSearch => 'Start typing to search';

  @override
  String membersCount(int count) {
    return '$count members';
  }

  @override
  String get voiceChannel => 'Voice Channel';

  @override
  String get connectedLabel => 'Connected';

  @override
  String get muteAction => 'Mute';

  @override
  String get unmuteAction => 'Unmute';

  @override
  String get startVideo => 'Start Video';

  @override
  String get stopVideo => 'Stop Video';

  @override
  String get leaveCall => 'Leave';

  @override
  String get chatLabel => 'Chat';

  @override
  String get inviteLabel => 'Invite';

  @override
  String get activeCall => 'Active Call';

  @override
  String get youLabel => 'You';

  @override
  String userPlaceholder(int id) {
    return 'User $id';
  }

  @override
  String get noActiveVideoStreams => 'No active video streams';

  @override
  String get connecting => 'Connecting...';

  @override
  String get disconnectedLabel => 'Disconnected';

  @override
  String get downloadTitle => 'Download MOznoDS';

  @override
  String get downloadDescription =>
      'Get the Android app to use MOznoDS on your phone. Web version works in any browser.';

  @override
  String get downloadApkAction => 'Download APK';

  @override
  String get apkUnavailable =>
      'APK is not available right now. Please come back later.';

  @override
  String get versionLabel => 'Version';

  @override
  String get sizeLabel => 'Size';

  @override
  String get updatedLabel => 'Updated';

  @override
  String get backToLogin => 'Back to login';

  @override
  String get openInBrowser => 'Open the web version';

  @override
  String get installInstructionsTitle => 'Installation';

  @override
  String get installInstructions =>
      'After downloading, allow installation from unknown sources in Android settings, then open the file to install.';

  @override
  String get appVersion => 'MOznoDS v1.0.0';
}
