{ fontFamily, fontSize, ... }:

''
diff --git a/config.def.h b/config.def.h
index b983345..ecf1b76 100644
--- a/config.def.h
+++ b/config.def.h
@@ -5,7 +5,7 @@
  *
  * font: see http://freedesktop.org/software/fontconfig/fontconfig-user.html
  */
-static char *font = "Liberation Mono:pixelsize=12:antialias=true:autohint=true";
+static char *font = "${fontFamily}:pixelsize=${toString(fontSize)}:antialias=true:autohint=true";
 static int borderpx = 2;
 
 /*
@@ -27,7 +27,7 @@ char *vtiden = "\033[?6c";
 
 /* Kerning / character bounding-box multipliers */
 static float cwscale = 1.0;
-static float chscale = 1.0;
+static float chscale = 1.02;
 
 /*
  * word delimiter string
@@ -96,32 +96,32 @@
 /* Terminal colors (16 first used in escape sequence) */
 static const char *colorname[] = {
 	/* 8 normal colors */
-	"black",
-	"red3",
-	"green3",
-	"yellow3",
-	"blue2",
-	"magenta3",
-	"cyan3",
-	"gray90",
+	"#282c34", /* black   */
+	"#e06c75", /* red     */
+	"#98c379", /* green   */
+	"#e5c07b", /* yellow  */
+	"#61afef", /* blue    */
+	"#c678dd", /* magenta */
+	"#56b6c2", /* cyan    */
+	"#dcdfe4", /* white   */
 
 	/* 8 bright colors */
-	"gray50",
-	"red",
-	"green",
-	"yellow",
-	"#5c5cff",
-	"magenta",
-	"cyan",
-	"white",
+	"#434956", /* black   */
+	"#e06c75", /* red     */
+	"#98c379", /* green   */
+	"#e5c07b", /* yellow  */
+	"#61afef", /* blue    */
+	"#c678dd", /* magenta */
+	"#56b6c2", /* cyan    */
+	"#ffffff", /* white   */
 
 	[255] = 0,
 
 	/* more colors can be added after 255 to use with DefaultXX */
-	"#cccccc",
-	"#555555",
-	"black",
-	"gray90",
+	"#dcdfe4", /* cursor         */
+	"#282c34", /* cursor reverse */
+	"#282c34", /* background     */
+	"#dcdfe4", /* foreground     */
 };
 
 
@@ -174,8 +174,8 @@ static uint forcemousemod = ShiftMask;
  */
 static MouseShortcut mshortcuts[] = {
 	/* mask                 button   function        argument       release */
-	{ ShiftMask,            Button4, kscrollup,      {.i = 1} },
-	{ ShiftMask,            Button5, kscrolldown,    {.i = 1} },
+	{ ShiftMask,            Button4, kscrollup,      {.i = 3} },
+	{ ShiftMask,            Button5, kscrolldown,    {.i = 3} },
 	{ XK_ANY_MOD,           Button2, selpaste,       {.i = 0},      1 },
 	{ ShiftMask,            Button4, ttysend,        {.s = "\033[5;2~"} },
 	{ XK_ANY_MOD,           Button4, ttysend,        {.s = "\031"} },
@@ -201,8 +201,8 @@ static Shortcut shortcuts[] = {
 	{ TERMMOD,              XK_Y,           selpaste,       {.i =  0} },
 	{ ShiftMask,            XK_Insert,      selpaste,       {.i =  0} },
 	{ TERMMOD,              XK_Num_Lock,    numlock,        {.i =  0} },
-	{ ShiftMask,            XK_Page_Up,     kscrollup,      {.i = -1} },
-	{ ShiftMask,            XK_Page_Down,   kscrolldown,    {.i = -1} },
+	{ ShiftMask,            XK_Page_Up,     kscrollup,      {.i =  5} },
+	{ ShiftMask,            XK_Page_Down,   kscrolldown,    {.i =  5} },
 };
 
 /*
''
