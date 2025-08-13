#!/usr/bin/env bash
# PIRATENABENTEUER – ULTRA ASCII (linksbuendig, 200x50+ empfohlen)
# Vollbild-ASCII, nur ASCII-Zeichen, linksbündig für saubere Darstellung.

# --- Basics / Farben ----------------------------------------------------------
if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  echo "Dieses Abenteuer benötigt mindestens Bash 4."
  exit 1
fi
# Feste Locale vermeidet Breiten-Zickzack (rein ASCII nutzen wir trotzdem)
export LC_ALL=C LANG=C
if [ -z "$TERM" ]; then export TERM=xterm; fi
if command -v tput >/dev/null 2>&1; then
  bold=$(tput bold 2>/dev/null || true)
  dim=$(tput dim 2>/dev/null || true)
  reset=$(tput sgr0 2>/dev/null || true)
  red=$(tput setaf 1 2>/dev/null || true)
  green=$(tput setaf 2 2>/dev/null || true)
  yellow=$(tput setaf 3 2>/dev/null || true)
  blue=$(tput setaf 4 2>/dev/null || true)
  magenta=$(tput setaf 5 2>/dev/null || true)
  cyan=$(tput setaf 6 2>/dev/null || true)
  white=$(tput setaf 7 2>/dev/null || true)
else
  bold=""; dim=""; reset=""
  red=""; green=""; yellow=""; blue=""; magenta=""; cyan=""; white=""
fi

# --- Terminalgroesse ----------------------------------------------------------
min_cols=160
min_lines=48
get_cols(){ command -v tput >/dev/null 2>&1 && tput cols || echo 200; }
get_lines(){ command -v tput >/dev/null 2>&1 && tput lines || echo 50; }
check_terminal(){
  local c=$(get_cols) l=$(get_lines)
  if (( c < min_cols || l < min_lines )); then
    echo -e "${yellow}${bold}Hinweis:${reset} Dieses Spiel ist fuer mindestens ${min_cols}x${min_lines} optimiert."
    echo -e "Aktuell: ${c}x${l}. Bitte vergroessere das Terminal fuer Ultra-ASCII."
    read -rp "Trotzdem fortfahren? (j/N) " a
    [[ "$a" =~ ^[JjYy]$ ]] || exit 0
  fi
}

# --- State --------------------------------------------------------------------
declare -A inventory
declare -A crew
gold=15
has_ship=false
has_map=false
savefile="${HOME}/.piratenabenteuer.save"

# --- Helpers ------------------------------------------------------------------
press_enter(){ echo; read -rp "Druecke [Enter], um fortzufahren... "; }
say(){ echo -e "$*${reset}"; }
money(){ echo -e "${yellow}${bold}Gold:${reset} ${yellow}${gold}${reset}"; }
have(){ [[ -n "${inventory[$1]+x}" ]]; }
in_crew(){ [[ -n "${crew[$1]+x}" ]]; }
paint_left(){ local color="$1"; shift; while IFS= read -r line; do echo -e "${color}${line}${reset}"; done <<<"$*"; }

choose(){ # choose "Prompt" "Opt1" "Opt2" ...
  local prompt="$1"; shift
  local options=("$@")
  echo -e "${cyan}${prompt}${reset}"
  local i
  for i in "${!options[@]}"; do printf "  %2d) %s\n" "$((i+1))" "${options[$i]}"; done
  local sel
  while true; do
    read -rp "Deine Wahl: " sel
    if [[ "$sel" =~ ^[0-9]+$ ]] && (( sel>=1 && sel<=${#options[@]} )); then
      choice="${options[$((sel-1))]}"
      return 0
    fi
    say "${red}Ungueltige Eingabe.${reset}"
  done
}

save_game(){
  cat > "$savefile" <<EOF
gold=$gold
has_ship=$has_ship
has_map=$has_map
inventory_keys=$(printf "%s " "${!inventory[@]}")
crew_keys=$(printf "%s " "${!crew[@]}")
EOF
  say "${green}Spielstand gespeichert nach:${reset} ${savefile}"
}
load_game(){
  if [[ -f "$savefile" ]]; then
    # shellcheck disable=SC1090
    source "$savefile"
    declare -gA inventory
    declare -gA crew
    for k in $inventory_keys; do inventory["$k"]=true; done
    for k in $crew_keys; do crew["$k"]=true; done
    say "${green}Spielstand geladen.${reset}"
  else
    say "${red}Kein Spielstand gefunden (${savefile}).${reset}"
  fi
  press_enter
}

# --- ULTRA ASCII (linksbuendig, ASCII-only) -----------------------------------
banner_ultra(){ cat <<'EOF'
 ________________________________________________________________________________________________________________________________
|   ____ ___ ____    _    _____ _____ _____ _   _      _   _ _____ _   _ ______ _______ _   _ ______ _______ _____  _    _      |
|  |  _ \_ _/ ___|  / \  | ____|_   _| ____| \ | |    | \ | | ____| \ | |  ____|__   __| \ | |  ____|__   __|_   _|| |  | |     |
|  | |_) | | |     / _ \ |  _|   | | |  _| |  \| |    |  \| |  _| |  \| | |__     | |  |  \| | |__     | |    | |  | |  | |     |
|  |  __/| | |___ / ___ \| |___  | | | |___| |\  |    | |\  | |___| |\  |  __|    | |  | |\  |  __|    | |    | |  | |  | |     |
|  |_|  |___\____/_/   \_\_____| |_| |_____|_| \_|    |_| \_|_____|_| \_|_|       |_|  |_| \_|_|       |_|    |_|  |_|  |_|     |
|________________________________________________________________________________________________________________________________|
EOF
}

street_ultra(){ cat <<'EOF'
 ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
   .-^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^-.
  /                                                                                                                         \
 /    _________                        ________________                     ________________                                 \
/    /  ___   \     T A V E R N E     |   R U M   |  |       S T R A S S E |   F I S C H  |     M A R K T                    \
\    | |   |  |                       |  L I E D E R  |                    |   O B S T    |                                  /
 \   | |___|  |    Musik: pling pling |______________|                    |___K R A M_____|                                 /
  \  |_______/                                                                                                             /
   \_____________________________________________________________________________________________________________________/
     |                                                                                                             |
     |  -> H A F E N        Holzstege, Taue, Fässer, Boote, Leute, Wasser, mehr Wasser, sehr viel Wasser          |
     |_____________________________________________________________________________________________________________|
     ~  ~    ~   ~  ~ ~  ~    ~   ~   ~   ~   ~ ~  ~   ~   ~   ~  ~  ~   ~   ~  ~  ~   ~  ~   ~   ~   ~  ~   ~ ~ ~
EOF
}

tavern_ultra(){ cat <<'EOF'
 .-===========================================================================================================================-.
|  _______  _______  _______  _______  _______    _______  _______  _______  _______   ___    ___  _______  _______  _______  |
| |       ||       ||       ||       ||       |  |       ||       ||       ||       | |   |  |   ||       ||       ||       | |
| |   _   ||_     _||    ___||_     _||    ___|  |  _____||_     _||    ___||_     _| |   |  |   ||  _____||_     _||_     _| |
| |  | |  |  |   |  |   |___   |   |  |   |___   | |_____   |   |  |   |___   |   |   |   |  |   || |_____   |   |    |   |   |
| |  |_|  |  |   |  |    ___|  |   |  |    ___|  |_____  |  |   |  |    ___|  |   |   |   |  |   ||_____  |  |   |    |   |   |
| |       |  |   |  |   |___   |   |  |   |___    _____| |  |   |  |   |___   |   |   |   |__|   | _____| |  |   |    |   |   |
| |_______|  |___|  |_______|  |___|  |_______|  |_______|  |___|  |_______|  |___|   |__________||_______|  |___|    |___|   |
|                                                                                                                             |
|  Theke: [==][==]  Kruege: (o) (o) (o)  Fässer: [####] [####]  Gaeste murmeln, Laute ist schief gestimmt                    |
|                                                                                                                             |
|  +------------------------------+     +----------------------------------------------+                                     |
|  |            T H E K E         |     |                  T I S C H E                  |                                     |
|  |  [::] [::] [::]  [##] [##]   |     |  o   o   o    o    o   o    o    o    o       |                                     |
|  +------------------------------+     +----------------------------------------------+                                     |
|  Hinten: Koch sortiert Gewuerze in "explodiert" und "explodiert nicht".                                                     |
'-----------------------------------------------------------------------------------------------------------------------------'
EOF
}

market_ultra(){ cat <<'EOF'
 ________________________________________________________________________________________________________________________________
/   F R I S C H E R   F I S C H   -   O B S T   -   S E I L E   -   K R I M S K R A M S                                       \
\_______________________________________________________________________________________________________________________________/
|  +---------+  +---------+  +---------+  +---------+  +---------+  +---------+  +---------+  +---------+  +---------+         |
|  | A P F E |  | F I S C |  | S E I L |  | K O R B |  | W U R Z |  | S C H M |  | O B S T |  | K R A M |  | P R O B |         |
|  |   L E   |  |   H    |  |   E     |  |   E     |  |   E L N  |  |   U C K |  |   M I X |  |   K I S |  |   I E R |         |
|  +---------+  +---------+  +---------+  +---------+  +---------+  +---------+  +---------+  +---------+  +---------+         |
|  Haendler schreien: "Billig! Frisch! Heute nur heute!"                                                                       |
'------------------------------------------------------------------------------------------------------------------------------'
EOF
}

docks_ultra(){ cat <<'EOF'
                                      ________________________________________________________________
                                     /                        H O L Z S T E G E                       \
                                    /________________________________________________________ _________\
                                    |                                                              |   |
                                    |     __    __    __         kleiner Kahn         Segelboot    |   |
                                    |    / /   / /   / /         (ziemlich klein)     (okay)       |   |
                                    |   /_/   /_/   /_/                                          __|   |
                                    |   |_|   |_|   |_|                                         /  /   |
                                    |                                                           \_/    |
                                    |   Wellen: ~  ~   ~   ~  ~ ~  ~   ~   ~  ~   ~   ~ ~  ~ ~          |
                                    |___________________________________________________________________|
   ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~   ~   ~  ~   ~   ~  ~   ~  ~ ~  ~ ~   ~  ~   ~   ~ ~ ~ ~
EOF
}

lighthouse_ultra(){ cat <<'EOF'
                         /\
                        /  \
                       / /\ \
                      / /  \ \
                     /_/____\_\
                       |    |
                       | [] |
                       |____|
                    ___/____\___
                   /            \
                  /    LICHT     \
                 /      UND       \
                /      STURM      \
                --------------------
EOF
}

blacksmith_ultra(){ cat <<'EOF'
 ________________________________  S C H M I E D E  ___________________________________
/                                                                                __      \
/   Amboss   Funken    Hammer     Kohle      Blasebalg       Stahlstangen        |  |      \
|--------------------------------------------------------------------------------|__|-------|
|   [####]  * * * *   (====)     [====]      <::::::>         ||  ||  ||                    |
|    ||||               ||                                      ||  ||  ||                  |
|____||||_______________||______________________________________||__||__||__________________|
EOF
}

casino_ultra(){ cat <<'EOF'
 .-----------------.-----------------.-----------------.      E I N S A T Z   B I T T E
 |   [6]   [6]   [6]|   [3]   [4]   [5]|   [1]   [1]   [1]|      (Ohne Einsatz kein Spiel)
 '-----------------'-----------------'-----------------'
 .-----------------.-----------------.-----------------.
 |   [2]   [6]   [6]|   [4]   [2]   [5]|   [3]   [5]   [1]|
 '-----------------'-----------------'-----------------'
EOF
}

ship_ultra(){ cat <<'EOF'
                                                                                 |    |    |
                                                                                )_)  )_)  )_)
                                                                               )___))___))___)\
                                                                              )____)____)_____)\
                                                                            _____|____|____|____\__
                                                        --------\           K A P I T A E N         /--------
                                                                 \_________________________________/
                                                                 ~  ~   ~   ~   Wellen  ~  ~   ~  ~
EOF
}

# --- Szenen / Logik -----------------------------------------------------------
display_header(){
  clear
  paint_left "$cyan" "$(banner_ultra)"
  echo
  paint_left "$magenta" "$(street_ultra)"
  echo
  echo -e "${yellow}Du traeumst davon, so legendaer zu werden wie ${bold}Guybrush Threepwood${reset}${yellow}. Die Strasse der Hafenstadt liegt vor dir.${reset}"
  echo -e "${dim}* Aehnlichkeiten mit echten Piraten sind reiner Zufall. Oder Propaganda.${reset}"
  echo
}

status_screen(){
  clear
  say "${bold}${cyan}STATUS${reset}"
  money
  echo -e "${yellow}Inventar:${reset}"
  if ((${#inventory[@]}==0)); then echo "  (leer)"; else for k in "${!inventory[@]}"; do echo "  - $k"; done; fi
  echo -e "${yellow}Crew:${reset}"
  if ((${#crew[@]}==0)); then echo "  (keine)"; else for k in "${!crew[@]}"; do echo "  - $k"; done; fi
  echo -e "${yellow}Schiff:${reset} $([[ $has_ship == true ]] && echo 'Ja' || echo 'Nein')"
  echo -e "${yellow}Karte:${reset} $([[ $has_map == true ]] && echo 'Ja' || echo 'Nein')"
  echo
  choose "Aktion:" "Zurueck" "Spiel speichern" "Spiel laden"
  case "$choice" in
    "Spiel speichern") save_game; press_enter;;
    "Spiel laden") load_game;;
  esac
}

dice_game(){
  clear
  paint_left "$yellow" "$(casino_ultra)"
  say "${bold}Piraten-Pasch${reset}: 3 Wuerfel gegen 3 Wuerfel. Hoehere Summe gewinnt den Einsatz."
  while true; do
    money
    read -rp "Einsatz (1..50, 0=zurueck): " bet
    [[ ! "$bet" =~ ^[0-9]+$ ]] && { say "${red}Zahl, bitte.${reset}"; continue; }
    (( bet==0 )) && return
    if (( bet<1 || bet>50 )); then say "${red}Zwischen 1 und 50, bitte.${reset}"; continue; fi
    if (( gold<bet )); then say "${red}Zu wenig Gold fuer diesen Einsatz.${reset}"; continue; fi
    p1=$((1+RANDOM%6)); p2=$((1+RANDOM%6)); p3=$((1+RANDOM%6)); ps=$((p1+p2+p3))
    o1=$((1+RANDOM%6)); o2=$((1+RANDOM%6)); o3=$((1+RANDOM%6)); os=$((o1+o2+o3))
    echo -e "Du wuerfelst: ${green}${p1}-${p2}-${p3} (Summe ${ps})${reset}"
    echo -e "Gegner wuerfelt: ${red}${o1}-${o2}-${o3} (Summe ${os})${reset}"
    if (( ps>os )); then gold=$((gold+bet)); say "${green}Gewonnen! +${bet} Gold.${reset}"
    elif (( ps<os )); then gold=$((gold-bet)); say "${red}Verloren! -${bet} Gold.${reset}"
    else say "${yellow}Unentschieden.${reset}"; fi
    (( gold<1 )) && { say "${red}Pleite. Vielleicht jobben?${reset}"; press_enter; return; }
    choose "Nochmal?" "Ja" "Nein"; [[ "$choice" == "Nein" ]] && return
  done
}

tavern_cook_riddle(){
  say "${magenta}Koch:${reset} 'Nur wer Zutaten waehlt, die NICHT explodieren, verdient meine Kunst.'"
  say "Optionen: Wasser, Zwiebel, Salz, Rum, Chili, Banane"
  choose "Kombi waehlen:" \
    "Wasser + Zwiebel + Salz" \
    "Rum + Chili + Banane" \
    "Wasser + Banane + Rum"
  case "$choice" in
    "Wasser + Zwiebel + Salz")
      crew["Koch"]=true
      say "${green}Koch tritt bei. (Er wuerzt Rum mit Pfeffer – frag lieber nicht.)${reset}"
      ;;
    *)
      say "${red}In deiner Vorstellung explodiert der Eintopf. Koch guckt streng.${reset}"
      ;;
  esac
  press_enter
}

tavern_scene(){
  clear
  paint_left "$yellow" "$(tavern_ultra)"
  say "${cyan}Die Taverne vibriert. Gelaechter, Rum und fragwuerdige Hygiene.${reset}"
  while true; do
    local acts=("Mit dem Wirt sprechen" "Piraten-Pasch spielen" "Karte kaufen (30 Gold)" "Mit dem Koch sprechen" "Zurueck zur Strasse")
    choose "Was tun?" "${acts[@]}"
    case "$choice" in
      "Mit dem Wirt sprechen")
        say "${magenta}Wirt:${reset} 'Legendaere Schaetze – legendaer leere Geldbeutel!'"; press_enter;;
      "Piraten-Pasch spielen")
        dice_game;;
      "Karte kaufen (30 Gold)")
        if $has_map; then say "${yellow}Du hast bereits eine Karte.${reset}"
        elif (( gold<30 )); then say "${red}Dir fehlen Muenzen.${reset}"
        else
          choose "Fuer 30 Gold kaufen?" "Ja" "Nein"
          if [[ "$choice" == "Ja" ]]; then gold=$((gold-30)); has_map=true; inventory["Karte"]=true; say "${green}Eine knitterige Karte wechselt den Besitzer.${reset}"; fi
        fi
        press_enter;;
      "Mit dem Koch sprechen")
        if in_crew "Koch"; then say "${yellow}Der Koch schnippelt schief grinsend Gemuese.${reset}"; press_enter
        else tavern_cook_riddle; fi
        ;;
      "Zurueck zur Strasse") return;;
    esac
  done
}

market_scene(){
  clear
  paint_left "$green" "$(market_ultra)"
  say "${cyan}Der Markt ist laut, bunt und erstaunlich verhandelbar.${reset}"
  while true; do
    local acts=("Apfel kaufen (5 Gold)" "Tau/Seil kaufen (7 Gold)" "Mit Schiffsjungen sprechen" "Kleiner Job: Waren ausrufen (+4 Gold)" "Zurueck zur Strasse")
    choose "Was tun?" "${acts[@]}"
    case "$choice" in
      "Apfel kaufen (5 Gold)")
        if (( gold<5 )); then say "${red}Zu wenig Gold.${reset}"; else gold=$((gold-5)); inventory["Apfel"]=true; say "${green}Saftiger Apfel eingesackt.${reset}"; fi
        press_enter;;
      "Tau/Seil kaufen (7 Gold)")
        if (( gold<7 )); then say "${red}Zu wenig Gold.${reset}"; else gold=$((gold-7)); inventory["Seil"]=true; say "${green}Robustes Seil gekauft.${reset}"; fi
        press_enter;;
      "Mit Schiffsjungen sprechen")
        if in_crew "Schiffsjunge"; then say "${yellow}Er uebt Seemannsknoten. In deinem Schatten. Suess.${reset}"; press_enter
        else
          say "${magenta}Schiffsjunge:${reset} 'Aeh... Aufnahmegebuehr 30 Gold?'"
          if have "Apfel"; then
            say "${cyan}Du zeigst dramatisch einen glaenzenden Apfel.${reset}"
            choose "Zahlungsmittel waehlen:" "Apfel (Bestechung)" "30 Gold (falls vorhanden)" "Abbrechen"
            case "$choice" in
              "Apfel (Bestechung)")
                unset 'inventory["Apfel"]'; crew["Schiffsjunge"]=true
                say "${green}'APFEL!' – Er ist nun Crew. Guenstig!${reset}";;
              "30 Gold (falls vorhanden)")
                if (( gold>=30 )); then gold=$((gold-30)); crew["Schiffsjunge"]=true; say "${green}Er huepft an Bord – mit 30 Gold in der Tasche.${reset}"; else say "${red}Nicht genug Gold.${reset}"; fi
                ;;
              *) say "${yellow}Der Junge schaut dem Apfel traurig nach.${reset}";;
            esac
          else
            if (( gold>=30 )); then
              choose "30 Gold zahlen?" "Ja" "Nein"
              [[ "$choice" == "Ja" ]] && { gold=$((gold-30)); crew["Schiffsjunge"]=true; say "${green}Er ist jetzt dabei.${reset}"; }
            else
              say "${red}Kein Apfel, zu wenig Gold. Erst jobben?${reset}"
            fi
          fi
          press_enter
        fi
        ;;
      "Kleiner Job: Waren ausrufen (+4 Gold)")
        say "${cyan}Du schmetterst Marktschreier-Hits. Trinkgeld rieselt.${reset}"
        gold=$((gold+4)); money; press_enter;;
      "Zurueck zur Strasse") return;;
    esac
  done
}

lighthouse_scene(){
  clear
  paint_left "$white" "$(lighthouse_ultra)"
  say "${cyan}Leuchtturmwaerter:${reset} 'Navigator gesucht? Beweise Verstand!'"
  if in_crew "Navigator"; then say "${yellow}Der Navigator notiert Sterne in dein Logbuch.${reset}"; press_enter; return; fi
  say "${magenta}Raetsel:${reset} 'Ich zeige stets nach Norden, gehe aber nie. Was bin ich?'"
  choose "Antwort:" "Ein Kompass" "Die Ebbe" "Ein Pirat nach Feierabend"
  if [[ "$choice" == "Ein Kompass" ]]; then crew["Navigator"]=true; say "${green}'Richtig. Ich komme mit.'${reset}"
  else say "${red}'Falsch. Keine Sterne fuer heute.'${reset}"; fi
  press_enter
}

blacksmith_scene(){
  clear
  paint_left "$red" "$(blacksmith_ultra)"
  say "${cyan}Funken spruehen. Die Schmiedin mustert dich kurz, findet dich 'okay'.${reset}"
  while true; do
    local acts=("Mit Kanonier sprechen" "Mit Tischler sprechen" "Kleiner Job: Kohle schaufeln (+8 Gold)" "Zurueck zur Strasse")
    choose "Was tun?" "${acts[@]}"
    case "$choice" in
      "Mit Kanonier sprechen")
        if in_crew "Kanonier"; then say "${yellow}Der Kanonier poliert imaginare Rohre. 'Peng!' – 'Nein.'${reset}"
        else
          say "${magenta}Kanonier:${reset} 'Rechnen! Zwei Kanonen, alle 10 Sekunden je 1 Schuss. Wieviele Kugeln nach 60 Sekunden?'"
          choose "Antwort:" "12" "6" "10"
          if [[ "$choice" == "12" ]]; then crew["Kanonier"]=true; say "${green}'Aye. Ich bin dabei.'${reset}"
          else say "${red}'Nope.'${reset}"; fi
        fi
        press_enter;;
      "Mit Tischler sprechen")
        if in_crew "Tischler"; then say "${yellow}Der Tischler nickt dir zu. Holz lebt. Und quietscht.${reset}"
        else
          say "${magenta}Tischler:${reset} 'Welcher Knoten fuer eine Rettungsschlinge?'"
          choose "Antwort:" "Palstek" "Schotstek" "Fischerknoten"
          if [[ "$choice" == "Palstek" ]]; then crew["Tischler"]=true; say "${green}'Bestanden. Ich komme mit.'${reset}"
          else say "${red}'Das haelt hoechstens deine Buchsen.'${reset}"; fi
        fi
        press_enter;;
      "Kleiner Job: Kohle schaufeln (+8 Gold)")
        say "${cyan}Staubig, heiss, bezahlt. +8 Gold.${reset}"
        gold=$((gold+8)); money; press_enter;;
      "Zurueck zur Strasse") return;;
    esac
  done
}

harbour_scene(){
  clear
  paint_left "$cyan" "$(docks_ultra)"
  say "${cyan}Der Hafen riecht nach Salz, Holz und Abenteuer mit Spritzwasser.${reset}"
  while true; do
    local acts=("Die Schiffe bestaunen" "Mit dem Schiffsbauer sprechen" "Kleiner Job: Faesser schleppen (+6 Gold)" "Zum Leuchtturm (Navigator?)" "Zurueck zur Strasse")
    choose "Was tun?" "${acts[@]}"
    case "$choice" in
      "Die Schiffe bestaunen")
        say "${magenta}Du schwoerst dir: Bald gehoert dir eins davon. Die Moewen schwoeren nichts.${reset}"; press_enter;;
      "Mit dem Schiffsbauer sprechen")
        if $has_ship; then say "${yellow}Schiffsbauer:${reset} 'Pfleg es gut. Keine Bananenschalen an Deck!'"; press_enter
        else
          say "${magenta}Schiffsbauer:${reset} 'Kleines Schiff 50 Gold – nur an Leute mit Karte & Crew!'"
          if (( gold<50 )); then say "${red}Noch zu teuer.${reset}"
          elif ! $has_map; then say "${red}Ohne Karte keine Auslieferung.${reset}"
          elif ((${#crew[@]}<2)); then say "${red}Mindestens zwei Crewleute noetig.${reset}"
          else
            choose "Schiff fuer 50 Gold kaufen?" "Ja" "Nein"
            if [[ "$choice" == "Ja" ]]; then gold=$((gold-50)); has_ship=true; say "${green}Du erhaeltst Schluessel & stolzes (fast dichtes) Boot.${reset}"; fi
          fi
          press_enter
        fi
        ;;
      "Kleiner Job: Faesser schleppen (+6 Gold)")
        say "${cyan}Du hebst, du aechzt, du kassierst. +6 Gold.${reset}"
        gold=$((gold+6)); money; press_enter;;
      "Zum Leuchtturm (Navigator?)")
        lighthouse_scene;;
      "Zurueck zur Strasse") return;;
    esac
  done
}

sail_away(){
  clear
  paint_left "$cyan" "$(ship_ultra)"
  say "${yellow}Du hast Schiff, Karte und mindestens drei faehige Haende an Bord.${reset}"
  say "${blue}Der Wind fuellt die Segel. Vor dir: Horizont. Hinter dir: unbezahlte Tavernenrechnungen.${reset}"
  echo -e "${bold}${magenta}TO BE CONTINUED ...${reset}"
  press_enter
  exit 0
}

street_scene(){
  while true; do
    if $has_ship && $has_map && ((${#crew[@]}>=3)); then sail_away; fi
    clear
    paint_left "$cyan" "$(street_ultra)"
    say "${yellow}Du stehst auf der breiten Strasse der Hafenstadt (Ultra-ASCII, linksbuendig).${reset}"
    local ops=("Zur Taverne" "Zum Markt" "Zum Hafen" "Zur Schmiede" "Status anzeigen" "Spiel speichern" "Spiel beenden")
    choose "Wohin?" "${ops[@]}"
    case "$choice" in
      "Zur Taverne") tavern_scene ;;
      "Zum Markt") market_scene ;;
      "Zum Hafen") harbour_scene ;;
      "Zur Schmiede") blacksmith_scene ;;
      "Status anzeigen") status_screen ;;
      "Spiel speichern") save_game; press_enter ;;
      "Spiel beenden") say "${magenta}Mast- und Schotbruch!${reset}"; exit 0 ;;
    esac
  done
}

# --- Start --------------------------------------------------------------------
check_terminal
display_header
press_enter
street_scene
