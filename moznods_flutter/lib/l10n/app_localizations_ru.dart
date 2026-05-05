// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'MOznoDS';

  @override
  String get welcomeToMoznods => 'Добро пожаловать в MOznoDS';

  @override
  String get signInToContinue => 'Войдите, чтобы продолжить';

  @override
  String get username => 'Имя пользователя';

  @override
  String get password => 'Пароль';

  @override
  String get email => 'Email';

  @override
  String get displayName => 'Отображаемое имя';

  @override
  String get rememberMe => 'Запомнить меня';

  @override
  String get signIn => 'Войти';

  @override
  String get register => 'Регистрация';

  @override
  String get createAccount => 'Создать аккаунт';

  @override
  String get joinMoznodsToday => 'Присоединяйтесь к MOznoDS';

  @override
  String get confirmPassword => 'Подтвердите пароль';

  @override
  String get alreadyHaveAccount => 'Уже есть аккаунт?';

  @override
  String get noAccount => 'Нет аккаунта?';

  @override
  String get enterUsername => 'Введите имя пользователя';

  @override
  String get usernameMinLength =>
      'Имя пользователя должно быть не короче 3 символов';

  @override
  String get enterPassword => 'Введите пароль';

  @override
  String get passwordMinLength6 => 'Пароль должен быть не короче 6 символов';

  @override
  String get passwordMinLength8 => 'Пароль должен быть не короче 8 символов';

  @override
  String get enterEmail => 'Введите email';

  @override
  String get enterValidEmail => 'Введите корректный email';

  @override
  String get passwordsDoNotMatch => 'Пароли не совпадают';

  @override
  String get registrationSuccess =>
      'Регистрация прошла успешно! Войдите в аккаунт.';

  @override
  String get registrationFailed =>
      'Не удалось зарегистрироваться. Попробуйте ещё раз.';

  @override
  String get invalidCredentials => 'Неверное имя пользователя или пароль';

  @override
  String get fixHighlightedFields =>
      'Исправьте подсвеченные поля и попробуйте снова.';

  @override
  String get unexpectedError => 'Произошла непредвиденная ошибка.';

  @override
  String get downloadAndroidApp => 'Скачать приложение для Android';

  @override
  String get profile => 'Профиль';

  @override
  String get settings => 'Настройки';

  @override
  String get logout => 'Выйти';

  @override
  String get discover => 'Каталог';

  @override
  String get downloadApk => 'Скачать APK';

  @override
  String get online => 'В сети';

  @override
  String get editProfile => 'Редактировать профиль';

  @override
  String get sendMessage => 'Написать сообщение';

  @override
  String get displayNameEmpty => 'Имя не может быть пустым';

  @override
  String get displayNameTooLong => 'Имя слишком длинное';

  @override
  String get save => 'Сохранить';

  @override
  String get profileUpdated => 'Профиль обновлён';

  @override
  String get updateFailed => 'Не удалось обновить профиль';

  @override
  String get selectChannelToStart => 'Выберите канал, чтобы начать общение';

  @override
  String get youCanPostInChannel => 'Вы можете писать в этот канал';

  @override
  String get onlyAdminsCanPost =>
      'В этот канал могут писать только администраторы';

  @override
  String get noMessagesYet => 'Сообщений пока нет';

  @override
  String get beTheFirstToSay => 'Будьте первым, кто что-то скажет!';

  @override
  String get replyingTo => 'Ответ на';

  @override
  String get today => 'Сегодня';

  @override
  String get yesterday => 'Вчера';

  @override
  String get participants => 'Участники';

  @override
  String participantsWithCount(int count) {
    return 'Участники — $count';
  }

  @override
  String get bannedUsers => 'Заблокированные';

  @override
  String get bans => 'Блокировки';

  @override
  String get noBans => 'Никто не заблокирован';

  @override
  String get noReason => 'Без причины';

  @override
  String get admin => 'Админ';

  @override
  String get member => 'Участник';

  @override
  String get makeAdmin => 'Назначить админом';

  @override
  String get makeMember => 'Снять права админа';

  @override
  String get banUser => 'Заблокировать';

  @override
  String get removeFromRoom => 'Удалить из комнаты';

  @override
  String get addReaction => 'Добавить реакцию';

  @override
  String get reply => 'Ответить';

  @override
  String get delete => 'Удалить';

  @override
  String get attachFile => 'Прикрепить файл';

  @override
  String get emojiTooltip => 'Эмодзи';

  @override
  String get sendTooltip => 'Отправить';

  @override
  String messageHint(String room) {
    return 'Сообщение в #$room';
  }

  @override
  String get couldNotReadFile => 'Не удалось прочитать выбранный файл';

  @override
  String get failedToUpload => 'Не удалось загрузить файл';

  @override
  String get attachImage => 'Изображение';

  @override
  String get attachFileItem => 'Файл';

  @override
  String get codeSnippet => 'Фрагмент кода';

  @override
  String get quickEmoji => 'Быстрые эмодзи';

  @override
  String get disconnectedReconnecting =>
      'Соединение потеряно. Переподключение...';

  @override
  String get searchPublicRooms => 'Поиск публичных комнат';

  @override
  String get noPublicRoomsFound => 'Публичные комнаты не найдены';

  @override
  String get filterAll => 'Все';

  @override
  String get filterRooms => 'Комнаты';

  @override
  String get filterChannels => 'Каналы';

  @override
  String get join => 'Войти';

  @override
  String get notifications => 'Уведомления';

  @override
  String get pushNotifications => 'Push-уведомления';

  @override
  String get pushNotificationsDesc =>
      'Получать push-уведомления о новых сообщениях';

  @override
  String get sound => 'Звук';

  @override
  String get soundDesc => 'Воспроизводить звук уведомлений';

  @override
  String get vibration => 'Вибрация';

  @override
  String get vibrationDesc => 'Вибрировать при уведомлениях';

  @override
  String get appearance => 'Оформление';

  @override
  String get darkMode => 'Тёмная тема';

  @override
  String get darkModeDesc => 'Использовать тёмную тему';

  @override
  String get audio => 'Звук';

  @override
  String get masterVolume => 'Общая громкость';

  @override
  String get account => 'Аккаунт';

  @override
  String get changePassword => 'Сменить пароль';

  @override
  String get privacyPolicy => 'Политика конфиденциальности';

  @override
  String get termsOfService => 'Условия использования';

  @override
  String get logoutConfirm => 'Вы действительно хотите выйти?';

  @override
  String get cancel => 'Отмена';

  @override
  String get language => 'Язык';

  @override
  String get russianLanguage => 'Русский';

  @override
  String get englishLanguage => 'English';

  @override
  String get createRoom => 'Создать комнату';

  @override
  String get roomName => 'Название комнаты';

  @override
  String get roomNameRequired => 'Введите название комнаты';

  @override
  String get roomNameMinLength => 'Название должно быть не короче 2 символов';

  @override
  String get publicRoom => 'Публичная комната';

  @override
  String get channelMode => 'Режим канала (пишут только админы)';

  @override
  String get publicUsernameHint => 'Публичный username (без @)';

  @override
  String get publicUsernameRequired => 'Для публичных комнат нужен username';

  @override
  String get create => 'Создать';

  @override
  String get addMembers => 'Добавить участников';

  @override
  String get search => 'Поиск';

  @override
  String get noResults => 'Ничего не найдено';

  @override
  String get searchUsersHint => 'Поиск пользователей...';

  @override
  String get noUsersFound => 'Пользователи не найдены';

  @override
  String get startTypingToSearch => 'Начните вводить запрос';

  @override
  String membersCount(int count) {
    return '$count участн.';
  }

  @override
  String get voiceChannel => 'Голосовой канал';

  @override
  String get connectedLabel => 'Подключено';

  @override
  String get muteAction => 'Выключить микрофон';

  @override
  String get unmuteAction => 'Включить микрофон';

  @override
  String get startVideo => 'Включить видео';

  @override
  String get stopVideo => 'Выключить видео';

  @override
  String get leaveCall => 'Выйти';

  @override
  String get chatLabel => 'Чат';

  @override
  String get inviteLabel => 'Пригласить';

  @override
  String get activeCall => 'Активный звонок';

  @override
  String get youLabel => 'Вы';

  @override
  String userPlaceholder(int id) {
    return 'Участник $id';
  }

  @override
  String get noActiveVideoStreams => 'Нет активных видеопотоков';

  @override
  String get connecting => 'Подключение...';

  @override
  String get disconnectedLabel => 'Соединение разорвано';

  @override
  String get downloadTitle => 'Скачать MOznoDS';

  @override
  String get downloadDescription =>
      'Установите Android-приложение, чтобы пользоваться MOznoDS со смартфона. Веб-версия работает в любом браузере.';

  @override
  String get downloadApkAction => 'Скачать APK';

  @override
  String get apkUnavailable => 'APK сейчас недоступен. Попробуйте позже.';

  @override
  String get versionLabel => 'Версия';

  @override
  String get sizeLabel => 'Размер';

  @override
  String get updatedLabel => 'Обновлено';

  @override
  String get backToLogin => 'Вернуться ко входу';

  @override
  String get openInBrowser => 'Открыть веб-версию';

  @override
  String get installInstructionsTitle => 'Установка';

  @override
  String get installInstructions =>
      'После загрузки разрешите установку из неизвестных источников в настройках Android и откройте файл, чтобы установить.';

  @override
  String get appVersion => 'MOznoDS v1.0.0';
}
