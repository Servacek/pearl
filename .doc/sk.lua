server_utils_backend = {
    configuration_options = {
        -- Nastavením na false
        -- sa vypne kompletne celé odosielanie logov na discord.
        -- To zahŕňa napríklad aj správy o chybách a pod.
        DISCORD_LOGS = true, -- [true | false], default = true
        WEBHOOK_ID = "",
        WEBHOOK_TOKEN = "",
        -- Udáva v sekundách interval odosielania správ z cache na discord
        -- Nastavením na 0 sa cache vypne (nedoporučujem)
        REQUEST_FREQUENCY = 4, -- [..3, 4, 5...], default = 4

        -- Určuje interval kontrolovania verzie servera v minútach
        -- Nastavením na 0 sa táto funkcia vypne
        VERSION_CHECK_FREQUENCY = 10, -- [..5, 10, 15...], default = 10
        -- Určuje čas v minútach po ktorom sa má server aktualizovať (vypnúť)
        -- v prípade že nieje prázdny.
        -- Nastavením na 0 sa vypnú automatické aktualizácie ak server prázdny nieje.
        UPDATE_SERVER_AFTER = 5, -- [..5, 10, 15...], default = 5

        -- Určuje či má mod používať defaultný scheduler od Klei alebo môj špeciálny WallSheduler :P
        -- Rozdiel je v tom taký, že WallSchduler funguje aj keď je server pauznutý, teda stále.
        -- To môže byť užitočné napríklad pri overovaní verzie servera a detekovaní nových
        -- aktualizácií, kedy chceme aby tato úloha fungovala aj v prípade že na serveri nikto nehrá
        -- (napr. v noci kedy vychádza väčšina hotfixov).
        USE_WALL_SCHEDULER = true, -- [true | false], default = true

        -- Logovanie podozrivých inventárov na discord po odpojení hráča, aktuálne sa za podozrivý inventár považuje taký,
        -- ktorý obsahuje nejaký item na zozname monitorovaných itemov (napr. Deerclops Eyeball, Mandrake a pod.).
        -- Tento systém by bolo dobré do budúcna nejako vylepšiť, možno pridať nejaký spôsob overenia napríklad cez nahraté dni na serveri.
        -- Zoznam monitorovaných itemov sa dá nájsť v scripts/prefabs.lua
        LOG_SUSPICIOUS_INVENTORIES = true, -- [true | false], default = true

        -- Automatické hasenie ohňov po pokuse o zapálenie základne.
        FIRE_PROTECTION = true, -- [true | false], default = true
        -- Automatické kickovanie hráčov po zadanom počte pokusov o zapálenie základne.
        -- Nastavením na 0 sa táto funkcia vypne.
        MAX_FIRE_ATTEMPTS = 3, -- [...2, 3, 4...], default = 3

        -- Garantovaný Triple Mactusk
        FORCE_MACTUSK = false, -- [true, | false], default = false

        -- Oznamy o šírení ohňa
        IGNITE = true, -- [true, | false], default = true
        -- Oznamy o dohorení štruktúr
        BURNTUP = true, -- [true, | false], default = true
        -- Oznamy o rozbití štruktúr
        DESTROY = true, -- [true, | false], default = true
        -- Oznamy o zabití bossov
        KILLBOSS = true, -- [true, | false], default = true
        -- Oznamy o zabití užitočných mobov ako napr. Chester.
        KILLFOLLOWER = true, -- [true, | false], default = true
        -- Oznam o zabití neobnoviteľného moba, napr. Beafalo
        KILLMONITORED = true, -- [true, | false], default = true
        -- Oznam o jedení, krmení alebo podávaní vzácnych itemov
        EATRARE = true, -- [true, | false], default = true

        -- Povoliť pripojenie na server len pre hráčov ktorých ID je na whiteliste
        WHITELIST = true, -- [true | false], default = false
        DEBUG_MODE = false, -- [true | false], default = false
    },
    enabled=true,
}