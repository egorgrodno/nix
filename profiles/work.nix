{ pkgs, ... }:

{
  home.packages = with pkgs; [
    gpclient
    uv
    # Force XWayland: NVIDIA EGL rejects Slack's Ozone DMABuf imports on
    # Wayland (eglCreateImage → EGL_BAD_MATCH), which corrupts huddle blur.
    (slack.overrideAttrs (old: {
      postFixup = (old.postFixup or "") + ''
        wrapProgram $out/bin/slack \
          --add-flags "--ozone-platform=x11"
      '';
    }))
  ];
}
