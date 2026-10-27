# Teslim öncesi kontrol listesi

**Görsel**
- [ ] Sabit hex/punto yok; tema kaynakları / semantik renk / tip rampası
- [ ] Açık, koyu, yüksek kontrast (Windows) / büyük Dynamic Type (iOS) denendi
- [ ] Emoji ikon yok; ikonlar tek aileden (Fluent / SF Symbols), aynı boyut ve ağırlıkta
- [ ] Boşluklar 4/8 ızgarasında, hizalar tutarlı; metin taşınca üç nokta + tooltip
- [ ] Pencere en küçük ve en büyük boyutta bozulmuyor

**Etkileşim**
- [ ] Her tıklanabilir öğede hover/pressed durumu ve ≤100 ms geri bildirim
- [ ] Yükleniyor / boş / hata / çevrimdışı durumları var ve anlaşılır
- [ ] Hata mesajı: ne oldu + ne yapılabilir; teknik ayrıntı yok
- [ ] Animasyonlar 150–300 ms, "hareketi azalt"a uyuyor
- [ ] Son konum/ayarlar (sayfa, istasyon, ses, pencere boyutu) yeniden açılışta geri geliyor

**Erişilebilirlik & klavye**
- [ ] Tüm eylemler klavyeyle; odak sırası mantıklı ve odak çerçevesi görünür
- [ ] Sadece ikonlu düğmelerde erişilebilir ad + tooltip
- [ ] Metin kontrastı ≥ 4.5:1 (büyük metin 3:1)
- [ ] Narrator / VoiceOver ile bir tur; Windows'ta Accessibility Insights FastPass temiz

**Kod**
- [ ] View'da iş mantığı yok (MVVM); async komutlar, UI iş parçacığı bloklanmıyor
- [ ] Listeler sanallaştırılmış / lazy; kararlı id
