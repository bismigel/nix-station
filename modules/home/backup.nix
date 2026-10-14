{ ... }:
{
  config.station.home =
    { pkgs, config, lib, ... }:
    {
      # Back up the admin box's precious local data (homelab context, keys,
      # cloudflare backup, SOPS keyring, age keys, .env) to R2, age-encrypted —
      # the same recipient/bucket the hosts use. Creds come from
      # ~/.config/homelab-backup.env (values live in Bitwarden).
      systemd.user.services.homelab-backup-nixstation = {
        Unit.Description = "Back up nix-station admin data to R2";
        Service = {
          Type = "oneshot";
          EnvironmentFile = "${config.home.homeDirectory}/.config/homelab-backup.env";
          Environment = "PATH=${lib.makeBinPath (with pkgs; [ bash coreutils gnutar gzip age rclone ])}";
          ExecStart = pkgs.writeShellScript "backup-nixstation" ''
            set -euo pipefail
            export RCLONE_CONFIG_R2_TYPE=s3 RCLONE_CONFIG_R2_PROVIDER=Cloudflare \
              RCLONE_CONFIG_R2_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID" \
              RCLONE_CONFIG_R2_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY" \
              RCLONE_CONFIG_R2_ENDPOINT="$R2_ENDPOINT"
            w=$(mktemp -d); trap 'rm -rf "$w"' EXIT
            tar czf "$w/admin.tgz" -C "$HOME" \
              projects/homelab-context projects/ciceleywebsite/.env \
              cloudflare-backup .ssh .config/sops .config/bws \
              .homelab-backup.agekey .gitconfig 2>/dev/null || true
            out="$w/admin-$(hostname)-$(date -u +%Y%m%dT%H%M%SZ).tar.gz.age"
            age -r "$AGE_RECIPIENT" "$w/admin.tgz" > "$out"
            rclone copy "$out" "r2:$R2_BUCKET/nixstation/"
            echo "admin data -> r2:$R2_BUCKET/nixstation/"
          '';
        };
      };
      systemd.user.timers.homelab-backup-nixstation = {
        Unit.Description = "Daily nix-station admin backup to R2";
        Timer = {
          OnCalendar = "daily";
          Persistent = true;
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
}
