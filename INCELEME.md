# VibeProof — inceleme rehberi

Bu paket bir **Agent Skill**'dir: çalıştırılabilir bir program değil, bir kodlama
ajanının (Claude Code / Cursor / Codex) okuyup uyguladığı yordam. Dolayısıyla
"kodu çalıştır, çıktıyı ölç" yöntemiyle denetlenemez. Denetlenecek şey **yordamın
kendisi**: yeterince kesin mi, kötüye kullanıma kapalı mı, yanlış sonuç üretmeye
açık mı.

Canlı repo: https://github.com/mrsametyildirim/vibeproof

---

## Ne iddia ediyor

> Linter'lar kodunu inceler. VibeProof **ürün vaatlerini** inceler.

AI ile yazılmış uygulamalarda sık görülen "bitmiş görünen ama bağlanmamış" şeyleri
bulmayı hedefler: hiçbir şey yapmayan buton, sunucuya gitmeyen kaydet, API cevabını
beklemeden çıkan "başarılı" mesajı, sayfa yenilenince kaybolan değişiklik,
olmayan rotaya giden link.

---

## Dosya haritası

```
skills/vibeproof/SKILL.md          yordam · şiddet modeli · modlar · kapsam
  references/
    fake-features.md              sabit veri, boş handler, mock geri düşüş
    broken-wiring.md              eksik rota/endpoint/handler/import
    false-success.md              await'siz başarı, catch→success, yutulan hata
    persistence.md                yenilemeye dayanmayan değişiklik
    ghost-ui.md                   ölü kontrol, yetim bileşen, eksik durumlar
    false-positives.md            BASTIRMA KURALLARI — güven katmanı
    report-format.md              aritmetik skorlama, çıktı düzeni

hooks/tripwire.sh                 Stop hook — 5 hızlı kontrol (POSIX sh)
install.sh                        kurulum (opsiyonel hook kaydı)
examples/real-audit.md            gerçek bir çalıştırma + iki kıl payı
examples/sample-report.md         tam rapor örneği
```

---

## Tasarımın üç iddiası — asıl denetlenmesi gerekenler bunlar

### 1. Kanıt disiplini
`SKILL.md`: *"Alıntılanmış kanıtı olmayan bulgu, bulgu değildir. Sil."*
Her bulgu için gerçek `dosya:satır` + **birebir alıntı** + kopan halkanın adı
zorunlu. Emin olunamayan şey `FAKE` değil `UNPROVEN` olarak raporlanır.

**Sorulacak soru:** bu kural bir dil modelini gerçekten uydurmaktan alıkoyar mı,
yoksa kâğıt üzerinde mi kalır? Nerede delinebilir?

### 2. Aritmetik skor
Blocker −12, risk −4, cleanup −1, tabanı 0. Aynı commit her zaman aynı skoru verir.
Ship kararını **yalnız blocker'lar** belirler; iyi skor bir blocker'ı örtemez.
Sert kısıt: *yalnızca PROVEN bir bulgu BLOCKER olabilir.*

**Sorulacak soru:** ceza ağırlıkları savunulabilir mi? "12" keyfi mi? Kategoriler
arası çifte sayım olur mu (aynı hata hem fake-feature hem ghost-ui sayılabilir mi)?

### 3. Salt okunur
Kodu asla değiştirmez. Gerekçe: denetleyenin aynı zamanda düzeltmesi, neyin bozuk
olduğu konusunda güvenilirliğini yok eder.

---

## Bilinen zayıflıklar (kendi tespitimiz)

1. **`tripwire.sh` grep tabanlı.** Yalnız kaba desen eşleştirmesi yapar; sözdizimi
   ağacı okumaz. Yanlış pozitif üretebilir — bu yüzden tam denetim değil yalnızca
   "denetim çalıştırmaya değer mi?" sinyali olarak konumlandırıldı. İki gerçek
   yanlış pozitif bulunup düzeltildi (React `setX` setter'ları; tek dosyada
   `grep -B1` dosya adı öneki basmaması).

2. **Çerçeve kapsamı sınırlı.** `false-positives.md` Next.js/Nuxt/SvelteKit/Remix,
   NestJS/FastAPI/Spring/Rails konvansiyonlarını sayar. Listede olmayan bir çerçeve
   için "eksik rota" bulgusu yanlış olabilir; SKILL bu durumda Coverage bölümünde
   belirtmeyi zorunlu kılar ama garanti edemez.

3. **Ürün sözleşmesi çıkarımı modele bağlı.** "Uygulamanın vaatleri" listesi
   deterministik değil; farklı ajanlar farklı liste çıkarabilir. Skor aritmetiği
   deterministik ama **girdi kümesi** değil. Bu, "aynı commit aynı skoru verir"
   iddiasının en zayıf halkasıdır.

4. **Ölçüm yok.** Kaç gerçek hata yakaladığına dair istatistik yok; iki gerçek
   çalıştırma var (biri bu paketin kendisinde). Yanlış pozitif oranı ölçülmedi.

---

## Özellikle bakılması istenen yerler

- `references/false-positives.md` — bastırma kuralları fazla mı geniş? Gerçek
  hataları da eliyor olabilir mi?
- `references/false-success.md` §4 — `fetch` durum kontrolü. Axios/ky gibi 4xx'te
  fırlatan istemcileri doğru istisna tutuyor mu?
- `report-format.md` skorlama — bantlar ve eşikler savunulabilir mi?
- `hooks/tripwire.sh` — beş kontrolün regex'leri. Hangi gerçek kalıpları kaçırır?
- `SKILL.md` "Severity" bölümü — "yalnızca PROVEN blocker olabilir" kuralı yeterli
  bir koruma mı?

---

## Kendi üzerinde çalıştırıldı

Skill kendi reposuna uygulandı ve üç kusur buldu; ikisi ciddiydi:

- `--with-hook` bayrağı hook'u kurmuyordu, yalnız iki echo satırının metnini
  değiştiriyordu (kendi sınıflandırmasıyla: Ghost UI)
- `tripwire.sh` check-1, tek dosya değişen her durumda sessizce geçiyordu
  (`grep -B1` tek dosyada dosya adı öneki basmıyor)
- README "six reference files" diyordu, yedi tane vardı

Üçü de düzeltildi. İkisi de **kodu okuyarak değil, çalıştırıp sonucu vaade karşı
denetleyerek** bulundu.
