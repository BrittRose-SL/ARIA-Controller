//-- A.R.I.A. Interface RLV Module (Add-on)
//-- Version 3.1 - OPENCOLLAR AUTH INTEGRATION
//-- September 12, 2025 - Refactored to use AUTH_REQUEST/AUTH_REPLY system
//-- CHANGES v3.1:
//--   - Corrected auth-level comparisons to match the OpenCollar ordering
//-- CHANGES v3.0:
//--   - Removed synchronous getAccessLevel() and checkModuleAccess() functions
//--   - Implemented asynchronous AUTH_REQUEST/AUTH_REPLY protocol
//--   - Added pending auth request management for interface operations
//--   - Removed old permission variables and UPDATE_CONFIG handling
//--   - All menu functions now use async auth checks
//--   - Enhanced interface control security with mode-based restrictions

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

// --- RESTRICTION TRACKING ---
integer gRestrictionsActive = FALSE;
string gLastActionBy = "";

// --- ASYNCHRONOUS AUTH SYSTEM ---
list gPendingAuthRequests;  // Format: [requestId, userKey, action, timestamp, ...]
integer gNextRequestId = 1;
integer gAuthTimeoutSeconds = 30;

// --- MENU VARIABLES ---
key gCurrentMenuUser;
string gCurrentMenuContext = ""; // Track which menu context we're in

// --- AUTH MANAGEMENT FUNCTIONS ---

// Request auth for a specific interface action
requestInterfaceAuth(key user, string action) {
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
processInterfaceAuth(key user, integer authLevel, string action) {
    // Find and remove the pending request
    integer idx = llListFindList(gPendingAuthRequests, [user]);
    if (idx == -1) return; // Request not found
    
    string originalAction = llList2String(gPendingAuthRequests, idx + 1);
    gPendingAuthRequests = llDeleteSubList(gPendingAuthRequests, idx - 1, idx + 2);
    
    // Interface operations require trusted access minimum
    if (authLevel <= CMD_TRUSTED) {
        executeInterfaceAction(user, action);
    } else {
        llInstantMessage(user, "Access denied. Trusted User permissions required for Interface Module.");
    }
}

// Execute the requested interface action after auth confirmation
executeInterfaceAction(key user, string action) {
    if (action == "INTERFACE_MENU") {
        openControlMenu(user);
    }
    else if (action == "TOGGLE_INVENTORY") {
        gInvHidden = !gInvHidden;
        if (gInvHidden) {
            llInstantMessage(g_kWearer, "// Inventory interface disabled. Access restricted. //");
        } else {
            llInstantMessage(g_kWearer, "// Inventory interface enabled. //");
        }
        applyRestrictions();
        llInstantMessage(user, "Inventory visibility setting updated.");
        openControlMenu(user);
    }
    else if (action == "TOGGLE_MAPS") {
        gMapHidden = !gMapHidden;
        if (gMapHidden) {
            llInstantMessage(g_kWearer, "// Navigation systems disabled. Map access restricted. //");
        } else {
            llInstantMessage(g_kWearer, "// Navigation systems enabled. //");
        }
        applyRestrictions();
        llInstantMessage(user, "Map visibility setting updated.");
        openControlMenu(user);
    }
    else if (action == "TOGGLE_CAMERA") {
        gCameraLocked = !gCameraLocked;
        if (gCameraLocked) {
            llInstantMessage(g_kWearer, "// Camera control disabled. View locked. //");
        } else {
            llInstantMessage(g_kWearer, "// Camera control enabled. //");
        }
        applyRestrictions();
        llInstantMessage(user, "Camera lock setting updated.");
        openControlMenu(user);
    }
    else if (action == "TOGGLE_IM") {
        gIMHidden = !gIMHidden;
        if (gIMHidden) {
            llInstantMessage(g_kWearer, "// IM interface disabled. Communication panel restricted. //");
        } else {
            llInstantMessage(g_kWearer, "// IM interface enabled. //");
        }
        applyRestrictions();
        llInstantMessage(user, "IM panel setting updated.");
        openControlMenu(user);
    }
    else if (action == "TOGGLE_EDIT") {
        gEditHidden = !gEditHidden;
        if (gEditHidden) {
            llInstantMessage(g_kWearer, "// Edit functions disabled. Modification access restricted. //");
        } else {
            llInstantMessage(g_kWearer, "// Edit functions enabled. //");
        }
        applyRestrictions();
        llInstantMessage(user, "Edit access setting updated.");
        openControlMenu(user);
    }
    else if (action == "TOGGLE_BUILD") {
        gBuildHidden = !gBuildHidden;
        if (gBuildHidden) {
            llInstantMessage(g_kWearer, "// Build functions disabled. Construction access restricted. //");
        } else {
            llInstantMessage(g_kWearer, "// Build functions enabled. //");
        }
        applyRestrictions();
        llInstantMessage(user, "Build access setting updated.");
        openControlMenu(user);
    }
    else if (action == "TOGGLE_TP") {
        gTPBlocked = !gTPBlocked;
        if (gTPBlocked) {
            llInstantMessage(g_kWearer, "// Teleportation systems disabled. Movement restricted. //");
        } else {
            llInstantMessage(g_kWearer, "// Teleportation systems enabled. //");
        }
        applyRestrictions();
        llInstantMessage(user, "Teleport access setting updated.");
        openControlMenu(user);
    }
    else if (action == "TOGGLE_SIT") {
        gSitBlocked = !gSitBlocked;
        if (gSitBlocked) {
            llInstantMessage(g_kWearer, "// Sitting functions disabled. Posture locked. //");
        } else {
            llInstantMessage(g_kWearer, "// Sitting functions enabled. //");
        }
        applyRestrictions();
        llInstantMessage(user, "Sit access setting updated.");
        openControlMenu(user);
    }
    else if (action == "TOGGLE_RADAR") {
        gRadarHidden = !gRadarHidden;
        if (gRadarHidden) {
            llInstantMessage(g_kWearer, "// Radar systems disabled. Detection capabilities restricted. //");
        } else {
            llInstantMessage(g_kWearer, "// Radar systems enabled. //");
        }
        applyRestrictions();
        llInstantMessage(user, "Radar access setting updated.");
        openControlMenu(user);
    }
    else if (action == "MODE_STANDARD") {
        setInterfaceMode("Standard", user);
        openControlMenu(user);
    }
    else if (action == "MODE_RESTRICTED") {
        setInterfaceMode("Restricted", user);
        openControlMenu(user);
    }
    else if (action == "MODE_LOCKED") {
        setInterfaceMode("Locked", user);
        openControlMenu(user);
    }
    else if (action == "BLACKOUT_ALL") {
        setInterfaceMode("Blackout", user);
        openControlMenu(user);
    }
    else if (action == "RESTORE_ALL") {
        setInterfaceMode("Standard", user);
        openControlMenu(user);
    }
    else if (action == "REFRESH") {
        applyRestrictions();
        llInstantMessage(user, "Interface restrictions refreshed.");
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

// --- INTERFACE MODULE FUNCTIONS ---

// Apply current interface restrictions based on module state and battery level
applyRestrictions() {
    if (!gPowerState) {
        // When powered off, remove all restrictions
        llOwnerSay("@showinv=y,showworldmap=y,showminimap=y,camunlock=y,fartouch=y,edit=y,rez=y,shownames=y,tplm=y,tploc=y,tplure=y,sittp=y,unsit=y");
        return;
    }
    
    string restrictions = "";
    
    // Apply user-set restrictions
    if (gInvHidden) {
        restrictions += "@showinv=n,";
    } else {
        restrictions += "@showinv=y,";
    }
    
    if (gMapHidden) {
        restrictions += "@showworldmap=n,showminimap=n,";
    } else {
        restrictions += "@showworldmap=y,showminimap=y,";
    }
    
    if (gCameraLocked) {
        restrictions += "@camunlock=n,";
    } else {
        restrictions += "@camunlock=y,";
    }
    
    if (gIMHidden) {
        restrictions += "@showloc=n,";
    } else {
        restrictions += "@showloc=y,";
    }
    
    if (gEditHidden) {
        restrictions += "@edit=n,fartouch=n,";
    } else {
        restrictions += "@edit=y,fartouch=y,";
    }
    
    if (gBuildHidden) {
        restrictions += "@rez=n,";
    } else {
        restrictions += "@rez=y,";
    }
    
    if (gRadarHidden) {
        restrictions += "@shownames=n,";
    } else {
        restrictions += "@shownames=y,";
    }
    
    if (gTPBlocked) {
        restrictions += "@tplm=n,tploc=n,tplure=n,";
    } else {
        restrictions += "@tplm=y,tploc=y,tplure=y,";
    }
    
    if (gSitBlocked) {
        restrictions += "@sittp=n,unsit=n,";
    } else {
        restrictions += "@sittp=y,unsit=y,";
    }
    
    // Battery-based restrictions override user settings when critical
    if (gBatteryLevel <= 5.0) {
        restrictions += "@showinv=n,showworldmap=n,showminimap=n,edit=n,rez=n,tplm=n,tploc=n,tplure=n,";
        llInstantMessage(g_kWearer, "// CRITICAL POWER: All interface systems offline. //");
    } else if (gBatteryLevel <= 10.0) {
        restrictions += "@showworldmap=n,edit=n,rez=n,tplm=n,tploc=n,";
        llInstantMessage(g_kWearer, "// LOW POWER: Advanced interface functions disabled. //");
    } else if (gBatteryLevel <= 15.0) {
        restrictions += "@edit=n,rez=n,";
        llInstantMessage(g_kWearer, "// WARNING: Build/edit functions disabled to preserve power. //");
    }
    
    // Remove trailing comma and apply
    if (llStringLength(restrictions) > 0) {
        restrictions = llGetSubString(restrictions, 0, -2);
        llOwnerSay(restrictions);
    }
    
    gRestrictionsActive = TRUE;
}

// Set interface mode with predefined restriction sets
setInterfaceMode(string mode, key user) {
    gInterfaceMode = mode;
    gLastActionBy = llKey2Name(user);
    
    if (mode == "Standard") {
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
        llInstantMessage(g_kWearer, "// Interface mode: STANDARD - Full interface access restored //");
    }
    else if (mode == "Restricted") {
        gInvHidden = TRUE;
        gMapHidden = TRUE;
        gCameraLocked = FALSE;
        gIMHidden = TRUE;
        gEditHidden = TRUE;
        gBuildHidden = TRUE;
        gRadarHidden = FALSE;
        gTPBlocked = FALSE;
        gSitBlocked = FALSE;
        gInterfaceLocked = FALSE;
        llInstantMessage(g_kWearer, "// Interface mode: RESTRICTED - Limited interface access //");
    }
    else if (mode == "Locked") {
        gInvHidden = TRUE;
        gMapHidden = TRUE;
        gCameraLocked = TRUE;
        gIMHidden = TRUE;
        gEditHidden = TRUE;
        gBuildHidden = TRUE;
        gRadarHidden = TRUE;
        gTPBlocked = TRUE;
        gSitBlocked = FALSE;
        gInterfaceLocked = TRUE;
        llInstantMessage(g_kWearer, "// Interface mode: LOCKED - Severe interface restrictions //");
    }
    else if (mode == "Blackout") {
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
        llInstantMessage(g_kWearer, "// Interface mode: BLACKOUT - Full interface lockdown engaged //");
    }
    
    applyRestrictions();
    llInstantMessage(user, "Interface mode changed to: " + mode);
}

// Build and display the main interface control menu
openControlMenu(key user) {
    gCurrentMenuUser = user;
    gCurrentMenuContext = "MAIN";
    gMenuChannel = (integer)("0x" + llGetSubString((string)user, -7, -1));
    
    string dialog = "\n[ INTERFACE CONTROL MODULE ]\n";
    dialog += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
    dialog += "Battery: " + (string)((integer)gBatteryLevel) + "%\n";
    dialog += "Power: " + (string)gPowerState + "\n";
    dialog += "Interface Mode: " + gInterfaceMode + "\n\n";
    
    // Status indicators
    string invStatus = "VISIBLE";
    if (gInvHidden) invStatus = "HIDDEN";
    
    string mapStatus = "VISIBLE";
    if (gMapHidden) mapStatus = "HIDDEN";
    
    string camStatus = "FREE";
    if (gCameraLocked) camStatus = "LOCKED";
    
    string imStatus = "VISIBLE";
    if (gIMHidden) imStatus = "HIDDEN";
    
    string editStatus = "ALLOWED";
    if (gEditHidden) editStatus = "BLOCKED";
    
    string buildStatus = "ALLOWED";
    if (gBuildHidden) buildStatus = "BLOCKED";
    
    dialog += "Interface Status:\n";
    dialog += "• Inventory: " + invStatus + "\n";
    dialog += "• Maps: " + mapStatus + "\n";
    dialog += "• Camera: " + camStatus + "\n";
    dialog += "• IM Panel: " + imStatus + "\n";
    dialog += "• Edit: " + editStatus + "\n";
    dialog += "• Build: " + buildStatus + "\n";
    
    // Battery warnings
    if (gBatteryLevel <= 15.0) {
        dialog += "\n⚠️ LOW POWER RESTRICTIONS ACTIVE\n";
    }
    
    list buttons = [
        "[HIDE INV: " + invStatus + "]",
        "[HIDE MAPS: " + mapStatus + "]",
        "[CAM LOCK: " + camStatus + "]",
        "[HIDE IM: " + imStatus + "]",
        "[BLOCK EDIT: " + editStatus + "]",
        "[BLOCK BUILD: " + buildStatus + "]",
        "More...",
        "Modes",
        "Close"
    ];
    
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llDialog(user, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

// Build and display the advanced controls menu
openAdvancedMenu(key user) {
    string dialog = "\n[ ADVANCED INTERFACE CONTROLS ]\n";
    dialog += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
    dialog += "Advanced restriction controls:\n\n";
    
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
        "Refresh",
        "-Back-"
    ];
    
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llDialog(user, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

// Build and display the interface modes menu
openModesMenu(key user) {
    string dialog = "\n[ INTERFACE MODES ]\n";
    dialog += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
    dialog += "Current Mode: " + gInterfaceMode + "\n\n";
    dialog += "Available preset modes:\n\n";
    dialog += "• Standard: Full access\n";
    dialog += "• Restricted: Limited access\n";
    dialog += "• Locked: Severe restrictions\n";
    dialog += "• Blackout: Complete lockdown\n";
    
    list buttons = [
        "Standard",
        "Restricted", 
        "Locked",
        "BLACKOUT ALL",
        "RESTORE ALL",
        "-Back-"
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
        
        // Initialize interface state
        gInterfaceMode = "Standard";
        gInterfaceLocked = FALSE;
        gRestrictionsActive = FALSE;
        gLastActionBy = "";
        
        // Initialize all restrictions as OFF
        gInvHidden = FALSE;
        gMapHidden = FALSE;
        gCameraLocked = FALSE;
        gIMHidden = FALSE;
        gEditHidden = FALSE;
        gBuildHidden = FALSE;
        gRadarHidden = FALSE;
        gTPBlocked = FALSE;
        gSitBlocked = FALSE;
        
        // Register with main module
        llMessageLinked(LINK_SET, MODULE_REGISTER, "Interface", NULL_KEY);
        
        // Apply initial (unrestricted) state
        applyRestrictions();
        
        llOwnerSay("Interface Control Module v3.0 initialized with OpenCollar auth system.");
    }

    link_message(integer sender, integer num, string msg, key id) {
        if (num == AUTH_REPLY) {
            // Parse auth reply: "AuthReply|userKey|authLevel"
            list parts = llParseString2List(msg, ["|"], []);
            if (llList2String(parts, 0) == "AuthReply") {
                key user = (key)llList2String(parts, 1);
                integer authLevel = (integer)llList2String(parts, 2);
                string originalAction = (string)id; // The action from AUTH_REQUEST
                
                processInterfaceAuth(user, authLevel, originalAction);
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
                llOwnerSay("@showinv=y,showworldmap=y,showminimap=y,camunlock=y,fartouch=y,edit=y,rez=y,shownames=y,tplm=y,tploc=y,tplure=y,sittp=y,unsit=y");
            }
        }
        else if (num == OPEN_MY_MENU) {
            key user = (key)msg;
            // Request auth for interface menu access
            requestInterfaceAuth(user, "INTERFACE_MENU");
        }
    }

    listen(integer chan, string name, key id, string msg) {
        if (chan != gMenuChannel) return;
        
        llListenRemove(gListenHandle);
        
        if (msg == "Close") {
            llInstantMessage(id, "Interface control module menu closed.");
            return;
        }
        
        if (msg == "-Back-") {
            if (gCurrentMenuContext == "ADVANCED" || gCurrentMenuContext == "MODES") {
                requestInterfaceAuth(id, "INTERFACE_MENU");
            }
            return;
        }

        // Handle menu actions based on context
        if (gCurrentMenuContext == "MAIN") {
            // Main menu actions
            if (llSubStringIndex(msg, "[HIDE INV:") != -1) {
                requestInterfaceAuth(id, "TOGGLE_INVENTORY");
            }
            else if (llSubStringIndex(msg, "[HIDE MAPS:") != -1) {
                requestInterfaceAuth(id, "TOGGLE_MAPS");
            }
            else if (llSubStringIndex(msg, "[CAM LOCK:") != -1) {
                requestInterfaceAuth(id, "TOGGLE_CAMERA");
            }
            else if (llSubStringIndex(msg, "[HIDE IM:") != -1) {
                requestInterfaceAuth(id, "TOGGLE_IM");
            }
            else if (llSubStringIndex(msg, "[BLOCK EDIT:") != -1) {
                requestInterfaceAuth(id, "TOGGLE_EDIT");
            }
            else if (llSubStringIndex(msg, "[BLOCK BUILD:") != -1) {
                requestInterfaceAuth(id, "TOGGLE_BUILD");
            }
            else if (msg == "More...") {
                gCurrentMenuContext = "ADVANCED";
                openAdvancedMenu(id);
            }
            else if (msg == "Modes") {
                gCurrentMenuContext = "MODES";
                openModesMenu(id);
            }
        }
        else if (gCurrentMenuContext == "ADVANCED") {
            // Advanced menu actions
            if (llSubStringIndex(msg, "[BLOCK TP:") != -1) {
                requestInterfaceAuth(id, "TOGGLE_TP");
            }
            else if (llSubStringIndex(msg, "[BLOCK SIT:") != -1) {
                requestInterfaceAuth(id, "TOGGLE_SIT");
            }
            else if (llSubStringIndex(msg, "[HIDE RADAR:") != -1) {
                requestInterfaceAuth(id, "TOGGLE_RADAR");
            }
            else if (msg == "Refresh") {
                requestInterfaceAuth(id, "REFRESH");
            }
        }
        else if (gCurrentMenuContext == "MODES") {
            // Modes menu actions
            if (msg == "Standard") {
                requestInterfaceAuth(id, "MODE_STANDARD");
            }
            else if (msg == "Restricted") {
                requestInterfaceAuth(id, "MODE_RESTRICTED");
            }
            else if (msg == "Locked") {
                requestInterfaceAuth(id, "MODE_LOCKED");
            }
            else if (msg == "BLACKOUT ALL") {
                requestInterfaceAuth(id, "BLACKOUT_ALL");
            }
            else if (msg == "RESTORE ALL") {
                requestInterfaceAuth(id, "RESTORE_ALL");
            }
        }
    }

    timer() {
        // Clean up expired auth requests
        cleanupAuthRequests();
        
        // Continue timer for next cleanup
        llSetTimerEvent(60.0);
    }
}
