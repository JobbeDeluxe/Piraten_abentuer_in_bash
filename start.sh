#!/bin/bash
# PIRATENABENTEUER – erweiterte Version (bunter, größer, witziger, mit Rätseln & Jobs)
# Läuft im Terminal: bash piratenabenteuer.sh

# --- Runtime-Basics -----------------------------------------------------------
if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  echo "Dieses Abenteuer benötigt mindestens Bash 4. Bitte aktualisiere deine Bash-Version."
  exit 1
fi

# Farben (tput, fallback ohne Farben)
if [ -z "$TERM" ]; then export TERM=xterm; fi
if command -v tput >/dev/null 2>&1; then
  bold=$(tput bold 2>/dev/null || true)
  dim=$(tput dim 2>/dev/null || true)
  reset=$(tput sgr0 2>/dev/null || true)
  black=$(tput setaf 0 2>/dev/null || true)
  red=$(tput setaf 1 2>/dev/null || true)
  green=$(tput setaf 2 2>/dev/null || true)
  yellow=$(tput setaf 3 2>/dev/null || true)
  blue=$(tput setaf 4 2>/dev/null || true)
  magenta=$(tput setaf 5 2>/dev/null || true)
  cyan=$(tput setaf 6 2>/dev/null || true)
  white=$(tput setaf 7 2>/dev/null || true)
else
  bold=""; dim=""; reset=""
  black=""; red=""; green=""; yellow=""; blue=""; magenta=""; cyan=""; white=""
fi

# Mindest-Terminalgröße (für große ASCII-Bilder)
min_cols=90
min_lines=28
get_cols() { command -v tput >/dev/null 2>&1 && tput cols || echo 80; }
get_lines(){ command -v tput >/dev/null 2>&1 && tput lines || echo 24; }
check_terminal() {
  local c=$(get_cols) l=$(get_lines)
  if (( c < min_cols || l < min_lines )); then
    echo -e "${yellow}${bold}Hinweis:${reset} Dieses Spiel sieht am besten ab ${min_cols}x${min_lines} Zeichen aus."
    echo -e "Aktuell: ${c}x${l}. Bitte vergrößere das Terminal (z.B. Vollbild) und starte erneut."
    read -rp "Trotzdem spielen? (j/N) " ans
    [[ "$ans" =~ ^[JjYy]$ ]] || exit 0
  fi
}

# --- Spielzustand -------------------------------------------------------------
declare -A inventory   # Items: ["Karte"]=true, ["Apfel"]=true, ...
declare -A crew        # Crew:  ["Schiffsjunge"]=true, ["Navigator"]=true ...
gold=15                # Startkapital, klein aber fein
has_ship=false
has_map=false          # bleibt für Logik zusätzlich zu inventory["Karte"]
savefile="${HOME}/.piratenabenteuer.save"

# --- Helpers ------------------------------------------------------------------
press_enter(){ echo; read -rp "Drücke [Enter], um fortzufahren... "; }
say(){ echo -e "$*${reset}"; }
money(){ echo -e "${yellow}${bold}Gold:${reset} ${yellow}${gold}${reset}"; }
have(){ [[ -n "${inventory[$1]+x}" ]]; }     # have "Item"
in_crew(){ [[ -n "${crew[$1]+x}" ]]; }       # in_crew "Rolle"

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
    say "${red}Ungültige Eingabe.${reset}"
  done
}

# --- ASCII-Kunst --------------------------------------------------------------
banner(){
  cat <<'EOF'
 __    __  .__   __.  _______   ______   .___________. _______  _______   ______  __    __
|  |  |  | |  \ |  | |       \ /  __  \  |           ||   ____||   ____| /      ||  |  |  |
|  |__|  | |   \|  | |  .--.  |  |  |  | `---|  |----`|  |__   |  |__   |  ,----'|  |__|  |
|   __   | |  . `  | |  |  |  |  |  |  |     |  |     |   __|  |   __|  |  |     |   __   |
|  |  |  | |  |\   | |  '--'  |  `--'  '     |  |     |  |____ |  |____ |  `----.|  |  |  |
|__|  |__| |__| \__| |_______/ \______/      |__|     |_______||_______| \______||__|  |__|
EOF
}

ascii_street(){
  cat <<'EOF'
              ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
         ~  ~        .-^^-._        _.-^^-.         ~   ~
            _     .-^  _   _^-.  .-^_   _  ^-.   _
           / \  .^   .´ `-´ `.  V  .´`-´ `.   ^. / \
          / | \/  .-´  TAVERNE `-^-´  MARKT  `-. \/ | \
         /  | /  /   _    |   _   _    |    _   \ \ |  \
        /   |/  |   (_)   |  (_) (_)   |   (_)   | \|   \
====/====/====/====/====/====/====/====/====/====/====/======
      |         HAFEN ->           ~  ~  ~  ~
      |___________________________ Holzplanken ~  ~
EOF
}

ascii_tavern_big(){
  cat <<'EOF'
        .-~~~~~~~~~~~~~~~~~~~~~~~~~~~~-.
       /   _   _    ____    _   _       \
      /   | | | |  / __ \  | \ | |       \
     |    | |_| | | |  | | |  \| |        |
     |    |  _  | | |  | | | . ` |  ____  |
     |    | | | | | |__| | | |\  | |____| |
      \   |_| |_|  \____/  |_| \_|        /
       \_________________________________/
          |  _   _  |  |  _   _  |  |   |
          | | | | | |  | | | | | |  |   |
          | | |_| | |  | | |_| | |  |   |
          | |  _  | |  | |  _  | |  |   |
          | | | | | |  | | | | | |  |   |
          |_|_| |_|_|  |_|_| |_|_|  |___|
         /  __   __  \  /   __   \   | |
        /  (  ) (  )  \/   (  )   \  | |
       /___||____||____\___||______\_|_|
          Krüge • Rum • Gekicher • Lieder
EOF
}

ascii_market_big(){
  cat <<'EOF'
            ________________________________
           /  FRISCHER FISCH  •  OBST  •  SEILE \
          /_____________________________________\
          |  o   o    o    o    o    o    o     |
          |    o    o    o    o    o    o       |
          | o    o   o   o   o   o    o    o    |
          |_____________________________________|
            \__\__\__\__\__\__\__\__\__\__\__/
                 |      |      |      |
                 |      |      |      |
              Händler  Äpfel  Krimskrams
EOF
}

ascii_docks_big(){
  cat <<'EOF'
                           |\
                           | \      Möwen: "Kreee!"
                     ______|__\____________________
                    /   Holzsteg  |               /|
                   /              |   KLEINER    / |
                  /     WASSER    |    KAHN     /  |
                 /________________|____________/   |
                 |                                |
                 |    Fässer • Taue • Matrosen    |
                 |________________________________|
                ~~~    ~~~      ~~~     ~~~    ~~~~
EOF
}

ascii_lighthouse(){
  cat <<'EOF'
                 /\ 
                /  \
               / /\ \
              / /  \ \
             /_/____\_\
               |    |
               | [] |
               |____|      ~  ~      Sterne funkeln
            ___/____\___
           /            \
          /   LEUCHT-    \
         /     TURM       \
         -------------------
EOF
}

ascii_blacksmith(){
  cat <<'EOF'
      (__)   SCHMIEDE
   ___(  ))__________________
  /  /|  /  Hammer  Funken  /|
 /__/ |_/___________________/ |
 |  __      __      __      | |
 | |__|    |__|    |__|     | |
 |  ||      ||      ||      | |
 |__||______||______||______|/
   (glühendes Eisen)   (Kohle)
EOF
}

ascii_casino(){
  cat <<'EOF'
     .------.------.------.      Einsatz! Würfel rollen!
     |  6   |  6   |  6   |      (Kein Einsatz -> kein Spiel)
     '------'------'------'
     .------.------.------.
     |  3   |  4   |  5   |
     '------'------'------'
EOF
}

ascii_ship_big(){
  cat <<'EOF'
                 |    |    |
                )_)  )_)  )_)
               )___))___))___)\ 
              )____)____)_____)\\
            _____|____|____|____\\\__
    -------\         KAPITÄN         /-----
             \_______________________/
             ~ ~ ~   Wellen   ~ ~ ~ ~
EOF
}

# Druck-Helfer für farbige Bilder
paint(){ local color="$1"; shift; while IFS= read -r line; do echo -e "${color}${line}${reset}"; done <<<"$*"; }

# --- Speichern/Laden ----------------------------------------------------------
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
    # Rekonstruiere Booleans & Maps
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

# --- Szenen & Logik -----------------------------------------------------------
display_header(){
  clear
  paint "$cyan" "$(banner)"
  echo
  paint "$magenta" "$(ascii_street)"
  echo -e "${yellow}Du träumst davon, so legendär zu werden wie ${bold}Guybrush Threepwood${reset}${yellow}.*${reset}"
  echo -e "${dim}* Völlig zufällige Ähnlichkeit mit berühmten Piraten ist selbstverständlich Zufall.${reset}"
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
  choose "Aktion:" "Zurück" "Spiel speichern" "Spiel laden"
  case "$choice" in
    "Spiel speichern") save_game; press_enter;;
    "Spiel laden") load_game;;
  esac
}

# --- Taverne: Glücksspiel, Karte, Koch anheuern (Rätsel) ----------------------
dice_game(){
  clear
  paint "$yellow" "$(ascii_casino)"
  say "${bold}Piraten-Pasch${reset}: Du & der Pirat würfeln je 3 Würfel. Höhere Summe gewinnt den Einsatz."
  while true; do
    money
    read -rp "Einsatz (1..50, 0=zurück): " bet
    [[ ! "$bet" =~ ^[0-9]+$ ]] && { say "${red}Zahl, bitte.${reset}"; continue; }
    (( bet==0 )) && return
    if (( bet<1 || bet>50 )); then say "${red}Zwischen 1 und 50, bitte.${reset}"; continue; fi
    if (( gold<bet )); then say "${red}Du hast nicht genug Gold für diesen Einsatz.${reset}"; continue; fi
    # würfeln
    p1=$((1+RANDOM%6)); p2=$((1+RANDOM%6)); p3=$((1+RANDOM%6)); ps=$((p1+p2+p3))
    o1=$((1+RANDOM%6)); o2=$((1+RANDOM%6)); o3=$((1+RANDOM%6)); os=$((o1+o2+o3))
    echo -e "Du würfelst: ${green}${p1}-${p2}-${p3} (Summe ${ps})${reset}"
    echo -e "Gegner würfelt: ${red}${o1}-${o2}-${o3} (Summe ${os})${reset}"
    if (( ps>os )); then
      gold=$((gold+bet))
      say "${green}Gewonnen! +${bet} Gold.${reset}"
    elif (( ps<os )); then
      gold=$((gold-bet))
      say "${red}Verloren! -${bet} Gold.${reset}"
    else
      say "${yellow}Unentschieden. Kein Gewinn, kein Verlust.${reset}"
    fi
    (( gold<1 )) && { say "${red}Du bist pleite. Vielleicht Teller spülen?${reset}"; press_enter; return; }
    choose "Nochmal?" "Ja" "Nein"
    [[ "$choice" == "Nein" ]] && return
  done
}

tavern_cook_riddle(){
  # Koch will nur mit, wenn du ein absurd-kulinarisches Rätsel packst
  say "${magenta}Der Koch brummt:${reset} 'Ich schließe mich nur einem Genie an. Wähle die drei Zutaten, die NICHT explodieren.'"
  say "Optionen: Wasser, Zwiebel, Salz, Rum, Chili, Banane"
  choose "Wähle eine Kombination:" \
    "Wasser + Zwiebel + Salz" \
    "Rum + Chili + Banane" \
    "Wasser + Banane + Rum"
  case "$choice" in
    "Wasser + Zwiebel + Salz")
      crew["Koch"]=true
      say "${green}Der Koch nickt beeindruckt: 'Endlich jemand mit Geschmacksknospen!' (Koch tritt bei)${reset}"
      ;;
    "Rum + Chili + Banane"|"Wasser + Banane + Rum")
      say "${red}BOOOOM! (Zum Glück nur in der Fantasie – aber der Koch schaut sehr enttäuscht.)${reset}"
      say "${yellow}Tipp:${reset} Alkohol & Banane sind fürs Dessert – nicht für die Suppe."
      ;;
  esac
  press_enter
}

tavern_scene(){
  clear
  paint "$yellow" "$(ascii_tavern_big)"
  say "${cyan}Die Taverne bebt. Lachen, Rumgeruch, jemand spielt auf einer verstimmten Laute.${reset}"
  while true; do
    local acts=("Mit dem Wirt sprechen" "Piraten-Pasch spielen" "Karte kaufen (30 Gold)" "Mit dem Koch sprechen" "Zurück zur Straße")
    choose "Was tun?" "${acts[@]}"
    case "$choice" in
      "Mit dem Wirt sprechen")
        say "${magenta}Wirt:${reset} 'Legendäre Schätze! Legendäre Rechnungen! Was darf's sein?'"
        press_enter
        ;;
      "Piraten-Pasch spielen")
        dice_game
        ;;
      "Karte kaufen (30 Gold)")
        if $has_map; then
          say "${yellow}Du besitzt bereits eine Karte.${reset}"
        elif (( gold<30 )); then
          say "${red}Nicht genug Gold. Vielleicht unten am Hafen jobben?${reset}"
        else
          choose "Für 30 Gold kaufen?" "Ja" "Nein"
          if [[ "$choice" == "Ja" ]]; then
            gold=$((gold-30)); has_map=true; inventory["Karte"]=true
            say "${green}Du erwirbst eine knitterige Schatzkarte. Hoffentlich ist sie nicht von Kindern gemalt.${reset}"
          fi
        fi
        press_enter
        ;;
      "Mit dem Koch sprechen")
        if in_crew "Koch"; then
          say "${yellow}Der Koch ist bereits in deiner Crew. Er würzt gerade den Rum mit Pfeffer (frag nicht).${reset}"
          press_enter
        else
          tavern_cook_riddle
        fi
        ;;
      "Zurück zur Straße")
        return
        ;;
    esac
  done
}

# --- Markt: Apfel, Schiffsjunge (Apfel-Trick), Kleinkram, Job -----------------
market_scene(){
  clear
  paint "$green" "$(ascii_market_big)"
  say "${cyan}Der Markt: laut, bunt, leicht klebrig unter den Sandalen.${reset}"
  while true; do
    local acts=("Apfel kaufen (5 Gold)" "Tau/Seil kaufen (7 Gold)" "Mit Schiffsjungen sprechen" "Kleiner Job: Waren ausrufen (+4 Gold)" "Zurück zur Straße")
    choose "Was tun?" "${acts[@]}"
    case "$choice" in
      "Apfel kaufen (5 Gold)")
        if (( gold<5 )); then say "${red}Dafür fehlt dir Gold.${reset}"; else gold=$((gold-5)); inventory["Apfel"]=true; say "${green}Du kaufst einen herrlich saftigen Apfel.${reset}"; fi
        press_enter
        ;;
      "Tau/Seil kaufen (7 Gold)")
        if (( gold<7 )); then say "${red}Zu wenig Gold.${reset}"; else gold=$((gold-7)); inventory["Seil"]=true; say "${green}Ein robustes Seil – kann man immer brauchen.${reset}"; fi
        press_enter
        ;;
      "Mit Schiffsjungen sprechen")
        if in_crew "Schiffsjunge"; then
          say "${yellow}Der Schiffsjunge ist schon an Bord – er übt gerade 'Seemannsknoten für Dummies'.${reset}"
          press_enter
        else
          say "${magenta}Schiffsjunge:${reset} 'Ich komme mit, aber... äh... Aufnahmegebühr 30 Gold?'"
          if have "Apfel"; then
            say "${cyan}Du hältst langsam einen glänzenden Apfel in die Höhe.${reset}"
            choose "Der Apfel...?" "Bestechung versuchen" "Lieber 30 Gold zahlen (wenn vorhanden)" "Doch nicht"
            case "$choice" in
              "Bestechung versuchen")
                say "${green}Schiffsjunge:${reset} '…ist das ein ${bold}Apfel${reset}? Ich LIEBE Äpfel. Deal!'"
                unset 'inventory["Apfel"]'
                crew["Schiffsjunge"]=true
                say "${green}Der Schiffsjunge tritt deiner Crew bei – bezahlt in Obst.${reset}"
                ;;
              "Lieber 30 Gold zahlen (wenn vorhanden)")
                if (( gold>=30 )); then gold=$((gold-30)); crew["Schiffsjunge"]=true; say "${green}Er steckt die 30 Gold ein und springt auf.${reset}"; else say "${red}Du hast keine 30 Gold.${reset}"; fi
                ;;
              *)
                say "${yellow}Der Junge schaut enttäuscht dem Apfel hinterher, der wieder in der Tasche verschwindet.${reset}"
                ;;
            esac
          else
            if (( gold>=30 )); then
              choose "30 Gold für den Schiffsjungen zahlen?" "Ja" "Nein"
              [[ "$choice" == "Ja" ]] && { gold=$((gold-30)); crew["Schiffsjunge"]=true; say "${green}Er ist jetzt an Bord (und leicht gierig).${reset}"; }
            else
              say "${red}Du hast keinen Apfel und zu wenig Gold. Vielleicht erst jobben?${reset}"
            fi
          fi
          press_enter
        fi
        ;;
      "Kleiner Job: Waren ausrufen (+4 Gold)")
        say "${cyan}Du brüllst: 'FRISCHE FISCHE! FRISCHE… *hust*' – Ein paar Münzen klimpern in deine Hand.${reset}"
        gold=$((gold+4)); money; press_enter
        ;;
      "Zurück zur Straße")
        return
        ;;
    esac
  done
}

# --- Hafen/Docks: Schiffsbauer, Jobs, Navigator (Leuchtturm) ------------------
harbour_scene(){
  clear
  paint "$cyan" "$(ascii_docks_big)"
  say "${cyan}Der Hafen riecht nach Salz, Holz und leicht verbranntem Seemann.${reset}"
  while true; do
    local acts=("Die Schiffe bestaunen" "Mit dem Schiffsbauer sprechen" "Kleiner Job: Fässer schleppen (+6 Gold)" "Zum Leuchtturm (Navigator?)" "Zurück zur Straße")
    choose "Was tun?" "${acts[@]}"
    case "$choice" in
      "Die Schiffe bestaunen")
        say "${magenta}Du starrst verträumt: 'Eines Tages, Baby…' – Die Möwen sind unbeeindruckt.${reset}"
        press_enter
        ;;
      "Mit dem Schiffsbauer sprechen")
        if $has_ship; then
          say "${yellow}Schiffsbauer:${reset} 'Pflege dein Schiff gut. Keine Bananenschalen an Deck!'"
          press_enter
        else
          say "${magenta}Schiffsbauer:${reset} 'Kleines Schiff, 50 Gold. Aber nur an Leute mit Karte und Crew!'"
          if (( gold<50 )); then
            say "${red}Du brauchst 50 Gold.${reset}"
          elif ! $has_map; then
            say "${red}Ohne Karte keine Auslieferung – Versicherungsding.${reset}"
          elif ((${#crew[@]}<2)); then
            say "${red}Mindestens zwei Crew-Mitglieder nötig.${reset}"
          else
            choose "Schiff für 50 Gold kaufen?" "Ja" "Nein"
            if [[ "$choice" == "Ja" ]]; then
              gold=$((gold-50)); has_ship=true
              say "${green}Du erhältst einen Schlüsselbund und ein Boot, das 'nicht ganz dicht' nur sprichwörtlich ist.${reset}"
            fi
          fi
          press_enter
        fi
        ;;
      "Kleiner Job: Fässer schleppen (+6 Gold)")
        say "${cyan}Uff! Aua! …und +6 Gold. Dein Rücken verhandelt über Urlaub.${reset}"
        gold=$((gold+6)); money; press_enter
        ;;
      "Zum Leuchtturm (Navigator?)")
        lighthouse_scene
        ;;
      "Zurück zur Straße")
        return
        ;;
    esac
  done
}

lighthouse_scene(){
  clear
  paint "$white" "$(ascii_lighthouse)"
  say "${cyan}Der Leuchtturmwärter blinzelt: 'Navigator suchst du? Beweise dein Hirn kann mehr als Rum verdunsten.'${reset}"
  if in_crew "Navigator"; then
    say "${yellow}Der Navigator zeichnet schon Sterne in dein Logbuch.${reset}"; press_enter; return
  fi
  say "${magenta}Rätsel:${reset} 'Ich zeige immer nach Norden, obwohl ich nie gehe. Was bin ich?'"
  choose "Antwort wählen:" "Ein Kompass" "Die Ebbe" "Ein Pirat nach Feierabend"
  if [[ "$choice" == "Ein Kompass" ]]; then
    crew["Navigator"]=true
    say "${green}'Richtig. Ich komme mit. Aber ich parke den Leuchtturm ordentlich!' (Navigator tritt bei)${reset}"
  else
    say "${red}'Nope.' Der Wärter macht das universelle 'falsche Antwort'-Gesicht.${reset}"
  fi
  press_enter
}

# --- Schmiede: Kanonier (Mathe), Tischler (Knoten), Job -----------------------
blacksmith_scene(){
  clear
  paint "$red" "$(ascii_blacksmith)"
  say "${cyan}Es zischt und funkelt. Die Schmiedin nickt knapp.${reset}"
  while true; do
    local acts=("Mit Kanonier sprechen" "Mit Tischler sprechen" "Kleiner Job: Kohle schaufeln (+8 Gold)" "Zurück zur Straße")
    choose "Was tun?" "${acts[@]}"
    case "$choice" in
      "Mit Kanonier sprechen")
        if in_crew "Kanonier"; then
          say "${yellow}Der Kanonier poliert imaginäre Kanonen. 'Peng!' – 'Noch nicht!'${reset}"
        else
          say "${magenta}Kanonier:${reset} 'Rechnen kannst du? Test: Zwei Kanonen schießen alle 10 Sekunden je eine Kugel. Wie viele Kugeln nach 1 Minute?'"
          choose "Deine Antwort:" "12" "6" "10"
          if [[ "$choice" == "12" ]]; then
            crew["Kanonier"]=true; say "${green}'Passt. Ich bin dabei.' (Kanonier tritt bei)${reset}"
          else
            say "${red}'Du bist doch nicht die Buchhaltung, oder?'${reset}"
          fi
        fi
        press_enter
        ;;
      "Mit Tischler sprechen")
        if in_crew "Tischler"; then
          say "${yellow}Der Tischler klopft auf Holz. 'Klingt solide.'${reset}"
        else
          say "${magenta}Tischler:${reset} 'Welcher Knoten für eine Rettungsschlinge?'"
          choose "Antwort:" "Palstek" "Schotstek" "Fischerknoten"
          if [[ "$choice" == "Palstek" ]]; then
            crew["Tischler"]=true; say "${green}'Aye. Du bist mein Kapitän.' (Tischler tritt bei)${reset}"
          else
            say "${red}'Das hält höchstens deine Hose.'${reset}"
          fi
        fi
        press_enter
        ;;
      "Kleiner Job: Kohle schaufeln (+8 Gold)")
        say "${cyan}Schwitz! Staub! Aber +8 Gold. Deine Lunge singt 'Hust-Hust' im Kanon.${reset}"
        gold=$((gold+8)); money; press_enter
        ;;
      "Zurück zur Straße")
        return
        ;;
    esac
  done
}

# --- Segeln (Ziel) ------------------------------------------------------------
sail_away(){
  clear
  paint "$cyan" "$(ascii_ship_big)"
  say "${yellow}Du hast: Schiff, Karte und mindestens drei fähige Gestalten, die 'Backbord' nicht für ein Brettspiel halten.${reset}"
  say "${blue}Der Wind füllt die Segel. Du stichst in See. Irgendwo gackert eine Möwe auf Piratisch.${reset}"
  echo -e "${bold}${magenta}TO BE CONTINUED ...${reset}"
  press_enter
  exit 0
}

# --- Hauptschleife / Stadt ----------------------------------------------------
street_scene(){
  while true; do
    # Siegbedingung: Schiff, Karte, >=3 Crew
    if $has_ship && $has_map && ((${#crew[@]}>=3)); then sail_away; fi

    clear
    paint "$cyan" "$(ascii_street)"
    say "${yellow}Du stehst auf der staubigen Straße der Hafenstadt."
    local ops=("Zur Taverne" "Zum Markt" "Zum Hafen" "Zur Schmiede" "Status anzeigen" "Spiel speichern" "Spiel beenden")
    choose "Wohin?" "${ops[@]}"
    case "$choice" in
      "Zur Taverne") tavern_scene ;;
      "Zum Markt") market_scene ;;
      "Zum Hafen") harbour_scene ;;
      "Zur Schmiede") blacksmith_scene ;;
      "Status anzeigen") status_screen ;;
      "Spiel speichern") save_game; press_enter ;;
      "Spiel beenden") say "${magenta}Bis zum nächsten Mal!${reset}"; exit 0 ;;
    esac
  done
}

# --- Start --------------------------------------------------------------------
check_terminal
display_header
press_enter
street_scene
