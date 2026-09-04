//-- A.R.I.A. Speech RLV Module (Add-on)
//-- Version 3.1 - OPENCOLLAR AUTH INTEGRATION
//-- September 12, 2025 - Refactored to use AUTH_REQUEST/AUTH_REPLY system
//-- CHANGES v3.1:
//--   - Corrected auth-level comparisons to match the OpenCollar ordering
//-- CHANGES v3.0:
//--   - Removed synchronous getAccessLevel() and checkModuleAccess() functions
//--   - Implemented asynchronous AUTH_REQUEST/AUTH_REPLY protocol
//--   - Added pending auth request management for module actions
//--   - Removed old permission variables and UPDATE_CONFIG handling
//--   - All menu functions now use async auth checks
//--   - Streamlined module access control

// --- LINKED MESSAGE CODES ---
integer UPDATE_BATTERY = 101;
integer MODULE_REGISTER = 200;
integer OPEN_MY_MENU = 201;
integer POWER_STATE_CHANGE = 300;

// --- AUTH SYSTEM CODES ---
integer AUTH_REQUEST = 600;
integer AUTH_REPLY = 601;

// --- AUTH LEVEL CONSTANTS (matching permission module) ---
integer CMD_OWNER = 500;
integer CMD_TRUSTED = 501;
integer CMD_GROUP = 502;
integer CMD_WEARER = 503;
integer CMD_EVERYONE = 504;
integer CMD_BLOCKED = 598;
integer CMD_NOACCESS = 599;

// --- STATE VARIABLES ---
key g_kWearer;
float gBatteryLevel = 100.0;
integer gMenuChannel;
integer gListenHandle;
integer gPowerState = TRUE;

// --- MODULE STATE ---
integer gIsMuted = FALSE;
integer gIsGagged = FALSE;
integer gIsIMBlocked = FALSE;

// --- ASYNCHRONOUS AUTH SYSTEM ---
list gPendingAuthRequests;  // Format: [requestId, userKey, action, timestamp, ...]
integer gNextRequestId = 1;
integer gAuthTimeoutSeconds = 30;

// --- MENU VARIABLES ---
key gCurrentMenuUser;

// --- AUTH MANAGEMENT FUNCTIONS ---

// Request auth for a specific module action
requestModuleAuth(key user, string action) {
    string requestId = (string)gNextRequestId;
    gNextRequestId++;
    
    // Store pending request: [requestId, userKey, action, timestamp]
    integer timestamp = llGetUnixTime();
    gPendingAuthRequests += [requestId, user, action, timestamp];
    
    // Send auth request to permission module
    llMessageLinked(LINK_SET, AUTH_REQUEST, action, user);
    
    // Start cleanup timer
    llSetTimerEvent(5.0);
}

// Process auth response and execute authorized action
processModuleAuth(key user, integer authLevel, string action) {
    // Find and remove the pending request
    integer idx = llListFindList(gPendingAuthRequests, [user]);
    if (idx == -1) return; // Request not found
    
    string originalAction = llList2String(gPendingAuthRequests, idx + 1);
    gPendingAuthRequests = llDeleteSubList(gPendingAuthRequests, idx - 1, idx + 2);
    
    // Check if user has sufficient access for this module
    if (authLevel <= CMD_TRUSTED) {
        executeModuleAction(user, action);
    } else {
        string levelName = "Unknown";
        if (CMD_TRUSTED == 501) levelName = "Trusted User";
        llInstantMessage(user, "Access denied. " + levelName + " permissions required for Speech RLV Module.");
    }
}

// Execute the requested action after auth confirmation
executeModuleAction(key user, string action) {
    if (action == "SPEECH_MENU") {
        openControlMenu(user);
    }
    else if (action == "TOGGLE_MUTE") {
        gIsMuted = !gIsMuted;
        if (gIsMuted) {
            llInstantMessage(g_kWearer, "// Vocalizer protocol disabled. Outgoing local chat restricted. //");
        } else {
            llInstantMessage(g_kWearer, "// Vocalizer protocol enabled. //");
        }
        applyRestrictions();
        llInstantMessage(user, "Mute setting updated.");
        openControlMenu(user);
    }
    else if (action == "TOGGLE_GAG") {
        gIsGagged = !gIsGagged;
        if (gIsGagged) {
            llInstantMessage(g_kWearer, "// Auditory sensor protocol disabled. Incoming local chat restricted. //");
        } else {
            llInstantMessage(g_kWearer, "// Auditory sensor protocol enabled. //");
        }
        applyRestrictions();
        llInstantMessage(user, "Gag setting updated.");
        openControlMenu(user);
    }
    else if (action == "TOGGLE_IM_BLOCK") {
        gIsIMBlocked = !gIsIMBlocked;
        if (gIsIMBlocked) {
            llInstantMessage(g_kWearer, "// Subspace comms protocol disabled. Incoming IM restricted. //");
        } else {
            llInstantMessage(g_kWearer, "// Subspace comms protocol enabled. //");
        }
        applyRestrictions();
        llInstantMessage(user, "IM Block setting updated.");
        openControlMenu(user);
    }
    else if (action == "SILENCE_ALL") {
        gIsMuted = TRUE;
        gIsGagged = TRUE;
        gIsIMBlocked = TRUE;
        llInstantMessage(g_kWearer, "// All communication protocols disabled. Full communication lockdown. //");
        applyRestrictions();
        llInstantMessage(user, "All speech restrictions activated.");
        openControlMenu(user);
    }
    else if (action == "RESTORE_ALL") {
        gIsMuted = FALSE;
        gIsGagged = FALSE;
        gIsIMBlocked = FALSE;
        llInstantMessage(g_kWearer, "// All communication protocols enabled. Communication lockdown lifted. //");
        applyRestrictions();
        llInstantMessage(user, "All speech restrictions removed.");
        openControlMenu(user);
    }
}

// Clean up expired auth requests
cleanupAuthRequests() {
    integer currentTime = llGetUnixTime();
    integer i = 0;
    
    while (i < llGetListLength(gPendingAuthRequests)) {
        integer requestTime = llList2Integer(gPendingAuthRequests, i + 3);
        if (currentTime - requestTime > gAuthTimeoutSeconds) {
            // Remove expired request
            gPendingAuthRequests = llDeleteSubList(gPendingAuthRequests, i, i + 3);
        } else {
            i += 4; // Move to next request
        }
    }
}

// --- MODULE FUNCTIONS ---

// Apply current speech restrictions based on module state and battery level
applyRestrictions() {
    if (!gPowerState) {
        // When powered off, remove all restrictions
        llOwnerSay("@sendchat=y,recvchat=y,sendim=y,recvim=y");
        return;
    }
    
    // Battery-based automatic restrictions
    string restrictions = "";
    
    // Apply user-set restrictions
    if (gIsMuted) {
        restrictions += "@sendchat=n,";
    } else {
        restrictions += "@sendchat=y,";
    }
    
    if (gIsGagged) {
        restrictions += "@recvchat=n,";
    } else {
        restrictions += "@recvchat=y,";
    }
    
    if (gIsIMBlocked) {
        restrictions += "@sendim=n,recvim=n,";
    } else {
        restrictions += "@sendim=y,recvim=y,";
    }
    
    // Battery-based restrictions override user settings when critical
    if (gBatteryLevel <= 5.0) {
        restrictions += "@sendchat=n,recvchat=n,sendim=n,recvim=n,";
        llInstantMessage(g_kWearer, "// CRITICAL POWER: All communication systems offline. //");
    } else if (gBatteryLevel <= 10.0) {
        restrictions += "@sendchat=n,recvchat=n,";
        llInstantMessage(g_kWearer, "// LOW POWER: Local communication systems offline. //");
    } else if (gBatteryLevel <= 15.0) {
        restrictions += "@sendchat=n,";
        llInstantMessage(g_kWearer, "// WARNING: Outgoing communication restricted to preserve power. //");
    }
    
    // Remove trailing comma and apply
    if (llStringLength(restrictions) > 0) {
        restrictions = llGetSubString(restrictions, 0, -2);
        llOwnerSay(restrictions);
    }
}

// Build and display the speech control menu
openControlMenu(key user) {
    gCurrentMenuUser = user;
    gMenuChannel = (integer)("0x" + llGetSubString((string)user, -7, -1));
    
    string dialog = "\n[ SPEECH RLV CONTROL ]\n\n";
    dialog += "Battery: " + (string)((integer)gBatteryLevel) + "%\n";
    dialog += "Power: " + (string)gPowerState + "\n\n";
    
    // Status indicators
    string muteStatus = "OFF";
    string gagStatus = "OFF";
    string imStatus = "OFF";
    
    if (gIsMuted) muteStatus = "ON";
    if (gIsGagged) gagStatus = "ON";
    if (gIsIMBlocked) imStatus = "ON";
    
    dialog += "Mute (Send Chat): " + muteStatus + "\n";
    dialog += "Gag (Receive Chat): " + gagStatus + "\n";
    dialog += "Block IM: " + imStatus + "\n\n";
    
    // Battery warnings
    if (gBatteryLevel <= 15.0) {
        dialog += "⚠️ LOW POWER RESTRICTIONS ACTIVE\n\n";
    }
    
    dialog += "Select option to toggle:";
    
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
        g_kWearer = llGetOwner();
        gPendingAuthRequests = [];
        
        gMenuChannel = (integer)("0x" + llGetSubString(llGetKey(), -8, -2));
        
        // Initialize with safe defaults
        gIsMuted = FALSE;
        gIsGagged = FALSE;
        gIsIMBlocked = FALSE;
        
        // Register with main module
        llMessageLinked(LINK_SET, MODULE_REGISTER, "Speech RLV", NULL_KEY);
        
        // Apply initial (unrestricted) state
        applyRestrictions();
        
        llOwnerSay("Speech RLV Module v3.0 initialized with OpenCollar auth system.");
    }

    link_message(integer sender, integer num, string msg, key id) {
        if (num == AUTH_REPLY) {
            // Parse auth reply: "AuthReply|userKey|authLevel"
            list parts = llParseString2List(msg, ["|"], []);
            if (llList2String(parts, 0) == "AuthReply") {
                key user = (key)llList2String(parts, 1);
                integer authLevel = (integer)llList2String(parts, 2);
                string originalAction = (string)id; // The action from AUTH_REQUEST
                
                processModuleAuth(user, authLevel, originalAction);
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
            } else {
                gPowerState = FALSE;
                // When powered off, remove all restrictions
                llOwnerSay("@sendchat=y,recvchat=y,sendim=y,recvim=y");
            }
        }
        else if (num == OPEN_MY_MENU) {
            key user = (key)msg;
            // Request auth for speech menu access
            requestModuleAuth(user, "SPEECH_MENU");
        }
    }

    listen(integer chan, string name, key id, string msg) {
        if (chan != gMenuChannel) return;
        
        llListenRemove(gListenHandle);
        
        if (msg == "Close") {
            llInstantMessage(id, "Speech RLV module menu closed.");
            return;
        }

        // All menu actions require auth - request it for each action
        if (llSubStringIndex(msg, "[MUTE:") != -1) {
            requestModuleAuth(id, "TOGGLE_MUTE");
        }
        else if (llSubStringIndex(msg, "[GAG:") != -1) {
            requestModuleAuth(id, "TOGGLE_GAG");
        }
        else if (llSubStringIndex(msg, "[BLOCK IM:") != -1) {
            requestModuleAuth(id, "TOGGLE_IM_BLOCK");
        }
        else if (msg == "SILENCE ALL") {
            requestModuleAuth(id, "SILENCE_ALL");
        }
        else if (msg == "RESTORE ALL") {
            requestModuleAuth(id, "RESTORE_ALL");
        }
    }

    timer() {
        // Clean up expired auth requests
        cleanupAuthRequests();
        
        // Continue timer for next cleanup
        llSetTimerEvent(60.0);
    }
}
