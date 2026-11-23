import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_l10n_en.dart';
import 'app_l10n_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
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
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

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
    Locale('he'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'ZT Gallery'**
  String get appTitle;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @photosTab.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get photosTab;

  /// No description provided for @albumsTab.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get albumsTab;

  /// No description provided for @accountTab.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTab;

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

  /// No description provided for @photo.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get photo;

  /// No description provided for @video.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get video;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in or create an account'**
  String get signIn;

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 selected} other{{count} selected}}'**
  String selectedCount(int count);

  /// No description provided for @itemCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Empty} =1{1 item} other{{count} items}}'**
  String itemCount(int count);

  /// No description provided for @megabytes.
  ///
  /// In en, this message translates to:
  /// **'{amount} MB'**
  String megabytes(String amount);

  /// No description provided for @accessTitle.
  ///
  /// In en, this message translates to:
  /// **'See your photos here'**
  String get accessTitle;

  /// No description provided for @accessBody.
  ///
  /// In en, this message translates to:
  /// **'ZT Gallery shows the photos and videos on this phone. They stay on the phone: nothing is uploaded unless you choose to.'**
  String get accessBody;

  /// No description provided for @allowAccess.
  ///
  /// In en, this message translates to:
  /// **'Allow access'**
  String get allowAccess;

  /// No description provided for @somePhotosTitle.
  ///
  /// In en, this message translates to:
  /// **'Only some photos'**
  String get somePhotosTitle;

  /// No description provided for @somePhotosBody.
  ///
  /// In en, this message translates to:
  /// **'You let ZT Gallery see only the photos you picked.'**
  String get somePhotosBody;

  /// No description provided for @pickMore.
  ///
  /// In en, this message translates to:
  /// **'Pick more'**
  String get pickMore;

  /// No description provided for @noPhotos.
  ///
  /// In en, this message translates to:
  /// **'No photos or videos on this phone yet.'**
  String get noPhotos;

  /// No description provided for @photosCantLoad.
  ///
  /// In en, this message translates to:
  /// **'The photos couldn\'t be read. Try again in a moment.'**
  String get photosCantLoad;

  /// No description provided for @onThisPhone.
  ///
  /// In en, this message translates to:
  /// **'On this phone'**
  String get onThisPhone;

  /// No description provided for @inYourAccount.
  ///
  /// In en, this message translates to:
  /// **'In your account'**
  String get inYourAccount;

  /// No description provided for @inYourAccountEncrypted.
  ///
  /// In en, this message translates to:
  /// **'In your account, end-to-end encrypted'**
  String get inYourAccountEncrypted;

  /// No description provided for @untitledAlbum.
  ///
  /// In en, this message translates to:
  /// **'Untitled album'**
  String get untitledAlbum;

  /// No description provided for @detailName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get detailName;

  /// No description provided for @detailSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get detailSize;

  /// No description provided for @detailLength.
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get detailLength;

  /// No description provided for @detailFolder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get detailFolder;

  /// No description provided for @detailWhere.
  ///
  /// In en, this message translates to:
  /// **'Kept'**
  String get detailWhere;

  /// No description provided for @detailFileSize.
  ///
  /// In en, this message translates to:
  /// **'File size'**
  String get detailFileSize;

  /// No description provided for @detailCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get detailCopy;

  /// No description provided for @spaceSaverCopy.
  ///
  /// In en, this message translates to:
  /// **'Smaller copy (space saver)'**
  String get spaceSaverCopy;

  /// No description provided for @videoCantPlay.
  ///
  /// In en, this message translates to:
  /// **'This video can\'t be played.'**
  String get videoCantPlay;

  /// No description provided for @shareFailed.
  ///
  /// In en, this message translates to:
  /// **'Nothing could be shared.'**
  String get shareFailed;

  /// No description provided for @shareVideoTitle.
  ///
  /// In en, this message translates to:
  /// **'Share the video as it is?'**
  String get shareVideoTitle;

  /// No description provided for @shareVideoBody.
  ///
  /// In en, this message translates to:
  /// **'Photos are shared without where, when and on which phone they were taken. Videos are shared as they are, so they may still say where they were filmed.'**
  String get shareVideoBody;

  /// No description provided for @shareAnyway.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareAnyway;

  /// No description provided for @saveToPhone.
  ///
  /// In en, this message translates to:
  /// **'Save to phone'**
  String get saveToPhone;

  /// No description provided for @savedToPhone.
  ///
  /// In en, this message translates to:
  /// **'Saved to this phone (ZT Gallery folder).'**
  String get savedToPhone;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'It couldn\'t be saved to this phone.'**
  String get saveFailed;

  /// No description provided for @accountSignedOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Your encrypted photos'**
  String get accountSignedOutTitle;

  /// No description provided for @accountSignedOutBody.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your Zero-Trust account to see the photos you back up with ZT Camera. They are encrypted on your phone before they leave it: nobody else can see them, not even us.'**
  String get accountSignedOutBody;

  /// No description provided for @accountEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing in your account yet'**
  String get accountEmptyTitle;

  /// No description provided for @accountEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Photos you back up from ZT Camera\'s Private vault show here, on every phone you sign in on.'**
  String get accountEmptyBody;

  /// No description provided for @accountCantLoadTitle.
  ///
  /// In en, this message translates to:
  /// **'Your account\'s photos couldn\'t be read'**
  String get accountCantLoadTitle;

  /// No description provided for @accountCantLoadBody.
  ///
  /// In en, this message translates to:
  /// **'Check the connection and try again.'**
  String get accountCantLoadBody;

  /// No description provided for @photoAccess.
  ///
  /// In en, this message translates to:
  /// **'Photo access'**
  String get photoAccess;

  /// No description provided for @photoAccessAll.
  ///
  /// In en, this message translates to:
  /// **'All photos and videos'**
  String get photoAccessAll;

  /// No description provided for @photoAccessSome.
  ///
  /// In en, this message translates to:
  /// **'Only the photos you picked'**
  String get photoAccessSome;

  /// No description provided for @photoAccessNone.
  ///
  /// In en, this message translates to:
  /// **'Not allowed'**
  String get photoAccessNone;

  /// No description provided for @cleanShareTitle.
  ///
  /// In en, this message translates to:
  /// **'Clean sharing'**
  String get cleanShareTitle;

  /// No description provided for @cleanShareBody.
  ///
  /// In en, this message translates to:
  /// **'Photos you share leave without where, when and on which phone they were taken.'**
  String get cleanShareBody;

  /// No description provided for @sharingTab.
  ///
  /// In en, this message translates to:
  /// **'Sharing'**
  String get sharingTab;

  /// No description provided for @sharedSignedOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Shared albums'**
  String get sharedSignedOutTitle;

  /// No description provided for @sharedSignedOutBody.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your Zero-Trust account to share albums with family and friends. Shared albums are end-to-end encrypted: only the people in an album can see its photos, not even us.'**
  String get sharedSignedOutBody;

  /// No description provided for @sharedUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Shared albums can\'t be reached right now. Check the connection and try again.'**
  String get sharedUnavailable;

  /// No description provided for @sharedEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No shared albums yet'**
  String get sharedEmptyTitle;

  /// No description provided for @sharedEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Make an album and invite people with a link or a QR code. Everyone in it sees its photos and can add their own.'**
  String get sharedEmptyBody;

  /// No description provided for @newSharedAlbum.
  ///
  /// In en, this message translates to:
  /// **'New shared album'**
  String get newSharedAlbum;

  /// No description provided for @joinSharedAlbum.
  ///
  /// In en, this message translates to:
  /// **'Join with a link'**
  String get joinSharedAlbum;

  /// No description provided for @albumNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Name the album'**
  String get albumNameTitle;

  /// No description provided for @albumNameHint.
  ///
  /// In en, this message translates to:
  /// **'Album name'**
  String get albumNameHint;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @people.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get people;

  /// No description provided for @addPhotos.
  ///
  /// In en, this message translates to:
  /// **'Add photos'**
  String get addPhotos;

  /// No description provided for @fromThisPhone.
  ///
  /// In en, this message translates to:
  /// **'From this phone'**
  String get fromThisPhone;

  /// No description provided for @fromYourAccount.
  ///
  /// In en, this message translates to:
  /// **'From your account'**
  String get fromYourAccount;

  /// No description provided for @addSelected.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Add} other{Add {count}}}'**
  String addSelected(int count);

  /// No description provided for @addingPhotos.
  ///
  /// In en, this message translates to:
  /// **'Adding {done} of {total}…'**
  String addingPhotos(int done, int total);

  /// No description provided for @photosAdded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 added to the album} other{{count} added to the album}}'**
  String photosAdded(int count);

  /// No description provided for @someNotAdded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 couldn\'t be added. Try it again.} other{{count} couldn\'t be added. Try them again.}}'**
  String someNotAdded(int count);

  /// No description provided for @addVideoTitle.
  ///
  /// In en, this message translates to:
  /// **'Add the video as it is?'**
  String get addVideoTitle;

  /// No description provided for @addVideoBody.
  ///
  /// In en, this message translates to:
  /// **'Photos are added without where, when and on which phone they were taken. Videos are added as they are, so they may still say where they were filmed.'**
  String get addVideoBody;

  /// No description provided for @addAnyway.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addAnyway;

  /// No description provided for @waitingTitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting to be let in'**
  String get waitingTitle;

  /// No description provided for @waitingBody.
  ///
  /// In en, this message translates to:
  /// **'Ask the person who invited you to let you in. First compare this code with the one on their phone:'**
  String get waitingBody;

  /// No description provided for @stopWaiting.
  ///
  /// In en, this message translates to:
  /// **'Stop waiting'**
  String get stopWaiting;

  /// No description provided for @albumEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get albumEmptyTitle;

  /// No description provided for @albumEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add photos from this phone or your account, and invite people to add theirs.'**
  String get albumEmptyBody;

  /// No description provided for @invitePeople.
  ///
  /// In en, this message translates to:
  /// **'Invite people'**
  String get invitePeople;

  /// No description provided for @sharedAlbumDescription.
  ///
  /// In en, this message translates to:
  /// **'Everyone in this album sees all its photos and can add their own. Only whoever added a photo can remove it. When someone leaves, what they added leaves with them.'**
  String get sharedAlbumDescription;

  /// No description provided for @memberCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 person} other{{count} people}}'**
  String memberCount(int count);

  /// No description provided for @detailAddedBy.
  ///
  /// In en, this message translates to:
  /// **'Added by'**
  String get detailAddedBy;

  /// No description provided for @detailAdded.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get detailAdded;

  /// No description provided for @inSharedAlbumEncrypted.
  ///
  /// In en, this message translates to:
  /// **'In a shared album, end-to-end encrypted'**
  String get inSharedAlbumEncrypted;

  /// No description provided for @removeFromAlbum.
  ///
  /// In en, this message translates to:
  /// **'Remove from album'**
  String get removeFromAlbum;

  /// No description provided for @removePhotoTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove it from the album?'**
  String get removePhotoTitle;

  /// No description provided for @removePhotoBody.
  ///
  /// In en, this message translates to:
  /// **'It is removed for everyone in the album. A copy on your phone or in your account stays.'**
  String get removePhotoBody;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @removedFromAlbum.
  ///
  /// In en, this message translates to:
  /// **'Removed from the album.'**
  String get removedFromAlbum;

  /// No description provided for @chooseSharedAlbum.
  ///
  /// In en, this message translates to:
  /// **'Add to a shared album'**
  String get chooseSharedAlbum;

  /// No description provided for @addToSharedAlbum.
  ///
  /// In en, this message translates to:
  /// **'Add to shared album'**
  String get addToSharedAlbum;

  /// No description provided for @signInToShare.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your Zero-Trust account to share albums.'**
  String get signInToShare;

  /// No description provided for @someone.
  ///
  /// In en, this message translates to:
  /// **'Someone'**
  String get someone;

  /// No description provided for @nothingToPick.
  ///
  /// In en, this message translates to:
  /// **'Nothing to pick here.'**
  String get nothingToPick;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppL10nEn();
    case 'he':
      return AppL10nHe();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
