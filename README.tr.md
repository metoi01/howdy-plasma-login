# howdy-plasma-login

[Howdy](https://github.com/boltgolt/howdy) ile **KDE Plasma Login Manager**
giriş ekranında yüz tanıma. **Bazzite**, **Fedora KDE** ve diğer **Fedora
Atomic** (Kinoite) sistemlerde çalışır.

[English README](README.md)

## Sorun

Howdy'yi kurdunuz ve yüzünüzü tanıttınız. Kilit ekranında ve `sudo`
komutunda çalışıyor. Ama bilgisayarı yeniden başlatınca giriş ekranı yine
şifre soruyor.

Bunun iki nedeni var:

1. **Giriş ekranı farklı bir PAM dosyası kullanıyor.** Kilit ekranı
   `/etc/pam.d/kde` dosyasını okur, Plasma Login Manager ise `plasmalogin`
   dosyasını. Bazzite gibi imaj tabanlı sistemlerde bu dosya salt okunur
   `/usr/lib/pam.d/` klasöründedir. Rehberlerin çoğu bu yüzden onu atlar.
2. **SELinux kamerayı engelliyor.** Giriş ekranı `xdm_t` bağlamında çalışır
   ve SELinux bu bağlamın kamerayı belleğe almasına (`map`) izin vermez.
   Kilit ekranı sizin kullanıcınızla çalıştığı için bu engele takılmaz.

Bu depo iki sorunu tek komutla düzeltir. Kaldırma betiği de yaptığı her
değişikliği geri alır.

## Gereksinimler

- KDE Plasma ve Plasma Login Manager. Bulunamazsa SDDM kullanılır.
- Howdy kurulu olmalı ve yüzünüz tanıtılmış olmalı (`sudo howdy add`).
- `sudo` komutunda yüz tanıma çalışıyor olmalı. Denemek için:
  `sudo -k; sudo true`

## Kurulum

```bash
git clone https://github.com/metoi01/howdy-plasma-login.git
cd howdy-plasma-login
sudo ./install.sh --dry-run   # önce neyin değişeceğini görün
sudo ./install.sh
```

Bilgisayarı yeniden başlatın. Giriş ekranında **kullanıcınızı seçin, şifre
alanını boş bırakıp Enter'a basın** ve kameraya bakın. Plasma Login Manager
taramayı ancak Enter'a basınca başlatır.

## İsteğe bağlı: uygulamayı yüzle açmak

Örneğin bir mesajlaşma uygulaması menüden açılırken yüz taraması istesin:

```bash
sudo ./install.sh --with-polkit
./app-lock/lock-app.sh uygulama.kimligi   # sudo olmadan çalıştırın
```

Uygulamanın kimliğini `flatpak list --app` komutuyla bulabilirsiniz. Geri
almak için:

```bash
./app-lock/lock-app.sh --remove uygulama.kimligi
```

> **Bu bir caydırıcıdır, gerçek bir güvenlik önlemi değildir.** Kilidi açık
> masaüstünüzü kullanan birinin uygulamayı menüden açmasını engeller. Ama
> oturumunuza erişen biri uygulamayı başka yollarla yine başlatabilir.

## Kaldırma

```bash
sudo ./uninstall.sh
```

## Sorun giderme

- **Giriş ekranında kaldınız mı?** `Ctrl+Alt+F3` ile yazı ekranına geçin,
  şifrenizle girin ve `sudo ./uninstall.sh` komutunu çalıştırın.
- **Giriş ekranında kızılötesi ışıklar yanmıyor mu?** SELinux'un başka bir
  şeyi engelleyip engellemediğine bakın:
  `sudo ausearch -m avc -ts boot | grep xdm_t`
  Çıktıyı bir issue açarak paylaşın.
- **KWallet şifre soruyor:** Bu normal. KWallet giriş şifrenizle şifrelenir
  ve yüzle girişte ortada bir şifre olmaz. KWalletManager'dan cüzdan
  şifresini boş yapabilirsiniz, ama bunu yalnızca diskiniz şifreliyse (LUKS)
  yapın.

## Teşekkür

Yüz tanımanın tamamını [Howdy](https://github.com/boltgolt/howdy) yapar. Bu
proje yalnızca onu Plasma giriş ekranına bağlar.

## Lisans

[MIT](LICENSE)
