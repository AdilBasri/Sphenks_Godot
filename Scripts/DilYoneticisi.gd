extends Node

# Global Sinyal - Tüm UI'lar dinleyecek
signal dil_degisti

# Aktif dil (Default is English now)
var secili_dil: String = "en" 

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
	},
	"besle": {
		"tr": "[E] Besle",
		"en": "[E] Feed"
	},
	"oku": {
		"tr": "[E] Oku",
		"en": "[E] Read"
	},
	"depo_mektup": {
		"tr": "Onu besleyenler onun bir\nparcasi olur, ben besledim\nve geldigim nokta bu.\n\nKac kurtar kendini!.",
		"en": "Those who feed it become\na part of it, I fed it\nand this is where I ended up.\n\nRun and save yourself!."
	},
	"kapidan_cik": {
		"tr": "[E] Kapıdan Çık",
		"en": "[E] Exit Through Door"
	},
	"depo_anubis_1": {
		"tr": "Emeklerin için çok yaşa, şimdi bizden birisin işte.",
		"en": "Long live for your efforts, now you are one of us."
	},
	"depo_anubis_2": {
		"tr": "Sphenks'e dön ve benden haber bekle!",
		"en": "Return to Sphenks and wait for word from me!"
	},
	"birak": {
		"tr": "[Sol Tık] Bırak",
		"en": "[Left Click] Drop"
	},
	"surmeyi_birak": {
		"tr": "[E] Sürmeyi Bırak",
		"en": "[E] Stop Driving"
	},
	"kahin_gozu_isim": {
		"tr": "Kahin'in Gözü",
		"en": "Seer's Eye"
	},
	"kahin_gozu_aciklama": {
		"tr": "Boss'un bir sonraki turda ne yapacağını\nturun başında gösterir.",
		"en": "Shows what the Boss will do\nat the beginning of the next turn."
	},
	"curuk_temel_isim": {
		"tr": "Çürük Temel",
		"en": "Rotten Foundation"
	},
	"curuk_temel_aciklama": {
		"tr": "Tek seferlik panik butonu, masadaki tüm\nasitleri ve taşları temizler.",
		"en": "One-time panic button, clears all\nacids and stones on the table."
	},
	"kanli_indirim_isim": {
		"tr": "Kanlı İndirim",
		"en": "Bloody Discount"
	},
	"kanli_indirim_aciklama": {
		"tr": "Marketteki her şey %50 indirimli ama\nmarkete girdiğin an 3 HP kaybedersin.",
		"en": "Everything in the shop is 50% off but\nyou lose 3 HP the moment you enter."
	},
	"kanli_civi_isim": {
		"tr": "Kanlı Çivi",
		"en": "Bloody Nail"
	},
	"kanli_civi_aciklama": {
		"tr": "Bu özellik masada çapraz\neşleştirmeyi de aktif kılar.",
		"en": "This feature activates diagonal\nmatching on the table as well."
	},
	"kedi_birak": {
		"tr": "[SOL TIK] Kediyi Bırak",
		"en": "[LEFT CLICK] Drop Cat"
	},
	"kedi_al": {
		"tr": "[SOL TIK] Kediyi Eline Al",
		"en": "[LEFT CLICK] Pick Up Cat"
	},
	"altin_kart": {
		"tr": "[E] Altın Kart",
		"en": "[E] Gold Card"
	},
	"uyku_karti": {
		"tr": "[E] Uyku Kartı",
		"en": "[E] Sleep Card"
	},
	"mezbaha_bosalt": {
		"tr": "Boşaltmak için el arabasını\nburada bırak [E]",
		"en": "Leave the wheelbarrow here\nto empty it [E]"
	},
	"mezbaha_yukle": {
		"tr": "Parçaları yüklemek için\n[R] basılı tut",
		"en": "Hold [R] to load the pieces"
	},
	"mezbaha_yerlestir": {
		"tr": "Parçaları el arabasına\nyerleştir (%d/4)",
		"en": "Place pieces in the wheelbarrow\n(%d/4)"
	},
	"baltayi_al": {
		"tr": "[E] Baltayı Al",
		"en": "[E] Take Axe"
	},
	"baltayi_as": {
		"tr": "[E] Baltayı Yerine As",
		"en": "[E] Hang Axe Back"
	},
	"anahtar_al": {
		"tr": "(E) Anahtarı Al",
		"en": "(E) Take Key"
	},
	"kilitli_kapi_anahtari_lazim": {
		"tr": "Kilitli - Kapı Anahtarı Lazım",
		"en": "Locked - Door Key Needed"
	},
	"sandigi_ac": {
		"tr": "(E) Sandığı Aç",
		"en": "(E) Open Chest"
	},
	"kilitli_masadan_anahtar_al": {
		"tr": "Kilitli - Masadan Anahtarı Al",
		"en": "Locked - Take Key from Table"
	},
	"sandik_anahtari_alindi": {
		"tr": "🗝️ Sandık Anahtarı alındı!",
		"en": "🗝️ Chest Key received!"
	},
	"cikis_anahtari_alindi": {
		"tr": "🚪 Çıkış Anahtarı alındı!",
		"en": "🚪 Exit Key received!"
	},
	"sandik_anahtari_kirildi": {
		"tr": "💥 Sandık Anahtarı Kırıldı! Daha fazla sandık açılamaz.",
		"en": "💥 Chest Key Broke! No more chests can be opened."
	},
	"kahin_gozu_bilgi": {
		"tr": "👁️ Kahin'in Gözü: Boss'un sıradaki hamlesini göreceksin!",
		"en": "👁️ Seer's Eye: You will see the boss's next move!"
	},
	"curuk_temel_bilgi": {
		"tr": "🪄 Çürük Temel: Envanterinde! Grid'i temizler.",
		"en": "🪄 Rotten Foundation: In inventory! Clears the grid."
	},
	"kanli_indirim_bilgi": {
		"tr": "💀 Kanlı İndirim: Market %50 indirimli ama -3 HP!",
		"en": "💀 Bloody Discount: Shop 50% off but -3 HP!"
	},
	"kanli_civi_bilgi": {
		"tr": "🩸 Kanlı Çivi: Çapraz hareketler artık patlıyor!",
		"en": "🩸 Bloody Nail: Diagonal moves now explode!"
	},
	"bos_sandik_hasar": {
		"tr": "💀 Boş sandık! -3 HP!",
		"en": "💀 Empty chest! -3 HP!"
	},
	"anahtar_hazir_cikis": {
		"tr": "🗝️ Anahtar hazır! Artık çıkabilirsin.",
		"en": "🗝️ Key ready! You can leave now."
	},
	"intro_diyalog_1": {
		"tr": "Bu biçimsiz insan kalabalığından sıkıldım artık...",
		"en": "I'm tired of this shapeless crowd of people..."
	},
	"intro_diyalog_2": {
		"tr": "Hepsi aynı tornadan çıkmış et yığınları.",
		"en": "Masses of meat, all from the same mold."
	},
	"intro_diyalog_3": {
		"tr": "Gördüklerini anlamayıp, inandıklarını görüyorlar.",
		"en": "They don't understand what they see, they see what they believe."
	},
	"intro_diyalog_4": {
		"tr": "İmkanım olsa şu lanet yerde bir dakika durmam.",
		"en": "If I could, I wouldn't stay in this damn place for a minute."
	},
	"intro_diyalog_5": {
		"tr": "Biçimsiz yüzler ve anlamsız sözler...",
		"en": "Shapeless faces and meaningless words..."
	},
	"intro_diyalog_6": {
		"tr": "Bu düzenin düzensizliğinden yoruldum.",
		"en": "I'm tired of the disorder of this order."
	},
	"intro_diyalog_7": {
		"tr": "Bir süre ortadan kaybolsam kimsenin ruhu bile duymaz.",
		"en": "If I disappeared for a while, no one would even notice."
	},
	"intro_diyalog_8": {
		"tr": "Eğer bir gün burayı terk etseydim acaba nereye giderdim?",
		"en": "If I left here one day, I wonder where I would go?"
	},
	"baltayi_eline_al": {
		"tr": "Baltayı eline al",
		"en": "Take the axe"
	},
	"eti_parcala": {
		"tr": "Eti parçala",
		"en": "Chop the meat"
	},
	"tekrar": {
		"tr": "TEKRAR!",
		"en": "AGAIN!"
	},
	"yukleniyor": {
		"tr": "Yükleniyor...",
		"en": "Loading..."
	},
	"ogutuluyor": {
		"tr": "Öğütülüyor...",
		"en": "Grinding..."
	},
	"uyku_diyalog_1": {
		"tr": "S*ktir, s*ktir, s*ktir!",
		"en": "F*ck, f*ck, f*ck!"
	},
	"uyku_diyalog_2": {
		"tr": "Uyanmam lazım!\nBu gerçek olamaz!",
		"en": "I need to wake up!\nThis can't be real!"
	},
	"uyku_diyalog_3": {
		"tr": "Evet! Parmaklarım...\nEğer rüyadaysam onları sayamamam gerekir!",
		"en": "Yes! My fingers...\nIf I'm in a dream, I shouldn't be able to count them!"
	},
	"uyku_parmak_say": {
		"tr": "Parmaklarını Say...",
		"en": "Count Your Fingers..."
	},
	"uyku_cevap": {
		"tr": "Cevap?",
		"en": "Answer?"
	},
	"uyku_yanlis": {
		"tr": "Yanlış! Tekrar Say...",
		"en": "Wrong! Count Again..."
	},
	"gorev_tamamlandi": {
		"tr": "GÖREV TAMAMLANDI!",
		"en": "MISSION ACCOMPLISHED!"
	},
	"mezbaha_surukle": {
		"tr": "El arabasını et\nparçalayıcısına sürükle",
		"en": "Drag the wheelbarrow\nto the meat grinder"
	},
	"tut_baslik_1": { "tr": "EĞİTİM: SPHENKS'E HOŞ GELDİN", "en": "TUTORIAL: WELCOME TO SPHENKS" },
	"tut_metin_1": { "tr": "Sphenks'e hoş geldin! Temelde yapman gereken şey çok basit:\n\nKarşındaki firavunu alt etmek için elinde çeşitli bloklar var. Bu blokları satır ve sütun olarak dizip patlatarak firavuna hasar verebilir ve onu yoldan kaldırabilirsin!", "en": "Welcome to Sphenks! What you need to do is very simple:\n\nYou have various blocks to defeat the pharaoh in front of you. You can damage the pharaoh and clear him out of the way by arranging these blocks in rows and columns and popping them!" },
	"tut_ipucu_1": { "tr": "(Devam etmek için [SOL TIK] / [A] tuşuna bas)", "en": "(Press [LEFT CLICK] / [A] to continue)" },
	"tut_baslik_2": { "tr": "ADIM 1: OYUN ALANINA GEÇİŞ", "en": "STEP 1: ENTER THE GAME AREA" },
	"tut_metin_2": { "tr": "Oyunu başlatmak için önce tabureye oturmalısın.\nMasaya yaklaş ve otur.", "en": "To start the game, you must first sit on the stool.\nApproach the table and sit." },
	"tut_ipucu_2": { "tr": "(Tabureye odaklanıp [E] veya [Y] tuşuna bas)", "en": "(Focus on the stool and press [E] or [Y])" },
	"tut_baslik_3": { "tr": "ADIM 2: BLOKLARI SÜRÜKLE", "en": "STEP 2: DRAG THE BLOCKS" },
	"tut_metin_3": { "tr": "Sol tarafta voidden çıkan bloklar yer alıyor. Blokları tıklayıp basılı tutarak istediğin gibi sürükleyebilir ve masadaki ızgaraya (grid) bırakabilirsin!", "en": "Blocks emerging from the void are located on the left. You can drag the blocks as you wish by clicking and holding, and place them on the grid on the table!" },
	"tut_ipucu_3": { "tr": "(Farenin Sol Tuşuna veya [A] tuşuna basılı tutarak bloğu masaya çek)", "en": "(Hold Left Mouse Button or [A] to drag the block to the table)" },
	"tut_baslik_4": { "tr": "ADIM 3: MASAYA BAKIŞ", "en": "STEP 3: VIEWING THE TABLE" },
	"tut_metin_4": { "tr": "Kamerayı ayarlamak masayı daha iyi görmeni sağlar.\n[A] ve [D] tuşlarıyla (Gamepad: LT / RT) masaya baktığın konumu sağa ve sola çevirebilirsin.\n\nŞimdi blokları dizerek bir satır veya sütun patlatmayı dene!", "en": "Adjusting the camera allows you to see the table better.\nYou can turn your view left and right with [A] and [D] (Gamepad: LT / RT).\n\nNow try popping a row or column by arranging blocks!" },
	"tut_ipucu_4": { "tr": "(Devam etmek için [SOL TIK] / [A] tuşuna bas)", "en": "(Press [LEFT CLICK] / [A] to continue)" },
	"tut_baslik_5": { "tr": "ADIM 4: FİRAVUNUN UYANIŞI", "en": "STEP 4: PHARAOH'S AWAKENING" },
	"tut_metin_5": { "tr": "DİKKAT! Satır patlattıktan sonra blokların çıkarttığı ses firavunu derin uykusundan uyandırır.\n\nUyanan firavun artık HER blok yerleştirmenden sonra sana ölümcül bir saldırı yapacaktır!", "en": "ATTENTION! The sound blocks make after popping a row wakes the pharaoh from his deep sleep.\n\nThe awakened pharaoh will now make a deadly attack on you after EVERY block you place!" },
	"tut_ipucu_5": { "tr": "(Devam etmek için [SOL TIK] / [A] tuşuna bas)", "en": "(Press [LEFT CLICK] / [A] to continue)" },
	"tut_baslik_6": { "tr": "ADIM 5: SAVUŞTURMA (BEKLE)", "en": "STEP 5: PARRY (WAIT)" },
	"tut_metin_6": { "tr": "Boss sana saldırmak üzere! Suratını ekranda gördüğün an tepki vermeye hazır ol...\n(Saldırıyı bekle)", "en": "The Boss is about to attack! Be ready to react the moment you see his face on screen...\n(Wait for the attack)" },
	"tut_ipucu_6": { "tr": "(Saldırı bekleniyor...)", "en": "(Waiting for attack...)" },
	"tut_baslik_7": { "tr": "HAZIR OL: PARRY YAP!", "en": "GET READY: PARRY!" },
	"tut_metin_7": { "tr": "Doğru zamanda PARRY (Savuşturma) yaparak boss atağını bloke edebilirsin!", "en": "You can block the boss attack by performing a PARRY at the right time!" },
	"tut_ipucu_7": { "tr": "(SAĞ TIK / [B] tuşuna basarak Savuşturur!)", "en": "(Press RIGHT CLICK / [B] to Parry!)" },
	"tut_baslik_8": { "tr": "ADIM 6: HAYALET HAMLE", "en": "STEP 6: GHOST MOVE" },
	"tut_metin_8": { "tr": "Mükemmel! Bir saldırıyı başarıyla savuşturduğunda, 5 saniyelik bir 'HAYALET HAMLE' penceresi kazanırsın.\n\nBu 5 saniye içinde masaya yerleştirdiğin bloklar Boss tarafından GÖRÜLMEZ. Sıranı kullanmadan kombo yapabilirsin!", "en": "Excellent! When you successfully parry an attack, you gain a 5-second 'GHOST MOVE' window.\n\nBlocks you place on the table during these 5 seconds are INVISIBLE to the Boss. You can combo without using your turn!" },
	"tut_ipucu_8": { "tr": "(Devam etmek için [SOL TIK] / [A] tuşuna bas)", "en": "(Press [LEFT CLICK] / [A] to continue)" },
	"tut_baslik_9": { "tr": "ADIM 7: HAYALET HAMLEYİ KULLAN", "en": "STEP 7: USE GHOST MOVE" },
	"tut_metin_9": { "tr": "Şimdi hızlı ol! Devam ettiğinde oyun süresi donacak, 5 saniyen var gibi düşünerek hemen bir blok alıp masaya yerleştir!", "en": "Now be quick! The game time will freeze when you continue, think as if you have 5 seconds and immediately take a block and place it on the table!" },
	"tut_ipucu_9": { "tr": "(Süre dondu... Hızlıca bir blok alıp masaya koy)", "en": "(Time is frozen... Quickly take a block and put it on the table)" },
	"tut_baslik_10": { "tr": "ADIM 8: AYAĞA KALKMA", "en": "STEP 8: STANDING UP" },
	"tut_metin_10": { "tr": "Masa başından kalkıp odanın geri kalanını keşfetmen gerekecek.\n\nTekrar [E] / [Y] tuşuna basarak masadan kalkıp odada gezebilirsin.", "en": "You'll need to get up from the table and explore the rest of the room.\n\nPress [E] / [Y] again to get up from the table and walk around the room." },
	"tut_ipucu_10": { "tr": "(Masadan kalkmak için [E] / [Y] tuşuna bas)", "en": "(Press [E] / [Y] to get up from the table)" },
	"tut_baslik_11": { "tr": "ADIM 9: ÖZEL EŞYALAR", "en": "STEP 9: SPECIAL ITEMS" },
	"tut_metin_11": { "tr": "Yan sehpada beliren Ruh Mantarı'na bak! Üzerine tıklayarak onu eline al.\n\nArdından havaya bakarak [SOL TIK] / [A] tuşuna basıp mantarı tüket!", "en": "Look at the Spirit Mushroom that appeared on the side table! Click on it to take it in your hand.\n\nThen look up and press [LEFT CLICK] / [A] to consume the mushroom!" },
	"tut_ipucu_11": { "tr": "(Mantarı sol tıkla eline al, tekrar sol tıkla tüket)", "en": "(Left click to take mushroom, left click again to consume)" },
	"tut_baslik_12": { "tr": "ADIM 10: EFEKTLER GÜZELDİR", "en": "STEP 10: EFFECTS ARE NICE" },
	"tut_metin_12": { "tr": "Vuhu! İşte şimdi ortama biraz renk geldi değil mi!\n\nMasaya dönmek için tekrar tabureye [E] ile otur.", "en": "Woohoo! Now the place has some color, right!\n\nSit on the stool with [E] again to return to the table." },
	"tut_ipucu_12": { "tr": "(Tabureye tekrar otur)", "en": "(Sit on the stool again)" },
	"tut_baslik_13": { "tr": "ADIM 11: RENK KOMBOLARI", "en": "STEP 11: COLOR COMBOS" },
	"tut_metin_13": { "tr": "Aynı renk blokları yan yana patlatmak sana ekstra bölüm içi puan (Altın) kazandırır!\n\nAma şunu unutma; marketten alınan ve kullanılan her nesne SADECE o bölüm için geçerlidir. Sonraki katmanlara taşınmaz!", "en": "Popping blocks of the same color adjacent to each other earns you extra in-level points (Gold)!\n\nBut remember; every item bought from the shop and used is ONLY valid for that level. They don't carry over to next layers!" },
	"tut_ipucu_13": { "tr": "(Devam etmek için [SOL TIK] / [A] tuşuna bas)", "en": "(Press [LEFT CLICK] / [A] to continue)" },
	"tut_baslik_14": { "tr": "ADIM 12: KAPIDAN GEÇİŞ", "en": "STEP 12: GOING THROUGH THE DOOR" },
	"tut_metin_14": { "tr": "Firavunu ortadan kaldırdığında bölüm biter!\n\nAçık olan kapıdan geçip bir sonraki asansör odasına varırsın. Orada iki yön belirir: SOL'da MARKET çatallanması, SAĞ'da ise CAMPFIRE yer alır. Tercih senin!", "en": "The level ends when you eliminate the Pharaoh!\n\nPass through the open door to reach the next elevator room. There, two paths appear: SHOP on the LEFT, CAMPFIRE on the RIGHT. The choice is yours!" },
	"tut_ipucu_14": { "tr": "(Eğitimi bitirmek için [SOL TIK] / [A] tuşuna bas)", "en": "(Press [LEFT CLICK] / [A] to end tutorial)" },
	"tut_baslik_15": { "tr": "PYRO MODU: MERMİ DİKKATİ", "en": "PYRO MODE: AMMO ATTENTION" },
	"tut_metin_15": { "tr": "Düşmanlar üzerine akın ederken, tabancanla (Revolver) onları yok edebilirsin.\n\nMermine dikkat et! Sınırlı sayıdalar.", "en": "Defeat enemies with your revolver as they swarm towards you.\n\nWatch your ammo! They are limited." },
	"tut_ipucu_15": { "tr": "(Ateş etmek için [SOL TIK] / [A] tuşuna bas)", "en": "(Press [LEFT CLICK] / [A] to fire)" },
	"tut_baslik_16": { "tr": "PYRO MODU: SAĞLIK YENİLEME", "en": "PYRO MODE: HEALTH REGENERATION" },
	"tut_metin_16": { "tr": "Düşmanlardan düşen et parçaları olacak.\n\nOnları toplayıp [R] / [L1] tuşu ile tüketebilirsin. İşler ters gittiğinde kaybettiğin canını geri doldurmanın tek yolu budur!", "en": "There will be pieces of meat dropped from enemies.\n\nYou can collect and consume them with [R] / [L1]. This is the only way to refill lost health when things go wrong!" },
	"tut_ipucu_16": { "tr": "(Devam etmek için [SOL TIK] / [A] tuşuna bas)", "en": "(Press [LEFT CLICK] / [A] to continue)" },
	"yetersiz_bakiye": { "tr": "Yetersiz Bakiye!", "en": "Insufficient Funds!" },
	"envanter_dolu": { "tr": "Envanter Dolu!", "en": "Inventory Full!" },
	"kan_bedeli_odendi": { "tr": "💩 KAN bedeli ödendi: -3 HP! Ama her şey %50 indirimli!", "en": "💩 Blood price paid: -3 HP! But everything is 50% off!" },
	"kombo": { "tr": "KOMBO x%d", "en": "COMBO x%d" },
	"altin_kazandin_mesaj": { "tr": " (+%d ALTIN)", "en": " (+%d GOLD)" },
	"guc_iksiri_duv": { "tr": " (GÜÇ x1.3)", "en": " (POWER x1.3)" },
	"renk_bonusu": { "tr": " (RENK BONUSU)", "en": " (COLOR BONUS)" },
	"boss_karar_veriyor": { "tr": "BOSS KARAR VERİYOR...", "en": "BOSS IS DECIDING..." },
	"kaya_firlatiyor": { "tr": "KAYA FIRLATIYOR!", "en": "THROWING ROCKS!" },
	"asit_tukuruyor": { "tr": "ASİT TÜKÜRÜYOR!", "en": "SPITTING ACID!" },
	"zar_atiyor": { "tr": "ZAR ATIYOR!", "en": "ROLLING DICE!" },
	"kedi_diyalog_0": { "tr": "[shake rate=20 level=10]Seni aptal insan![/shake] Buraya gelmemeliydin.", "en": "[shake rate=20 level=10]You foolish human![/shake] You shouldn't have come here." },
	"kedi_secim_0_1": { "tr": "Neden?", "en": "Why?" },
	"kedi_secim_0_2": { "tr": "Seni ilgilendirmez.", "en": "None of your business." },
	"kedi_diyalog_1": { "tr": "Sayamadığım kadar çok yıldır bu tünellerde iğrenç yaratıklar arasında geziyorum...", "en": "I've been wandering among these disgusting creatures in these tunnels for more years than I can count..." },
	"kedi_secim_1": { "tr": "Devam Et", "en": "Continue" },
	"kedi_diyalog_2": { "tr": "Merak etme, firavunun hazinesi için buradasın değil mi? Hehe...", "en": "Don't worry, you're here for the pharaoh's treasure, right? Hehe..." },
	"kedi_secim_2_1": { "tr": "Öyle bir şey mi var?", "en": "Is there such a thing?" },
	"kedi_secim_2_2": { "tr": "Elbette!", "en": "Of course!" },
	"kedi_diyalog_3": { "tr": "Para benim için çöp! Ama şanslısın, BANA sahipsin. Beni besle, ben de seni yaşatayım.", "en": "Money is trash to me! But you're lucky, you have ME. Feed me, and I'll keep you alive." },
	"kedi_secim_3": { "tr": "Tamam (Eğitimi Başlat)", "en": "Okay (Start Tutorial)" },
	"bloklar_bitene_kadar": { "tr": "\nBlokların bitene kadar kazanmaya devam et!", "en": "\nKeep winning until you run out of blocks!" },
	"kahin_gozu_baslik": { "tr": "👁️ KAHİN GÖZÜ • ", "en": "👁️ SEER'S EYE • " },
	"sira_kaya": { "tr": "🪨 Sıra: KAYA", "en": "🪨 Next: ROCK" },
	"sira_asit": { "tr": "🧪 Sıra: ASİT", "en": "🧪 Next: ACID" },
	"sira_zar": { "tr": "🎲 Sıra: ZAR", "en": "🎲 Next: DICE" },
	"duraklatildi": { "tr": "DURAKLATILDI", "en": "PAUSED" },
	"oyun_bitti": { "tr": "OYUN BİTTİ", "en": "GAME OVER" },
	"asansor_odasi": { "tr": "ASANSÖR ODASI", "en": "ELEVATOR ROOM" },
	"sandik_odasi_baslik": { "tr": "SANDIK ODASI", "en": "CHEST ROOM" },
	"yetersiz_puan": { "tr": "YETERSİZ PUAN - KAYBETTİN", "en": "INSUFFICIENT SCORE - YOU LOST" },
	"yer_kalmadi": { "tr": "MASADA YER KALMADI - KAYBETTİN", "en": "NO SPACE LEFT ON TABLE - YOU LOST" },
	"zar_kirici_aktif": { "tr": "Zar Kırıcı: Düşman Tek Zar Atacak!", "en": "Dice Breaker: Enemy Will Roll Single Dice!" },
	"pelerin_aktif_bilgi": { "tr": "Pelerin Aktif: 3 Tur Koruma!", "en": "Cloak Active: 3 Turns Protection!" },
	"kedi_beslendi": { "tr": "Kedi Beslendi! Oyun Kaydedildi.", "en": "Cat Fed! Game Saved." },
	"sadece_kedi_yer": { "tr": "Bunu sadece Kedi yiyebilir!", "en": "Only the Cat can eat this!" },
	"guc_iksiri_aktif": { "tr": "🧪 GÜÇ İKSİRİ İÇİLDİ! (Puanlar x1.3)", "en": "🧪 POWER POTION DRINKED! (Score x1.3)" },
	"revive_aktif_bilgi": { "tr": "😇 REVIVE AKTİF! (Ölürsen Canlanırsın)", "en": "😇 REVIVE ACTIVE! (Auto-respawn on death)" },
	"yarasalar_dondu": { "tr": "🔦 FENER AÇILDI! (Yarasalar Dondu)", "en": "🔦 LANTERN OPEN! (Bats Frozen)" },
	"kumsaati_aktif": { "tr": "⏳ KUMSAATİ: Zaman yavaşlıyor...", "en": "⏳ HOURGLASS: Time is slowing down..." },
	"kaldigin_yerden": { "tr": "KALDIĞIN YERDEN", "en": "CONTINUE" },
	"anahtar_yok": { "tr": "Kilitli (Çıkış Anahtarı Lazım)", "en": "Locked (Exit Key Needed)" },
	"puan_yok": { "tr": "puan yok", "en": "no points" },
	"renk_uyumu": { "tr": "Renk Uyumu", "en": "Color Match" },
	"seviye_atladin": { "tr": "SEVİYE ATLADIN!", "en": "LEVEL UP!" },
	"oyun_tuslari_baslik": { "tr": "OYUN TUŞLARI", "en": "GAME CONTROLS" },
	"time_isi": { "tr": "Kumsaati", "en": "Hourglass" },
	"time_ac": { "tr": "Pyro modunda düşman hızını %50 azaltır.", "en": "Reduces enemy speed by 50% in Pyro mode." },
	"fener_isi": { "tr": "Kör Fener", "en": "Blind Lantern" },
	"fener_ac": { "tr": "Pyro modunda düşmanları dondurur.", "en": "Freezes enemies in Pyro mode." },
	"paint_isi": { "tr": "Simyacı Fırçası", "en": "Alchemist's Brush" },
	"paint_ac": { "tr": "Seçilen bir bloku \"Gökkuşağı\" rengine boyar. Her renkle eşleşir.", "en": "Paints a selected block in \"Rainbow\" color. Matches every color." },
	"asit_isi": { "tr": "Asit Şişesi", "en": "Acid Bottle" },
	"asit_ac": { "tr": "Sütundaki tüm blokları yok eder (puan yok).", "en": "Destroys all blocks in the column (no points)." },
	"kilic_isi": { "tr": "Kılıç", "en": "Sword" },
	"kilic_ac": { "tr": "Seçilen TEK BİR bloku paramparça eder.", "en": "Shatters a SINGLE selected block." },
	"magnet_isi": { "tr": "Mıknatıs", "en": "Magnet" },
	"magnet_ac": { "tr": "Griddeki tüm blokları en alta indirir.", "en": "Pull all blocks in the grid to the bottom." },
	"revive_isi": { "tr": "Canlandırıcı İçecek", "en": "Revive Drink" },
	"revive_ac": { "tr": "Son anda ölümden kurtarır.", "en": "Saves you from death at the last second." },
	"mama_isi": { "tr": "Kedi Maması", "en": "Cat Food" },
	"mama_ac": { "tr": "Oyunu kaydetmek için kediyi besle!", "en": "Feed the cat to save the game!" },
	"dice_isi": { "tr": "Kaos Zarı", "en": "Chaos Dice" },
	"dice_ac": { "tr": "Düşmanın attığı zar sayısı 1'e düşer.", "en": "Enemy's dice count drops to 1." },
	"cloak_isi": { "tr": "Pelerin", "en": "Cloak" },
	"cloak_ac": { "tr": "3 tur boyunca zar atma sekansını atlar.", "en": "Skips the dice-throwing sequence for 3 turns." },
	"mantar_isi": { "tr": "Mantar", "en": "Mushroom" },
	"mantar_ac": { "tr": "Renk bonusu kazandırır.", "en": "Grants a color bonus." },
	"guc_isi": { "tr": "Altın Şerbet", "en": "Gold Sherbet" },
	"guc_ac": { "tr": "Bölümde kazanılan puanları 1.3x çarpar.", "en": "Multiplies earned score by 1.3x in the level." },
	"mermi_isi": { "tr": "Mermi Kutusu", "en": "Ammo Crate" },
	"mermi_ac": { "tr": "İçinden 8 mermi çıkar.", "en": "Contains 8 bullets." },
	"dig_isi": { "tr": "Altın Kazma", "en": "Gold Pickaxe" },
	"dig_ac": { "tr": "Bir bloku kırar ve anında +10 Altın verir.", "en": "Breaks a block and instantly grants +10 Gold." },
	"ev_diyalog_1": { "tr": "Mısır hep ilgimi çekmiştir...", "en": "Egypt has always interested me..." },
	"ev_diyalog_2": { "tr": "Bu ziyaret aklımda bazı şeyleri toplamama yardım edebilir.", "en": "This visit might help me put some things in order in my mind." },
	"ev_diyalog_3": { "tr": "Buralardan bir süreliğine uzaklaşmak...", "en": "To get away from here for a while..." },
	"ev_diyalog_4": { "tr": "Bunu değerlendirebilirim, evet.", "en": "I can consider this, yes." },
	"ev_diyalog_5": { "tr": "Ve gidersem, eminim kimse benim yokluğumu fark etmeyecektir bile.", "en": "And if I go, I'm sure no one would even notice my absence." },
	"ev_diyalog_6": { "tr": "İki gün sonra öğlen kalkıyor uçak.", "en": "The plane takes off at noon in two days." },
	"ev_diyalog_7": { "tr": "Öyleyse... Mısır'a gidiyoruz demek.", "en": "So... we are going to Egypt then." },
	"feda_edildi": { "tr": "%s feda edildi. (%d/%d)", "en": "%s sacrificed. (%d/%d)" },
	"rituel_eksik": { "tr": "Ritüel için daha fazla eşya gerekiyor.", "en": "More items are needed for the ritual." },
	"rituel_tamamlandi": { "tr": "GEÇMİŞ ÖĞÜTÜLDÜ...", "en": "THE PAST HAS BEEN GRINDED..." },
	"kapi_altindan_bilet": { "tr": "Kapının altından bir şey atıldı...", "en": "Something was thrown under the door..." },
	"misir_diyalog_1": { "tr": "Buraya kadar gelebileceğimi düşünmemiştim.", "en": "I didn't think I could make it this far." },
	"misir_diyalog_2": { "tr": "Bunu tarikat için filan yapmıyorum, hayır.", "en": "I'm not doing this for the cult or anything, no." },
	"misir_diyalog_3": { "tr": "Zaten pek inançlı da sayılmam...", "en": "I'm not much of a believer anyway..." },
	"misir_diyalog_4": { "tr": "Ama beni bu dünyadan biraz koparabilecek her şeye razıyım şuanda.", "en": "But right now I'm willing to do anything that\ncan detach me from this world." },
	"misir_diyalog_5": { "tr": "Bu ziyaret de tam olarak bunu sağlıyor işte!", "en": "And this visit provides exactly that!" },
	"misir_diyalog_6": { "tr": "İçeride nelerle karşılaşacağımı bilmiyorum.", "en": "I don't know what I'm going to face inside." },
	"misir_diyalog_7": { "tr": "İnsanlar bunun tehlikeli olabileceğini söylüyor, uzaylı zırvaları filan!", "en": "People say it could be dangerous, alien nonsense and stuff!" },
	"misir_diyalog_8": { "tr": "Görevimi tamamladıktan sonra belki...", "en": "Maybe after completing my mission..." },
	"misir_diyalog_9": { "tr": "Bir süre daha buralarda vakit geçirebilirim...", "en": "I can spend some more time around here..." },
	"Eşya": { "tr": "Eşya", "en": "Item" }
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
