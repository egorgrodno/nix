{ username, ... }:

{
  # Leave the hardware virtualization extensions free for VirtualBox to use
  boot.blacklistedKernelModules = [ "kvm" "kvm_amd" "kvm_intel" ];

  virtualisation.virtualbox.host.enable = true;

  users.extraGroups.vboxusers.members = [ username ];
}
