//-- A.R.I.A. Speech RLV Module (Add-on)
//-- Version 2.1 - FIXED PERMISSIONS SYSTEM + RLV SPEECH CONTROL
//-- CHANGELOG v2.1:
//-- - Added new standardized permissions system from template
//-- - Fixed permission validation in all menu functions
//-- - Added proper config synchronization with master kernel
//-- - Improved access level checking for trusted users
//-- - Added permission status display in menus
//-- - RLV speech controls require trusted user access minimum

// --- LINKED MESSAGE CODES ---
integer UPDATE_BATTERY = 101;
integer UPDATE_CONFIG = 102;
integer MODULE_REGISTER = 200;
integer OPEN_MY_MENU = 201;
integer POWER_STATE_CHANGE = 300;

// --- PERMISSION VARIABLES (REQUIRED) ---
list gAdministrators;
list gTrustedUsers;
key wearer;
integer gWearerAdminMode = TRUE;
integer gConfigReceived = FALSE;

// --- PERMISSION LEVELS (REQUIRED) ---
integer ACCESS_ADMIN = 4;
integer ACCESS_TRUSTED = 3;
integer ACCESS_WEARER = 2;
integer ACCESS_PUBLIC = 1;

// --- STATE VARIABLES ---
float gBatteryLevel = 100.0;
integer gMenuChannel;
integer gListenHandle;
key gAdministrator;
integer gPowerState = TRUE;

// --- MODULE STATE ---
integer gIsMuted = FALSE;
integer gIsGagged = FALSE;
integer gIsIMBlocked = FALSE;

// --- PERMISSION FUNCTIONS (REQUIRED) ---

integer getAccessLevel(key id) {
    // Check administrator list first
    if (llListFindList(gAdministrators, [id]) != -1) return ACCESS_ADMIN;
    
    // Check trusted users list
    if (llListFindList(gTrustedUsers, [id]) != -1) return ACCESS_TRUSTED;
    
    // Check if it's the wearer
    if (id == wearer) {
        // Wearer access depends on wearer admin mode
        if (gWearerAdminMode) {
            return ACCESS_ADMIN;
        } else {
            return ACCESS_WEARER;
        }
    }
    
    // Everyone else gets public access
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

openControlMenu(key user) {
    // Check permissions first
    if (!checkModuleAccess(user, ACCESS_TRUSTED, "Speech RLV")) {
        return;
    }
    
    integer access = getAccessLevel(user);
    
    string dialog = "\n[ SPEECH RLV PROTOCOLS ]\n";
    dialog += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
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
    
    dialog += "\nAccess Level: ";
    if (access >= ACCESS_ADMIN) {
        dialog += "ADMINISTRATOR\n";
    } else if (access >= ACCESS_TRUSTED) {
        dialog += "TRUSTED USER\n";
    } else {
        dialog += "WEARER\n";
    }
    
    dialog += "Config Status: ";
    if (gConfigReceived) {
        dialog += "SYNCHRONIZED";
    } else {
        dialog += "WAITING";
    }
    
    if (gBatteryLevel <= 15.0) {
        dialog += "\n\n⚠ Low power restrictions active!";
    }
    
    list buttons = [
        "[MUTE: " + muteStatus + "]", 
        "[GAG: " + gagStatus + "]",
        "[BLOCK IM: " + imStatus + "]",
        "SILENCE ALL", 
        "RESTORE ALL", 
        "Close"
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
        gConfigReceived = FALSE;
        
        // Initialize with owner as admin (backup measure)
        gAdministrators = [wearer];
        gTrustedUsers = [];
        
        gMenuChannel = (integer)("0x" + llGetSubString(llGetKey(), -8, -2));
        
        // Initialize with safe defaults
        gIsMuted = FALSE;
        gIsGagged = FALSE;
        gIsIMBlocked = FALSE;
        
        // Register with main module
        llMessageLinked(LINK_ROOT, MODULE_REGISTER, "Speech RLV", NULL_KEY);
        
        // Apply initial (unrestricted) state
        applyRestrictions();
        
        llOwnerSay("Speech RLV module v2.1 initialized with permissions system...");
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
            // Receive configuration from master kernel
            list parts = llParseString2List(msg, ["|"], []);
            if (llGetListLength(parts) >= 2) {
                string adminCsv = llList2String(parts, 0);
                string trustedCsv = llList2String(parts, 1);
                
                // Update local lists from master kernel
                if (adminCsv != "") {
                    gAdministrators = llCSV2List(adminCsv);
                } else {
                    gAdministrators = [llGetOwner()]; // Ensure owner is always admin
                }
                
                if (trustedCsv != "") {
                    gTrustedUsers = llCSV2List(trustedCsv);
                } else {
                    gTrustedUsers = [];
                }
                
                gConfigReceived = TRUE;
                llOwnerSay("Speech RLV Module permissions updated from master kernel.");
                llOwnerSay("Administrators: " + (string)llGetListLength(gAdministrators));
                llOwnerSay("Trusted Users: " + (string)llGetListLength(gTrustedUsers));
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
            
            // Check permissions using new system
            if (checkModuleAccess(user, ACCESS_TRUSTED, "Speech RLV")) {
                gAdministrator = user;
                openControlMenu(user);
            }
        }
    }

    listen(integer chan, string name, key id, string msg) {
        if (chan != gMenuChannel) return;
        
        llListenRemove(gListenHandle);
        
        // Always check permissions in listen events
        integer access = getAccessLevel(id);
        
        if (msg == "Close") {
            llInstantMessage(id, "Speech RLV module menu closed.");
            return;
        }

        if (llSubStringIndex(msg, "[MUTE:") != -1) {
            if (access >= ACCESS_TRUSTED) {
                gIsMuted = !gIsMuted;
                if (gIsMuted) {
                    llInstantMessage(wearer, "// Vocalizer protocol disabled. Outgoing local chat restricted. //");
                } else {
                    llInstantMessage(wearer, "// Vocalizer protocol enabled. //");
                }
                applyRestrictions();
                llInstantMessage(id, "Mute setting updated.");
                openControlMenu(id);
            } else {
                llInstantMessage(id, "Access denied. Trusted user permissions required for speech controls.");
            }
        }
        else if (llSubStringIndex(msg, "[GAG:") != -1) {
            if (access >= ACCESS_TRUSTED) {
                gIsGagged = !gIsGagged;
                if (gIsGagged) {
                    llInstantMessage(wearer, "// Auditory sensor protocol disabled. Incoming local chat restricted. //");
                } else {
                    llInstantMessage(wearer, "// Auditory sensor protocol enabled. //");
                }
                applyRestrictions();
                llInstantMessage(id, "Gag setting updated.");
                openControlMenu(id);
            } else {
                llInstantMessage(id, "Access denied. Trusted user permissions required for speech controls.");
            }
        }
        else if (llSubStringIndex(msg, "[BLOCK IM:") != -1) {
            if (access >= ACCESS_TRUSTED) {
                gIsIMBlocked = !gIsIMBlocked;
                if (gIsIMBlocked) {
                    llInstantMessage(wearer, "// Subspace comms protocol disabled. All IM functions restricted. //");
                } else {
                    llInstantMessage(wearer, "// Subspace comms protocol enabled. //");
                }
                applyRestrictions();
                llInstantMessage(id, "IM blocking setting updated.");
                openControlMenu(id);
            } else {
                llInstantMessage(id, "Access denied. Trusted user permissions required for IM controls.");
            }
        }
        else if (msg == "SILENCE ALL") {
            if (access >= ACCESS_TRUSTED) {
                gIsMuted = TRUE;
                gIsGagged = TRUE;
                gIsIMBlocked = TRUE;
                llInstantMessage(wearer, "// Full communication blackout engaged. //");
                applyRestrictions();
                llInstantMessage(id, "Complete communication silence activated.");
                openControlMenu(id);
            } else {
                llInstantMessage(id, "Access denied. Trusted user permissions required for silence controls.");
            }
        }
        else if (msg == "RESTORE ALL") {
            if (access >= ACCESS_TRUSTED) {
                gIsMuted = FALSE;
                gIsGagged = FALSE;
                gIsIMBlocked = FALSE;
                llInstantMessage(wearer, "// Communication protocols restored to standard operation. //");
                applyRestrictions();
                llInstantMessage(id, "All communication restored.");
                openControlMenu(id);
            } else {
                llInstantMessage(id, "Access denied. Trusted user permissions required for speech controls.");
            }
        }
    }
    
    timer() {
        llListenRemove(gListenHandle);
        llSetTimerEvent(0.0);
    }
    
    changed(integer c) {
        if (c & CHANGED_OWNER) {
            llResetScript();
        }
    }
}

//-- IMPLEMENTATION NOTES v2.1:
//-- 1. Added complete permissions system from template
//-- 2. All menu functions now check permissions before execution
//-- 3. Speech controls require trusted user access minimum for safety
//-- 4. Permissions are synchronized from master kernel via UPDATE_CONFIG
//-- 5. Access levels displayed in menus for transparency
//-- 6. Config status shows synchronization state
//-- 7. Owner automatically has admin access as backup measure
//-- 8. All RLV speech operations require trusted user permissions
//-- 9. Permission checks added to all listen event handlers
//-- 10. Proper error messages when access is denied
//-- 11. Maintains original RLV functionality with enhanced security
//-- 12. Battery-based restrictions still apply automatically
