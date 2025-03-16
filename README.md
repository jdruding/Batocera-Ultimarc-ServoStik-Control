Here’s your updated README with the **"Details of How This Functions"** section appended and improved for clarity, formatting, and readability:

---

# Ultimarc ServoStik Auto Configuration for Batocera  

## Compatible With:  
- **Batocera**  
- **Ultimarc ServoStik**  
- **Ultimarc ServoStik Control Board**  

## Overview  

This repository provides the necessary scripts and files to automatically configure an **Ultimarc ServoStik** to switch between **4-way** and **8-way** modes based on the game being played.  

By default, all games are assumed to use **8-way mode** unless explicitly listed in the configuration file for **4-way mode**. Prepopulated configuration files for **MAME** and **FBNEO** have been generated using data from:  

🔗 [Arcade Database - MAME Game List](http://adb.arcadeitalia.net/lista_mame.php)  

⚠ **Note:** I have not personally verified this list, so there may be errors. You can manually add or remove games from the configuration following the instructions below.  

🚀 **Credit:** Full credit for discovering this method and creating these scripts goes to **u/dobat** on Reddit from [this post](#).  

---

## Installation  

1. **Download & Extract Files**  
   - Download the latest release ZIP from the **Releases** section.  
   - Extract all files to the **root of the data share directory** on your Batocera device.  

2. **Make the script executable**  
   - SSH into your Batocera device:  
     ```sh
     ssh root@batocera.local
     ```  
   - The default Batocera SSH password is: **linux**  
   - Run the following command to make `restrictor-start.sh` executable:  
     ```sh
     chmod +x /userdata/system/configs/emulationstation/scripts/game-start/restrictor-start.sh
     ```  

---

## Adding or Removing Games for 4-Way Mode  

By default, games are set to **8-way mode**, unless specified otherwise in the configuration files.  

### Configuration Files Location  
After installing the files, you will find a folder named **restrictor** inside the Batocera **share folder**. This folder contains two configuration files:  

- **mame** (for MAME games)  
- **fbneo** (for FBNeo games)  

These files **do not** have extensions but are simple text files.  

### Editing the Configuration Files  

- To **set a game to 4-way mode**, add the ROM name to the respective file (`mame` or `fbneo`).  
- To **remove a game from 4-way mode** (making it default to 8-way), delete its entry from the file.  

---

## Details of How This Works  

💡 **Courtesy of u/dobat on Reddit**  

### Accessing the File System in Batocera  

You can access the Batocera file system through **SSH/command line** or the **shared folder**. The local path `/userdata/` is equivalent to the shared folder path `\\batocera\share\`. These paths are interchangeable.  

💡 **Quick Tip:** To open the command line in Batocera, press **Ctrl + Alt + F3** on the keyboard. To return to the main interface, press **Ctrl + Alt + F2**.  

---

### UMTool Configuration  

Batocera includes **UMTool**, a built-in utility for configuring Ultimarc hardware.  

First, we need to create two configuration files:  
- **servo_4.json** (for 4-way mode)  
- **servo_8.json** (for 8-way mode)  

#### Configuration Files  

📄 **File:** `/userdata/restrictor/servo_4.json`  
```json
{
  "version": 2,
  "product": "servostik",
  "config": {
    "debounce": "standard",
    "paclink": "disabled"
  },
  "switch": 4
}
```
📄 **File:** `/userdata/restrictor/servo_8.json`  
```json
{
  "version": 2,
  "product": "servostik",
  "config": {
    "debounce": "standard",
    "paclink": "disabled"
  },
  "switch": 8
}
```

### Testing UMTool  

To manually switch modes, use the following command:  

```sh
umtool -c /userdata/restrictor/servo_8.json
```
If successful, your ServoStik should respond accordingly. If it does not work, try connecting your ServoStik to a Windows computer and using Ultimarc’s utility to verify proper wiring.  

---

### Game Start Script  

Batocera allows scripts to run at game start. **EmulationStation** will execute any script placed inside:  

📂 **Folder:** `/userdata/system/configs/emulationstation/scripts/game-start`  

### Game Start Script File  

📄 **File:** `/userdata/system/configs/emulationstation/scripts/game-start/restrictor-start.sh`  

```sh
#!/bin/bash
# Uncomment the line below to log the parameters received by this script
# echo "$@" >> /userdata/restrictor/logfile.txt

# Variables
path="$1"
folder=$(echo "$path" | cut -d'/' -f4)
status=$(</userdata/restrictor/status)

# Check if game is in the 4-way configuration file
if grep -q -w "$2" /userdata/restrictor/"$folder"; then
    gametype="4"
else
    gametype="8"
fi

# Switch ServoStik mode if needed
if [[ "$gametype" != "$status" ]]; then
    if [[ "$gametype" = "4" ]]; then
        # Switch to 4-way mode
        umtool -c /userdata/restrictor/servo_4.json
        echo "4" > /userdata/restrictor/status
    else
        # Switch to 8-way mode
        umtool -c /userdata/restrictor/servo_8.json
        echo "8" > /userdata/restrictor/status
    fi
fi
```

### Making the Script Executable  

After creating the script, you **must** make it executable:  

```sh
chmod +x /userdata/system/configs/emulationstation/scripts/game-start/restrictor-start.sh
```

---

## Need Help?  

For additional support or questions, feel free to open an **Issue** on GitHub or check out the original Reddit post by **u/dobat**.  

---

### 🔹 Improvements & Enhancements in this Version  
- **Clearer formatting** for better readability.  
- **Proper file path references** to avoid confusion.  
- **Added explanations** for how and why each step is needed.  
- **Code blocks formatted correctly** for better understanding.  

This should make your README much easier to follow and use. Let me know if you need any further refinements! 🚀
