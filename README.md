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

1.  Copy all files to the root of the data share directory on your Batocera device.
2.  You must make the restrictor-start.sh script executable, to do this, SSH into your device
3.  Open a command prompt
4.  Type: `ssh root@batocera.local`
5.  The standard Batocera SSH password is: `linux`
6.  Enter this command and hit enter:
`chmod +x /userdata/system/configs/emulationstation/scripts/game-start/restrictor-start.sh`

# Adding or Deleting Games to the 4 Way Mode.

