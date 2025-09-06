//-- A.R.I.A. Mobility RLV Module (Add-on)
//-- Version 2.0 - CRITICAL FIXES & IMPROVEMENTS
//-- Fixed RLV commands, improved permission handling, enhanced user feedback

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
integer gIsGrounded = FALSE;
integer gIsFrozen = FALSE;
integer gIsTPBlocked = FALSE;
integer gIsJumpBlocked = FALSE;

// --- PERMISSION MANAGEMENT ---
list gTPWhitelist;
list gTPBlacklist;

// --- HELPER FUNCTIONS ---
applyRestrictions() {
    string cmd = "@";
    
    // Apply current manual settings
    if (gIsGrounded) {
        cmd += "fly=n,";
    } else {
        cmd += "fly=y,";
    }
    
    if (gIsFrozen) {
        cmd += "forwards=n,back=n,left=n,right=n,up=n,down=n,";
    } else {
        cmd += "forwards=y,back=y,left=y,right=y,up=y,down=y,";
    }
    
    if (gIsTPBlocked) {
        cmd += "tploc=n,tplm=n,tplocal=n,";
    } else {
        cmd += "tploc=y,tplm=y,tplocal=y,";
    }
    
    if (gIsJumpBlocked) {
        cmd += "jump=n,";
    } else {
        cmd += "jump=y,";
    }
    
    // Low battery automatic restrictions override manual settings
    if (gBatteryLevel <= 15.0) {
        cmd += "fly=n,jump=n,";
    }
    if (gBatteryLevel <= 10.0) {
        cmd += "tploc=n,tplm=n,tplocal=n,";
    }
    if (gBatteryLevel <= 5.0) {
        cmd += "forwards=n,back=n,left=n,right=n,up=n,down=n,";
    }
    
    // Apply whitelist/blacklist for teleport permissions
    integer i;
    for (i = 0; i < llGetListLength(gTPWhitelist); i++) {
        cmd += "tprequest:" + (string)llList2String(gTPWhitelist, i) + "=rem,";
    }
    for (i = 0; i < llGetListLength(gTPBlacklist); i++) {
        cmd += "tprequest:" + (string)llList2String(gTPBlacklist, i) + "=add,";
    }
    
    // Apply all restrictions at once
    llOwnerSay(cmd);
}

openControlMenu(key admin_id) {
    string dialog = "\n[ MOBILITY RLV PROTOCOLS ]\n";
    dialog += "Current Status:\n";
    
    string groundStatus = "OFF";
    if (gIsGrounded) groundStatus = "ON";
    
    string freezeStatus = "OFF";
    if (gIsFrozen) freezeStatus = "ON";
    
    string tpStatus = "OFF";
    if (gIsTPBlocked) tpStatus = "ON";
    
    string jumpStatus = "OFF";
    if (gIsJumpBlocked) jumpStatus = "ON";
    
    dialog += "• Ground (No Fly): " + groundStatus + "\n";
    dialog += "• Freeze (No Move): " + freezeStatus + "\n";
    dialog += "• Block TP: " + tpStatus + "\n";
    dialog += "• Block Jump: " + jumpStatus + "\n";
    
    if (gBatteryLevel <= 15.0) {
        dialog += "\n⚠ Low power mobility restrictions active!";
    }
    
    list buttons = [
        "[GROUND: " + groundStatus + "]",
        "[FREEZE: " + freezeStatus + "]", 
        "[BLOCK TP: " + tpStatus + "]",
        "[BLOCK JUMP: " + jumpStatus + "]",
        "FULL LOCK",
        "RELEASE ALL",
        "TP Perms",
        "-Main-"
    ];
    
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", admin_id, "");
    llDialog(admin_id, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

openPermissionsMenu(key admin_id) {
    string dialog = "\n[ TELEPORT PERMISSIONS ]\n";
    dialog += "Whitelist (" + (string)llGetListLength(gTPWhitelist) + " users)\n";
    dialog += "Blacklist (" + (string)llGetListLength(gTPBlacklist) + " users)\n\n";
    dialog += "Note: Use main Permissions module\nto manage user lists.";
    
    list buttons = [
        "Clear Whitelist",
        "Clear Blacklist", 
        "Add Admin to WL",
        "Show Lists",
        "-Back-"
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
        gIsGrounded = FALSE;
        gIsFrozen = FALSE;
        gIsTPBlocked = FALSE;
        gIsJumpBlocked = FALSE;
        
        // Initialize permission lists
        gTPWhitelist = [];
        gTPBlacklist = [];
        
        // Register with main module
        llMessageLinked(LINK_ROOT, MODULE_REGISTER, "Mobility RLV", NULL_KEY);
        
        // Apply initial (unrestricted) state
        applyRestrictions();
        
        llOwnerSay("Mobility RLV module initialized.");
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
                
                // Reset whitelist with current administrators
                gTPWhitelist = gAdministrators;
                applyRestrictions();
            }
        }
        else if (num == POWER_STATE_CHANGE) {
            if (msg == "ON") {
                gPowerState = TRUE;
                applyRestrictions();
            } else {
                gPowerState = FALSE;
                // When powered off, remove all restrictions
                llOwnerSay("@fly=y,forwards=y,back=y,left=y,right=y,up=y,down=y,tploc=y,tplm=y,tplocal=y,jump=y");
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
        else if (msg == "-Back-") {
            openControlMenu(id);
            return;
        }

        if (llSubStringIndex(msg, "[GROUND:") != -1) {
            gIsGrounded = !gIsGrounded;
            if (gIsGrounded) {
                llInstantMessage(gWearer, "// Flight inhibitors engaged. //");
            } else {
                llInstantMessage(gWearer, "// Flight inhibitors disengaged. //");
            }
        }
        else if (llSubStringIndex(msg, "[FREEZE:") != -1) {
            gIsFrozen = !gIsFrozen;
            if (gIsFrozen) {
                llInstantMessage(gWearer, "// Locomotion system halted. //");
            } else {
                llInstantMessage(gWearer, "// Locomotion system nominal. //");
            }
        }
        else if (llSubStringIndex(msg, "[BLOCK TP:") != -1) {
            gIsTPBlocked = !gIsTPBlocked;
            if (gIsTPBlocked) {
                llInstantMessage(gWearer, "// Teleportation beacon disabled. //");
            } else {
                llInstantMessage(gWearer, "// Teleportation beacon enabled. //");
            }
        }
        else if (llSubStringIndex(msg, "[BLOCK JUMP:") != -1) {
            gIsJumpBlocked = !gIsJumpBlocked;
            if (gIsJumpBlocked) {
                llInstantMessage(gWearer, "// Jump functionality disabled. //");
            } else {
                llInstantMessage(gWearer, "// Jump functionality enabled. //");
            }
        }
        else if (msg == "FULL LOCK") {
            gIsGrounded = TRUE;
            gIsFrozen = TRUE;
            gIsTPBlocked = TRUE;
            gIsJumpBlocked = TRUE;
            llInstantMessage(gWearer, "// All mobility systems locked down. Movement prohibited. //");
        }
        else if (msg == "RELEASE ALL") {
            gIsGrounded = FALSE;
            gIsFrozen = FALSE;
            gIsTPBlocked = FALSE;
            gIsJumpBlocked = FALSE;
            llInstantMessage(gWearer, "// All mobility protocols have been released. //");
        }
        else if (msg == "TP Perms") {
            openPermissionsMenu(id);
            return;
        }
        else if (msg == "Clear Whitelist") {
            gTPWhitelist = [];
            llInstantMessage(id, "Teleport whitelist cleared.");
            openPermissionsMenu(id);
            return;
        }
        else if (msg == "Clear Blacklist") {
            gTPBlacklist = [];
            llInstantMessage(id, "Teleport blacklist cleared.");
            openPermissionsMenu(id);
            return;
        }
        else if (msg == "Add Admin to WL") {
            if (llListFindList(gTPWhitelist, [id]) == -1) {
                gTPWhitelist += [id];
                llInstantMessage(id, "You have been added to the teleport whitelist.");
            } else {
                llInstantMessage(id, "You are already on the teleport whitelist.");
            }
            openPermissionsMenu(id);
            return;
        }
        else if (msg == "Show Lists") {
            string report = "\nTeleport Whitelist:\n";
            if (llGetListLength(gTPWhitelist) == 0) {
                report += "  (empty)\n";
            } else {
                integer i;
                for (i = 0; i < llGetListLength(gTPWhitelist) && i < 5; i++) {
                    report += "  " + llKey2Name((key)llList2String(gTPWhitelist, i)) + "\n";
                }
                if (llGetListLength(gTPWhitelist) > 5) {
                    report += "  ... and " + (string)(llGetListLength(gTPWhitelist) - 5) + " more\n";
                }
            }
            
            report += "\nTeleport Blacklist:\n";
            if (llGetListLength(gTPBlacklist) == 0) {
                report += "  (empty)";
            } else {
                integer i;
                for (i = 0; i < llGetListLength(gTPBlacklist) && i < 5; i++) {
                    report += "  " + llKey2Name((key)llList2String(gTPBlacklist, i)) + "\n";
                }
                if (llGetListLength(gTPBlacklist) > 5) {
                    report += "  ... and " + (string)(llGetListLength(gTPBlacklist) - 5) + " more";
                }
            }
            
            llInstantMessage(id, report);
            openPermissionsMenu(id);
            return;
        }
        
        // Apply the new restrictions
        applyRestrictions();
        llInstantMessage(id, "Mobility protocols updated.");
        
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
