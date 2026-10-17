{
  config,
  lib,
  ...
}:
let
  pkgs = config.station.pkgs;
  check = pkgs.writeShellScript "homelab-deadman-check" ''
    set -u
    env_file="$HOME/.config/homelab-deadman.env"
    state="$HOME/.config/homelab-deadman.state"
    url="https://status.bismigel.dev/health"
    [ -f "$env_file" ] && . "$env_file"
    : "''${TELEGRAM_BOT_TOKEN:?TELEGRAM_BOT_TOKEN missing}"
    : "''${TELEGRAM_CHAT_ID:?TELEGRAM_CHAT_ID missing}"
    fails=0; [ -f "$state" ] && fails=$(cat "$state" 2>/dev/null || echo 0)
    send() {
      ${pkgs.curl}/bin/curl -fsS -m 10 "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
        -d "chat_id=$TELEGRAM_CHAT_ID" --data-urlencode "text=$1" >/dev/null || true
    }
    if ${pkgs.curl}/bin/curl -fsS -m 10 -o /dev/null "$url"; then
      if [ "$fails" -ge 3 ]; then send "✅ homelab edge is back ($(date '+%F %T'))"; fi
      echo 0 > "$state"
    else
      fails=$((fails + 1)); echo "$fails" > "$state"
      if [ "$fails" -ge 3 ]; then
        send "🚨 homelab edge unreachable (''${fails}x): $url — check the cluster"
      fi
    fi
  '';
in
{
  # Dead-man's switch that runs OUTSIDE the cluster (this workstation).
  # Credentials live in ~/.config/homelab-deadman.env (not in this repo).
  config.station.home =
    { ... }:
    {
      systemd.user.services.homelab-deadman = {
        Unit.Description = "External dead-man's switch (homelab edge)";
        Service = {
          Type = "oneshot";
          ExecStart = "${check}";
        };
      };
      systemd.user.timers.homelab-deadman = {
        Unit.Description = "Run the homelab dead-man's switch every 15m";
        Timer = {
          OnBootSec = "2min";
          OnUnitActiveSec = "15min";
          Persistent = true;
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
}
