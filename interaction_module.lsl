//-- A.R.I.A. Interface RLV Module (Add-on)
//-- Version 2.0 - CRITICAL FIXES & IMPROVEMENTS
//-- Fixed RLV commands, improved UI restrictions, enhanced user feedback

// --- LINKED MESSAGE CODES ---
integer UPDATE_BATTERY = 101;
integer UPDATE_CONFIG = 102;
integer MODULE_REGISTER = 200;
integer OPEN_MY_MENU = 201;
integer POWER_STATE_CHANGE = 300;

// --- STATE VARIABLES ---
float gBatteryLevel = 100.0;
integer gMenuChannel;
integer gListenHandle;
key gAdministrator;
key gWearer;
list gAdministrators;
list gTrustedUsers;
integer gPowerState = TRUE;

// --- MODULE STATE ---
integer gInvHidden = FALSE;
integer gMapHidden = FALSE;
integer gCameraLocked = FALSE;
integer gIMHidden = FALSE;
integer gEditHidden = FALSE;
integer gBuildHidden = FALSE;
integer gRadarHidden = FALSE;

// --- HELPER FUNCTIONS ---
applyRestrictions() {
    string cmd = "@";
    
    // Apply current manual settings
    if (gInvHidden) {
        cmd += "showinv=n,";
    } else {
        cmd += "showinv=y,";
    }
    
    if (gMapHidden) {
        cmd += "showworldmap=n,showminimap=n,";
    } else {
        cmd += "showworldmap=y,showminimap=y,";
    }
    
    if (gCameraLocked) {
        cmd += "camunlock=n,camdistmax=3.0,camzoommax=3.0,";
    } else {
        cmd += "camunlock=y,camdistmax=64.0,camzoommax=64.0,";
    }
    
    if (gIMHidden) {
        cmd += "showim=n,";
    } else {
        cmd += "showim=y,";
    }
    
    if (gEditHidden) {
        cmd += "edit=n,";
    } else {
        cmd += "edit=y,";
    }
    
    if (gBuildHidden) {
        cmd += "rez=n,";
    } else {
        cmd += "rez=y,";
    }
    
    if (gRadarHidden) {
        cmd += "shownames=n,";
    } else {
        cmd += "shownames=y,";
    }
    
    // Low battery automatic restrictions override manual settings
    if (gBatteryLevel <= 15.0) {
        cmd += "showinv=n,edit=n,";
    }
    if (gBatteryLevel <= 10.0) {
        cmd += "showworldmap=n,showminimap=n,rez=n,";
    }
    if (gBatteryLevel <= 5.0) {
        cmd += "camunlock=n,camdistmax=1.0,showim=n,";
    }
    
    // Apply all restrictions at once
    llOwnerSay(cmd);
}

openControlMenu(key admin_id) {
    string dialog = "\n[ INTERFACE RLV PROTOCOLS ]\n";
    dialog += "Current Status:\n";
    
    string invStatus = "OFF";
    if (gInvHidden) invStatus = "ON";
    
    string mapStatus = "OFF";
    if (gMapHidden) mapStatus = "ON";
    
    string camStatus = "OFF";
    if (gCameraLocked) camStatus = "ON";
    
    string imStatus = "OFF";
    if (gIMHidden) imStatus = "ON";
    
    string editStatus = "OFF";
    if (gEditHidden) editStatus = "ON";
    
    string buildStatus = "OFF";
    if (gBuildHidden) buildStatus = "ON";
    
    dialog += "• Hide Inventory: " + invStatus + "\n";
    dialog += "• Hide Maps: " + mapStatus + "\n";
    dialog += "• Lock Camera: " + camStatus + "\n";
    dialog += "• Hide IM Panel: " + imStatus + "\n";
    dialog += "• Block Edit: " + editStatus + "\n";
    dialog += "• Block Build: " + buildStatus + "\n";
    
    if (gBatteryLevel <= 15.0) {
        dialog += "\n⚠ Low power interface restrictions active!";
    }
    
    list buttons = [
        "[HIDE INV: " + invStatus + "]",
        "[HIDE MAPS: " + mapStatus + "]", 
        "[CAM LOCK: " + camStatus + "]",
        "[HIDE IM: " + imStatus + "]",
        "[BLOCK EDIT: " + editStatus + "]",
        "[BLOCK BUILD: " + buildStatus + "]",
        "UI BLACKOUT",
        "RELEASE ALL",
        "-Main-"
    ];
    
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", admin_id, "");
    llDialog(admin_id, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

// --- MAIN SCRIPT LOGIC ---
default {
    state_entry() {
        gWearer = llGetOwner();
        gMenuChannel = (integer)("0x" + llGetSubString(llGetKey(), -8, -2));
        
        // Initialize with safe defaults
        gInvHidden = FALSE;
        gMapHidden = FALSE;
        gCameraLocked = FALSE;
        gIMHidden = FALSE;
        gEditHidden = FALSE;
        gBuildHidden = FALSE;
        gRadarHidden = FALSE;
        
        // Register with main module
        llMessageLinked(LINK_ROOT, MODULE_REGISTER, "Interface RLV", NULL_KEY);
        
        // Apply initial (unrestricted) state
        applyRestrictions();
        
        llOwnerSay("Interface RLV module initialized.");
    }

    link_message(integer sender, integer num, string msg, key id) {
        if (num == UPDATE_BATTERY) {
            float oldBattery = gBatteryLevel;
            gBatteryLevel = (float)msg;
            
            // Only reapply restrictions if battery level crossed a threshold
            if ((oldBattery > 15.0 && gBatteryLevel <= 15.0) ||
                (oldBattery > 10.0 && gBatteryLevel <= 10.0) ||
                (oldBattery > 5.0 && gBatteryLevel <= 5.0) ||
                (oldBattery <= 15.0 && gBatteryLevel > 15.0) ||
                (oldBattery <= 10.0 && gBatteryLevel > 10.0) ||
                (oldBattery <= 5.0 && gBatteryLevel > 5.0)) {
                applyRestrictions();
            }
        }
        else if (num == UPDATE_CONFIG) {
            list parts = llParseString2List(msg, ["|"], []);
            if (llGetListLength(parts) >= 2) {
                gAdministrators = llCSV2List(llList2String(parts, 0));
                gTrustedUsers = llCSV2List(llList2String(parts, 1));
            }
        }
        else if (num == POWER_STATE_CHANGE) {
            if (msg == "ON") {
                gPowerState = TRUE;
                applyRestrictions();
            } else {
                gPowerState = FALSE;
                // When powered off, remove all restrictions
                llOwnerSay("@showinv=y,showworldmap=y,showminimap=y,camunlock=y,camdistmax=64.0,showim=y,edit=y,rez=y,shownames=y");
            }
        }
        else if (num == OPEN_MY_MENU) {
            key user = (key)msg;
            if (llListFindList(gAdministrators, [user]) != -1 || 
                llListFindList(gTrustedUsers, [user]) != -1) {
                gAdministrator = user;
                openControlMenu(user);
            } else {
                llInstantMessage(user, "Access denied. Trusted user or Administrator permissions required.");
            }
        }
    }

    listen(integer chan, string name, key id, string msg) {
        if (chan != gMenuChannel) return;
        
        // Verify user still has permissions
        if (llListFindList(gAdministrators, [id]) == -1 && 
            llListFindList(gTrustedUsers, [id]) == -1) {
            llInstantMessage(id, "Access denied. Permissions may have changed.");
            return;
        }
        
        llListenRemove(gListenHandle);

        if (msg == "-Main-") {
            llInstantMessage(id, "Returning to main menu.");
            return;
        }

        if (llSubStringIndex(msg, "[HIDE INV:") != -1) {
            gInvHidden = !gInvHidden;
            if (gInvHidden) {
                llInstantMessage(gWearer, "// Inventory access inhibited. //");
            } else {
                llInstantMessage(gWearer, "// Inventory access restored. //");
            }
        }
        else if (llSubStringIndex(msg, "[HIDE MAPS:") != -1) {
            gMapHidden = !gMapHidden;
            if (gMapHidden) {
                llInstantMessage(gWearer, "// Navigation systems offline. //");
            } else {
                llInstantMessage(gWearer, "// Navigation systems online. //");
            }
        }
        else if (llSubStringIndex(msg, "[CAM LOCK:") != -1) {
            gCameraLocked = !gCameraLocked;
            if (gCameraLocked) {
                llInstantMessage(gWearer, "// Camera perspective locked. //");
            } else {
                llInstantMessage(gWearer, "// Camera perspective unlocked. //");
            }
        }
        else if (llSubStringIndex(msg, "[HIDE IM:") != -1) {
            gIMHidden = !gIMHidden;
            if (gIMHidden) {
                llInstantMessage(gWearer, "// IM panel access restricted. //");
            } else {
                llInstantMessage(gWearer, "// IM panel access restored. //");
            }
        }
        else if (llSubStringIndex(msg, "[BLOCK EDIT:") != -1) {
            gEditHidden = !gEditHidden;
            if (gEditHidden) {
                llInstantMessage(gWearer, "// Object editing capabilities disabled. //");
            } else {
                llInstantMessage(gWearer, "// Object editing capabilities enabled. //");
            }
        }
        else if (llSubStringIndex(msg, "[BLOCK BUILD:") != -1) {
            gBuildHidden = !gBuildHidden;
            if (gBuildHidden) {
                llInstantMessage(gWearer, "// Object creation capabilities disabled. //");
            } else {
                llInstantMessage(gWearer, "// Object creation capabilities enabled. //");
            }
        }
        else if (msg == "UI BLACKOUT") {
            gInvHidden = TRUE;
            gMapHidden = TRUE;
            gCameraLocked = TRUE;
            gIMHidden = TRUE;
            gEditHidden = TRUE;
            gBuildHidden = TRUE;
            gRadarHidden = TRUE;
            llInstantMessage(gWearer, "// Full user interface blackout protocol engaged. //");
        }
        else if (msg == "RELEASE ALL") {
            gInvHidden = FALSE;
            gMapHidden = FALSE;
            gCameraLocked = FALSE;
            gIMHidden = FALSE;
            gEditHidden = FALSE;
            gBuildHidden = FALSE;
            gRadarHidden = FALSE;
            llInstantMessage(gWearer, "// All user interface protocols released. //");
        }
        
        // Apply the new restrictions
        applyRestrictions();
        llInstantMessage(id, "Interface protocols updated.");
        
        // Re-open menu to show new status
        openControlMenu(id);
    }
    
    timer() {
        llListenRemove(gListenHandle);
    }
    
    changed(integer c) {
        if (c & CHANGED_OWNER) {
            llResetScript();
        }
    }
}
