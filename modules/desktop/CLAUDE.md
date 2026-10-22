# Desktop

`default.nix` configures Hyprland and the session around it: hypridle, greetd, the color scheme, window rules, MIME associations, and the binds that call into the bar. Hyprland's config is Lua. The bar is `modules/quickshell/`, which has a `CLAUDE.md` of its own.

**Suspend.** Under `base.hibernate` every suspend is `suspend-then-hibernate`. Three places pick the verb from it: hypridle here, the lid in `roles/role-laptop.nix`, and the session menu in `modules/quickshell/Session.qml`. A new way to suspend **must** do the same.
