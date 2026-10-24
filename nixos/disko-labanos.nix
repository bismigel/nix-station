# Disk layout for labanos: LUKS2 full-disk encryption + LVM + btrfs.
#
#   /dev/nvme0n1
#   ├─ p1 (1G, ESP)     → /boot        (vfat, unencrypted)
#   └─ p2 (rest, LUKS2) → cryptroot
#        └─ LVM pool
#           ├─ swap (16G)  → [swap]     (hibernation)
#           └─ root (rest) → btrfs
#               ├─ @        → /
#               ├─ @nix     → /nix
#               └─ @home    → /home

{
  disko.devices = {
    disk.main = {
      type = "disk";
      device = "/dev/nvme0n1";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "fmask=0022" "dmask=0022" ];
            };
          };
          luks = {
            size = "100%";
            content = {
              type = "luks";
              name = "cryptroot";
              # Non-interactive install: the passphrase is copied to the
              # installer via `nixos-anywhere --disk-encryption-keys`.
              passwordFile = "/tmp/cryptroot.key";
              settings = {
                allowDiscards = true;
              };
              content = {
                type = "lvm_pv";
                vg = "pool";
              };
            };
          };
        };
      };
    };

    lvm_vg = {
      pool = {
        type = "lvm_vg";
        lvs = {
          swap = {
            size = "16G";
            content = {
              type = "swap";
              resumeDevice = true;
            };
          };
          root = {
            size = "100%FREE";
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              subvolumes = {
                "@" = {
                  mountpoint = "/";
                  mountOptions = [ "compress=zstd" "noatime" ];
                };
                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = [ "compress=zstd" "noatime" ];
                };
                "@home" = {
                  mountpoint = "/home";
                  mountOptions = [ "compress=zstd" "noatime" ];
                };
              };
            };
          };
        };
      };
    };
  };
}
