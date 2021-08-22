{ username, name, email }:

{ users.users.${username} =
    { isNormalUser = true;
      description = name;
      home = "/home/${username}";

      extraGroups =
        [ "wheel"
          "networkmanager"
        ];
    };
}
