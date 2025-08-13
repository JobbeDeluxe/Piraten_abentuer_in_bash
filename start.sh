#!/usr/bin/env bash
# PIRATENABENTEUER – REINE ASCII VERSION (linksbuendig, 160x48+ empfohlen)
# Features:
# - Startmenue (Banner bleibt stehen)
# - Grosse ASCII-Szenen, reine ASCII-Zeichen
# - Faire Jobs: pro Runde 4 Tasks (Markt, Hafen, Schmiede, 1x Wuerfeln)
# - Statusleiste unten: Gold / Inventar / Crew / Jobs-Runde

# --- Basics -------------------------------------------------------------------
if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  echo "Dieses Abenteuer braucht mindestens Bash 4."
  exit 1
fi
export LC_ALL=C LANG=C
if [ -z "${TERM:-}" ]; then export TERM=xterm; fi
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
else bold=""; dim=""; reset=""; red=""; green=""; yellow=""; blue=""; magenta=""; cyan=""; white=""; fi

min_cols=160; min_lines=48
get_cols(){ command -v tput >/dev/null 2>&1 && tput cols || echo 200; }
get_lines(){ command -v tput >/dev/null 2>&1 && tput lines || echo 60; }
check_terminal(){
  local c=$(get_cols) l=$(get_lines)
  if (( c < min_cols || l < min_lines )); then
    echo -e "${yellow}${bold}Hinweis:${reset} Mindestens ${min_cols}x${min_lines} empfohlen. Aktuell: ${c}x${l}."
    read -rp "Trotzdem starten? (j/N) " a; [[ "$a" =~ ^[JjYy]$ ]] || exit 0
  fi
}

# --- State --------------------------------------------------------------------
declare -A inventory
declare -A crew
gold=15
has_map=false
has_ship=false

# 4 Tasks pro Runde: market_barker, harbour_barrels, blacksmith_coal, dice_once
declare -A job_done=( ["market_barker"]="false" ["harbour_barrels"]="false" ["blacksmith_coal"]="false" ["dice_once"]="false" )

jobs_all_done(){
  [[ "${job_done[market_barker]}" == "true" && "${job_done[harbour_barrels]}" == "true" \
     && "${job_done[blacksmith_coal]}" == "true" && "${job_done[dice_once]}" == "true" ]]
}
maybe_reset_jobs_round(){
  if jobs_all_done; then
    job_done[market_barker]="false"
    job_done[harbour_barrels]="false"
    job_done[blacksmith_coal]="false"
    job_done[dice_once]="false"
    echo -e "${green}${bold}\n-- Neue Arbeitsrunde verfuegbar! --${reset}"
  fi
}

# --- Helpers ------------------------------------------------------------------
flush_stdin(){ while read -r -t 0; do read -r; done 2>/dev/null || true; }
press_enter(){ flush_stdin; echo; read -rp "Druecke [Enter], um fortzufahren... " _; }
say(){ echo -e "$*${reset}"; }
money(){ echo -e "${yellow}${bold}Gold:${reset} ${yellow}${gold}${reset}"; }
have(){ [[ -n "${inventory[$1]+x}" ]]; }
in_crew(){ [[ -n "${crew[$1]+x}" ]]; }

list_keys(){ # prints keys of assoc array passed by name, comma-separated
  local -n ref="$1"; local first=1 out=""
  for k in "${!ref[@]}"; do
    [[ -n "${ref[$k]}" ]] || continue
    if [[ $first -eq 1 ]]; then out="$k"; first=0; else out="$out, $k"; fi
  done
  [[ -n "$out" ]] && printf "%s" "$out" || printf "leer"
}

status_bar(){
  local inv crewlist
  inv=$(list_keys inventory)
  crewlist=$(list_keys crew)
  local n=0; for kk in "${!job_done[@]}"; do [[ "${job_done[$kk]}" == "true" ]] && ((n++)); done
  echo
  echo "----------------------------------------------------------------------------------------------------"
  echo "  GOLD: $gold  |  INVENTAR: $inv  |  CREW: $crewlist  |  JOB-RUNDE: $n/4 (Markt, Hafen, Schmiede, Wuerfeln)"
}

paint_left(){ local color="$1"; shift; while IFS= read -r line; do echo -e "${color}${line}${reset}"; done <<<"$*"; }

# --- ASCII ART (linksbuendig, ASCII-only) -------------------------------------
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
     |  -> H A F E N        Holzstege, Taue, Faesser, Boote, Leute, Wasser, mehr Wasser, sehr viel Wasser         |
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
|  Theke: [==][==]  Kruege: (o) (o) (o)  Faesser: [####] [####]  Gaeste murmeln, Laute ist schief gestimmt                    |
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
   ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~   ~   ~  ~   ~   ~  ~   ~  ~ ~  ~ ~   ~  ~   ~   ~ ~ ~ ~
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

# --- Save/Load ----------------------------------------------------------------
savefile="${HOME}/.piratenabenteuer.save"
save_game(){
  : > "$savefile"
  {
    echo "gold=$gold"
    echo "has_map=$has_map"
    echo "has_ship=$has_ship"
    echo "inv_keys=$(printf "%s " "${!inventory[@]}")"
    echo "crew_keys=$(printf "%s " "${!crew[@]}")"
    for k in "${!job_done[@]}"; do echo "job_$k=${job_done[$k]}"; done
  } >> "$savefile"
  say "${green}Gespeichert: ${savefile}${reset}"
}
load_game(){
  if [[ -f "$savefile" ]]; then
    # shellcheck disable=SC1090
    source "$savefile"
    declare -gA inventory; for k in ${inv_keys:-}; do [[ -n "$k" ]] && inventory["$k"]=true; done
    declare -gA crew; for k in ${crew_keys:-}; do [[ -n "$k" ]] && crew["$k"]=true; done
    for k in "${!job_done[@]}"; do v="job_$k"; job_done[$k]="${!v:-false}"; done
    say "${green}Spielstand geladen.${reset}"
  else
    say "${red}Kein Spielstand gefunden.${reset}"
  fi
  press_enter
}

# --- Scenes -------------------------------------------------------------------
display_header(){
  clear
  paint_left "$cyan" "$(banner_ultra)"
  echo
  echo -e "${yellow}Willkommen zu PIRATENABENTEUER (ASCII Edition)!${reset}"
  echo -e "Werde legendaer wie ${bold}Guybrush Threepwood${reset}* … oder wenigstens halb so chaotisch."
  echo -e "${dim}* Aehnlichkeiten mit echten Piraten sind reiner Zufall.${reset}"
  echo
}

main_menu(){
  while true; do
    display_header
    echo "  1) Spiel starten"
    echo "  2) Spiel laden"
    echo "  3) Beenden"
    read -rp "Deine Wahl: " a
    case "$a" in
      1) return ;;
      2) load_game ;;
      3) echo "Bis bald!"; exit 0 ;;
    esac
  done
}

street_scene(){
  while true; do
    if $has_ship && $has_map && ((${#crew[@]}>=3)); then sail_away; fi
    clear
    paint_left "$cyan" "$(street_ultra)"; status_bar
    echo
    echo "  1) Zur Taverne"
    echo "  2) Zum Markt"
    echo "  3) Zum Hafen"
    echo "  4) Zur Schmiede"
    echo "  5) Status anzeigen"
    echo "  6) Spiel speichern"
    echo "  7) Spiel beenden"
    read -rp "Wohin? " a
    case "$a" in
      1) tavern_scene ;;
      2) market_scene ;;
      3) harbour_scene ;;
      4) blacksmith_scene ;;
      5) status_screen ;;
      6) save_game; press_enter ;;
      7) say "${magenta}Mast- und Schotbruch!${reset}"; exit 0 ;;
    esac
  done
}

status_screen(){
  clear
  say "${bold}${cyan}STATUS${reset}"
  money
  echo -e "${yellow}Inventar:${reset} $(list_keys inventory)"
  echo -e "${yellow}Crew:${reset} $(list_keys crew)"
  echo -e "${yellow}Schiff:${reset} $([[ $has_ship == true ]] && echo 'Ja' || echo 'Nein')"
  echo -e "${yellow}Karte:${reset} $([[ $has_map == true ]] && echo 'Ja' || echo 'Nein')"
  local n=0; for k in "${!job_done[@]}"; do [[ "${job_done[$k]}" == "true" ]] && ((n++)); done
  echo -e "${yellow}Job-Runde:${reset} ${n}/4 erledigt (Markt, Hafen, Schmiede, Wuerfeln)"
  press_enter
}

dice_game(){
  if [[ "${job_done[dice_once]}" == "true" ]]; then
    say "${yellow}Wuerfelspiel in dieser Runde bereits gespielt.${reset}"
    press_enter; return
  fi
  while true; do
    clear
    paint_left "$yellow" "$(casino_ultra)"; status_bar
    echo
    money
    read -rp "Einsatz (1..50, 0=zurueck): " bet
    [[ ! "$bet" =~ ^[0-9]+$ ]] && { say "${red}Zahl, bitte.${reset}"; press_enter; continue; }
    (( bet==0 )) && break
    if (( bet<1 || bet>50 )); then say "${red}Zwischen 1 und 50, bitte.${reset}"; press_enter; continue; fi
    if (( gold<bet )); then say "${red}Nicht genug Gold.${reset}"; press_enter; continue; fi

    p1=$((1+RANDOM%6)); p2=$((1+RANDOM%6)); p3=$((1+RANDOM%6)); ps=$((p1+p2+p3))
    o1=$((1+RANDOM%6)); o2=$((1+RANDOM%6)); o3=$((1+RANDOM%6)); os=$((o1+o2+o3))

    echo -e "Du:    ${green}${p1}-${p2}-${p3} (Summe ${ps})${reset}"
    echo -e "Gegn.: ${red}${o1}-${o2}-${o3} (Summe ${os})${reset}"

    if (( ps>os )); then gold=$((gold+bet)); say "${green}Gewonnen! +${bet} Gold.${reset}"
    elif (( ps<os )); then gold=$((gold-bet)); say "${red}Verloren! -${bet} Gold.${reset}"
    else say "${yellow}Unentschieden.${reset}"; fi

    # Nur EINMAL Goldanzeige (kein doppeltes money):
    echo -e "Neues Guthaben: ${yellow}${gold}${reset}"
    read -rp "Nochmal (j) oder zurueck (Enter)? " again
    [[ "$again" =~ ^[JjYy]$ ]] || break
  done
  job_done[dice_once]="true"
  maybe_reset_jobs_round
  press_enter
}

tavern_cook_riddle(){
  say "${magenta}Koch:${reset} 'Waehle die NICHT explodierenden Zutaten (3): Wasser, Zwiebel, Salz, Rum, Chili, Banane'"
  echo "  1) Wasser + Zwiebel + Salz"
  echo "  2) Rum + Chili + Banane"
  echo "  3) Wasser + Banane + Rum"
  read -rp "Deine Wahl: " r
  if [[ "$r" == "1" ]]; then crew["Koch"]=true; say "${green}Koch tritt bei.${reset}"
  else say "${red}BOOOM (nur mental). Koch schuettelt den Kopf.${reset}"; fi
  press_enter
}

tavern_scene(){
  while true; do
    clear
    paint_left "$yellow" "$(tavern_ultra)"; status_bar
    echo
    echo "  1) Mit dem Wirt sprechen"
    echo "  2) Piraten-Pasch (1x pro Runde)"
    echo "  3) Karte kaufen (30 Gold)"
    echo "  4) Mit dem Koch sprechen (Crew-Raetsel)"
    echo "  5) Zurueck"
    read -rp "Deine Wahl: " a
    case "$a" in
      1) say "${magenta}Wirt:${reset} 'Legendaere Schaetze – legendaer leere Beutel!'"; press_enter;;
      2) dice_game ;;
      3)
        if $has_map; then say "${yellow}Du hast bereits eine Karte.${reset}"
        elif (( gold<30 )); then say "${red}Zu wenig Gold.${reset}"
        else read -rp "Karte fuer 30 Gold kaufen? (j/N) " y; [[ "$y" =~ ^[JjYy]$ ]] && { gold=$((gold-30)); has_map=true; inventory["Karte"]=true; say "${green}Karte erworben.${reset}"; }
        fi
        press_enter;;
      4)
        if in_crew "Koch"; then say "${yellow}Koch ist bereits Crew.${reset}"; press_enter
        else tavern_cook_riddle; fi
        ;;
      5) return ;;
    esac
  done
}

market_scene(){
  while true; do
    clear
    paint_left "$green" "$(market_ultra)"; status_bar
    echo
    echo "  1) Apfel kaufen (5 Gold)"
    echo "  2) Tau/Seil kaufen (7 Gold)"
    echo "  3) Mit Schiffsjungen sprechen (Apfel-Bestechung moeglich)"
    echo "  4) Kleiner Job: Waren ausrufen (+4 Gold) [1x/Runde]"
    echo "  5) Zurueck"
    read -rp "Deine Wahl: " a
    case "$a" in
      1) if (( gold<5 )); then say "${red}Zu wenig Gold.${reset}"; else gold=$((gold-5)); inventory["Apfel"]=true; say "${green}Apfel gekauft.${reset}"; fi; press_enter;;
      2) if (( gold<7 )); then say "${red}Zu wenig Gold.${reset}"; else gold=$((gold-7)); inventory["Seil"]=true; say "${green}Seil gekauft.${reset}"; fi; press_enter;;
      3)
        if in_crew "Schiffsjunge"; then say "${yellow}Schiffsjunge ist schon Crew.${reset}"; press_enter
        else
          say "${magenta}Schiffsjunge:${reset} 'Aufnahmegebuehr 30 Gold?'"
          if have "Apfel"; then
            read -rp "Apfel anbieten statt 30 Gold? (j/N) " y
            if [[ "$y" =~ ^[JjYy]$ ]]; then unset 'inventory[Apfel]'; crew["Schiffsjunge"]=true; say "${green}Er liebt Aepfel. Crew erweitert!${reset}"
            elif (( gold>=30 )); then gold=$((gold-30)); crew["Schiffsjunge"]=true; say "${green}Bezahlt. Crew erweitert.${reset}"
            else say "${red}Weder Apfel noch genug Gold.${reset}"; fi
          else
            if (( gold>=30 )); then read -rp "30 Gold zahlen? (j/N) " y; [[ "$y" =~ ^[JjYy]$ ]] && { gold=$((gold-30)); crew["Schiffsjunge"]=true; say "${green}Crew erweitert.${reset}"; }
            else say "${red}Kein Apfel und zu wenig Gold.${reset}"
            fi
          fi
          press_enter
        fi
        ;;
      4)
        if [[ "${job_done[market_barker]}" == "true" ]]; then
          say "${yellow}Marktschreien in dieser Runde schon erledigt.${reset}"; press_enter
        else
          say "${cyan}Du bruellst Preise, kassierst Trinkgeld. +4 Gold.${reset}"; gold=$((gold+4))
          job_done[market_barker]="true"; maybe_reset_jobs_round; press_enter
        fi
        ;;
      5) return ;;
    esac
  done
}

harbour_scene(){
  while true; do
    clear
    paint_left "$cyan" "$(docks_ultra)"; status_bar
    echo
    echo "  1) Die Schiffe bestaunen"
    echo "  2) Mit dem Schiffsbauer sprechen"
    echo "  3) Kleiner Job: Faesser schleppen (+6 Gold) [1x/Runde]"
    echo "  4) Zum Leuchtturm (Navigator?)"
    echo "  5) Zurueck"
    read -rp "Deine Wahl: " a
    case "$a" in
      1) say "${magenta}Eines Tages gehoert dir eins davon.${reset}"; press_enter;;
      2)
        if $has_ship; then say "${yellow}Schiffsbauer:${reset} 'Pfleg es gut!'"; press_enter
        else
          say "${magenta}Schiffsbauer:${reset} 'Kleines Schiff 50 Gold – nur mit Karte & Crew (>=2)!'"
          if (( gold<50 )); then say "${red}Zu teuer.${reset}"
          elif ! $has_map; then say "${red}Ohne Karte keine Auslieferung.${reset}"
          elif ((${#crew[@]}<2)); then say "${red}Mindestens zwei Crew-Mitglieder.${reset}"
          else read -rp "Schiff fuer 50 Gold kaufen? (j/N) " y; [[ "$y" =~ ^[JjYy]$ ]] && { gold=$((gold-50)); has_ship=true; say "${green}Dein eigenes Boot!${reset}"; }
          fi
          press_enter
        fi
        ;;
      3)
        if [[ "${job_done[harbour_barrels]}" == "true" ]]; then
          say "${yellow}Faesser heben in dieser Runde schon erledigt.${reset}"; press_enter
        else
          say "${cyan}Uff! +6 Gold.${reset}"; gold=$((gold+6))
          job_done[harbour_barrels]="true"; maybe_reset_jobs_round; press_enter
        fi
        ;;
      4) lighthouse_scene ;;
      5) return ;;
    esac
  done
}

lighthouse_scene(){
  clear
  paint_left "$white" "$(lighthouse_ultra)"; status_bar
  echo
  say "${cyan}Leuchtturmwaerter:${reset} 'Navigator gesucht? Beweise Verstand!'"
  if in_crew "Navigator"; then say "${yellow}Navigator ist schon an Bord.${reset}"; press_enter; return; fi
  echo "  1) Ein Kompass"
  echo "  2) Die Ebbe"
  echo "  3) Ein Pirat nach Feierabend"
  read -rp "Antwort: " a
  if [[ "$a" == "1" ]]; then crew["Navigator"]=true; say "${green}Richtig. Navigator tritt bei.${reset}"
  else say "${red}Falsch. Kein Stern fuer dich.${reset}"; fi
  press_enter
}

blacksmith_scene(){
  while true; do
    clear
    paint_left "$red" "$(blacksmith_ultra)"; status_bar
    echo
    echo "  1) Mit Kanonier sprechen (Mathe)"
    echo "  2) Mit Tischler sprechen (Knoten)"
    echo "  3) Kleiner Job: Kohle schaufeln (+8 Gold) [1x/Runde]"
    echo "  4) Zurueck"
    read -rp "Deine Wahl: " a
    case "$a" in
      1)
        if in_crew "Kanonier"; then say "${yellow}Kanonier ist schon Crew.${reset}"
        else
          say "${magenta}Kanonier:${reset} '2 Kanonen, alle 10s je 1 Schuss. Wieviele Kugeln nach 60s?'"
          echo "  1) 12   2) 6   3) 10"; read -rp "Antwort: " r
          [[ "$r" == "1" ]] && { crew["Kanonier"]=true; say "${green}Bestanden. Kanonier tritt bei.${reset}"; } || say "${red}Nope.${reset}"
        fi
        press_enter;;
      2)
        if in_crew "Tischler"; then say "${yellow}Tischler ist schon Crew.${reset}"
        else
          say "${magenta}Tischler:${reset} 'Welcher Knoten fuer eine Rettungsschlinge?'"
          echo "  1) Palstek   2) Schotstek   3) Fischerknoten"; read -rp "Antwort: " r
          [[ "$r" == "1" ]] && { crew["Tischler"]=true; say "${green}Aye. Tischler tritt bei.${reset}"; } || say "${red}Nein.${reset}"
        fi
        press_enter;;
      3)
        if [[ "${job_done[blacksmith_coal]}" == "true" ]]; then
          say "${yellow}Kohleschaufeln in dieser Runde schon erledigt.${reset}"; press_enter
        else
          say "${cyan}Staubig, heiss, bezahlt. +8 Gold.${reset}"; gold=$((gold+8))
          job_done[blacksmith_coal]="true"; maybe_reset_jobs_round; press_enter
        fi
        ;;
      4) return ;;
    esac
  done
}

sail_away(){
  clear
  paint_left "$cyan" "$(ship_ultra)"; status_bar
  echo
  say "${yellow}Du hast Schiff, Karte und mindestens drei faehige Haende.${reset}"
  say "${blue}Der Wind fuellt die Segel. Vor dir: Horizont. Hinter dir: offene Tavernenrechnungen.${reset}"
  echo -e "${bold}${magenta}TO BE CONTINUED ...${reset}"
  press_enter; exit 0
}

# --- Start --------------------------------------------------------------------
check_terminal
main_menu
street_scene
