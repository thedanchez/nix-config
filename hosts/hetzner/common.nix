{ lib, modulesPath, ... }:
{
  # All Hetzner Cloud VMs are QEMU/KVM guests
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  # Virtio drivers used by all Hetzner Cloud VMs
  boot.initrd.availableKernelModules = [
    "ahci" "xhci_pci" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod"
  ];

  # Hetzner Cloud uses SeaBIOS (legacy BIOS), not UEFI
  # Disko handles GRUB config via the EF02 partition

  # DHCP — Hetzner assigns IPs this way
  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
