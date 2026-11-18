# One palette per color scheme, under the same names. `background.raised`
# lifts panels, popups and tooltips off `main`, which the windows share:
# a shadow barely shows on the dark one. `background.desktop` is
# Hyprland's background, which the lock screen and greeter must match.
# Foreground tones run from `strong`, the bar's text, to `faint`; `black`
# and `white` are the terminal's.
{
  fontMono = "Inconsolata LGC Nerd Font Mono";
  fontUI = "Overpass Nerd Font";
  dark = {
    background.main = "#16191D";
    background.raised = "#282C34";
    background.desktop = "#16191D";
    foreground = {
      strong = "#FFFFFF";
      main = "#DCDFE4";
      muted = "#ABB2BF";
      faint = "#434956";
    };
    red = "#E06C75";
    green = "#98C379";
    yellow = "#E5C07B";
    blue = "#61AFEF";
    magenta = "#C678DD";
    cyan = "#56B6C2";
    # One Dark's dark yellow and dark red, outside the ANSI eight.
    orange = "#D19A66";
    darkRed = "#BE5046";
    black = "#21252B";
    white = "#ABB2BF";
    # The ANSI bright half, for terminals. Each accent is carried through
    # One Dark Pro's own normal-to-bright step — +0.08 lightness and +0.24
    # saturation in HSL — so bright text gains vividness, not pallor, and
    # stays on the hue it brightens.
    bright = {
      black = "#434956";
      red = "#F87C86";
      green = "#AAE282";
      yellow = "#FAD48E";
      blue = "#79C3FF";
      magenta = "#DC88F5";
      cyan = "#5CD5E4";
      white = "#F2F4F5";
    };
  };
  # One Light. Every ANSI color stays readable on the background, white
  # included, as a program printing white text assumes a dark terminal.
  light = {
    background.main = "#FAFAFA";
    background.raised = "#FFFFFF";
    # One Light's third UI level, as plain white glares.
    background.desktop = "#DBDBDC";
    foreground = {
      strong = "#202227";
      main = "#383A42";
      muted = "#696C77";
      faint = "#A0A1A7";
    };
    red = "#E45649";
    green = "#50A14F";
    yellow = "#C18401";
    blue = "#4078F2";
    magenta = "#A626A4";
    cyan = "#0184BC";
    orange = "#986801";
    darkRed = "#CA1243";
    black = "#383A42";
    white = "#A0A1A7";
    # The bright step turned toward contrast on a light background: -0.08
    # lightness, saturation kept.
    bright = {
      black = "#696C77";
      red = "#DF3525";
      green = "#428642";
      yellow = "#986801";
      blue = "#1A5DEF";
      magenta = "#851E83";
      cyan = "#016893";
      white = "#BCBEC4";
    };
  };
}
