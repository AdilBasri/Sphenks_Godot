extends Node

## BossManager (Compatibility Layer)
## KatmanBitisYoneticisi tarafından beklenen carry_over_ekle metodunu sağlar.

func carry_over_ekle(tip: int, hp: int):
	if GameManager:
		GameManager.boss_kacti_ekle(tip, hp)
		print("👹 BossManager: Boss carry-over'a eklendi (Tip: %d, HP: %d)" % [tip, hp])
