{ keyboardLayout, ... }:

{
  programs.less = {
    enable = true;
    config = if keyboardLayout == "hallmack" then ''
      e back-line
      E back-line-force
      a forw-line
      A forw-line-force
    '' else "";
  };
}
