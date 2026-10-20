import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../shared/formatters.dart';

/// Uygulama metinleri. İngilizce varsayılan, Türkçe Ayarlar'dan seçilebilir.
class AppLocalizations {
  const AppLocalizations(this.locale);

  factory AppLocalizations.forLanguageCode(String code) =>
      AppLocalizations(Locale(code == 'tr' ? 'tr' : 'en'));

  final Locale locale;

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [Locale('en'), Locale('tr')];

  bool get isTurkish => locale.languageCode == 'tr';

  String get languageCode => isTurkish ? 'tr' : 'en';

  String _t(String en, String tr) => isTurkish ? tr : en;

  String _intlLocale() => isTurkish ? 'tr_TR' : 'en_US';

  // --- General ---
  String get appTagline =>
      _t('Your personal AI assistant', 'Kişisel AI Asistanın');
  String get settings => _t('Settings', 'Ayarlar');
  String get cancel => _t('Cancel', 'Vazgeç');
  String get save => _t('Save', 'Kaydet');
  String get delete => _t('Delete', 'Sil');
  String get add => _t('Add', 'Ekle');
  String get retry => _t('Retry', 'Tekrar Dene');
  String get language => _t('Language', 'Dil');
  String get languageSubtitle =>
      _t('Choose the app language', 'Uygulama dilini seç');
  String get english => 'English';
  String get turkish => 'Türkçe';
  String get account => _t('Account', 'Hesap');
  String get logout => _t('Log out', 'Çıkış Yap');
  String get logoutTitle => _t('Log out', 'Çıkış yap');
  String get logoutConfirm => _t(
    'Do you want to log out of your account?',
    'Hesabından çıkmak istiyor musun?',
  );
  String get notSignedIn => _t('Not signed in', 'Giriş yapılmadı');
  String get accountEmail => _t('Account email', 'Hesap e-postası');
  String get today => _t('Today', 'Bugün');
  String get yesterday => _t('Yesterday', 'Dün');
  String get tomorrow => _t('Tomorrow', 'Yarın');
  String get overdue => _t('Overdue', 'Gecikti');
  String get otherPlatform => _t('Other', 'Diğer');
  String get saveFailed =>
      _t('Could not save. Please try again.', 'Kaydedilemedi. Tekrar dene.');

  String priorityLabel(int priority) =>
      _t('Priority $priority', 'Öncelik $priority');

  String platformName(String raw) => raw == 'Diğer' ? otherPlatform : raw;

  // --- Tabs ---
  String get tasksTab => _t('Tasks', 'Görevler');
  String get pricesTab => _t('Prices', 'Fiyatlar');
  String get planTab => _t('Plan', 'Plan');

  // --- Tasks ---
  String get tasksTitle => _t('Tasks', 'Görevler');
  String get addTask => _t('Add task', 'Görev Ekle');
  String get all => _t('All', 'Tümü');
  String get active => _t('Active', 'Aktif');
  String get completed => _t('Completed', 'Biten');
  String get noCompletedTasksTitle =>
      _t('No completed tasks yet', 'Henüz tamamlanan görev yok');
  String get noTasksTitle => _t('No tasks yet', 'Görevün yok');
  String get completedTasksHere => _t(
    'Completed tasks will be listed here.',
    'Biten görevler burada listelenir.',
  );
  String get addFirstTask => _t(
    'Tap the button below to add your first task.',
    'Sağ alttaki butonla ilk görevini ekle.',
  );
  String pendingDoneSummary(int pending, int done) => isTurkish
      ? '$pending bekleyen · $done tamamlanan'
      : '$pending pending · $done completed';
  String get deleteTaskTitle => _t('Delete task', 'Görevi sil');
  String deleteTaskConfirm(String title) => isTurkish
      ? '"$title" kalıcı olarak silinsin mi?'
      : 'Delete "$title" permanently?';
  String get taskTitleRequired =>
      _t('Task title is required.', 'Görev başlığı gerekli.');
  String get newTask => _t('New task', 'Yeni Görev');
  String get titleLabel => _t('Title', 'Başlık');
  String get taskTitleHint =>
      _t('e.g. Research keyboard options', 'Örn: Klavye siparişini araştır');
  String get descriptionOptional =>
      _t('Description (optional)', 'Açıklama (isteğe bağlı)');
  String get pickDate => _t('Pick a date', 'Tarih seç');
  String get aiPrioritize => _t('Prioritize with AI', 'AI ile önceliklendir');
  String get aiPrioritizeSubtitle => _t(
    'Get a priority and subtask suggestions.',
    'Öncelik ve alt görev önerisi alırsın.',
  );

  // --- Prices ---
  String get pricesTitle => _t('Price tracking', 'Fiyat Takip');
  String get trackProduct => _t('Track product', 'Ürün Takip Et');
  String get noProductsTitle =>
      _t('No tracked products yet', 'Takip edilen ürün yok');
  String get noProductsMessage => _t(
    'Paste a product link from Trendyol, n11, Hepsiburada and more. We will let you know when the price drops.',
    'Trendyol, n11, Hepsiburada ve daha fazlasından ürün linki yapıştır, fiyatı düşünce haber verelim.',
  );
  String get trackedTitle => _t('Tracked', 'Takiptekiler');
  String trackedSubtitle(int count) => isTurkish
      ? '$count ürün · fiyatlar düzenli kontrol edilir'
      : '$count ${count == 1 ? 'product' : 'products'} · prices checked regularly';
  String get productsLabel => _t('Products', 'Ürün');
  String get atTargetLabel => _t('At target', 'Hedefte');
  String get activeLabel => _t('Active', 'Aktif');
  String get currentLabel => _t('Current', 'Güncel');
  String get targetLabel => _t('Target', 'Hedef');
  String get notSet => _t('Not set', 'Belirtilmedi');
  String targetLine(String price) => _t('Target: $price', 'Hedef: $price');
  String notificationLine(String description) =>
      _t('Alert: $description', 'Bildirim: $description');
  String get productNotFound => _t('Product not found.', 'Ürün bulunamadı.');
  String get productDetails => _t('Product details', 'Ürün Detayı');
  String get priceHistory => _t('Price history', 'Fiyat Geçmişi');
  String get noHistory => _t('No history yet.', 'Henüz geçmiş verisi yok.');
  String get targetReachedBanner => _t(
    'Target price reached! You can buy now.',
    'Hedef fiyata ulaşıldı! Satın alabilirsin.',
  );
  String get targetTrackingBanner => _t(
    'We are tracking until the price drops below your target.',
    'Hedef fiyatın altına düşene kadar takip ediyoruz.',
  );
  String get updatePriceNow => _t('Update price now', 'Fiyatı Şimdi Güncelle');
  String get openInBrowser =>
      _t('Open product in browser', 'Ürünü Tarayıcıda Aç');
  String get browserOpenFailed =>
      _t('Could not open the browser.', 'Tarayıcı açılamadı.');
  String get updateTarget => _t('Update target price', 'Hedef Fiyatı Güncelle');
  String get stopTracking => _t('Stop tracking', 'Takibi Bırak');
  String get targetPriceTitle => _t('Target price', 'Hedef Fiyat');
  String get newTargetLabel => _t('New target (₺)', 'Yeni hedef (₺)');
  String get priceReadFailed =>
      _t('Could not read the price.', 'Fiyat okunamadı.');
  String priceUpdated(String price) =>
      _t('Price updated: $price', 'Fiyat güncellendi: $price');
  String priceUpdatedReached(String price) => _t(
    'Price updated: $price — Target reached!',
    'Fiyat güncellendi: $price — Hedefe ulaştı!',
  );
  String get priceUpdateFailed => _t(
    'Could not update the price. Check the link.',
    'Fiyat güncellenemedi. Linki kontrol et.',
  );
  String get alertSettingsTitle => _t('Alert settings', 'Bildirim Ayarları');
  String get percentDropLabel => _t('Drop percentage (%)', 'Düşüş yüzdesi (%)');
  String get alertTargetDescription => _t(
    'You will be notified when the price drops below your target.',
    'Fiyat, hedef fiyatın altına düşünce haber verilir.',
  );
  String get alertDropDescription => _t(
    'You will be notified when the price drops below the previous price.',
    'Fiyat, bir önceki fiyatın altına düşünce haber verilir.',
  );
  String get alertPercentDescription => _t(
    'You will be notified when the price drops by the selected percentage.',
    'Fiyat, seçtiğin yüzde kadar düşünce haber verilir.',
  );
  String get setTargetFirst =>
      _t('Set a target price first.', 'Önce bir hedef fiyat belirle.');
  String get alertTargetLabel => _t('When it hits target', 'Hedefe düşünce');
  String get alertDropLabel => _t('On any drop', 'Her düşüşte');
  String get alertPercentLabel => _t('On percentage drop', 'Yüzde düşüşte');
  String alertPercentShort(double? percent) => isTurkish
      ? '%${(percent ?? 10).toStringAsFixed(0)} düşüşte'
      : 'on a ${(percent ?? 10).toStringAsFixed(0)}% drop';
  String alertTypeLabel(String type) => switch (type) {
    'target' => alertTargetLabel,
    'drop' => alertDropLabel,
    _ => alertPercentLabel,
  };
  String alertTypeDescription(String type, double? percent) => switch (type) {
    'target' => alertTargetDescription,
    'drop' => alertDropDescription,
    _ => alertPercentDescription,
  };
  String get addProductTitle => _t('Track a product', 'Ürün Takip Et');
  String get productLinkLabel => _t('Product link', 'Ürün linki');
  String get invalidProductLink => _t(
    'Enter a valid product link. e.g. https://www.trendyol.com/...',
    'Geçerli bir ürün linki gir. Örn: https://www.trendyol.com/...',
  );
  String get priceFetchFailedManual => _t(
    'Could not read the price. You can enter the target manually.',
    'Fiyat okunamadı, hedefi elle girebilirsin.',
  );
  String get productFetchFailed =>
      _t('Could not fetch the product.', 'Ürün alınamadı.');
  String get getPrice => _t('Get price', 'Fiyatı Getir');
  String get currentPriceLineLabel => _t('Current', 'Güncel');
  String get targetPriceInputLabel => _t('Target price (₺)', 'Hedef fiyat (₺)');
  String get targetPriceHint => _t('e.g. 1200', 'Örn: 1200');
  String get notificationLabel => _t('Alert', 'Bildirim');
  String get percentHint => _t('e.g. 10', 'Örn: 10');
  String get trackButton => _t('Track', 'Takip Et');
  String get siteLabel => _t('Site', 'Site');
  String automaticPlatform(String detected) =>
      detected.isEmpty || detected == 'Diğer'
      ? _t('Auto', 'Otomatik')
      : _t('Auto · $detected', 'Otomatik · $detected');
  String get productFallbackName => _t('Product', 'Ürün');
  String get productLinkRequired =>
      _t('Please paste a product link.', 'Lütfen bir ürün linki yapıştır.');
  String get targetPriceRequired =>
      _t('Target price is required.', 'Hedef fiyat gerekli.');
  String get sessionRequired => _t('Session required.', 'Oturum gerekli.');
  String productSaveFailed(Object error) =>
      isTurkish ? 'Kayıt başarısız: $error' : 'Save failed: $error';
  String get loginFailed => _t(
    'Sign in failed. Check your details.',
    'Giriş başarısız. Bilgilerini kontrol et.',
  );

  // --- Web price reader ---
  String get readingPriceTitle => _t('Reading price', 'Fiyat okunuyor');
  String get pageOpening => _t('Opening page…', 'Sayfa açılıyor…');
  String priceReadingProgress(int attempt, int total) => isTurkish
      ? 'Fiyat okunuyor… ($attempt/$total)'
      : 'Reading price… ($attempt/$total)';
  String get webViewExplanation => _t(
    'The page opens using your phone\'s internet. This bypasses bot protection and works on sites like Trendyol.',
    'Sayfa, telefonun internetiyle açılıyor. Bu yöntem bot korumasını aşar; Trendyol gibi sitelerde kullanılır.',
  );

  // --- Planner ---
  String get planTitle => _t('Plan', 'Plan');
  String get aiPlan => _t('AI plan', 'AI Plan');
  String get eventLabel => _t('Event', 'Etkinlik');
  String get addEvent => _t('Add event', 'Etkinlik Ekle');
  String get noEventsTitle =>
      _t('No events for this day', 'Bu gün için etkinlik yok');
  String get noEventsMessage => _t(
    'Add an event or create a day plan with AI.',
    'Etkinlik ekle veya AI ile günün planını oluştur.',
  );
  String get aiPlanFailed => _t(
    'Could not create an AI plan. Check the Gemini key.',
    'AI plan oluşturulamadı. Gemini anahtarını kontrol et.',
  );
  String get previousWeek => _t('Previous week', 'Önceki hafta');
  String get nextWeek => _t('Next week', 'Sonraki hafta');
  String get aiDayPlan => _t('AI day plan', 'AI Gün Planı');
  String get deleteEventTitle => _t('Delete event', 'Etkinliği sil');
  String deleteEventConfirm(String title) =>
      _t('Delete "$title"?', '"$title" silinsin mi?');
  String get eventTitleRequired =>
      _t('Event title is required.', 'Etkinlik başlığı gerekli.');
  String get endAfterStart => _t(
    'End time must be after the start time.',
    'Bitiş saati başlangıçtan sonra olmalı.',
  );
  String get eventAddFailed => _t(
    'Could not add the event. Try again.',
    'Etkinlik eklenemedi. Tekrar dene.',
  );
  String get newEvent => _t('New event', 'Yeni Etkinlik');
  String get eventTitleLabel => _t('Title', 'Başlık');
  String get eventTitleHint =>
      _t('e.g. Dentist appointment', 'Örn: Diş randevusu');
  String get startLabel => _t('Start', 'Başlangıç');
  String get endLabel => _t('End', 'Bitiş');
  String get eventTypeTask => _t('Task', 'Görev');
  String get eventTypeAppointment => _t('Appointment', 'Randevu');
  String get eventTypeReminder => _t('Reminder', 'Hatırlatma');
  String eventTypeLabel(String type) => switch (type) {
    'task' => eventTypeTask,
    'appointment' => eventTypeAppointment,
    _ => eventTypeReminder,
  };
  String get freeLabel => _t('Free', 'Boş');
  String get nowLabel => _t('Now', 'Şimdi');
  String get emptySlot => _t('No events', 'Etkinlik yok');
  String eventCount(int count) => isTurkish
      ? '$count etkinlik'
      : '$count ${count == 1 ? 'event' : 'events'}';
  String scheduledDuration(String duration) =>
      _t('$duration scheduled', '$duration planlı');
  String get addAllToCalendar =>
      _t('Add all to calendar', 'Tümünü takvime ekle');
  String get addAllEvents => _t('Add all', 'Tümünü Ekle');
  String addSelectedEvents(int count) =>
      isTurkish ? 'Seçilenleri ekle ($count)' : 'Add selected ($count)';
  String get eventDetails => _t('Event details', 'Etkinlik Detayı');
  String get aiGeneratedLabel => _t('AI generated', 'AI oluşturdu');
  String addedToCalendar(String title) =>
      _t('$title added.', '$title eklendi.');
  String eventsAdded(int count) => isTurkish
      ? '$count etkinlik takvime eklendi.'
      : '$count ${count == 1 ? 'event' : 'events'} added to your calendar.';
  String get conflictLabel => _t('Overlaps', 'Çakışıyor');
  String get planSummary => _t('Summary', 'Özet');
  String get noPlanItems => _t(
    'AI could not suggest a plan. Try again.',
    'AI bir plan öneremedi. Tekrar dene.',
  );

  // --- Notifications ---
  String get notifications => _t('Notifications', 'Bildirimler');
  String get markAllRead => _t('Mark all as read', 'Tümünü okundu yap');
  String get noNotifications =>
      _t('No notifications yet.', 'Henüz bildirim yok.');
  String get priceDropsHere =>
      _t('Price drops will appear here.', 'Fiyat düşüşleri burada görünecek.');
  String timeToday(String time) => _t('Today $time', 'Bugün $time');
  String timeYesterday(String time) => _t('Yesterday $time', 'Dün $time');

  // --- Auth ---
  String get welcomeBack => _t('Welcome back', 'Tekrar hoş geldin');
  String get continueWhereYouLeft =>
      _t('Pick up where you left off.', 'Kaldığın yerden devam et.');
  String get emailLabel => _t('Email', 'E-posta');
  String get passwordLabel => _t('Password', 'Şifre');
  String get signIn => _t('Sign in', 'Giriş Yap');
  String get googleContinue =>
      _t('Continue with Google', 'Google ile devam et');
  String get noAccountSignUp =>
      _t("Don't have an account? Sign up", 'Hesabın yok mu? Kayıt ol');
  String get emailPasswordRequired =>
      _t('Email and password are required.', 'E-posta ve şifre gerekli.');
  String get invalidEmail =>
      _t('Enter a valid email address.', 'Geçerli bir e-posta adresi gir.');
  String get googleStartFailed =>
      _t('Could not start Google sign-in.', 'Google girişi başlatılamadı.');
  String get googleSignInFailed =>
      _t('Google sign-in failed.', 'Google girişi başarısız.');
  String get registerTitle => _t('Sign up', 'Kayıt Ol');
  String get passwordMin6 => _t(
    'Password must be at least 6 characters.',
    'Şifre en az 6 karakter olmalı.',
  );
  String get confirmationSent => _t(
    'A confirmation link has been sent to your email.',
    'Onay bağlantısı e-postana gönderildi.',
  );
  String get accountCreated =>
      _t('Account created. Welcome!', 'Hesap oluşturuldu, hoş geldin!');
  String get registerFailed => _t(
    'Sign up failed. The email may already be in use.',
    'Kayıt başarısız. E-posta kullanılıyor olabilir.',
  );
  String get createAccount => _t('Create account', 'Hesap Oluştur');
  String get haveAccountSignIn =>
      _t('Already have an account? Sign in', 'Zaten hesabım var, giriş yap');
  String get passwordMin6Hint =>
      _t('Password (at least 6 characters)', 'Şifre (en az 6 karakter)');
  String get googleRegisterFailed =>
      _t('Google sign-up failed.', 'Google ile kayıt başarısız.');
  String get comparePrices => _t('Compare prices', 'Fiyatları karşılaştır');
  String get addStoreOffer => _t('Add store offer', 'Mağaza teklifi ekle');
  String get storeProductLink =>
      _t('Product link from another store', 'Diğer mağazadaki ürün linki');
  String get offerPriceNotFound => _t('Price not found', 'Fiyat bulunamadı');
  String get cheapestOffer => _t('Cheapest offer', 'En ucuz teklif');
  String get priceDifference => _t('Difference', 'Fiyat farkı');
  String get offerReadFailed =>
      _t('The store price could not be read.', 'Mağaza fiyatı okunamadı.');
  String get searchByProductName =>
      _t('Search by product name', 'Ürün adıyla ara');
  String get productNameSearchHint =>
      _t('e.g. wireless headphones', 'Örn: kablosuz kulaklık');
  String get searchStores => _t('Search stores', 'Mağazalarda ara');
  String get searchInProgressTitle =>
      _t('Searching stores', 'Mağazalar aranıyor');
  String searchInProgressMessage(int seconds) => _t(
    'The bot is checking the selected stores. Elapsed: $seconds s',
    'Bot seçilen mağazaları kontrol ediyor. Geçen süre: $seconds sn',
  );
  String get searchInProgressHint => _t(
    'Results will appear here when the search is complete.',
    'Arama tamamlanınca sonuçlar burada görünecek.',
  );
  String get noSearchResults => _t(
    'No products found in selected stores.',
    'Seçilen mağazalarda ürün bulunamadı.',
  );
  String searchError(String error) =>
      _t('Product search failed: $error', 'Ürün araması başarısız: $error');
  String selectedOfferCount(int count) =>
      isTurkish ? '$count teklif seçildi' : '$count offers selected';
  String get trackSelectedOffers =>
      _t('Track selected offers', 'Seçilen teklifleri takip et');

  // --- Setup ---
  String get supabaseConnection =>
      _t('Supabase connection', 'Supabase bağlantısı');
  String get toStart => _t('To get started:', 'Başlamak için:');
  List<String> get setupSteps => isTurkish
      ? const [
          '1. Ücretsiz bir Supabase projesi oluştur.',
          '2. schema.sql dosyasını SQL Editor\'de çalıştır.',
          '3. lib/core/config/secrets.dart dosyasını doldur.',
          '4. Supabase Auth > URL Configuration bölümüne '
              'com.mutalabs.muta://login-callback ekle.',
          '5. AI için: supabase secrets set GEMINI_API_KEY=...',
          '6. Uygulamayı yeniden başlat.',
        ]
      : const [
          '1. Create a Supabase project (free).',
          '2. Run schema.sql in the SQL Editor.',
          '3. Fill in lib/core/config/secrets.dart.',
          '4. Add com.mutalabs.muta://login-callback under '
              'Supabase Auth > URL Configuration.',
          '5. For AI: supabase secrets set GEMINI_API_KEY=...',
          '6. Restart the app.',
        ];

  // --- Settings ---
  String get trackedSites => _t('Tracked sites', 'Takip Edilen Siteler');
  String get trackedSitesSubtitle => _t(
    'Choose the stores used for price tracking',
    'Fiyat takibinde kullanacağın firmaları seç',
  );
  String get addNewSite => _t('Add a new site', 'Yeni site ekle');
  String get removeTooltip => _t('Remove', 'Kaldır');
  String get addSiteTitle => _t('Add new site', 'Yeni Site Ekle');
  String get siteNameLabel => _t('Site name', 'Site adı');
  String get siteNameHint => _t('e.g. Pazarama', 'Örn: Pazarama');
  String get siteAddressLabel => _t('Site address', 'Site adresi');
  String get siteAddressHint => _t('pazarama.com', 'pazarama.com');
  String get invalidSite => _t(
    'Enter a valid site name and address.\ne.g. Pazarama · pazarama.com',
    'Geçerli bir site adı ve adresi gir.\nÖrn: Pazarama · pazarama.com',
  );

  // --- Formatting ---
  String price(double? value) => formatPrice(value, languageCode);
  String dateLong(DateTime date) => DateFormat(
    isTurkish ? 'd MMMM EEEE' : 'EEEE, MMMM d',
    _intlLocale(),
  ).format(date);
  String dateShort(DateTime date) =>
      DateFormat(isTurkish ? 'd MMM' : 'MMM d', _intlLocale()).format(date);
  String compactDate(DateTime date) =>
      DateFormat(isTurkish ? 'd/M' : 'M/d', _intlLocale()).format(date);
  String monthDayYear(DateTime date) => DateFormat(
    isTurkish ? 'd MMMM y' : 'MMMM d, y',
    _intlLocale(),
  ).format(date);
  String weekdayShort(DateTime date) =>
      DateFormat('EEE', _intlLocale()).format(date);
  String time(DateTime date) => DateFormat('HH:mm').format(date);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (l) => l.languageCode == locale.languageCode,
  );

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture(AppLocalizations(locale));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
