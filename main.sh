#!/bin/bash

# dmenu with in characters
DMENU_WIDTH=75

# Getting File name from argument given
FILE=$1
# Locate the line that keybindings start
KEYSBINDSTART=$(awk '/keys\[\]/ {print NR}' $FILE)
# Locate the line that keybindings end
KEYBINDEND=$(awk 'NR>89 && /};/  {print NR;exit}' $FILE)
# Modkey Number
MODKEYNUM=$(awk '/define MODKEY/ {$4=tolower($3); $3=substr($3,1,length($3)-4);print $3}' $FILE)

declare -A MODMAP

MODMAP["Mod1"]=$(xmodmap | awk '/mod1/ {print $2}')
MODMAP["Mod2"]=$(xmodmap| awk '/mod2/ {print $2}')
MODMAP["Mod3"]=$(xmodmap | awk '/mod3/ {print $2}')
MODMAP["Mod4"]=$(xmodmap | awk '/mod4/ {print $2}')
MODMAP["Mod5"]=$(xmodmap | awk '/mod5/ {print $2}')

# Getting modkey name from xmodmap
MODKEY=${MODMAP[${MODKEYNUM}]}
# Extracting Keybindings and description
KEYBINDINGS=$(awk  -v DMENU_WIDTH=$DMENU_WIDTH -v START=$KEYSBINDSTART -v FINISH=$KEYBINDEND ' 
	# This part extracts keybindings and descriptions from curly braces 
	NR>=START && NR<=FINISH && /^[\t" "]+{/ {

	# Description extraction	
	descStart=index($0,"/*");
	descEnd=index($0,"*/");
	desc=substr($0,descStart,descEnd)
	desc=substr(desc,3,length(desc)-4)
	sub(/^[\t" "]+/,"",desc)
	sub(/[\t" "]+$/,"",desc)

	# Mod extraction

	gsub(/Mask/,"",$2)	
	$2=substr($2,1,length($2)-1);
	gsub(/\|/," + ",$2)

	# Key extraction
	$3=substr($3,1,length($3)-1);
	gsub(/XF86XK_/, "Button_", $3);
	gsub(/XK_/, "", $3);

	# Printing
	if (length($2)>4){
	spaces = (DMENU_WIDTH - length($2 $3 desc) - 3); # Minus because during printing we add " + " characters
	pad = "";
	for(i=0; i<spaces; i++){
		pad=pad " ";
	}
	print $2 " + " $3 pad desc;}
	else{
	spaces=(DMENU_WIDTH-length($3 desc));
	pad = "";
	for(i=0; i<spaces; i++){
		pad = pad " ";
	}
	print $3 pad  desc;
	}	
	
	}	
' $FILE)
# Capturing to TAGKEYS array which keys use TAGKEYS definition
TAGKEYS=($(awk  -v DMENU_WIDTH=$DMENU_WIDTH -v START=$KEYSBINDSTART -v FINISH=$KEYBINDEND ' 
	# This part extracts keybinding and definitions from TAGKEYS definition
	NR>=START && NE<=FINISH && /^[\t" "]+TAGKEYS/ {
	# Trim and isolate the key (remove XK_)
	$2=substr($2,1,length($2)-1);
	gsub(/XK_/,"",$2);
	gsub(/XF86XK_/,"Btn",$2);
	# Pass it to an array
	print  $2 ;
} ' $FILE));

# Find where TAGKEYS is defined
TAGKEYSLINE=$(awk '/# define TAGKEYS/' $FILE)
let TAGNUM=0
# For each TAGKEY extract the mods and description
for i in "${TAGKEYS[@]}"; do
let TAGNUM++
KEYBINDINGS=$KEYBINDINGS"\n"$(awk -v DMENU_WIDTH=$DMENU_WIDTH -v TAGNUM=$TAGNUM -v TAG=$i -v TAGKEYSLINE=$TAGKEYSLINE '

	NR>TAGKEYSLINE && /KEY/ && /TAG/ && /.ui = 1/  {

	# If last character is \ remove it because is parsed as special character

	if (substr($0,length($0),length($0))=="\\"){	
	$0 = substr($0,1,length($0)-1);	
	}

	# Mod extraction

	gsub(/Mask/,"",$2)	
	$2=substr($2,1,length($2)-1);
	gsub(/\|/," + ",$2)
	
	# Description extraction	

	descStart=index($0,"/*");
	descEnd=index($0,"*/");
	desc=substr($0,descStart,descEnd)
	desc=substr(desc,3,length(desc)-4)
	sub(/^[\t" "]+/,"",desc)
	sub(/[\t" "]+$/,"",desc)
		
	# Print 

	spaces=(DMENU_WIDTH-length($2 " + " TAG desc " TAG[" TAG "]" ));
	pad="";
	for(i=0;i<spaces;i++){
		pad=pad " ";
	}
	print $2 " + " TAG pad desc " TAG[" TAGNUM "]" ;
	}
	
' $FILE)
done

# Final substitution of the mod keys to the actual keys
KEYBINDINGS=${KEYBINDINGS//"MODKEY"/$MODKEY}
for KEY in "${!MODMAP[@]}"; do
	KEYBINDINGS=${KEYBINDINGS//$KEY/${MODMAP[$KEY]}}
done
# Dmenu
echo -e "$KEYBINDINGS" | dmenu -c -i -l 20 -p 'Keybindings'

