//-- A.R.I.A. Speech RLV Module (Add-on)
//-- Version 2.0 - CRITICAL FIXES & IMPROVEMENTS
//-- Fixed menu handling, improved RLV commands, enhanced user feedback

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
integer gIsMuted = FALSE;
integer gIsGagged = FALSE;
integer gIsIMBlocked = FALSE;

// --- HELPER FUNCTIONS ---
applyRestrictions() {
    string cmd = "@";
    
    // Apply current manual settings
    if (gIsMuted) {
        cmd += "sendchat=n,";
    } else {
        cmd += "sendchat=y,";
    }
    
    if (gIsGagged) {
        cmd += "recvchat=n,";
    } else {
        cmd += "recvchat=y,";
    }
    
    if (gIsIMBlocked) {
        cmd += "sendim=n,recvim=n,";
    } else {
        cmd += "sendim=y,recvim=y,";
    }
    
    // Low battery automatic restrictions override manual settings
    if (gBatteryLevel <= 15.0) {
        cmd += "sendchat=n,";
    }
    if (gBatteryLevel <= 10.0) {
        cmd += "sendim=n,";
    }
    if (gBatteryLevel <= 5.0) {
        cmd += "recvchat=n,recvim=n,";
    }
    
    // Apply all restrictions at once
    llOwnerSay(cmd);
}

openControlMenu(key admin_id) {
    string dialog = "\n[ SPEECH RLV PROTOCOLS ]\n";
    dialog += "Current Status:\n";
    
    string muteStatus = "OFF";
    if (gIsMuted) muteStatus = "ON";
    
    string gagStatus = "OFF"; 
    if (gIsGagged) gagStatus = "ON";
    
    string imStatus = "OFF";
    if (gIsIMBlocked) imStatus = "ON";
    
    dialog += "• Mute (Send): " + muteStatus + "\n";
    dialog += "• Gag (Receive): " + gagStatus + "\n";
    dialog += "• Block IM: " + imStatus + "\n";
    
    if (gBatteryLevel <= 15.0) {
        dialog += "\n⚠ Low power restrictions active!";
    }
    
    list buttons = [
        "[MUTE: " + muteStatus + "]", 
        "[GAG: " + gagStatus + "]",
        "[BLOCK IM: " + imStatus + "]",
        "SILENCE ALL", 
        "RESTORE ALL", 
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
        gIsMuted = FALSE;
        gIsGagged = FALSE;
        gIsIMBlocked = FALSE;
        
        // Register with main module
        llMessageLinked(LINK_ROOT, MODULE_REGISTER, "Speech RLV", NULL_KEY);
        
        // Apply initial (unrestricted) state
        applyRestrictions();
        
        llOwnerSay("Speech RLV module initialized.");
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
                llOwnerSay("@sendchat=y,recvchat=y,sendim=y,recvim=y");
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

        if (llSubStringIndex(msg, "[MUTE:") != -1) {
            gIsMuted = !gIsMuted;
            if (gIsMuted) {
                llInstantMessage(gWearer, "// Vocalizer protocol disabled. Outgoing local chat restricted. //");
            } else {
                llInstantMessage(gWearer, "// Vocalizer protocol enabled. //");
            }
        }
        else if (llSubStringIndex(msg, "[GAG:") != -1) {
            gIsGagged = !gIsGagged;
            if (gIsGagged) {
                llInstantMessage(gWearer, "// Auditory sensor protocol disabled. Incoming local chat restricted. //");
            } else {
                llInstantMessage(gWearer, "// Auditory sensor protocol enabled. //");
            }
        }
        else if (llSubStringIndex(msg, "[BLOCK IM:") != -1) {
            gIsIMBlocked = !gIsIMBlocked;
            if (gIsIMBlocked) {
                llInstantMessage(gWearer, "// Subspace comms protocol disabled. All IM functions restricted. //");
            } else {
                llInstantMessage(gWearer, "// Subspace comms protocol enabled. //");
            }
        }
        else if (msg == "SILENCE ALL") {
            gIsMuted = TRUE;
            gIsGagged = TRUE;
            gIsIMBlocked = TRUE;
            llInstantMessage(gWearer, "// Full communication blackout engaged. //");
        }
        else if (msg == "RESTORE ALL") {
            gIsMuted = FALSE;
            gIsGagged = FALSE;
            gIsIMBlocked = FALSE;
            llInstantMessage(gWearer, "// Communication protocols restored to standard operation. //");
        }
        
        // Apply the new restrictions
        applyRestrictions();
        llInstantMessage(id, "Speech protocols updated.");
        
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
