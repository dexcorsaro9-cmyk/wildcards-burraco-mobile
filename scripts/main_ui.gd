class_name MainUI
extends CanvasLayer

const AssetLoader = preload("res://scripts/asset_loader.gd")

@onready var bg_texture_rect: TextureRect = $Background
@onready var table_layer: Control = $TableLayer
@onready var blind_box_layer: Control = $BlindBoxLayer
@onready var club_layer: Control = $ClubLayer

@onready var tab_table_btn: Button = $HeaderBar/Nav/TabTable
@onready var tab_box_btn: Button = $HeaderBar/Nav/TabBlindBox
@onready var tab_club_btn: Button = $HeaderBar/Nav/TabClub
@onready var sound_btn: Button = get_node_or_null("HeaderBar/Nav/SoundToggleBtn")

@onready var stock_btn: BaseButton = $TableLayer/CenterArea/StockButton

func _ready() -> void:
    if bg_texture_rect:
        bg_texture_rect.texture = AssetLoader.get_tex("res://assets/table_felt_luxury.png")

    if stock_btn is TextureButton:
        stock_btn.texture_normal = AssetLoader.get_tex("res://assets/card_back_luxury.png")

    tab_table_btn.pressed.connect(func(): switch_tab(0))
    tab_box_btn.pressed.connect(func(): switch_tab(1))
    tab_club_btn.pressed.connect(func(): switch_tab(2))
    if sound_btn:
        sound_btn.pressed.connect(func():
            var audio = get_node_or_null("/root/AudioSynth")
            if audio:
                var is_muted = audio.toggle_mute()
                sound_btn.text = "🔇" if is_muted else "🔊"
        )
    switch_tab(0)

    var all_args = OS.get_cmdline_args() + OS.get_cmdline_user_args()
    for arg in all_args:
        if "test-melds" in arg:
            get_tree().create_timer(0.3).timeout.connect(func():
                var mgr = get_node_or_null("/root/Main/BurracoGameManager")
                if mgr:
                    var CardData = preload("res://scripts/card_data.gd")
                    var Rules = preload("res://scripts/rules.gd")
                    # 1. Player Burraco Pulito (Spades 3 to 9)
                    var m1 = Rules.BurracoMeld.new()
                    m1.type = Rules.MeldType.SEQUENCE
                    m1.suit = CardData.Suit.SPADES
                    for r in [CardData.Rank.THREE, CardData.Rank.FOUR, CardData.Rank.FIVE, CardData.Rank.SIX, CardData.Rank.SEVEN, CardData.Rank.EIGHT, CardData.Rank.NINE]:
                        m1.cards.append(CardData.create_card(100 + r, CardData.Suit.SPADES, r))
                    mgr.player_melds.append(m1)

                    # 2. Player Burraco Semipulito (Spades Pinella Dragon + 3..8)
                    var m2 = Rules.BurracoMeld.new()
                    m2.type = Rules.MeldType.SEQUENCE
                    m2.suit = CardData.Suit.SPADES
                    var p_card = CardData.create_card(200, CardData.Suit.SPADES, CardData.Rank.TWO)
                    m2.cards.append(p_card)
                    for r in [CardData.Rank.THREE, CardData.Rank.FOUR, CardData.Rank.FIVE, CardData.Rank.SIX, CardData.Rank.SEVEN, CardData.Rank.EIGHT]:
                        m2.cards.append(CardData.create_card(200 + r, CardData.Suit.SPADES, r))
                    mgr.player_melds.append(m2)

                    # 3. Opponent Burraco Sporco (Joker + Hearts 4..9)
                    var m3 = Rules.BurracoMeld.new()
                    m3.type = Rules.MeldType.SEQUENCE
                    m3.suit = CardData.Suit.HEARTS
                    var j_card = CardData.create_card(300, CardData.Suit.JOKER, CardData.Rank.NONE, 0, true)
                    m3.cards.append(j_card)
                    for r in [CardData.Rank.FOUR, CardData.Rank.FIVE, CardData.Rank.SIX, CardData.Rank.SEVEN, CardData.Rank.EIGHT, CardData.Rank.NINE]:
                        m3.cards.append(CardData.create_card(300 + r, CardData.Suit.HEARTS, r))
                    mgr.opponent_melds.append(m3)

                    # Also add a Joker to the player hand to showcase it in the hand fan
                    var hand_joker = CardData.create_card(999, CardData.Suit.JOKER, CardData.Rank.JOKER, 0, true)
                    mgr.player_hand.insert(0, hand_joker)

                    mgr.refresh_all_ui()
            )

        if "screenshot" in arg:
            get_tree().create_timer(1.2).timeout.connect(func():
                var img = get_viewport().get_texture().get_image()
                var p = ProjectSettings.globalize_path("res://assets/game_screenshot.png")
                var err = img.save_png(p)
                print("SCREENSHOT_SAVED: ", p, " err=", err)
                get_tree().quit()
            )

func switch_tab(idx: int) -> void:
    table_layer.visible = (idx == 0)
    blind_box_layer.visible = (idx == 1)
    club_layer.visible = (idx == 2)
