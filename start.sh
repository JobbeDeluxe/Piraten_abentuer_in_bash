#!/bin/bash

# Pirate Adventure – a simple text‑based point‑and‑click style game for the terminal
#
# This script uses ANSI escape sequences for colour and simple ASCII art to
# illustrate scenes. The player takes the role of a wannabe pirate who explores
# a small harbour town in search of a ship. Throughout the adventure the
# player can visit locations such as a tavern, the market and the docks,
# interact with characters, collect items and make choices that branch the
# story. Eventually, when the necessary objectives have been achieved, the
# player will set sail, and the game ends with a "to be continued" message.
#
# To play the game, run this script in a Unix/Linux terminal: bash pirate_adventure.sh
# Ensure the terminal supports colours; if not, the game will still work but
# colours will not display as intended.

# Check for Bash version 4 or later to ensure associative arrays work
if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  echo "Dieses Abenteuer benötigt mindestens Bash 4. Bitte aktualisiere deine Bash-Version."
  exit 1
fi

# Set up some ANSI colour codes using tput. The TERM environment variable must
# be defined for tput to work; otherwise tput will complain. If TERM is not
# set, we default to "xterm". Should tput be unavailable or fail, we fall
# back to empty strings so the script still runs without colours.
if [ -z "$TERM" ]; then
  # Default to xterm if TERM is undefined. Exporting ensures that child
  # processes like clear and tput see the value.
  export TERM=xterm
fi
if command -v tput >/dev/null 2>&1; then
  # Try to assign colours; suppress potential error messages by redirecting
  # stderr to /dev/null. If tput fails (e.g. unsupported terminal), variables
  # remain empty.
  bold=$(tput bold 2>/dev/null || true)
  red=$(tput setaf 1 2>/dev/null || true)
  green=$(tput setaf 2 2>/dev/null || true)
  yellow=$(tput setaf 3 2>/dev/null || true)
  blue=$(tput setaf 4 2>/dev/null || true)
  magenta=$(tput setaf 5 2>/dev/null || true)
  cyan=$(tput setaf 6 2>/dev/null || true)
  white=$(tput setaf 7 2>/dev/null || true)
  reset=$(tput sgr0 2>/dev/null || true)
else
  bold=""; red=""; green=""; yellow=""; blue=""; magenta=""; cyan=""; white=""; reset=""
fi

# Global state variables. These track whether the player has acquired certain
# items or completed particular tasks. The game uses them to enable or
# restrict actions.
declare -A inventory
has_ship=false
has_map=false
gold=0

# Helper function to pause until the user presses Enter.
press_enter() {
  echo
  read -rp "Drücke [Enter], um fortzufahren... "
}

# ASCII art definitions. These are displayed at various points in the game.
ascii_pirate() {
  # A simple pirate portrait using ASCII art. This illustration gives the
  # impression of a pirate with a bandana and eyepatch.
  cat <<'EOF'
         _~_
        (o.o)
         |)|
        _| |_
      _/     \_
EOF
}

ascii_tavern() {
  # An interior view of a rustic tavern. The mugs and bottles on the
  # bar hint at a busy establishment.
  cat <<'EOF'
        .-"""-.
       /       \
      /  .-""-. \
     |  /      \ |
     | |  .--.  | |
     | | (    ) | |
     |  \ '--' /  |
      \  '-..-'  /
       '-.____.-'
        /  ||  \
       |   ||   |
       |   ||   |
       |   ||   |
        \  ||  /
         '--'--'
EOF
}

ascii_market() {
  # A simple market stall with an awning. Fruits and goods are hinted by
  # different characters.
  cat <<'EOF'
      _______
     /\_____/\
    / /     \ \
   ( (       ) )
    \ \_____/ /
     \_______/
     /       \
    /  o   o  \
   /    o      \
  / o       o   \
EOF
}

ascii_harbour() {
  # A small boat moored at a dock. The waves below simulate the sea.
  cat <<'EOF'
            |\
           /| \    
          /_|__\
       ___/_____\____
      /             /|
     /    O   O    / |
    /_____________/  |
    |             |  |
    |             |  |
    |             |  |
    |_____________| /
     \_____________/
      ~~~    ~~~
EOF
}

ascii_ship() {
  # A larger sailing ship used when the player finally obtains their own ship.
  cat <<'EOF'
                 |    |    |
                )_)  )_)  )_)
               )___))___))___)\
              )____)____)_____)\\
            _____|____|____|____\\\__
    -------\                   /-----
             \_________________/
EOF
}

# Function: display_header
# Prints the game title and initial banner with colours and ASCII art.
display_header() {
  clear
  echo -e "${bold}${cyan}Willkommen bei PIRATENABENTEUER!${reset}"
  echo -e "${yellow}Du bist ein junger Abenteurer, der davon träumt, ein großer Pirat zu werden – so legendär wie Guybrush Threepwood.${reset}"
  echo
  ascii_pirate | while read -r line; do echo -e "${magenta}${line}${reset}"; done
  echo
  echo -e "${blue}Du befindest dich in einer kleinen Hafenstadt auf einer tropischen Insel. Es riecht nach Rum, Salz und Abenteuer...${reset}"
  echo
}

# Function: choose
# Generic helper to present a list of choices and return the selected option.
# Arguments: a list of strings (each option) and sets $choice to the selection.
choose() {
  local prompt="$1"; shift
  local options=()
  local i=1
  for opt in "$@"; do
    options+=("$opt")
  done
  echo -e "$prompt"
  for idx in "${!options[@]}"; do
    printf "  %s) %s\n" "$((idx+1))" "${options[$idx]}"
  done
  local sel
  while true; do
    read -rp "Deine Wahl: " sel
    if [[ "$sel" =~ ^[0-9]+$ && $sel -ge 1 && $sel -le ${#options[@]} ]]; then
      choice=${options[$((sel-1))]}
      break
    else
      echo "Ungültige Eingabe. Bitte gib eine Zahl zwischen 1 und ${#options[@]} ein."
    fi
  done
}

# Function: tavern_scene
# Handles the interactions within the tavern. The player can talk to patrons,
# gamble for gold or buy a map if they have enough gold. The tavern sets up
# story elements and possibilities for acquiring a map.
tavern_scene() {
  clear
  echo -e "${yellow}Du betrittst die Taverne. Das Gemurmel von Stimmen, das Klirren von Krügen und eine leise Musik erfüllen den Raum.${reset}"
  # Display the tavern with a warm yellow/brown tone. Since there is no explicit
  # brown colour in many terminals, we reuse yellow as a substitute.
  ascii_tavern | while read -r line; do echo -e "${yellow}${line}${reset}"; done
  echo
  local leave=false
  while [ "$leave" = false ]; do
    echo -e "${cyan}Was möchtest du tun?${reset}"
    # Define available actions depending on the player's current state
    local actions=("Mit dem Wirt sprechen" "Mit einem Piraten würfeln" "Zurück zur Straße")
    if ! $has_map; then
      actions+=("Nach einer Karte fragen")
    fi
    choose "" "${actions[@]}"
    case "$choice" in
      "Mit dem Wirt sprechen")
        echo -e "${magenta}Du bestellst einen Krug Rum und plauderst mit dem Wirt. Er erzählt dir von einem legendären Schatz, der irgendwo in diesen Gewässern versteckt sein soll.${reset}"
        press_enter
        ;;
      "Mit einem Piraten würfeln")
        echo -e "${magenta}Du setzt dich an einen Tisch, an dem ein zahnloser Pirat Würfel in der Hand hält.${reset}"
        echo -e "${magenta}Ihr spielt eine Runde um 10 Goldstücke.${reset}"
        # Simulate a simple dice game: random win/loss
        local roll=$((RANDOM % 2))
        if [[ $roll -eq 0 ]]; then
          echo -e "${red}Du verlierst! Der Pirat lacht dreckig und streicht deine 10 Goldstücke ein.${reset}"
          ((gold=gold-10))
          if [ $gold -lt 0 ]; then gold=0; fi
        else
          echo -e "${green}Du gewinnst! Der Pirat knurrt, aber überreicht dir 20 Goldstücke.${reset}"
          ((gold=gold+20))
        fi
        echo -e "${yellow}Du hast jetzt $gold Goldstücke.${reset}"
        press_enter
        ;;
      "Nach einer Karte fragen")
        if $has_map; then
          echo -e "${magenta}Du besitzt bereits eine Karte.${reset}"
        elif [ $gold -lt 30 ]; then
          echo -e "${red}Der Wirt schüttelt den Kopf. 'Ich verkaufe dir eine alte Schatzkarte für 30 Goldstücke. Du hast nicht genug Gold.'${reset}"
        else
          echo -e "${green}Der Wirt lächelt verschwörerisch und legt eine vergilbte Karte auf den Tisch.${reset}"
          echo -e "${green}'Für 30 Goldstücke gehört sie dir', sagt er.${reset}"
          choose "Möchtest du die Karte kaufen?" "Ja" "Nein"
          if [[ "$choice" = "Ja" ]]; then
            ((gold=gold-30))
            has_map=true
            inventory["Karte"]=true
            echo -e "${yellow}Du hast eine Schatzkarte erworben!${reset}"
            echo -e "${yellow}Verbleibendes Gold: $gold${reset}"
          else
            echo -e "${magenta}Du entscheidest, das Angebot abzulehnen.${reset}"
          fi
        fi
        press_enter
        ;;
      "Zurück zur Straße")
        leave=true
        ;;
    esac
  done
}

# Function: market_scene
# Handles the market. Here the player can buy supplies or pick up a crew member.
market_scene() {
  clear
  echo -e "${yellow}Du spazierst über den geschäftigen Markt. Händler preisen lautstark ihre Waren an – Fische, exotische Früchte und Seile stapeln sich an ihren Ständen.${reset}"
  ascii_market | while read -r line; do echo -e "${green}${line}${reset}"; done
  echo
  local leave=false
  while [ "$leave" = false ]; do
    echo -e "${cyan}Was möchtest du tun?${reset}"
    local actions=("Einen Apfel kaufen (5 Gold)" "Mit einem Schiffsjungen sprechen" "Zurück zur Straße")
    choose "" "${actions[@]}"
    case "$choice" in
      "Einen Apfel kaufen (5 Gold)")
        if [ $gold -lt 5 ]; then
          echo -e "${red}Du hast nicht genug Gold, um einen Apfel zu kaufen.${reset}"
        else
          ((gold=gold-5))
          echo -e "${green}Der Apfel ist saftig und erfrischend. Du fühlst dich gestärkt.${reset}"
          echo -e "${yellow}Gold übrig: $gold${reset}"
        fi
        press_enter
        ;;
      "Mit einem Schiffsjungen sprechen")
        echo -e "${magenta}Ein junger Schiffsjunge erzählt dir, dass er von einem großen Abenteuer träumt. Er bietet seine Hilfe an, wenn du einmal eine Crew brauchst.${reset}"
        if [[ -z ${inventory["Schiffsjunge"]+x} ]]; then
          choose "Möchtest du ihn anheuern?" "Ja" "Nein"
          if [[ "$choice" = "Ja" ]]; then
            inventory["Schiffsjunge"]=true
            echo -e "${green}Der Schiffsjunge schließt sich dir an!${reset}"
          else
            echo -e "${magenta}Der Schiffsjunge zuckt mit den Schultern und kehrt zu seiner Arbeit zurück.${reset}"
          fi
        else
          echo -e "${magenta}Der Schiffsjunge ist bereits Teil deiner Mannschaft.${reset}"
        fi
        press_enter
        ;;
      "Zurück zur Straße")
        leave=true
        ;;
    esac
  done
}

# Function: harbour_scene
# Handles the harbour/docks. The player can inspect ships, talk to a shipwright
# and, if conditions are met (enough gold and map and crew), purchase a ship.
harbour_scene() {
  clear
  echo -e "${yellow}Du schlenderst zum Hafen. Möwen kreischen über dir, und das Wasser schwappt sanft gegen die Holzpfähle.${reset}"
  ascii_harbour | while read -r line; do echo -e "${cyan}${line}${reset}"; done
  echo
  local leave=false
  while [ "$leave" = false ]; do
    echo -e "${cyan}Was möchtest du tun?${reset}"
    local actions=("Die Schiffe bestaunen" "Mit dem Schiffsbauer sprechen" "Zurück zur Straße")
    choose "" "${actions[@]}"
    case "$choice" in
      "Die Schiffe bestaunen")
        echo -e "${magenta}Du siehst prächtige Schiffe mit hohen Masten und heruntergekommene Kähne. Ein Schiff in der Ferne trägt eine schwarze Flagge mit Totenkopf und gekreuzten Knochen – das Zeichen der Piraten.${reset}"
        press_enter
        ;;
      "Mit dem Schiffsbauer sprechen")
        echo -e "${magenta}Der Schiffsbauer schiebt seine Brille zurecht und nickt dir zu.${reset}"
        if $has_ship; then
          echo -e "${magenta}'Du hast bereits dein Schiff', erinnert er dich.${reset}"
        else
          echo -e "${magenta}'Möchtest du ein Schiff kaufen? Ein kleines Schiff kostet 50 Goldstücke', sagt er.${reset}"
          if [ $gold -lt 50 ]; then
            echo -e "${red}Du hast nicht genug Gold, um ein Schiff zu kaufen.${reset}"
          else
            if ! $has_map; then
              echo -e "${red}'Ich verkaufe keine Schiffe an Leute ohne Karte. Du wirst dich sonst verirren!', warnt der Schiffsbauer.${reset}"
            else
              if [[ -z ${inventory["Schiffsjunge"]+x} ]]; then
                echo -e "${red}'Du hast keine Crew. Auch ein kleines Schiff benötigt mindestens einen Matrosen!', sagt der Schiffsbauer.${reset}"
              else
                choose "Möchtest du das Schiff für 50 Gold kaufen?" "Ja" "Nein"
                if [[ "$choice" = "Ja" ]]; then
                  ((gold=gold-50))
                  has_ship=true
                  echo -e "${green}Du übergibst 50 Goldstücke. Der Schiffsbauer lächelt und überreicht dir die Schlüssel. Du besitzt nun ein eigenes Schiff!${reset}"
                  echo -e "${yellow}Verbleibendes Gold: $gold${reset}"
                else
                  echo -e "${magenta}Du zögerst noch. Vielleicht später.${reset}"
                fi
              fi
            fi
          fi
        fi
        press_enter
        ;;
      "Zurück zur Straße")
        leave=true
        ;;
    esac
  done
}

# Function: sail_away
# Triggered when the player has a ship, a map and a crew. Shows the final
# sailing scene with ASCII art and ends the game with a 'to be continued'.
sail_away() {
  clear
  echo -e "${yellow}Du hast alles, was du brauchst: eine Karte, Gold für Vorräte, eine kleine Crew und dein eigenes Schiff.${reset}"
  echo -e "${blue}Mit pochendem Herzen läufst du an Bord. Der Wind füllt die Segel, und das Schiff schneidet durchs Wasser.${reset}"
  ascii_ship | while read -r line; do echo -e "${cyan}${line}${reset}"; done
  echo
  echo -e "${bold}${magenta}Du stichst in See und beginnst dein erstes großes Abenteuer!${reset}"
  echo -e "${bold}${magenta}TO BE CONTINUED ...${reset}"
  press_enter
  exit 0
}

# Function: main_loop
# Coordinates the player's movement between locations until they achieve their
# goal. If the player obtains the ship along with necessary items, the game
# calls sail_away().
main_loop() {
  while true; do
    # Check winning condition
    if $has_ship && $has_map && [[ -n ${inventory["Schiffsjunge"]+x} ]]; then
      sail_away
    fi
    clear
    echo -e "${yellow}Du stehst auf der staubigen Straße der Hafenstadt. Rechts steht die Taverne, links der Markt und geradeaus siehst du den Hafen.${reset}"
    echo -e "${cyan}Wohin möchtest du gehen?${reset}"
    local options=("Zur Taverne" "Zum Markt" "Zum Hafen" "Status anzeigen" "Spiel beenden")
    choose "" "${options[@]}"
    case "$choice" in
      "Zur Taverne")
        tavern_scene
        ;;
      "Zum Markt")
        market_scene
        ;;
      "Zum Hafen")
        harbour_scene
        ;;
      "Status anzeigen")
        echo -e "${yellow}Gold: $gold${reset}"
        echo -e "${yellow}Inventar:${reset}"
        local any=false
        for key in "${!inventory[@]}"; do
          if [[ ${inventory[$key]} == true ]]; then
            echo -e "  - $key"
            any=true
          fi
        done
        if ! $any; then
          echo -e "  (leer)"
        fi
        press_enter
        ;;
      "Spiel beenden")
        echo -e "${magenta}Bis zum nächsten Mal!${reset}"
        exit 0
        ;;
    esac
  done
}

# Start the game
display_header
press_enter
main_loop
