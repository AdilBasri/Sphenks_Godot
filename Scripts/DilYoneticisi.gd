extends Node

# Global Sinyal - Tüm UI'lar dinleyecek
signal dil_degisti

# Aktif dil (Varsayılan tr)
var secili_dil: String = "tr" 

# Tüm kelimelerin sözlüğü
var ceviriler = {
	"basla": {
		"tr": "BAŞLA",
		"en": "START"
	},
	"cikis": {
		"tr": "ÇIKIŞ",
		"en": "QUIT"
	},
	"kaydi_sifirla": {
		"tr": "KAYDI SIFIRLA",
		"en": "RESET SAVE"
	},
	"satin_al": {
		"tr": "[Sol Tık / A] SATIN AL\n%s (%d Altın)",
		"en": "[Left/A] BUY\n%s (%d Gold)"
	},
	"al": {
		"tr": "[Sol Tık / A] AL\n%s",
		"en": "[Left/A] TAKE\n%s"
	},
	"kapiyi_ac": {
		"tr": "[E / Y] Kapıyı Aç",
		"en": "[E / Y] Open Door"
	},
	"oynamak_icin_otur": {
		"tr": "[E / Y] Oynamak için Otur",
		"en": "[E / Y] Sit to Play"
	},
	"tut": {
		"tr": "[Sol Tık / A] TUT",
		"en": "[Left/A] HOLD"
	},
	"kalk": {
		"tr": "[E / Y] Kalk",
		"en": "[E / Y] Stand Up"
	},
	"daha_fazla_yemek": {
		"tr": "Daha fazla yemek istemiyorum.",
		"en": "I don't want to eat anymore."
	},
	"mermi_sayisi": {
		"tr": "MERMİ: %d / %d",
		"en": "AMMO: %d / %d"
	},
	"totem_sayisi": {
		"tr": "TOTEM %d/%d",
		"en": "TOTEM %d/%d"
	},
	"katman_yazisi": {
		"tr": "KATMAN %d",
		"en": "LAYER %d"
	},
	"perk_soru": {
		"tr": "DÜŞMANDAN BİR 'KANLI ÇİVİ' PERKİ DÜŞTÜ!\nALMAK İSTİYOR MUSUN?",
		"en": "ENEMY DROPPED A 'BLOODY NAIL' PERK!\nDO YOU WANT TO TAKE IT?"
	},
	"evet": {
		"tr": "EVET",
		"en": "YES"
	},
	"hayir": {
		"tr": "HAYIR",
		"en": "NO"
	},
	"devam_et": {
		"tr": "DEVAM ET",
		"en": "RESUME"
	},
	"ayarlar": {
		"tr": "AYARLAR",
		"en": "SETTINGS"
	},
	"ana_menu": {
		"tr": "ANA MENÜYE ÇIK",
		"en": "QUIT TO MAIN MENU"
	},
	"cozunurluk": {
		"tr": "ÇÖZÜNÜRLÜK",
		"en": "RESOLUTION"
	},
	"goruntu_modu": {
		"tr": "EKRAN MODU",
		"en": "DISPLAY MODE"
	},
	"tam_ekran": {
		"tr": "Tam Ekran",
		"en": "Fullscreen"
	},
	"pencere": {
		"tr": "Pencereli",
		"en": "Windowed"
	},
	"kontroller": {
		"tr": "KONTROLLER",
		"en": "CONTROLS"
	},
	"dil": {
		"tr": "DİL",
		"en": "LANGUAGE"
	},
	"oyun_tuslari": {
		"tr": "OYUN TUŞLARI",
		"en": "GAME CONTROLS"
	},
	"action_drag": {
		"tr": "Aksiyon (Sürükle/Ateş) [Sol Tık / A]",
		"en": "Action (Drag/Shoot) [Left Click / A]"
	},
	"action_parry": {
		"tr": "İptal / Parry [Sağ Tık / B]",
		"en": "Cancel / Parry [Right Click / B]"
	},
	"action_turn": {
		"tr": "Masa Kamerası (Klavye: A/D - Gamepad: LT/RT)",
		"en": "Table Camera (Key: A/D - Pad: LT/RT)"
	},
	"action_sprint": {
		"tr": "Koşma [Shift / R1]",
		"en": "Sprint [Shift / R1]"
	},
	"action_interact": {
		"tr": "Etkileşim [E / Y]",
		"en": "Interact [E / Y]"
	},
	"action_inspect": {
		"tr": "İncele [F / X]",
		"en": "Inspect [F / X]"
	},
	"action_eat": {
		"tr": "Ye [R / L1]",
		"en": "Eat [R / L1]"
	},
	"kapat": {
		"tr": "KAPAT",
		"en": "CLOSE"
	},
	"geri": {
		"tr": "GERİ",
		"en": "BACK"
	},
	"boss_uyandi": {
		"tr": "BOSS UYANDI!",
		"en": "BOSS AWAKENED!"
	},
	"tebrikler_boss": {
		"tr": "TEBRİKLER! BOSS YENİLDİ.",
		"en": "CONGRATS! BOSS DEFEATED."
	},
	"hasar": {
		"tr": "HASAR: ",
		"en": "DAMAGE: "
	},
	"altin_kazandin": {
		"tr": "+%d Altın Kazandın!",
		"en": "+%d Gold Earned!"
	},
	"campfire_gold_tooltip": {
		"tr": "Açgözlülük: Altın ara (0-30 Gold)",
		"en": "Greed: Search for gold (0-30 Gold)"
	},
	"campfire_sleep_tooltip": {
		"tr": "Dinlenme: Rüyalara dal (+1 Can)",
		"en": "Rest: Fall into dreams (+1 Health)"
	},
	"sec_bir_yol": {
		"tr": "Bir yol seç...",
		"en": "Choose a path..."
	},
	"anubis_konus_etkilesim": {
		"tr": "[E / Y] Konuş",
		"en": "[E / Y] Talk"
	},
	"anubis_diyalog_1": {
		"tr": "Demek bana gelmeye karar verdin.",
		"en": "So you have decided to come to me."
	},
	"anubis_diyalog_2": {
		"tr": "Asırlardır insanlar kutuların içinde, anlamsız bir sona doğru sürüklenip duruyor.",
		"en": "For centuries, humans have been drifting in boxes toward a meaningless end."
	},
	"anubis_diyalog_3": {
		"tr": "Sen de o yığınlardan koptun. İçindeki o çürüyen boşluğu, o bitmek bilmeyen tatminsizliği görebiliyorum.",
		"en": "You too broke away from those masses. I can see that rotting emptiness, that endless dissatisfaction within you."
	},
	"anubis_diyalog_4": {
		"tr": "Buraya kendi iradenle geldiğini sanıyorsun... Halbuki adımların, sen daha doğmadan önce bu kumların üzerine yazılmıştı.",
		"en": "You think you came here of your own will... But your steps were written on these sands before you were even born."
	},
	"anubis_diyalog_5": {
		"tr": "Etrafına bak. Bu maskelerin ardında kimlik yok, acı yok... Sadece ebedi bir adanmışlık var.",
		"en": "Look around. Behind these masks, there is no identity, no pain... Only eternal devotion."
	},
	"anubis_diyalog_6": {
		"tr": "Senin kalbin ise hala dış dünyanın o sahte anılarıyla, o kof arzularla çok ağır. Ma'at'ın terazisinde ezileceksin.",
		"en": "Your heart is still too heavy with the fake memories and hollow desires of the outside world. You will be crushed under Ma'at's scale."
	},
	"anubis_diyalog_7": {
		"tr": "Ama korkma... Seni o yüklerden arındıracağız. Zihnini yavaş yavaş, parça parça soyacağız.",
		"en": "But fear not... We will cleanse you of those burdens. We will strip your mind slowly, piece by piece."
	},
	"anubis_diyalog_8": {
		"tr": "Ölüm bir son değil, yalnızca ilk adımdır. Şimdi diz çök... ve gerçek uyanışını kucakla.",
		"en": "Death is not an end, merely the first step. Now kneel... and embrace your true awakening."
	},
	"anubis_diyalog_9": {
		"tr": "Evine git ve de dönüşü olmayan bu yolculuk için hazırlan!",
		"en": "Go home and prepare for this journey of no return!"
	},
	"anubis_diyalog_10": {
		"tr": "Yakında benden bir haber alacaksın, ölümlü.",
		"en": "You will hear from me soon, mortal."
	}
}

func dili_degistir(yeni_dil: String) -> void:
	if secili_dil != yeni_dil:
		secili_dil = yeni_dil
		dil_degisti.emit()

func metin_al(anahtar: String) -> String:
	if ceviriler.has(anahtar):
		var bolum = ceviriler[anahtar]
		if bolum.has(secili_dil):
			return bolum[secili_dil]
	return anahtar # Bulamazsa kendisini döndür
