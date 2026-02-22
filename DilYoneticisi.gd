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
