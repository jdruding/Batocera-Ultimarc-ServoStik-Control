#!/bin/bash
#echo "$@" >>  /userdata/restrictor/logfile.txt
#Uncomment the line above to log the parameters received by this script.
#Working directory is /userdata

## $1 is path, $2 is romfile name, no extension, $3 is pretty name.
# Path looks like this /userdata/roms/fbneo/pacman.zip

path="$1"
folder=$(echo "$path" | cut -d'/' -f4)

status=$(</userdata/restrictor/status)

#Look up 4 way games
if grep -q -w "$2" /userdata/restrictor/"$folder"; then
    gametype="4"

else
    gametype="8"

fi

if [[ "$gametype" != "$status" ]]; then
    #Things aren't right so they need to be flipped.
    if [[ "$gametype" = "4" ]]; then
    #switch to 4
    umtool -c /userdata/restrictor/servo_4.json
    echo "4" > /userdata/restrictor/status
    else
    #switch to 8
    umtool -c /userdata/restrictor/servo_8.json
    echo "8" > /userdata/restrictor/status
    fi
fi