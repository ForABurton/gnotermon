gnotermon() {
  local GNOME_TERM_DEST="org.gnome.Terminal"
  local GNOME_TERM_PATH="/org/gnome/Terminal"

  case "$1" in
    puppetry)
      shift
      local cmd="$1"; shift
      case "$cmd" in
        list-windows)
          echo "Available terminal windows:"
          gdbus introspect --session --dest "$GNOME_TERM_DEST" \
            --object-path "$GNOME_TERM_PATH/window" \
            | awk '/node [0-9]+/ {print $2}' | tr -d '{}'
          ;;
        list-actions)
          local win="$1"
          if [[ -z "$win" ]]; then
            echo "Usage: gnotermon puppetry list-actions <window-id>"
            return 1
          fi
          gdbus call --session \
            --dest "$GNOME_TERM_DEST" \
            --object-path "$GNOME_TERM_PATH/window/$win" \
            --method org.gtk.Actions.List
          ;;
        activate)
          local win="$1"; shift
          local action="$1"; shift
          if [[ -z "$win" || -z "$action" ]]; then
            echo "Usage: gnotermon puppetry activate <window-id> <action>"
            return 1
          fi
          gdbus call --session \
            --dest "$GNOME_TERM_DEST" \
            --object-path "$GNOME_TERM_PATH/window/$win" \
            --method org.gtk.Actions.Activate "$action" "[]" "{}"
          ;;
        screens)
          gdbus introspect --session --dest "$GNOME_TERM_DEST" \
            --object-path "$GNOME_TERM_PATH/screen"
          ;;
        ping)
          gdbus call --session \
            --dest "$GNOME_TERM_DEST" \
            --object-path "$GNOME_TERM_PATH" \
            --method org.freedesktop.DBus.Peer.Ping
          ;;
        monitor)
          gdbus monitor --session --dest "$GNOME_TERM_DEST"
          ;;
        *)
          echo "Usage: gnotermon puppetry {list-windows|list-actions|activate|screens|ping|monitor}"
          ;;
      esac
      ;;
    
    arbory)
      echo "=== Building GNOME Terminal process tree via PTYs ==="

      _find_server() {
        local pid="$1"
        while [ -n "$pid" ] && [ "$pid" -ne 1 ]; do
          local comm
          comm=$(ps -o comm= -p "$pid" 2>/dev/null | tail -n1)
          if [[ "$comm" == *gnome-terminal* ]]; then
            echo "$pid"
            return 0
          fi
          pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tail -n1)
        done
        return 1
      }

      _list_children() {
        local p="$1"
        local prefix="$2"
        local kids
        kids=$(ps --ppid "$p" -o pid=)
        for kid in $kids; do
          local comm
          comm=$(ps -o comm= -p "$kid" 2>/dev/null | tail -n1)
          echo "${prefix}└─ $kid $comm"
          _list_children "$kid" "  $prefix"
        done
      }

      declare -A server_ptys
      for tty in /dev/pts/[0-9]*; do
        pts="${tty#/dev/}"
        pid=$(ps -t "$pts" -o pid= | head -n1)
        [ -z "$pid" ] && continue
        server=$(_find_server "$pid")
        [ -z "$server" ] && continue
        server_ptys["$server"]+="$pts:$pid "
      done

      for server in "${!server_ptys[@]}"; do
        local comm
        comm=$(ps -o comm= -p "$server" | tail -n1)
        echo ">>> Terminal server PID $server ($comm)"
        echo
        for mapping in ${server_ptys[$server]}; do
          pts="${mapping%%:*}"
          pid="${mapping##*:}"
          leafcomm=$(ps -o comm= -p "$pid" | tail -n1)
          echo "/dev/$pts:"
          echo "  $pid $leafcomm"
          kids=$(ps --ppid "$pid" -o pid=)
          if [ -z "$kids" ]; then
            echo "    (IDLE — no children)"
          else
            echo "    (BUSY — children below)"
            _list_children "$pid" "    "
          fi
          echo
        done
      done
      ;;
    
       wranglery)
      shift
      local action="$1"; shift
      local wins
      wins=$(xdotool search --class "gnome-terminal" 2>/dev/null) || return 1
      case "$action" in
        list)
          for wid in $wins; do
            local title
            title=$(xdotool getwindowname "$wid" 2>/dev/null)
            echo "$wid | $title"
          done
          ;;
        
        minimize-all)
          for wid in $wins; do
            xdotool windowminimize "$wid"
          done
          ;;
        
        minimize-idle)
          for wid in $wins; do
            local title
            title=$(xdotool getwindowname "$wid" 2>/dev/null)
            if [[ "$title" =~ (bash|zsh|fish)$ ]]; then
              xdotool windowminimize "$wid"
            fi
          done
          ;;
        
        unminimize-all)
          for wid in $wins; do
            xdotool windowmap "$wid"
          done
          ;;
        
        minimize)
          local wid="$1"
          if [[ -z "$wid" ]]; then
            echo "Usage: gnotermon wranglery minimize <window-id>"
            return 1
          fi
          xdotool windowminimize "$wid"
          ;;
        
        unminimize)
          local wid="$1"
          if [[ -z "$wid" ]]; then
            echo "Usage: gnotermon wranglery unminimize <window-id>"
            return 1
          fi
          xdotool windowmap "$wid"
          ;;
        
        geometry)
          local wid="$1"
          if [[ -z "$wid" ]]; then
            echo "Usage: gnotermon wranglery geometry <window-id>"
            return 1
          fi
          xdotool getwindowgeometry "$wid"
          ;;
        
        raise-all)
          for wid in $wins; do
            xdotool windowraise "$wid"
          done
          ;;
        
        focus)
          local wid="$1"
          if [[ -z "$wid" ]]; then
            echo "Usage: gnotermon wranglery focus <window-id>"
            return 1
          fi
          xdotool windowactivate "$wid"
          ;;
        
        rename)
          local wid="$1"; shift
          local newtitle="$*"
          if [[ -z "$wid" || -z "$newtitle" ]]; then
            echo "Usage: gnotermon wranglery rename <window-id> <new-title>"
            return 1
          fi
          xdotool set_window --name "$newtitle" "$wid"
          ;;
        
        move)
          local wid="$1"; local x="$2"; local y="$3"
          if [[ -z "$wid" || -z "$x" || -z "$y" ]]; then
            echo "Usage: gnotermon wranglery move <window-id> <x> <y>"
            return 1
          fi
          xdotool windowmove "$wid" "$x" "$y"
          ;;
        
        resize)
          local wid="$1"; local w="$2"; local h="$3"
          if [[ -z "$wid" || -z "$w" || -z "$h" ]]; then
            echo "Usage: gnotermon wranglery resize <window-id> <width> <height>"
            return 1
          fi
          xdotool windowsize "$wid" "$w" "$h"
          ;;
        
        fullscreen)
          local wid="$1"
          if [[ -z "$wid" ]]; then
            echo "Usage: gnotermon wranglery fullscreen <window-id>"
            return 1
          fi
          xdotool windowactivate "$wid"
          xdotool key --window "$wid" F11
          ;;
        
        close)
          local wid="$1"
          if [[ -z "$wid" ]]; then
            echo "Usage: gnotermon wranglery close <window-id>"
            return 1
          fi
          xdotool windowclose "$wid"
          ;;
        
tile)
  # Get screen size
  read sw sh <<<"$(xdotool getdisplaygeometry)"

  local count=$(echo "$wins" | wc -w)
  if (( count == 0 )); then
    echo "No GNOME Terminal windows found"
    return 1
  fi

  echo "Smart tiling $count windows..."

  layout=()
  case $count in
    1) layout=(1) ;;       # 1 row of 1
    2) layout=(2) ;;       # 1 row of 2
    3) layout=(2 1) ;;     # 2 on top, 1 on bottom
    4) layout=(2 2) ;;     # 2 rows of 2
    5) layout=(3 2) ;;     # 3 on top, 2 on bottom
    6) layout=(3 3) ;;     # 2 rows of 3
    7) layout=(3 4) ;;     # 3 + 4
    8) layout=(4 4) ;;     # 2 rows of 4
    9) layout=(3 3 3) ;;   # 3 rows of 3
    *)
      # Fallback: aspect-ratio grid
      local cols=$(awk -v sw=$sw -v sh=$sh -v n=$count \
        'BEGIN {
          aspect = sw/sh
          cols = int(sqrt(n*aspect))
          if (cols < 1) cols = 1
          print cols
        }')
      local rows=$(( (count + cols - 1) / cols ))
      for ((r=0; r<rows; r++)); do
        if (( r == rows - 1 )); then
          layout+=($(( count - r*cols )))
        else
          layout+=($cols)
        fi
      done
      ;;
  esac

  # Total rows
  local rows=${#layout[@]}
  local row_height=$(( sh / rows ))

  local i=0
  local y=0
  for row_cols in "${layout[@]}"; do
    local row_w=$(( sw / row_cols ))
    local x=0
    for ((c=0; c<row_cols; c++)); do
      local wid=$(echo "$wins" | awk "NR==$((i+1))")
      if [[ -z "$wid" ]]; then break; fi

      # Stretch last column to absorb remainder
      if (( c == row_cols - 1 )); then
        w=$(( sw - x ))
      else
        w=$row_w
      fi
      # Stretch last row to absorb vertical remainder
      if (( y + row_height*rows >= sh && row_cols == layout[-1] )); then
        h=$(( sh - y ))
      else
        h=$row_height
      fi

      xdotool windowmove "$wid" "$x" "$y"
      xdotool windowsize "$wid" "$w" "$h"

      x=$(( x + row_w ))
      i=$(( i+1 ))
    done
    y=$(( y + row_height ))
  done
  ;;

        
        *)
          echo "Usage: gnotermon wranglery {list|minimize-all|minimize-idle|unminimize-all|minimize|unminimize|geometry|raise-all|focus|rename|move|resize|fullscreen|close|tile}"
          ;;
      esac
      ;;

    
        admiralty)
      store_dir="${XDG_RUNTIME_DIR:-/tmp}/gnotermon"
      statefile="$store_dir/xadmiralty.state"
      mkdir -p "$store_dir"

      _update_state() {
        local wid="$1" status="$2" tag="$3" ts="$4" pid="$5" tty="$6"
        tmpf=$(mktemp "$store_dir/admiralty.XXXXXX")
        awk -F'|' -v wid="$wid" -v st="$status" -v tg="$tag" -v ts="$ts" -v pid="$pid" -v tty="$tty" '
          BEGIN { found=0 }
          {
            if ($1==wid) {
              print wid "|" st "|" tg "|" ts "|" pid "|" tty
              found=1
            } else {
              print $0
            }
          }
          END { if (!found) print wid "|" st "|" tg "|" ts "|" pid "|" tty }
        ' "$statefile" 2>/dev/null >"$tmpf"
        mv "$tmpf" "$statefile"
      }

      case "$2" in
          focus-port)
          local port="$3"
          if [[ -z "$port" ]]; then
            echo "Usage: gnotermon admiralty focus-port <port>"
            return 1
          fi

          # Find PIDs using the port
          pids=$(lsof -ti :"$port")
          if [[ -z "$pids" ]]; then
            echo "No process found using port $port"
            return 1
          fi

          for pid in $pids; do
            # climb up the tree until we find a recorded PID
            cur="$pid"
            while [[ -n "$cur" && "$cur" -ne 1 ]]; do
              # check statefile for matching PID
              if grep -q "|$cur|" "$statefile" 2>/dev/null; then
                wid=$(awk -F'|' -v pid="$cur" '$5==pid {print $1}' "$statefile")
                if [[ -n "$wid" ]]; then
                  echo "Focusing window $wid for PID $cur (port $port)"
                  xdotool windowactivate "$wid"
                  xdotool windowraise "$wid"
                  return 0
                fi
              fi
              cur=$(ps -o ppid= -p "$cur" 2>/dev/null | awk '{print $1}')
            done
          done

          echo "No matching GNOME Terminal window found for port $port"
          ;;

        checkin)
          shift 2
          wid=$(xdotool getactivewindow 2>/dev/null) || {
            echo "No active window"
            return 1
          }
          class=$(xprop -id "$wid" WM_CLASS 2>/dev/null | awk -F'"' '{print $2}')
          if [[ "$class" != "gnome-terminal" && "$class" != "gnome-terminal-server" ]]; then
            echo "Active window is not gnome-terminal (class=$class)"
            return 1
          fi

          # snapshot activity check
          if jobs >/dev/null 2>&1 && [ -z "$(jobs)" ]; then
            status="IDLE"
          else
            status="BUSY"
          fi
          tag="$1"
          ts=$(date +%s)
          pid="$$"
          tty=$(tty 2>/dev/null | sed 's:^/dev/::')

          _update_state "$wid" "$status" "$tag" "$ts" "$pid" "$tty"

          # decorate window title
          current_title=$(xdotool getwindowname "$wid" 2>/dev/null)
          new_title="${current_title% [*]} [$status${tag:+|$tag}]"
          printf '\033]0;%s\007' "$new_title"

          echo "Recorded $wid ($class) as $status${tag:+ with tag '$tag'} (pid=$pid tty=$tty)"
          ;;
          
        focus-all-busy)
          if [[ ! -f "$statefile" ]]; then
            echo "No state recorded yet"
            return 0
          fi

          while IFS="|" read -r wid st tg ts pid tty; do
            # recompute live status
            if ps -p "$pid" >/dev/null 2>&1; then
              kids=$(ps --ppid "$pid" -o pid=)
              if [[ -n "$kids" ]]; then
                echo "Focusing BUSY window $wid"
                xdotool windowactivate "$wid"
                xdotool windowraise "$wid"
                # small pause so you can see the focus switch
                sleep 0.2
              fi
            fi
          done <"$statefile"
          ;;
          
                write-tag)
          local wid="$3"
          local newtag="$4"
          if [[ -z "$wid" || -z "$newtag" ]]; then
            echo "Usage: gnotermon admiralty write-tag <window-id> <new-tag>"
            return 1
          fi
          # rewrite entry in statefile with new tag
          awk -F'|' -v wid="$wid" -v tg="$newtag" '
            BEGIN {OFS="|"}
            {
              if ($1==wid) {
                print $1, $2, tg, $4, $5, $6
              } else {
                print $0
              }
            }
          ' "$statefile" >"$statefile.tmp" && mv "$statefile.tmp" "$statefile"
          echo "Updated tag for window $wid → $newtag"
          ;;

        focus-all-tagged)
          local tag="$3"
          if [[ -z "$tag" ]]; then
            echo "Usage: gnotermon admiralty focus-all-tagged <tag>"
            return 1
          fi
          while IFS="|" read -r wid st tg ts pid tty; do
            # normalize tg without ANSI
            rawtag=$(echo "$tg" | sed 's/\x1b\[[0-9;]*m//g')
            if [[ "$rawtag" == "$tag" ]]; then
              echo "Focusing tagged window $wid ($tag)"
              xdotool windowactivate "$wid"
              xdotool windowraise "$wid"
              sleep 0.2
            fi
          done <"$statefile"
          ;;

        close-all-tagged)
          local tag="$3"
          if [[ -z "$tag" ]]; then
            echo "Usage: gnotermon admiralty close-all-tagged <tag>"
            return 1
          fi
          while IFS="|" read -r wid st tg ts pid tty; do
            rawtag=$(echo "$tg" | sed 's/\x1b\[[0-9;]*m//g')
            if [[ "$rawtag" == "$tag" ]]; then
              echo "Closing tagged window $wid ($tag)"
              xdotool windowclose "$wid"
            fi
          done <"$statefile"
          ;;

        minimize-all-tagged)
          local tag="$3"
          if [[ -z "$tag" ]]; then
            echo "Usage: gnotermon admiralty minimize-all-tagged <tag>"
            return 1
          fi
          while IFS="|" read -r wid st tg ts pid tty; do
            rawtag=$(echo "$tg" | sed 's/\x1b\[[0-9;]*m//g')
            if [[ "$rawtag" == "$tag" ]]; then
              echo "Minimizing tagged window $wid ($tag)"
              xdotool windowminimize "$wid"
            fi
          done <"$statefile"
          ;;

        stats)
          if [[ ! -f "$statefile" ]]; then
            echo "No state recorded yet"
            return 0
          fi
          total=0 idle=0 busy=0 dead=0
          declare -A tagcounts
          while IFS="|" read -r wid st tg ts pid tty; do
            total=$((total+1))
            if ps -p "$pid" >/dev/null 2>&1; then
              kids=$(ps --ppid "$pid" -o pid=)
              if [[ -n "$kids" ]]; then
                busy=$((busy+1))
              else
                idle=$((idle+1))
              fi
            else
              dead=$((dead+1))
            fi
            rawtag=$(echo "$tg" | sed 's/\x1b\[[0-9;]*m//g')
            [[ -n "$rawtag" && "$rawtag" != "<none>" ]] && tagcounts["$rawtag"]=$((tagcounts["$rawtag"]+1))
          done <"$statefile"

          echo "Total windows: $total"
          echo "  IDLE: $idle"
          echo "  BUSY: $busy"
          echo "  DEAD: $dead"
          echo "Tags:"
          for t in "${!tagcounts[@]}"; do
            echo "  $t: ${tagcounts[$t]}"
          done
          ;;
          
          
                focus-all-envvar)
          local kv="$3"
          if [[ -z "$kv" ]]; then
            echo "Usage: gnotermon admiralty focus-all-envvar VAR=VALUE"
            return 1
          fi
          local var="${kv%%=*}"
          local val="${kv#*=}"
          while IFS="|" read -r wid st tg ts pid tty; do
            if [[ -n "$pid" && -r "/proc/$pid/environ" ]]; then
              if tr '\0' '\n' <"/proc/$pid/environ" | grep -q "^${var}=${val}\$"; then
                echo "Focusing window $wid (PID=$pid, $var=$val)"
                xdotool windowactivate "$wid"
                xdotool windowraise "$wid"
                sleep 0.2
              fi
            fi
          done <"$statefile"
          ;;

        minimize-all-envvar)
          local kv="$3"
          if [[ -z "$kv" ]]; then
            echo "Usage: gnotermon admiralty minimize-all-envvar VAR=VALUE"
            return 1
          fi
          local var="${kv%%=*}"
          local val="${kv#*=}"
          while IFS="|" read -r wid st tg ts pid tty; do
            if [[ -n "$pid" && -r "/proc/$pid/environ" ]]; then
              if tr '\0' '\n' <"/proc/$pid/environ" | grep -q "^${var}=${val}\$"; then
                echo "Minimizing window $wid (PID=$pid, $var=$val)"
                xdotool windowminimize "$wid"
              fi
            fi
          done <"$statefile"
          ;;

        close-all-envvar)
          local kv="$3"
          if [[ -z "$kv" ]]; then
            echo "Usage: gnotermon admiralty close-all-envvar VAR=VALUE"
            return 1
          fi
          local var="${kv%%=*}"
          local val="${kv#*=}"
          while IFS="|" read -r wid st tg ts pid tty; do
            if [[ -n "$pid" && -r "/proc/$pid/environ" ]]; then
              if tr '\0' '\n' <"/proc/$pid/environ" | grep -q "^${var}=${val}\$"; then
                echo "Closing window $wid (PID=$pid, $var=$val)"
                xdotool windowclose "$wid"
              fi
            fi
          done <"$statefile"
          ;;

        list-envvar)
          local var="$3"
          if [[ -z "$var" ]]; then
            echo "Usage: gnotermon admiralty list-envvar VAR"
            return 1
          fi
          echo "Listing windows with env var: $var"
          echo "Window | PID | $var | Title"
          while IFS="|" read -r wid st tg ts pid tty; do
            if [[ -n "$pid" && -r "/proc/$pid/environ" ]]; then
              value=$(tr '\0' '\n' <"/proc/$pid/environ" | grep "^${var}=" | cut -d= -f2-)
              if [[ -n "$value" ]]; then
                title=$(xdotool getwindowname "$wid" 2>/dev/null)
                echo "$wid | $pid | $value | $title"
              fi
            fi
          done <"$statefile"
          ;;

          
        tmux-all-sessions-force)
          if ! command -v tmux >/dev/null 2>&1; then
            echo "tmux not installed"
            return 1
          fi

          [[ ! -f "$statefile" ]] && touch "$statefile"

          echo "Ensuring every tmux session has exactly one GNOME Terminal viewer..."
          sessions=$(tmux ls -F '#S' 2>/dev/null || true)
          if [[ -z "$sessions" ]]; then
            echo "No tmux sessions found"
            return 0
          fi

          for s in $sessions; do
            echo "Session: $s"

            # list attached clients
            client_ttys=$(tmux list-clients -t "$s" -F '#{client_tty}' 2>/dev/null || true)

            if [[ -n "$client_ttys" ]]; then
              # session already has at least one attached client
              for ctty in $client_ttys; do
                shorttty=$(basename "$ctty")
                wid=$(awk -F'|' -v tty="$shorttty" '$6==tty {print $1}' "$statefile")
                if [[ -n "$wid" ]]; then
                  echo "  Focusing existing GNOME Terminal for session $s (tty=$shorttty)"
                  xdotool windowactivate "$wid"
                  xdotool windowraise "$wid"
                  break
                fi
              done
              # If no matching wid found, don’t spawn — assume it’s running elsewhere (SSH, xterm, etc.)
              [[ -z "$wid" ]] && echo "  Session $s has clients, but none in GNOME Terminal (skipping)"
            else
              # session has no clients → launch new GNOME Terminal and attach
              echo "  No clients attached to session $s — launching new GNOME Terminal..."
              gnome-terminal -- tmux attach -t "$s" &
              sleep 0.5
            fi
          done
          ;;

              focus-all-tmux)
          if ! command -v tmux >/dev/null 2>&1; then
            echo "tmux not installed"
            return 1
          fi
          [[ ! -f "$statefile" ]] && { echo "No state recorded yet"; return 0; }

          sessions=$(tmux ls -F '#S' 2>/dev/null || true)
          if [[ -z "$sessions" ]]; then
            echo "No tmux sessions found"
            return 0
          fi

          for s in $sessions; do
            client_ttys=$(tmux list-clients -t "$s" -F '#{client_tty}' 2>/dev/null || true)
            for ctty in $client_ttys; do
              shorttty=$(basename "$ctty")
              wid=$(awk -F'|' -v tty="$shorttty" '$6==tty {print $1}' "$statefile")
              if [[ -n "$wid" ]]; then
                echo "Focusing tmux session $s (tty=$shorttty, win=$wid)"
                xdotool windowactivate "$wid"
                xdotool windowraise "$wid"
                sleep 0.2
              fi
            done
          done
          ;;

        minimize-all-tmux)
          if ! command -v tmux >/dev/null 2>&1; then
            echo "tmux not installed"
            return 1
          fi
          [[ ! -f "$statefile" ]] && { echo "No state recorded yet"; return 0; }

          sessions=$(tmux ls -F '#S' 2>/dev/null || true)
          if [[ -z "$sessions" ]]; then
            echo "No tmux sessions found"
            return 0
          fi

          for s in $sessions; do
            client_ttys=$(tmux list-clients -t "$s" -F '#{client_tty}' 2>/dev/null || true)
            for ctty in $client_ttys; do
              shorttty=$(basename "$ctty")
              wid=$(awk -F'|' -v tty="$shorttty" '$6==tty {print $1}' "$statefile")
              if [[ -n "$wid" ]]; then
                echo "Minimizing tmux session $s (tty=$shorttty, win=$wid)"
                xdotool windowminimize "$wid"
              fi
            done
          done
          ;;

        close-all-tmux)
          if ! command -v tmux >/dev/null 2>&1; then
            echo "tmux not installed"
            return 1
          fi
          [[ ! -f "$statefile" ]] && { echo "No state recorded yet"; return 0; }

          sessions=$(tmux ls -F '#S' 2>/dev/null || true)
          if [[ -z "$sessions" ]]; then
            echo "No tmux sessions found"
            return 0
          fi

          for s in $sessions; do
            client_ttys=$(tmux list-clients -t "$s" -F '#{client_tty}' 2>/dev/null || true)
            for ctty in $client_ttys; do
              shorttty=$(basename "$ctty")
              wid=$(awk -F'|' -v tty="$shorttty" '$6==tty {print $1}' "$statefile")
              if [[ -n "$wid" ]]; then
                echo "Closing tmux session $s (tty=$shorttty, win=$wid)"
                xdotool windowclose "$wid"
              fi
            done
          done
          ;;


        tmux-all-sessions)
          if ! command -v tmux >/dev/null 2>&1; then
            echo "tmux not installed"
            return 1
          fi

          if [[ ! -f "$statefile" ]]; then
            echo "No state recorded yet"
            return 0
          fi

          echo "Checking tmux sessions against GNOME Terminal windows..."
          sessions=$(tmux ls -F '#S' 2>/dev/null || true)
          if [[ -z "$sessions" ]]; then
            echo "No tmux sessions found"
            return 0
          fi

          for s in $sessions; do
            echo "Session: $s"
            # Collect client ttys for this session
            client_ttys=$(tmux list-clients -t "$s" -F '#{client_tty}' 2>/dev/null || true)
            found=0
            for ctty in $client_ttys; do
              # Normalize: drop leading /dev/
              shorttty=$(basename "$ctty")
              # See if any admiralty window recorded this tty
              if awk -F'|' -v tty="$shorttty" '$6==tty {exit 0;}' "$statefile"; then
                echo "  Attached on GNOME Terminal (tty=$shorttty)"
                found=1
              fi
            done
            if [[ $found -eq 0 ]]; then
              echo "  No GNOME Terminal window recorded for this session"
            fi
          done
          ;;
          
          
        netwatch)
          if [[ ! -f "$statefile" ]]; then
            echo "No state recorded yet"
            return 0
          fi

          echo "Monitoring network activity for all managed PIDs..."
          echo "Press Ctrl+C to stop."

          while true; do
            while IFS="|" read -r wid st tg ts pid tty; do
              if [[ -n "$pid" && -r "/proc/$pid/net/dev" ]]; then
                # Get RX bytes (received traffic)
                rx_before=$(awk '/:/ {sum+=$2} END{print sum}' "/proc/$pid/net/dev" 2>/dev/null)
                sleep 1
                rx_after=$(awk '/:/ {sum+=$2} END{print sum}' "/proc/$pid/net/dev" 2>/dev/null)

                if [[ -n "$rx_before" && -n "$rx_after" ]]; then
                  delta=$(( rx_after - rx_before ))
                  if (( delta > 0 )); then
                    echo "Incoming traffic detected for PID=$pid → focusing window $wid"
                    xdotool windowactivate "$wid"
                    xdotool windowraise "$wid"
                    # Optional: small pause to avoid rapid-fire focus switches
                    sleep 0.5
                  fi
                fi
              fi
            done <"$statefile"
          done
          ;;

    netwatch_smart)
      if [[ ! -f "$statefile" ]]; then
        echo "No state recorded yet"
        return 0
      fi

      if ! command -v ss >/dev/null 2>&1; then
        echo "The 'ss' command is required but not installed"
        return 1
      fi

      echo "Monitoring incoming connections for all managed PIDs..."
      echo "Press Ctrl+C to stop."

      while true; do
        while IFS="|" read -r wid st tg ts pid tty; do
          if [[ -n "$pid" ]] && ps -p "$pid" >/dev/null 2>&1; then
            # Look for ESTABLISHED TCP sockets with a foreign (remote) address
            conns=$(ss -tupi 2>/dev/null | awk -v pid="$pid" '
              $0 ~ ("pid="pid",") && $1=="ESTAB" {print $0}
            ')

            if [[ -n "$conns" ]]; then
              echo "Incoming connection detected for PID=$pid → focusing window $wid"
              xdotool windowactivate "$wid"
              xdotool windowraise "$wid"
              # debounce: avoid thrashing between multiple active PIDs
              sleep 0.5
            fi
          fi
        done <"$statefile"

        # Poll interval (adjustable)
        sleep 1
      done
      ;;

        focus-all-networked)
          if [[ ! -f "$statefile" ]]; then
            echo "No state recorded yet"
            return 0
          fi
          while IFS="|" read -r wid st tg ts pid tty; do
            if ps -p "$pid" >/dev/null 2>&1; then
              if lsof -i -a -p "$pid" >/dev/null 2>&1; then
                echo "Focusing NETWORKED window $wid"
                xdotool windowactivate "$wid"
                xdotool windowraise "$wid"
                sleep 0.2
              fi
            fi
          done <"$statefile"
          ;;
          
                focus-all-tmux)
          if [[ ! -f "$statefile" ]]; then
            echo "No state recorded yet"
            return 0
          fi

        is_tmux_proc() {
          local cur="$1"
          while [[ -n "$cur" && "$cur" -ne 1 ]]; do
            local comm args
            comm=$(ps -o comm= -p "$cur" 2>/dev/null | tail -n1)
            args=$(ps -o args= -p "$cur" 2>/dev/null | tail -n1)

            # Detect tmux server by name or full command
            if [[ "$comm" == "tmux" ]] || [[ "$args" =~ (^|[[:space:]])tmux([[:space:]]|$) ]]; then
              return 0
            fi

            # Detect tmux client sessions via env var
            if grep -az "TMUX=" /proc/$cur/environ 2>/dev/null | grep -q TMUX; then
              return 0
            fi

            # Walk upwards in process tree
            cur=$(ps -o ppid= -p "$cur" 2>/dev/null | awk '{print $1}')
          done
          return 1
        }

          while IFS="|" read -r wid st tg ts pid tty; do
            if ps -p "$pid" >/dev/null 2>&1; then
              if is_tmux_proc "$pid"; then
                echo "Focusing TMUX window $wid"
                xdotool windowactivate "$wid"
                xdotool windowraise "$wid"
                sleep 0.2
              fi
            fi
          done <"$statefile"
          ;;

        minimize-all-tmux)
          if [[ ! -f "$statefile" ]]; then
            echo "No state recorded yet"
            return 0
          fi

          is_tmux_proc() {
            local cur="$1"
            while [[ -n "$cur" && "$cur" -ne 1 ]]; do
              if ps -o comm= -p "$cur" 2>/dev/null | grep -q '^tmux$'; then
                return 0
              elif grep -az "TMUX=" /proc/$cur/environ 2>/dev/null | grep -q TMUX; then
                return 0
              fi
              cur=$(ps -o ppid= -p "$cur" 2>/dev/null | awk '{print $1}')
            done
            return 1
          }

          while IFS="|" read -r wid st tg ts pid tty; do
            if ps -p "$pid" >/dev/null 2>&1; then
              if is_tmux_proc "$pid"; then
                echo "Minimizing TMUX window $wid"
                xdotool windowminimize "$wid"
              fi
            fi
          done <"$statefile"
          ;;


        minimize-all-networked)
          if [[ ! -f "$statefile" ]]; then
            echo "No state recorded yet"
            return 0
          fi
          while IFS="|" read -r wid st tg ts pid tty; do
            if ps -p "$pid" >/dev/null 2>&1; then
              if lsof -i -a -p "$pid" >/dev/null 2>&1; then
                echo "Minimizing NETWORKED window $wid"
                xdotool windowminimize "$wid"
              fi
            fi
          done <"$statefile"
          ;;

        focus-all-dockered)
          if [[ ! -f "$statefile" ]]; then
            echo "No state recorded yet"
            return 0
          fi

          is_docker_proc() {
            local cur="$1"
            while [[ -n "$cur" && "$cur" -ne 1 ]]; do
              comm=$(ps -o comm= -p "$cur" 2>/dev/null | tail -n1)
              args=$(ps -o args= -p "$cur" 2>/dev/null)
              if [[ "$comm" == "docker" && "$args" =~ (exec|run).*-it ]]; then
                return 0
              elif [[ "$comm" == "docker-compose" ]]; then
                return 0
              elif grep -q docker /proc/"$cur"/cgroup 2>/dev/null; then
                return 0
              fi
              cur=$(ps -o ppid= -p "$cur" 2>/dev/null | awk '{print $1}')
            done
            return 1
          }

          while IFS="|" read -r wid st tg ts pid tty; do
            if ps -p "$pid" >/dev/null 2>&1; then
              if is_docker_proc "$pid"; then
                echo "Focusing DOCKERED window $wid"
                xdotool windowactivate "$wid"
                xdotool windowraise "$wid"
                sleep 0.2
              fi
            fi
          done <"$statefile"
          ;;

        minimize-all-dockered)
          if [[ ! -f "$statefile" ]]; then
            echo "No state recorded yet"
            return 0
          fi
          while IFS="|" read -r wid st tg ts pid tty; do
            if ps -p "$pid" >/dev/null 2>&1; then
              if grep -q docker /proc/"$pid"/cgroup 2>/dev/null; then
                echo "Minimizing DOCKERED window $wid"
                xdotool windowminimize "$wid"
              fi
            fi
          done <"$statefile"
          ;;

          
        minimize-all-idle)
          if [[ ! -f "$statefile" ]]; then
            echo "No state recorded yet"
            return 0
          fi

          while IFS="|" read -r wid st tg ts pid tty; do
            # recompute live status
            if ps -p "$pid" >/dev/null 2>&1; then
              kids=$(ps --ppid "$pid" -o pid=)
              if [[ -z "$kids" ]]; then
                echo "Minimizing IDLE window $wid"
                xdotool windowminimize "$wid"
              fi
            fi
          done <"$statefile"
          ;;

        close-all-idle)
          if [[ ! -f "$statefile" ]]; then
            echo "No state recorded yet"
            return 0
          fi

          while IFS="|" read -r wid st tg ts pid tty; do
            # recompute live status
            if ps -p "$pid" >/dev/null 2>&1; then
              kids=$(ps --ppid "$pid" -o pid=)
              if [[ -z "$kids" ]]; then
                echo "Closing IDLE window $wid"
                xdotool windowclose "$wid"
              fi
            fi
          done <"$statefile"
          ;;
          

        list)
          if [[ ! -f "$statefile" ]]; then
            echo "No state recorded yet"
            return 0
          fi

          # ANSI colors
          RED="\033[0;31m"
          GREEN="\033[0;32m"
          YELLOW="\033[0;33m"
          BLUE="\033[0;34m"
          MAGENTA="\033[0;35m"
          CYAN="\033[0;36m"
          BOLD="\033[1m"
          RESET="\033[0m"

          check_tmux_status() {
            local cur="$1"
            while [[ -n "$cur" && "$cur" -ne 1 ]]; do
              if ps -o comm= -p "$cur" 2>/dev/null | grep -q '^tmux$'; then
                echo " ${MAGENTA}(tmux-server)${RESET}"
                return 0
              elif grep -az "TMUX=" /proc/$cur/environ 2>/dev/null | grep -q TMUX; then
                echo " ${CYAN}(tmux-client)${RESET}"
                return 0
              fi
              cur=$(ps -o ppid= -p "$cur" 2>/dev/null | awk '{print $1}')
            done
            return 1
          }

          echo -e "${BOLD}Window | Status(stored→live) | Tag | Age(s) | PID | TTY | Title${RESET}"
          while IFS="|" read -r wid st tg ts pid tty; do
            now=$(date +%s)
            age=$(( now - ts ))
            title=$(xdotool getwindowname "$wid" 2>/dev/null)
            class=$(xprop -id "$wid" WM_CLASS 2>/dev/null | awk -F'"' '{print $2}')
            if [[ "$class" != "gnome-terminal" && "$class" != "gnome-terminal-server" ]]; then
              continue
            fi

            # recompute live status
            if ps -p "$pid" >/dev/null 2>&1; then
              kids=$(ps --ppid "$pid" -o pid=)
              if [[ -n "$kids" ]]; then
                live="${YELLOW}BUSY${RESET}"
              else
                live="${GREEN}IDLE${RESET}"
              fi
            else
              live="${RED}DEAD${RESET}"
            fi

            # detect tmux by walking the process tree
            tmux_status=$(check_tmux_status "$pid")

            # colorize tag
            if [[ -n "$tg" ]]; then
              tg="${BLUE}$tg${RESET}"
            else
              tg="<none>"
            fi

            echo -e "${BOLD}${wid}${RESET} | ${st}→$live | $tg | ${age}s | ${pid} | ${tty} | ${title}${tmux_status}"
          done <"$statefile"
          ;;


        clear)
          rm -f "$statefile"
          echo "Cleared statefile $statefile"
          ;;
        
        *)
echo "Usage: gnotermon admiralty <subcommand> [args...]"
echo
echo "Core:"
echo "  checkin [tag]           Record the active terminal's state"
echo "  list                    Show all tracked windows"
echo "  clear                   Clear the statefile"
echo "  focus-port <port>       Focus window tied to process using <port>"
echo
echo "Tags:"
echo "  write-tag <wid> <tag>   Assign a tag to a window"
echo "  focus-all-tagged <tag>  Focus all windows with given tag"
echo "  minimize-all-tagged <tag> | close-all-tagged <tag>"
echo
echo "Env vars:"
echo "  focus-all-envvar VAR=VAL"
echo "  minimize-all-envvar VAR=VAL"
echo "  close-all-envvar VAR=VAL"
echo "  list-envvar VAR"
echo
echo "Tmux integration:"
echo "  tmux-all-sessions[|-force]   Check/ensure tmux sessions are tied to terminals"
echo "  focus-all-tmux | minimize-all-tmux | close-all-tmux"
echo
echo "Network activity:"
echo "  netwatch | netwatch_smart"
echo "  focus-all-networked | minimize-all-networked"
echo
echo "Docker detection:"
echo "  focus-all-dockered | minimize-all-dockered"
echo
echo "Idle/busy management:"
echo "  focus-all-busy | minimize-all-idle | close-all-idle"
echo
echo
echo "Stats:"
echo "  stats                   Show counts of idle/busy/dead windows and tags"

      esac
      ;;
      
      
posterity)
    subcmd="$1"
    shift
    
    
    
    
    case "$subcmd" in
              
          record_tagged)
          local tag="$3"
          if [[ -z "$tag" ]]; then
            echo "Usage: gnotermon admiralty posterity_blackbox_record_tagged <tag>"
            return 1
          fi

          if [[ ! -f "$statefile" ]]; then
            echo "No state recorded yet"
            return 1
          fi

          mkdir -p "$store_dir/records"
          session_dir="$store_dir/records/session-$(date +%Y%m%d%H%M%S)"
          mkdir -p "$session_dir"

          while IFS="|" read -r wid st tg ts pid tty; do
            rawtag=$(echo "$tg" | sed 's/\x1b\[[0-9;]*m//g')
            if [[ "$rawtag" == "$tag" ]]; then
              castfile="$session_dir/${tag}-${wid}.cast"
              echo "Starting asciinema record in window $wid → $castfile"
              xdotool windowactivate "$wid"
              xdotool windowraise "$wid"
              xdotool type --window "$wid" "asciinema rec -q $castfile" 
              xdotool key --window "$wid" Return
            fi
          done <"$statefile"

          echo "Recording started for all '$tag' windows"
          ;;

        stoprecord_tagged)
          local tag="$3"
          if [[ -z "$tag" ]]; then
            echo "Usage: gnotermon admiralty posterity_blackbox_stoprecord_tagged <tag>"
            return 1
          fi

          if [[ ! -f "$statefile" ]]; then
            echo "No state recorded yet"
            return 1
          fi

          while IFS="|" read -r wid st tg ts pid tty; do
            rawtag=$(echo "$tg" | sed 's/\x1b\[[0-9;]*m//g')
            if [[ "$rawtag" == "$tag" ]]; then
              echo "Stopping asciinema record in window $wid"
              # asciinema stops on Ctrl-D or EOF; send Ctrl-D
              xdotool key --window "$wid" Ctrl+d
            fi
          done <"$statefile"
          ;;

        play_tagged)
          local tag="$3"
          if [[ -z "$tag" ]]; then
            echo "Usage: gnotermon admiralty posterity_blackbox_play_tagged <tag>"
            return 1
          fi

          session_dir=$(ls -dt "$store_dir"/records/session-* 2>/dev/null | head -n1)
          if [[ -z "$session_dir" ]]; then
            echo "No recordings found"
            return 1
          fi

          echo "Replaying all recordings for tag '$tag' from $session_dir"
          for cast in "$session_dir"/${tag}-*.cast; do
            [[ -e "$cast" ]] || continue
            echo "Playing $cast"
            asciinema play "$cast" &
          done
          wait
          ;;

        grepjump_tagged)
          local tag="$3"
          local pattern="$4"
          if [[ -z "$tag" || -z "$pattern" ]]; then
            echo "Usage: gnotermon admiralty posterity_blackbox_grepjump_tagged <tag> <pattern>"
            return 1
          fi

          session_dir=$(ls -dt "$store_dir"/records/session-* 2>/dev/null | head -n1)
          if [[ -z "$session_dir" ]]; then
            echo "No recordings found"
            return 1
          fi

          for cast in "$session_dir"/${tag}-*.cast; do
            [[ -e "$cast" ]] || continue
            echo "Searching $cast for '$pattern'"

            tmpfile=$(mktemp /tmp/cast.XXXXXX)
            t0=$(jq -r --arg pat "$pattern" '
              . as $all
              | map(select(.[2] | test($pat)))
              | if length > 0 then .[0][0] else empty end
            ' "$cast")

            if [[ -n "$t0" ]]; then
              echo " → Match at $t0 seconds"
              jq --argjson t0 "$t0" '
                . as $all
                | [$all[0], ($all[1:]
                  | map(select(.[0] >= $t0)
                  | [ (.[0]-$t0), .[1], .[2] ] )) ]
              ' "$cast" > "$tmpfile"
              asciinema play "$tmpfile"
              rm -f "$tmpfile"
            else
              echo "No match in $cast"
            fi
          done
          ;;


                merge)
          session_dir=$(ls -dt "$store_dir"/records/session-* 2>/dev/null | head -n1)
          if [[ -z "$session_dir" ]]; then
            echo "No session directory found"
            return 1
          fi

          manifest="$session_dir/manifest.json"
          if [[ ! -f "$manifest" ]]; then
            echo "Manifest not found in $session_dir"
            return 1
          fi

          outcast="$session_dir/merged.cast"

          echo "Merging all .cast files from $session_dir into $outcast..."

          # Read session start baseline
          baseline=$(jq -r '.started_at' "$manifest")

          tmpfile=$(mktemp /tmp/merge.XXXXXX)

          # For each tag and cast in manifest, rebase and prefix tag
          jq -r '
            .tags
            | to_entries[]
            | .key as $tag
            | .value[]
            | "\($tag)|\(.cast)"
          ' "$manifest" | while IFS="|" read -r tag cast; do
            file="$session_dir/$cast"
            [[ -f "$file" ]] || continue
            echo "  including $file (tag=$tag)"

            # Rebase timestamps and add tag prefix
            jq -r --arg tag "$tag" --argjson base "$baseline" '
              . as $root
              | if ($root | type) == "object" and $root.version then empty else
                  [ (.[0] - $base), .[1], "[" + $tag + "] " + (.[2]|tostring) ]
                | @json
              end
            ' "$file" >> "$tmpfile"
          done

          # Build merged header (take from first cast)
          first_cast=$(jq -r '.tags | to_entries[0].value[0].cast' "$manifest")
          header=$(jq 'select(type=="object" and .version)' "$session_dir/$first_cast")

          {
            echo "$header"
            sort -n -t, -k1 "$tmpfile"
          } > "$outcast"

          rm -f "$tmpfile"

          echo "Merged session written to $outcast"
          echo "Replay with: asciinema play $outcast"
          ;;


        
    *)
           echo "Usage: gnotermon posterity {record-tagged|stop-tagged|play-tagged|grepjump-tagged|merge}" >&2
            ;;
    esac
    ;;

checkdeps)
  echo "Checking required dependencies for gnotermon..."

  # List of commands required for various modules
  deps=(
    gdbus
    xdotool
    xprop
    awk
    ps
    jq
    lsof
    ss
    asciinema
    tmux
  )

  missing=()
  for cmd in "${deps[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      printf "  [MISSING] %s\n" "$cmd"
      missing+=("$cmd")
    else
      printf "  [OK]      %s (%s)\n" "$cmd" "$(command -v "$cmd")"
    fi
  done

  echo
  if (( ${#missing[@]} > 0 )); then
    echo "Some dependencies are missing:"
    printf "  %s\n" "${missing[@]}"
    echo
    echo "You can install them using your package manager, e.g.:"
    echo "  sudo apt install ${missing[*]}"
    echo "  # or: sudo dnf install ${missing[*]}"
    return 1
  else
    echo "All dependencies appear to be installed and available."
  fi
    echo
  if [[ -n "$WAYLAND_DISPLAY" ]]; then
    echo "Note: Running under Wayland — some xdotool and X11 features will not work."
  elif [[ -z "$DISPLAY" ]]; then
    echo "Warning: No X11 or Wayland display detected — GUI commands will not function."
  fi

  if ! gdbus call --session --dest org.gnome.Terminal \
      --object-path /org/gnome/Terminal \
      --method org.freedesktop.DBus.Peer.Ping >/dev/null 2>&1; then
    echo "Warning: GNOME Terminal D-Bus service not reachable."
  fi

  ;;



  help|""|"-h"|"--help")
  echo "gnotermon (X11 GNOME Terminal Orchestration Tool)"
  echo "Usage: gnotermon <command> [args...]"
  echo
  echo "Commands:"
  echo "  puppetry <subcmd>     Control GNOME Terminal over D-Bus"
  echo "                         Subcommands: list-windows, list-actions <win>, activate <win> <action>,"
  echo "                                      screens, ping, monitor"
  echo
  echo "  arbory               Show GNOME Terminal → PTY → process tree"
  echo
  echo "  wranglery <subcmd>    X11 window control via xdotool"
  echo "                         Subcommands: list, minimize-all, minimize-idle, unminimize-all, minimize <id>,"
  echo "                                      unminimize <id>, geometry <id>, raise-all, focus <id>,"
  echo "                                      rename <id> <title>, move <id> <x> <y>, resize <id> <w> <h>,"
  echo "                                      fullscreen <id>, close <id>, tile"
  echo
  echo "  admiralty <subcmd>     Cooperative state tracking & window wrangling"
  echo "                         Subcommands include:"
  echo "                           checkin [tag], list, clear"
  echo "                           focus-port <port>, focus-all-busy, focus-all-tagged <tag>,"
  echo "                           close-all-tagged <tag>, minimize-all-tagged <tag>"
  echo "                           focus-all-envvar VAR=VAL, minimize-all-envvar VAR=VAL, close-all-envvar VAR=VAL,"
  echo "                           list-envvar VAR"
  echo "                           tmux-all-sessions, tmux-all-sessions-force,"
  echo "                           focus-all-tmux, minimize-all-tmux, close-all-tmux"
  echo "                           focus-all-networked, minimize-all-networked"
  echo "                           focus-all-dockered, minimize-all-dockered"
  echo "                           minimize-all-idle, close-all-idle"
  echo "                           netwatch, netwatch_smart"
  echo "  posterity <subcmd>      record and replay tagged sessions (for posterity)"
  echo "                           record_tagged <tag>,"
  echo "                           stoprecord_tagged <tag>,"
  echo "                           play_tagged <tag>,"
  echo "                           grepjump_tagged <tag> <pattern>,"
  echo "                           merge"
  echo
  echo "  checkdeps              Check to see if various dependencies for this tool are nominally available."
  echo "  help                   Show this message"
    if [[ "$XDG_SESSION_TYPE" == "wayland" || -n "$WAYLAND_DISPLAY" ]]; then
      echo "Note: Many features will be unavailable under Wayland absent a bridge extension due to its substantially less fun compositor security model."
    fi

  
  ;;

  esac
}
# If we are in an X11/Wayland session, auto-checkin (many features will be unavailable over Wayland)
if [[ -n "$DISPLAY" || -n "$WAYLAND_DISPLAY" ]]; then
    gnotermon admiralty checkin "auto" > /dev/null
fi
