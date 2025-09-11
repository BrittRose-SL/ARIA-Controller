//-- A.R.I.A. Interface RLV Module (Add-on)
//-- Version 2.1 - FIXED PERMISSIONS + UI RESTRICTIONS + ENHANCED FEEDBACK
//-- CHANGELOG v2.1: Integrated proper permissions system with master kernel synchronization
//-- CHANGELOG v2.0: Fixed RLV commands, improved UI restrictions, enhanced user feedback

// --- LINKED MESSAGE CODES ---
integer UPDATE_BATTERY = 101;
integer UPDATE_CONFIG = 102;
integer MODULE_REGISTER = 200;
integer OPEN_MY_MENU = 201;
integer POWER_STATE_CHANGE = 300;

// --- PERMISSION VARIABLES ---
list gAdministrators;
list gTrustedUsers;
key wearer;
integer gWearerAdminMode = TRUE;
integer gConfigReceived = FALSE;

// --- PERMISSION LEVELS ---
integer ACCESS_ADMIN = 4;
integer ACCESS_TRUSTED = 3;
integer ACCESS_WEARER = 2;
integer ACCESS_PUBLIC = 1;

// --- STATE VARIABLES ---
float gBatteryLevel = 100.0;
integer gMenuChannel;
integer gListenHandle;
integer gPowerState = TRUE;

// --- MODULE STATE ---
integer gInvHidden = FALSE;
integer gMapHidden = FALSE;
integer gCameraLocked = FALSE;
integer gIMHidden = FALSE;
integer gEditHidden = FALSE;
integer gBuildHidden = FALSE;
integer gRadarHidden = FALSE;
integer gTPBlocked = FALSE;
integer gSitBlocked = FALSE;

// --- INTERFACE CONTROL MODES ---
integer gInterfaceLocked = FALSE;
string gInterfaceMode = "Standard"; // Standard, Restricted, Locked, Blackout

// --- PERMISSION FUNCTIONS ---
integer getAccessLevel(key id) {
    if (llListFindList(gAdministrators, [id]) != -1) return ACCESS_ADMIN;
    if (llListFindList(gTrustedUsers, [id]) != -1) return ACCESS_TRUSTED;
    
    if (id == wearer) {
        if (gWearerAdminMode) {
            return ACCESS_ADMIN;
        } else {
            return ACCESS_WEARER;
        }
    }
    
    return ACCESS_PUBLIC;
}

integer checkModuleAccess(key user, integer requiredLevel, string moduleName) {
    integer access = getAccessLevel(user);
    
    if (access < requiredLevel) {
        string levelName = "Public";
        if (requiredLevel == ACCESS_WEARER) levelName = "Wearer";
        else if (requiredLevel == ACCESS_TRUSTED) levelName = "Trusted User";
        else if (requiredLevel == ACCESS_ADMIN) levelName = "Administrator";
        
        llInstantMessage(user, "Access denied. " + levelName + " permissions required for " + moduleName + ".");
        return FALSE;
    }
    
    if (!gConfigReceived) {
        llInstantMessage(user, "Module permissions not synchronized. Please try again in a moment.");
        return FALSE;
    }
    
    return TRUE;
}

// --- RLV RESTRICTION FUNCTIONS ---
applyRestrictions() {
    if (!gPowerState) {
        // When powered off, clear all restrictions
        llOwnerSay("@clear");
        return;
    }
    
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
    
    if (gTPBlocked) {
        cmd += "tplm=n,tplocal=n,tpto=n,";
    } else {
        cmd += "tplm=y,tplocal=y,tpto=y,";
    }
    
    if (gSitBlocked) {
        cmd += "sit=n,";
    } else {
        cmd += "sit=y,";
    }
    
    // Low battery automatic restrictions override manual settings
    if (gBatteryLevel <= 15.0) {
        cmd += "showinv=n,edit=n,";
    }
    if (gBatteryLevel <= 10.0) {
        cmd += "showworldmap=n,showminimap=n,rez=n,";
    }
    if (gBatteryLevel <= 5.0) {
        cmd += "camunlock=n,camdistmax=1.0,showim=n,tplm=n,";
    }
    
    // Apply all restrictions at once
    llOwnerSay(cmd);
}

setInterfaceMode(string mode, key user) {
    gInterfaceMode = mode;
    
    if (mode == "Standard") {
        // Clear all restrictions
        gInvHidden = FALSE;
        gMapHidden = FALSE;
        gCameraLocked = FALSE;
        gIMHidden = FALSE;
        gEditHidden = FALSE;
        gBuildHidden = FALSE;
        gRadarHidden = FALSE;
        gTPBlocked = FALSE;
        gSitBlocked = FALSE;
        gInterfaceLocked = FALSE;
        llInstantMessage(wearer, "// Interface mode: STANDARD - Full functionality restored //");
    }
    else if (mode == "Restricted") {
        // Light restrictions
        gInvHidden = TRUE;
        gEditHidden = TRUE;
        gBuildHidden = TRUE;
        llInstantMessage(wearer, "// Interface mode: RESTRICTED - Basic limitations applied //");
    }
    else if (mode == "Locked") {
        // Heavy restrictions
        gInvHidden = TRUE;
        gMapHidden = TRUE;
        gEditHidden = TRUE;
        gBuildHidden = TRUE;
        gTPBlocked = TRUE;
        gInterfaceLocked = TRUE;
        llInstantMessage(wearer, "// Interface mode: LOCKED - Comprehensive restrictions active //");
    }
    else if (mode == "Blackout") {
        // Maximum restrictions
        gInvHidden = TRUE;
        gMapHidden = TRUE;
        gCameraLocked = TRUE;
        gIMHidden = TRUE;
        gEditHidden = TRUE;
        gBuildHidden = TRUE;
        gRadarHidden = TRUE;
        gTPBlocked = TRUE;
        gSitBlocked = TRUE;
        gInterfaceLocked = TRUE;
        llInstantMessage(wearer, "// Interface mode: BLACKOUT - Full interface lockdown engaged //");
    }
    
    applyRestrictions();
    llInstantMessage(user, "Interface mode changed to: " + mode);
}

// --- MENU FUNCTIONS ---
openControlMenu(key user) {
    integer access = getAccessLevel(user);
    
    string dialog = "\n[ INTERFACE CONTROL MODULE ]\n";
    dialog += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
    dialog += "Access Level: ";
    if (access >= ACCESS_ADMIN) {
        dialog += "ADMINISTRATOR\n";
    } else if (access >= ACCESS_TRUSTED) {
        dialog += "TRUSTED USER\n";
    } else {
        dialog += "WEARER\n";
    }
    
    dialog += "Config Status: ";
    if (gConfigReceived) {
        dialog += "SYNCHRONIZED\n";
    } else {
        dialog += "WAITING\n";
    }
    
    dialog += "Interface Mode: " + gInterfaceMode + "\n";
    dialog += "Battery Level: " + (string)((integer)gBatteryLevel) + "%\n";
    dialog += "Power State: ";
    if (gPowerState) {
        dialog += "ONLINE";
    } else {
        dialog += "OFFLINE";
    }
    
    dialog += "\n\nInterface Status:\n";
    
    string invStatus = "VISIBLE";
    if (gInvHidden) invStatus = "HIDDEN";
    
    string mapStatus = "VISIBLE";
    if (gMapHidden) mapStatus = "HIDDEN";
    
    string camStatus = "FREE";
    if (gCameraLocked) camStatus = "LOCKED";
    
    string imStatus = "VISIBLE";
    if (gIMHidden) imStatus = "HIDDEN";
    
    dialog += "• Inventory: " + invStatus + "\n";
    dialog += "• Maps: " + mapStatus + "\n";
    dialog += "• Camera: " + camStatus + "\n";
    dialog += "• IM Panel: " + imStatus;
    
    list buttons = [];
    
    // Basic controls available to trusted users and above
    if (access >= ACCESS_TRUSTED) {
        buttons += ["[HIDE INV: " + invStatus + "]"];
        buttons += ["[HIDE MAPS: " + mapStatus + "]"];
        buttons += ["[CAM LOCK: " + camStatus + "]"];
        buttons += ["[HIDE IM: " + imStatus + "]"];
        
        string editStatus = "ALLOWED";
        if (gEditHidden) editStatus = "BLOCKED";
        buttons += ["[BLOCK EDIT: " + editStatus + "]"];
        
        string buildStatus = "ALLOWED";
        if (gBuildHidden) buildStatus = "BLOCKED";
        buttons += ["[BLOCK BUILD: " + buildStatus + "]"];
    }
    
    // Mode controls for administrators
    if (access >= ACCESS_ADMIN) {
        buttons += ["Mode: Standard", "Mode: Restricted", "Mode: Locked"];
        if (gInterfaceMode != "Blackout") {
            buttons += ["BLACKOUT ALL"];
        } else {
            buttons += ["RESTORE ALL"];
        }
    }
    
    buttons += ["Refresh", "Close", "-Main-"];
    
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llDialog(user, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

openAdvancedMenu(key user) {
    integer access = getAccessLevel(user);
    
    if (access < ACCESS_ADMIN) {
        llInstantMessage(user, "Access denied. Administrator permissions required for advanced interface controls.");
        openControlMenu(user);
        return;
    }
    
    string dialog = "\n[ ADVANCED INTERFACE CONTROLS ]\n";
    dialog += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
    dialog += "Advanced restriction controls for administrators.\n\n";
    
    string tpStatus = "ALLOWED";
    if (gTPBlocked) tpStatus = "BLOCKED";
    
    string sitStatus = "ALLOWED";
    if (gSitBlocked) sitStatus = "BLOCKED";
    
    string radarStatus = "VISIBLE";
    if (gRadarHidden) radarStatus = "HIDDEN";
    
    dialog += "• Teleport: " + tpStatus + "\n";
    dialog += "• Sitting: " + sitStatus + "\n";
    dialog += "• Radar/Names: " + radarStatus + "\n";
    dialog += "• Interface Lock: ";
    if (gInterfaceLocked) {
        dialog += "ENGAGED";
    } else {
        dialog += "DISENGAGED";
    }
    
    list buttons = [
        "[BLOCK TP: " + tpStatus + "]",
        "[BLOCK SIT: " + sitStatus + "]", 
        "[HIDE RADAR: " + radarStatus + "]",
        "Emergency Release",
        "Full Lockdown",
        "Reset All",
        "<-- Back",
        "-Main-"
    ];
    
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llDialog(user, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

// --- MAIN SCRIPT LOGIC ---
default {
    state_entry() {
        wearer = llGetOwner();
        gMenuChannel = (integer)("0x" + llGetSubString(llGetKey(), -8, -2));
        gConfigReceived = FALSE;
        
        // Initialize with owner as admin (backup measure)
        gAdministrators = [wearer];
        gTrustedUsers = [];
        
        // Initialize interface state
        gInterfaceMode = "Standard";
        gInterfaceLocked = FALSE;
        
        // Register with main module
        llMessageLinked(LINK_ROOT, MODULE_REGISTER, "Interface", NULL_KEY);
        
        // Apply initial (unrestricted) state
        applyRestrictions();
        
        llOwnerSay("Interface Control module v2.1 initialized successfully.");
        llOwnerSay("CHANGELOG v2.1: Integrated proper permissions system");
    }

    link_message(integer sender, integer num, string msg, key id) {
        if (num == UPDATE_CONFIG) {
            // Receive configuration from master kernel
            list parts = llParseString2List(msg, ["|"], []);
            if (llGetListLength(parts) >= 2) {
                string adminCsv = llList2String(parts, 0);
                string trustedCsv = llList2String(parts, 1);
                
                // Update local lists from master kernel
                if (adminCsv != "") {
                    gAdministrators = llCSV2List(adminCsv);
                } else {
                    gAdministrators = [wearer]; // Ensure owner is always admin
                }
                
                if (trustedCsv != "") {
                    gTrustedUsers = llCSV2List(trustedCsv);
                } else {
                    gTrustedUsers = [];
                }
                
                gConfigReceived = TRUE;
                llOwnerSay("Interface permissions updated from master kernel.");
                llOwnerSay("Administrators: " + (string)llGetListLength(gAdministrators));
                llOwnerSay("Trusted Users: " + (string)llGetListLength(gTrustedUsers));
            }
        }
        else if (num == OPEN_MY_MENU) {
            key user = (key)msg;
            if (checkModuleAccess(user, ACCESS_TRUSTED, "Interface Control")) {
                openControlMenu(user);
            }
        }
        else if (num == UPDATE_BATTERY) {
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
        else if (num == POWER_STATE_CHANGE) {
            if (msg == "ON") {
                gPowerState = TRUE;
                applyRestrictions();
                llInstantMessage(wearer, "// Interface control systems online //");
            } else {
                gPowerState = FALSE;
                // When powered off, clear all restrictions
                llOwnerSay("@clear");
                llInstantMessage(wearer, "// Interface control systems offline - all restrictions cleared //");
            }
        }
    }

    listen(integer chan, string name, key id, string message) {
        if (chan != gMenuChannel) return;
        
        llListenRemove(gListenHandle);
        
        integer access = getAccessLevel(id);
        
        if (message == "-Main-" || message == "Close") {
            if (message == "Close") {
                llInstantMessage(id, "Interface control menu closed.");
            }
            return;
        }
        
        if (message == "Refresh") {
            llInstantMessage(id, "Refreshing interface data...");
            openControlMenu(id);
            return;
        }
        
        // Check for mode changes (admin only)
        if (llSubStringIndex(message, "Mode: ") == 0) {
            if (access >= ACCESS_ADMIN) {
                string mode = llGetSubString(message, 6, -1);
                setInterfaceMode(mode, id);
            } else {
                llInstantMessage(id, "Access denied. Administrator permissions required.");
            }
            openControlMenu(id);
            return;
        }
        
        // Handle menu options with permission checks
        if (llSubStringIndex(message, "[HIDE INV:") != -1) {
            if (access >= ACCESS_TRUSTED) {
                gInvHidden = !gInvHidden;
                if (gInvHidden) {
                    llInstantMessage(wearer, "// Inventory access inhibited. //");
                } else {
                    llInstantMessage(wearer, "// Inventory access restored. //");
                }
                gInterfaceMode = "Custom";
            } else {
                llInstantMessage(id, "Access denied. Trusted user permissions required.");
            }
        }
        else if (llSubStringIndex(message, "[HIDE MAPS:") != -1) {
            if (access >= ACCESS_TRUSTED) {
                gMapHidden = !gMapHidden;
                if (gMapHidden) {
                    llInstantMessage(wearer, "// Navigation systems offline. //");
                } else {
                    llInstantMessage(wearer, "// Navigation systems online. //");
                }
                gInterfaceMode = "Custom";
            } else {
                llInstantMessage(id, "Access denied. Trusted user permissions required.");
            }
        }
        else if (llSubStringIndex(message, "[CAM LOCK:") != -1) {
            if (access >= ACCESS_TRUSTED) {
                gCameraLocked = !gCameraLocked;
                if (gCameraLocked) {
                    llInstantMessage(wearer, "// Camera perspective locked. //");
                } else {
                    llInstantMessage(wearer, "// Camera perspective unlocked. //");
                }
                gInterfaceMode = "Custom";
            } else {
                llInstantMessage(id, "Access denied. Trusted user permissions required.");
            }
        }
        else if (llSubStringIndex(message, "[HIDE IM:") != -1) {
            if (access >= ACCESS_TRUSTED) {
                gIMHidden = !gIMHidden;
                if (gIMHidden) {
                    llInstantMessage(wearer, "// IM panel access restricted. //");
                } else {
                    llInstantMessage(wearer, "// IM panel access restored. //");
                }
                gInterfaceMode = "Custom";
            } else {
                llInstantMessage(id, "Access denied. Trusted user permissions required.");
            }
        }
        else if (llSubStringIndex(message, "[BLOCK EDIT:") != -1) {
            if (access >= ACCESS_TRUSTED) {
                gEditHidden = !gEditHidden;
                if (gEditHidden) {
                    llInstantMessage(wearer, "// Object editing capabilities disabled. //");
                } else {
                    llInstantMessage(wearer, "// Object editing capabilities enabled. //");
                }
                gInterfaceMode = "Custom";
            } else {
                llInstantMessage(id, "Access denied. Trusted user permissions required.");
            }
        }
        else if (llSubStringIndex(message, "[BLOCK BUILD:") != -1) {
            if (access >= ACCESS_TRUSTED) {
                gBuildHidden = !gBuildHidden;
                if (gBuildHidden) {
                    llInstantMessage(wearer, "// Object creation capabilities disabled. //");
                } else {
                    llInstantMessage(wearer, "// Object creation capabilities enabled. //");
                }
                gInterfaceMode = "Custom";
            } else {
                llInstantMessage(id, "Access denied. Trusted user permissions required.");
            }
        }
        else if (llSubStringIndex(message, "[BLOCK TP:") != -1) {
            if (access >= ACCESS_ADMIN) {
                gTPBlocked = !gTPBlocked;
                if (gTPBlocked) {
                    llInstantMessage(wearer, "// Teleportation capabilities disabled. //");
                } else {
                    llInstantMessage(wearer, "// Teleportation capabilities enabled. //");
                }
                gInterfaceMode = "Custom";
            } else {
                llInstantMessage(id, "Access denied. Administrator permissions required.");
            }
        }
        else if (llSubStringIndex(message, "[BLOCK SIT:") != -1) {
            if (access >= ACCESS_ADMIN) {
                gSitBlocked = !gSitBlocked;
                if (gSitBlocked) {
                    llInstantMessage(wearer, "// Sitting capabilities disabled. //");
                } else {
                    llInstantMessage(wearer, "// Sitting capabilities enabled. //");
                }
                gInterfaceMode = "Custom";
            } else {
                llInstantMessage(id, "Access denied. Administrator permissions required.");
            }
        }
        else if (llSubStringIndex(message, "[HIDE RADAR:") != -1) {
            if (access >= ACCESS_ADMIN) {
                gRadarHidden = !gRadarHidden;
                if (gRadarHidden) {
                    llInstantMessage(wearer, "// Radar and name displays hidden. //");
                } else {
                    llInstantMessage(wearer, "// Radar and name displays restored. //");
                }
                gInterfaceMode = "Custom";
            } else {
                llInstantMessage(id, "Access denied. Administrator permissions required.");
            }
        }
        else if (message == "BLACKOUT ALL") {
            if (access >= ACCESS_ADMIN) {
                setInterfaceMode("Blackout", id);
            } else {
                llInstantMessage(id, "Access denied. Administrator permissions required.");
            }
        }
        else if (message == "RESTORE ALL" || message == "Emergency Release") {
            if (access >= ACCESS_ADMIN) {
                setInterfaceMode("Standard", id);
            } else {
                llInstantMessage(id, "Access denied. Administrator permissions required.");
            }
        }
        else if (message == "Full Lockdown") {
            if (access >= ACCESS_ADMIN) {
                setInterfaceMode("Locked", id);
            } else {
                llInstantMessage(id, "Access denied. Administrator permissions required.");
            }
        }
        else if (message == "Reset All") {
            if (access >= ACCESS_ADMIN) {
                setInterfaceMode("Standard", id);
                llInstantMessage(id, "All interface settings reset to default.");
            } else {
                llInstantMessage(id, "Access denied. Administrator permissions required.");
            }
        }
        else if (message == "<-- Back") {
            openControlMenu(id);
            return;
        }
        else if (message == "Advanced") {
            openAdvancedMenu(id);
            return;
        }
        else {
            llInstantMessage(id, "Unknown command: " + message);
        }
        
        // Apply the new restrictions and reopen menu
        applyRestrictions();
        llInstantMessage(id, "Interface protocols updated.");
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
