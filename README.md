# Batocera-Ultimarc-ServoStik-Conrol
For use with:
-  [Batocera](https://batocera.org)

-  [Ultimarc ServoStik](https://www.ultimarc.com/arcade-controls/joysticks/servostik/)
-  [Ultimarc ServoStik Control Board](https://www.ultimarc.com/arcade-controls/joysticks/servostik-control-board/)

This repository provides the scripts and files necessary to automatically configure an Ultimarc ServoStik to either 4 or 8 way, depending on the game.  Games are assumed to be 8 way unless they are added to the configuration file.  The configuration files for MAME and FBNEO have already been prepopulated via a query on this webpage:
http://adb.arcadeitalia.net/lista_mame.php
I have not personally verified this list so there may be errors. You can add or remove files from the configuration per the instructions below. 

All credit goes to [u/dobat](https://www.reddit.com/user/dotbat/) on Reddit from [this post](https://www.reddit.com/r/batocera/comments/1czqurz/tutorial_ultimarc_servostik_automatically_change/?show=original).




#  Installation

1.  Download a zip of the latest releass under Releases.  Extract all files to the root of the data share directory on your Batocera device.
2.  You must make the restrictor-start.sh that is included executable, to do this, SSH into your device
3.  Open a command prompt
4.  Type: `ssh root@batocera.local`
5.  The standard Batocera SSH password is: `linux`
6.  Enter this command and hit enter:
`chmod +x /userdata/system/configs/emulationstation/scripts/game-start/restrictor-start.sh`

# Adding or Deleting Games to the 4 Way Mode

As mentioned above, games are assumed to be 8 way, unless they are included in the proper configuration files.  There are two configuraiton files, one for MAME and one for FBNEO. After installing the contents of the zip, according to the instructions above, tehre will be a folder called "restrictor" in the Batocera share folder.  Inside the restrictor folder, there is file called "mame" and "fbneo".  The files do not have file extentions, but are text files.  If you add rom names ot the files, then they will treated as 4 way.  If you remove rom names, they will be treated as 8 way.  

# Details of How this Functions
Courtesy of [u/dobat](https://www.reddit.com/user/dotbat/) on Reddit from [this post](https://www.reddit.com/r/batocera/comments/1czqurz/tutorial_ultimarc_servostik_automatically_change/?show=original).

In Batocera, you may access the filestystem through SSH/Command line or though the shared folder. The local path `/userdata/` is equivalent to the file share path `\\batocera\share\`, so don't get confused if you see me use those interchangeably.

***Quick tip:*** To drop into command line in Batocera, press Ctrl+Alt+F3 on the keyboard. To return, use Ctrl+Alt+F2.

## UMTool Config

UMTool has been built into Batocera for a while. It's a program meant to push configuration files to Ultimarc hardware. First, we're going to create two configuration files, one for 4-way, one for 8-way. I'm saving these in a "restrictor" folder I made that I will use a lot.

File `/userdata/restrictor/servo_4.json`

```
{
  "version" : 2,
  "product" : "servostik",
  "config" : {
    "debounce" : "standard",
    "paclink" : "disabled"
  },
  "switch": 4
}
```

File `/userdata/restrictor/servo_8.json`
```
{
  "version" : 2,
  "product" : "servostik",
  "config" : {
    "debounce" : "standard",
    "paclink" : "disabled"
  },
  "switch": 8
}
```

You can now try to push one of these and see if it works. Note: if you push a config and it's already in that position, you'll still hear the motor move just a tiny bit.

## Run the following:

`umtool -c /userdata/restrictor/servo_8.json`
This tells the umtool to send the specified json file. If it worked, great! If it didn't, plug the servostik up to a windows computer and use Ultimarc's utility just to make sure you've wired them correctly.



## Game Start Script

There are a few ways that Batocera can run a script. The script that runs at game start is actually going to be launched by EmulationStation

Create the following folder: `/userdata/system/configs/emulationstation/scripts/game-start`

Any script inside that folder will launch at game start and receive some information about the game. *As long as you set the execution bit after creating the file. I'll show you how to do that at the end of this section.*

File `/userdata/system/configs/emulationstation/scripts/game-start/restrictor-start.sh`
```
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
```
Now you have to make the script executable. Run the following command.

`chmod +x /userdata/system/configs/emulationstation/scripts/game-start/restrictor-start.sh`






