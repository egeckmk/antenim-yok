# Medya / radyo oynatıcı kalıpları

## Bilgi mimarisi
- Ana bölümler: **Favoriler** (varsayılan) · **Keşfet/Ara** · **Ayarlar**. Hepsi ≤ 1 tıkla.
- **Şimdi Çalıyor** her ekranda görünür: altta sabit çubuk (masaüstü) / mini oynatıcı (iOS). İçerik: logo, istasyon adı,
  şarkı/sanatçı (varsa), çal/durdur, ses (masaüstü). Tıklayınca genişler (iOS tam ekran sayfa).
- Favori ızgarası: kare logo kartları, ad altında tek satır (taşarsa üç nokta + tooltip). Çalan kart vurgulu
  (vurgu kenarı + küçük "canlı" çubuk animasyonu, hareket azaltılmışsa statik ikon).

## Durumlar (her biri tasarlanmalı)
| Durum | Gösterim |
|-------|----------|
| Durdu | Play ikonu, son istasyon seçili |
| Bağlanıyor | Düğmede küçük ProgressRing; 10 sn'yi aşarsa "Bağlanılamadı — tekrar dene" |
| Çalıyor | Pause (radyo canlı → "durdur" = stop; geri sarma/ileri yok) |
| Arabellek | Sessiz geçiş, kısa ise gösterme (> 1,5 sn ise "arabelleğe alınıyor") |
| Hata | InfoBar/banner: ne oldu ("Yayına ulaşılamadı") + eylem ("Tekrar dene", "Başka istasyon") |
| Çevrimdışı | Listeler görünür, çalma devre dışı + açıklama |
| Boş favori | Boş durum: "Henüz favori yok" + "Keşfet'e git" düğmesi |

## Kontroller & kısayollar
- Tek tıkla çal: karta tıklamak = o istasyonu çal (onay yok). Çalan karta tekrar tıklamak = durdur.
- Ses: kaydırıcı + sessiz düğmesi; seviye hatırlanır. Fare tekerleği ses çubuğunda çalışır.
- Masaüstü kısayollar: Boşluk çal/durdur · Ctrl+1…9 favori · Ctrl+F ara · Ctrl+↑/↓ ses · M sessiz.
- Sistem entegrasyonu zorunlu: Windows SMTC / Apple Now Playing + Remote Commands → medya tuşları, kilit ekranı,
  Windows ses açılır penceresi, AirPods. Metadata: istasyon adı = başlık, şarkı = alt başlık, logo = kapak.
- Önceki/sonraki = favori listesinde önceki/sonraki istasyon.
- Pencereyi kapatmak çalmayı durdurmaz (masaüstü: tepside / menü çubuğunda devam). Gerçek çıkış menüden.

## Görsel
- İçerik sakin: logolar renkli, kabuk nötr. Vurgu rengi = sistem vurgusu (çalan öğe, birincil düğme).
- Logo yoksa: istasyon adının baş harfleri, nötr dolgu üstünde.
- Logolar önbelleğe alınır; yüklenene kadar yer tutucu (düzen kaymaz).
