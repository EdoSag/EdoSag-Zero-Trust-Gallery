// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class AppL10nHe extends AppL10n {
  AppL10nHe([String locale = 'he']) : super(locale);

  @override
  String get appTitle => 'ZT גלריה';

  @override
  String get settings => 'הגדרות';

  @override
  String get photosTab => 'תמונות';

  @override
  String get albumsTab => 'אלבומים';

  @override
  String get accountTab => 'חשבון';

  @override
  String get today => 'היום';

  @override
  String get yesterday => 'אתמול';

  @override
  String get photo => 'תמונה';

  @override
  String get video => 'סרטון';

  @override
  String get share => 'שיתוף';

  @override
  String get delete => 'מחיקה';

  @override
  String get cancel => 'ביטול';

  @override
  String get details => 'פרטים';

  @override
  String get play => 'הפעלה';

  @override
  String get pause => 'השהיה';

  @override
  String get signIn => 'כניסה או יצירת חשבון';

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'נבחרו $count',
      one: 'נבחר פריט אחד',
    );
    return '$_temp0';
  }

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count פריטים',
      one: 'פריט אחד',
      zero: 'ריק',
    );
    return '$_temp0';
  }

  @override
  String megabytes(String amount) {
    return '$amount MB';
  }

  @override
  String get accessTitle => 'התמונות שלך, כאן';

  @override
  String get accessBody =>
      'ZT גלריה מציגה את התמונות והסרטונים שבטלפון. הם נשארים בטלפון: שום דבר לא עולה לרשת אלא אם בחרת בכך.';

  @override
  String get allowAccess => 'מתן גישה';

  @override
  String get somePhotosTitle => 'רק חלק מהתמונות';

  @override
  String get somePhotosBody => 'נתת ל-ZT גלריה לראות רק את התמונות שבחרת.';

  @override
  String get pickMore => 'בחירת עוד';

  @override
  String get noPhotos => 'עדיין אין תמונות או סרטונים בטלפון.';

  @override
  String get photosCantLoad =>
      'לא ניתן היה לקרוא את התמונות. כדאי לנסות שוב בעוד רגע.';

  @override
  String get onThisPhone => 'בטלפון הזה';

  @override
  String get inYourAccount => 'בחשבון שלך';

  @override
  String get inYourAccountEncrypted => 'בחשבון שלך, בהצפנה מקצה לקצה';

  @override
  String get untitledAlbum => 'אלבום ללא שם';

  @override
  String get detailName => 'שם';

  @override
  String get detailSize => 'מידות';

  @override
  String get detailLength => 'אורך';

  @override
  String get detailFolder => 'תיקייה';

  @override
  String get detailWhere => 'שמור';

  @override
  String get detailFileSize => 'גודל הקובץ';

  @override
  String get detailCopy => 'עותק';

  @override
  String get spaceSaverCopy => 'עותק קטן יותר (חיסכון במקום)';

  @override
  String get videoCantPlay => 'לא ניתן להפעיל את הסרטון הזה.';

  @override
  String get shareFailed => 'לא ניתן היה לשתף דבר.';

  @override
  String get shareVideoTitle => 'לשתף את הסרטון כמו שהוא?';

  @override
  String get shareVideoBody =>
      'תמונות משותפות בלי המקום, הזמן והטלפון שבו צולמו. סרטונים משותפים כמו שהם, כך שייתכן שעדיין יופיע בהם איפה צולמו.';

  @override
  String get shareAnyway => 'שיתוף';

  @override
  String get saveToPhone => 'שמירה בטלפון';

  @override
  String get savedToPhone => 'נשמר בטלפון הזה (בתיקייה ZT Gallery).';

  @override
  String get saveFailed => 'לא ניתן היה לשמור בטלפון הזה.';

  @override
  String get accountSignedOutTitle => 'התמונות המוצפנות שלך';

  @override
  String get accountSignedOutBody =>
      'אפשר להיכנס עם חשבון Zero-Trust כדי לראות את התמונות שגיבית עם ZT מצלמה. הן מוצפנות בטלפון לפני שהן יוצאות ממנו: אף אחד אחר לא יכול לראות אותן, גם לא אנחנו.';

  @override
  String get accountEmptyTitle => 'עדיין אין כלום בחשבון';

  @override
  String get accountEmptyBody =>
      'תמונות שגיבית מהכספת הפרטית של ZT מצלמה יופיעו כאן, בכל טלפון שנכנסת בו.';

  @override
  String get accountCantLoadTitle => 'לא ניתן היה לקרוא את התמונות שבחשבון';

  @override
  String get accountCantLoadBody => 'כדאי לבדוק את החיבור ולנסות שוב.';

  @override
  String get photoAccess => 'גישה לתמונות';

  @override
  String get photoAccessAll => 'כל התמונות והסרטונים';

  @override
  String get photoAccessSome => 'רק התמונות שבחרת';

  @override
  String get photoAccessNone => 'לא ניתנה';

  @override
  String get cleanShareTitle => 'שיתוף נקי';

  @override
  String get cleanShareBody =>
      'תמונות שמשתפים יוצאות בלי המקום, הזמן והטלפון שבו צולמו.';
}
