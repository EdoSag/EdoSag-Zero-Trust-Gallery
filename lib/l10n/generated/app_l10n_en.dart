// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'ZT Gallery';

  @override
  String get settings => 'Settings';

  @override
  String get photosTab => 'Photos';

  @override
  String get albumsTab => 'Albums';

  @override
  String get accountTab => 'Account';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get photo => 'Photo';

  @override
  String get video => 'Video';

  @override
  String get share => 'Share';

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get details => 'Details';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get signIn => 'Sign in or create an account';

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
    );
    return '$_temp0';
  }

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
      zero: 'Empty',
    );
    return '$_temp0';
  }

  @override
  String megabytes(String amount) {
    return '$amount MB';
  }

  @override
  String get accessTitle => 'See your photos here';

  @override
  String get accessBody =>
      'ZT Gallery shows the photos and videos on this phone. They stay on the phone: nothing is uploaded unless you choose to.';

  @override
  String get allowAccess => 'Allow access';

  @override
  String get somePhotosTitle => 'Only some photos';

  @override
  String get somePhotosBody =>
      'You let ZT Gallery see only the photos you picked.';

  @override
  String get pickMore => 'Pick more';

  @override
  String get noPhotos => 'No photos or videos on this phone yet.';

  @override
  String get photosCantLoad =>
      'The photos couldn\'t be read. Try again in a moment.';

  @override
  String get onThisPhone => 'On this phone';

  @override
  String get inYourAccount => 'In your account';

  @override
  String get inYourAccountEncrypted => 'In your account, end-to-end encrypted';

  @override
  String get untitledAlbum => 'Untitled album';

  @override
  String get detailName => 'Name';

  @override
  String get detailSize => 'Size';

  @override
  String get detailLength => 'Length';

  @override
  String get detailFolder => 'Folder';

  @override
  String get detailWhere => 'Kept';

  @override
  String get detailFileSize => 'File size';

  @override
  String get detailCopy => 'Copy';

  @override
  String get spaceSaverCopy => 'Smaller copy (space saver)';

  @override
  String get videoCantPlay => 'This video can\'t be played.';

  @override
  String get shareFailed => 'Nothing could be shared.';

  @override
  String get shareVideoTitle => 'Share the video as it is?';

  @override
  String get shareVideoBody =>
      'Photos are shared without where, when and on which phone they were taken. Videos are shared as they are, so they may still say where they were filmed.';

  @override
  String get shareAnyway => 'Share';

  @override
  String get saveToPhone => 'Save to phone';

  @override
  String get savedToPhone => 'Saved to this phone (ZT Gallery folder).';

  @override
  String get saveFailed => 'It couldn\'t be saved to this phone.';

  @override
  String get accountSignedOutTitle => 'Your encrypted photos';

  @override
  String get accountSignedOutBody =>
      'Sign in with your Zero-Trust account to see the photos you back up with ZT Camera. They are encrypted on your phone before they leave it: nobody else can see them, not even us.';

  @override
  String get accountEmptyTitle => 'Nothing in your account yet';

  @override
  String get accountEmptyBody =>
      'Photos you back up from ZT Camera\'s Private vault show here, on every phone you sign in on.';

  @override
  String get accountCantLoadTitle => 'Your account\'s photos couldn\'t be read';

  @override
  String get accountCantLoadBody => 'Check the connection and try again.';

  @override
  String get photoAccess => 'Photo access';

  @override
  String get photoAccessAll => 'All photos and videos';

  @override
  String get photoAccessSome => 'Only the photos you picked';

  @override
  String get photoAccessNone => 'Not allowed';

  @override
  String get cleanShareTitle => 'Clean sharing';

  @override
  String get cleanShareBody =>
      'Photos you share leave without where, when and on which phone they were taken.';
}
