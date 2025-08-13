#!/usr/bin/env bash
# PIRATENABENTEUER – IMG→ASCII EDITION
# - Rendert Szenenbilder live mit image2ascii (convert2ascii)
# - Geld-Jobs sind nur 1x pro Runde möglich (inkl. 1x Würfeln). Nach allen 4 Tasks: Reset.
# - Fallback auf eingebaute ASCII-Kunst, wenn image2ascii oder Bild fehlt.

set -euo pipefail

# --- Basics / Farben ----------------------------------------------------------
if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  echo "Dieses Abenteuer benötigt mindestens Bash 4."
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

# --- Terminalgröße ------------------------------------------------------------
min_cols=160; min_lines=45
get_cols(){ command -v tput >/dev/null 2>&1 && tput cols || echo 200; }
get_lines(){ command -v tput >/dev/null 2>&1 && tput lines || echo 60; }
check_terminal(){
  local c=$(get_cols) l=$(get_lines)
  if (( c < min_cols || l < min_lines )); then
    echo -e "${yellow}${bold}Hinweis:${reset} Mindestens ${min_cols}x${min_lines} empfohlen. Aktuell: ${c}x${l}."
    read -rp "Trotzdem starten? (j/N) " a; [[ "$a" =~ ^[JjYy]$ ]] || exit 0
  fi
}

# --- Assets / convert2ascii ---------------------------------------------------
SCENE_IMG_DIR="${SCENE_IMG_DIR:-assets/img}"
USE_COLOR_ASCII="${USE_COLOR_ASCII:-1}"   # 1=color, 0=text
img(){ echo "${SCENE_IMG_DIR}/$1"; }      # img street.png -> assets/img/street.png

have_image2ascii(){ command -v image2ascii >/dev/null 2>&1; }
render_image(){
  local path="$1"
  local width=$(( $(get_cols) - 2 ))
  local style="text"; local block="false"
  if [[ "${USE_COLOR_ASCII}" == "1" ]]; then style="color"; block="true"; fi
  image2ascii -i "$path" -w "$width" -s "$style" -b "$block"
}

# --- Fallback ASCII (kurz, sauber linksbündig) --------------------------------
banner_ascii(){ cat <<'EOF'
 ________________________________________________________________________________________________________________________________
|   ____ ___ ____    _    _____ _____ _____ _   _      _   _ _____ _   _ ______ _______ _   _ ______ _______ _____  _    _      |
|________________________________________________________________________________________________________________________________|
EOF
}
street_ascii(){ cat <<'EOF'
 ~ ~ ~ ~ ~ ~  HAFEN -> Holzstege, Taue, Fässer, Boote
EOF
}
tavern_ascii(){ cat <<'EOF'
 [TAVERNE] Theke [::][::]  Krüge (o)(o)  Fässer [####]   Koch sortiert "explodiert/nicht"
EOF
}
market_ascii(){ cat <<'EOF'
 [MARKT] Apfel | Seil | Fisch | Krimskrams   Händler: "Frisch & billig!"
EOF
}
docks_ascii(){ cat <<'EOF'
 [HAFEN] Stege ___  Boote __/__/  Wellen ~ ~ ~ ~
EOF
}
lighthouse_ascii(){ cat <<'EOF'
   /\
  /  \    LEUCHTTURM
 /_/\_\
  |[]|
  |__|
EOF
}
blacksmith_ascii(){ cat <<'EOF'
 [SCHMIEDE] Amboss [####]  Funken ***  Hammer (====)  Kohle [====]
EOF
}
casino_ascii(){ cat <<'EOF'
 [CASINO] WÜRFEL: [6][4][2] vs [5][3][1] – Einsatz!
EOF
}
ship_ascii(){ cat <<'EOF'
   |    |    |
  )_)  )_)  )_)
 )___))___))___)\
)____)____)_____)\
_____ |____| _____\__
EOF
}

# --- Anzeige: Bild ODER Fallback, immer mit clear() ---------------------------
show_scene(){
  local path="$1"; shift
  local fallback="$1"; shift || true
  clear
  if have_image2ascii && [[ -f "$path" ]]; then
    render_image "$path" || "$fallback"
  else
    "$fallback"
  fi
}

press_enter(){ echo; read -rp "Drücke [Enter], um fortzufahren... "; }

say(){ echo -e "$*${reset}"; }
money(){ echo -e "${yellow}${bold}Gold:${reset} ${yellow}${gold}${reset}"; }

# --- Spielzustand -------------------------------------------------------------
declare -A inventory
declare -A crew
gold=15
has_map=false
has_ship=false

# Geld-Job-Runde (4 Tasks): market_barker, harbour_barrels, blacksmith_coal, dice_once
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
    say "${green}${bold}Neue Arbeitsrunde verfügbar!${reset}"
    press_enter
  fi
}

# --- Szenen -------------------------------------------------------------------
display_header(){
  show_scene "$(img banner.png)" banner_ascii
  show_scene "$(img street.png)" street_ascii
  echo -e "${yellow}Du stehst in der Hafenstadt. Rum in der Luft, Abenteuer im Blick.${reset}"
  echo -e "${dim}Tipp: Lege hochauflösende Szenenbilder in ${SCENE_IMG_DIR}/ und ich rendere sie live zu ASCII.${reset}"
  press_enter
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
  local n=0; for k in "${!job_done[@]}"; do [[ "${job_done[$k]}" == "true" ]] && ((n++)); done
  echo -e "${yellow}Arbeitsrunde:${reset} ${n}/4 erledigt (Markt, Hafen, Schmiede, Würfel)"
  echo
  read -rp "[Enter]=zurück, s=Speichern, l=Laden: " a
  case "$a" in
    s|S) save_game; press_enter;;
    l|L) load_game;;
  esac
}

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
}

dice_game(){
  # Nur 1x pro Runde
  if [[ "${job_done[dice_once]}" == "true" ]]; then
    say "${yellow}Würfelspiel diese Runde schon gespielt. Erledige die anderen Jobs, dann gibts einen Reset.${reset}"
    press_enter; return
  fi
  show_scene "$(img casino.png)" casino_ascii
  say "${bold}Piraten-Pasch${reset}: 3 Würfel gegen 3. Höhere Summe gewinnt den Einsatz."
  while true; do
    money
    read -rp "Einsatz (1..50, 0=beenden): " bet
    [[ ! "$bet" =~ ^[0-9]+$ ]] && { say "${red}Zahl, bitte.${reset}"; continue; }
    (( bet==0 )) && break
    if (( bet<1 || bet>50 )); then say "${red}Zwischen 1 und 50, bitte.${reset}"; continue; fi
    if (( gold<bet )); then say "${red}Nicht genug Gold.${reset}"; continue; fi
    p1=$((1+RANDOM%6)); p2=$((1+RANDOM%6)); p3=$((1+RANDOM%6)); ps=$((p1+p2+p3))
    o1=$((1+RANDOM%6)); o2=$((1+RANDOM%6)); o3=$((1+RANDOM%6)); os=$((o1+o2+o3))
    echo -e "Du: ${green}${p1}-${p2}-${p3} (Summe ${ps})${reset}"
    echo -e "Gegn.: ${red}${o1}-${o2}-${o3} (Summe ${os})${reset}"
    if (( ps>os )); then gold=$((gold+bet)); say "${green}+${bet} Gold${reset}"
    elif (( ps<os )); then gold=$((gold-bet)); say "${red}-${bet} Gold${reset}"
    else say "${yellow}Unentschieden.${reset}"; fi
    money
  done
  job_done[dice_once]="true"
  maybe_reset_jobs_round
  press_enter
}

tavern_scene(){
  show_scene "$(img tavern.png)" tavern_ascii
  say "${cyan}Die Taverne vibriert. Gelächter, Rum, fragwürdige Hygiene.${reset}"
  while true; do
    echo "  1) Mit dem Wirt sprechen"
    echo "  2) Piraten-Pasch (1x pro Runde)"
    echo "  3) Karte kaufen (30 Gold)"
    echo "  4) Mit dem Koch sprechen (Crew-Rätsel)"
    echo "  5) Zurück"
    read -rp "Deine Wahl: " a
    case "$a" in
      1) say "${magenta}Wirt:${reset} 'Legendäre Schätze – legendär leere Beutel!'"; press_enter;;
      2) dice_game;;
      3)
        if $has_map; then say "${yellow}Du hast bereits eine Karte.${reset}"
        elif (( gold<30 )); then say "${red}Zu wenig Gold.${reset}"
        else read -rp "Karte für 30 Gold kaufen? (j/N) " y; [[ "$y" =~ ^[JjYy]$ ]] && { gold=$((gold-30)); has_map=true; inventory["Karte"]=true; say "${green}Karte erworben.${reset}"; }
        fi
        press_enter;;
      4)
        if [[ -n "${crew[Koch]+x}" ]]; then say "${yellow}Koch ist schon an Bord.${reset}"; press_enter
        else
          say "${magenta}Koch:${reset} 'Wähle die NICHT explodierenden Zutaten (3): Wasser, Zwiebel, Salz, Rum, Chili, Banane'"
          echo "  1) Wasser + Zwiebel + Salz"
          echo "  2) Rum + Chili + Banane"
          echo "  3) Wasser + Banane + Rum"
          read -rp "Deine Wahl: " r
          if [[ "$r" == "1" ]]; then crew["Koch"]=true; say "${green}Koch tritt bei.${reset}"; else say "${red}BOOOM (nur mental). Koch schüttelt den Kopf.${reset}"; fi
          press_enter
        fi
        ;;
      5) return;;
    esac
  done
}

market_scene(){
  show_scene "$(img market.png)" market_ascii
  say "${cyan}Der Markt: laut, bunt, verhandelbar.${reset}"
  while true; do
    echo "  1) Apfel kaufen (5 Gold)"
    echo "  2) Tau/Seil kaufen (7 Gold)"
    echo "  3) Mit Schiffsjungen sprechen (Apfel-Bestechung möglich)"
    echo "  4) Kleiner Job: Waren ausrufen (+4 Gold) [1x/Runde]"
    echo "  5) Zurück"
    read -rp "Deine Wahl: " a
    case "$a" in
      1) if (( gold<5 )); then say "${red}Zu wenig Gold.${reset}"; else gold=$((gold-5)); inventory["Apfel"]=true; say "${green}Apfel gekauft.${reset}"; fi; press_enter;;
      2) if (( gold<7 )); then say "${red}Zu wenig Gold.${reset}"; else gold=$((gold-7)); inventory["Seil"]=true; say "${green}Seil gekauft.${reset}"; fi; press_enter;;
      3)
        if [[ -n "${crew[Schiffsjunge]+x}" ]]; then say "${yellow}Schiffsjunge ist schon Crew.${reset}"; press_enter
        else
          say "${magenta}Schiffsjunge:${reset} 'Aufnahmegebühr 30 Gold?'"
          if [[ -n "${inventory[Apfel]+x}" ]]; then
            read -rp "Apfel anbieten statt 30 Gold? (j/N) " y
            if [[ "$y" =~ ^[JjYy]$ ]]; then unset 'inventory[Apfel]'; crew["Schiffsjunge"]=true; say "${green}Er liebt Äpfel. Crew erweitert!${reset}"
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
          say "${cyan}Du brüllst Preise, kassierst Trinkgeld.${reset}"; gold=$((gold+4)); money
          job_done[market_barker]="true"; maybe_reset_jobs_round; press_enter
        fi
        ;;
      5) return;;
    esac
  done
}

harbour_scene(){
  show_scene "$(img docks.png)" docks_ascii
  say "${cyan}Der Hafen riecht nach Salz, Holz und Abenteuer.${reset}"
  while true; do
    echo "  1) Die Schiffe bestaunen"
    echo "  2) Mit dem Schiffsbauer sprechen"
    echo "  3) Kleiner Job: Fässer schleppen (+6 Gold) [1x/Runde]"
    echo "  4) Zum Leuchtturm (Navigator?)"
    echo "  5) Zurück"
    read -rp "Deine Wahl: " a
    case "$a" in
      1) say "${magenta}Eines Tages gehört dir eins davon.${reset}"; press_enter;;
      2)
        if $has_ship; then say "${yellow}Schiffsbauer:${reset} 'Pfleg es gut!'"; press_enter
        else
          say "${magenta}Schiffsbauer:${reset} 'Kleines Schiff 50 Gold – nur mit Karte & Crew (>=2)!'"
          if (( gold<50 )); then say "${red}Zu teuer.${reset}"
          elif ! $has_map; then say "${red}Ohne Karte keine Auslieferung.${reset}"
          elif ((${#crew[@]}<2)); then say "${red}Mindestens zwei Crew-Mitglieder.${reset}"
          else read -rp "Schiff für 50 Gold kaufen? (j/N) " y; [[ "$y" =~ ^[JjYy]$ ]] && { gold=$((gold-50)); has_ship=true; say "${green}Dein eigenes Boot!${reset}"; }
          fi
          press_enter
        fi
        ;;
      3)
        if [[ "${job_done[harbour_barrels]}" == "true" ]]; then
          say "${yellow}Fässer heben in dieser Runde schon erledigt.${reset}"; press_enter
        else
          say "${cyan}Uff! +6 Gold.${reset}"; gold=$((gold+6)); money
          job_done[harbour_barrels]="true"; maybe_reset_jobs_round; press_enter
        fi
        ;;
      4) lighthouse_scene ;;
      5) return ;;
    esac
  done
}

lighthouse_scene(){
  show_scene "$(img lighthouse.png)" lighthouse_ascii
  say "${cyan}Leuchtturmwärter:${reset} 'Navigator gesucht? Beweise Verstand!'"
  if [[ -n "${crew[Navigator]+x}" ]]; then say "${yellow}Navigator ist schon an Bord.${reset}"; press_enter; return; fi
  echo "  1) Ein Kompass"
  echo "  2) Die Ebbe"
  echo "  3) Ein Pirat nach Feierabend"
  read -rp "Antwort: " a
  if [[ "$a" == "1" ]]; then crew["Navigator"]=true; say "${green}Richtig. Navigator tritt bei.${reset}"
  else say "${red}Falsch. Kein Stern für dich.${reset}"; fi
  press_enter
}

blacksmith_scene(){
  show_scene "$(img blacksmith.png)" blacksmith_ascii
  say "${cyan}Funken sprühen. Schmiedin nickt knapp.${reset}"
  while true; do
    echo "  1) Mit Kanonier sprechen (Mathe)"
    echo "  2) Mit Tischler sprechen (Knoten)"
    echo "  3) Kleiner Job: Kohle schaufeln (+8 Gold) [1x/Runde]"
    echo "  4) Zurück"
    read -rp "Deine Wahl: " a
    case "$a" in
      1)
        if [[ -n "${crew[Kanonier]+x}" ]]; then say "${yellow}Kanonier ist schon Crew.${reset}"
        else
          say "${magenta}Kanonier:${reset} '2 Kanonen, alle 10s je 1 Schuss. Wieviele Kugeln nach 60s?'"
          echo "  1) 12   2) 6   3) 10"; read -rp "Antwort: " r
          [[ "$r" == "1" ]] && { crew["Kanonier"]=true; say "${green}Bestanden. Kanonier tritt bei.${reset}"; } || say "${red}Nope.${reset}"
        fi
        press_enter;;
      2)
        if [[ -n "${crew[Tischler]+x}" ]]; then say "${yellow}Tischler ist schon Crew.${reset}"
        else
          say "${magenta}Tischler:${reset} 'Welcher Knoten für eine Rettungsschlinge?'"
          echo "  1) Palstek   2) Schotstek   3) Fischerknoten"; read -rp "Antwort: " r
          [[ "$r" == "1" ]] && { crew["Tischler"]=true; say "${green}Aye. Tischler tritt bei.${reset}"; } || say "${red}Nein.${reset}"
        fi
        press_enter;;
      3)
        if [[ "${job_done[blacksmith_coal]}" == "true" ]]; then
          say "${yellow}Kohleschaufeln in dieser Runde schon erledigt.${reset}"; press_enter
        else
          say "${cyan}Staubig, heiß, bezahlt. +8 Gold.${reset}"; gold=$((gold+8)); money
          job_done[blacksmith_coal]="true"; maybe_reset_jobs_round; press_enter
        fi
        ;;
      4) return;;
    esac
  done
}

sail_away(){
  show_scene "$(img ship.png)" ship_ascii
  say "${yellow}Du hast Schiff, Karte und mindestens drei fähige Hände.${reset}"
  say "${blue}Der Wind füllt die Segel. Vor dir: Horizont. Hinter dir: offene Tavernenrechnungen.${reset}"
  echo -e "${bold}${magenta}TO BE CONTINUED ...${reset}"
  press_enter; exit 0
}

street_scene(){
  while true; do
    if $has_ship && $has_map && ((${#crew[@]}>=3)); then sail_away; fi
    show_scene "$(img street.png)" street_ascii
    say "${yellow}Du stehst auf der Straße der Hafenstadt.${reset}"
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

# --- Start --------------------------------------------------------------------
check_terminal
display_header
street_scene
