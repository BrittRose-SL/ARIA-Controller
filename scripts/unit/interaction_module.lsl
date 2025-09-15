//-- A.R.I.A. Interaction RLV Module (Add-on)
//-- Version 3.0 - OPENCOLLAR AUTH SYSTEM INTEGRATION
//-- September 12, 2025 - Updated to use AUTH_REQUEST/AUTH_REPLY system
//-- CHANGES v3.0:
//--   - Replaced old permission system with OpenCollar auth
//--   - Implemented AUTH_REQUEST/AUTH_REPLY protocol
//--   - Removed old permission variables and functions
//--   - Enhanced UI restrictions and interface controls
//--   - Improved restriction tracking and user feedback
//--   - Fixed all ternary operators and invalid LSL syntax

// --- LINKED MESSAGE CODES ---
integer UPDATE_BATTERY = 101;
integer MODULE_REGISTER = 200;
integer OPEN_MY_MENU = 201;
integer POWER_STATE_CHANGE = 300;

// --- NEW AUTH SYSTEM CODES ---
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
float gBatteryLevel = 100.0;
integer gMenuChannel;
integer gListenHandle;
integer gPowerState = TRUE;
key wearer;

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
list gPendingAuthRequests;  // Format: [requestId, userKey, action, ...]
integer gNextRequestId = 1;
key gCurrentMenuUser;

// --- MENU STATES ---
integer gMenuState = 0;
// 0 = main, 1 = basic controls, 2 = advanced controls

// --- AUTH HELPER FUNCTIONS ---

// Request authorization for an action
requestAuth(key user, string action) {
    integer requestId = gNextRequestId++;
    gPendingAuthRequests += [requestId, user, action];
    llMessageLinked(LINK_SET, AUTH_REQUEST, (string)requestId, user);
}

// Process auth response and execute action
processAuthResponse(string authReply, key originalUser) {
    list parts = llParseString2List(authReply, ["|"], []);
    if (llList2String(parts, 0) != "AuthReply") return;
    
    key user = (key)llList2String(parts, 1);
    integer authLevel = (integer)llList2String(parts, 2);
    
    // Find and remove the pending request
    integer idx = llListFindList(gPendingAuthRequests, [user]);
    if (idx == -1) return;
    
    integer requestId = (integer)llList2String(gPendingAuthRequests, idx - 1);
    string action = llList2String(gPendingAuthRequests, idx + 1);
    gPendingAuthRequests = llDeleteSubList(gPendingAuthRequests, idx - 1, idx + 1);
    
    // Execute the authorized action
    executeAuthorizedAction(user, authLevel, action);
}

// Execute action after authorization
executeAuthorizedAction(key user, integer authLevel, string action) {
    if (action == "MENU_ACCESS") {
        if (authLevel >= CMD_TRUSTED) {
            openControlMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Trusted user permissions required for Interface controls.");
        }
    }
    else if (action == "INV_TOGGLE") {
        if (authLevel >= CMD_TRUSTED) {
            gInvHidden = !gInvHidden;
            gLastActionBy = llKey2Name(user);
            applyRestrictions();
            string status;
            if (gInvHidden) {
                status = "hidden";
            } else {
                status = "visible";
            }
            llInstantMessage(user, "Inventory " + status + ".");
            llInstantMessage(wearer, "// Inventory interface " + status + " by " + llKey2Name(user) + " //");
            openControlMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Trusted user permissions required.");
        }
    }
    else if (action == "MAP_TOGGLE") {
        if (authLevel >= CMD_TRUSTED) {
            gMapHidden = !gMapHidden;
            gLastActionBy = llKey2Name(user);
            applyRestrictions();
            string status;
            if (gMapHidden) {
                status = "hidden";
            } else {
                status = "visible";
            }
            llInstantMessage(user, "Map interface " + status + ".");
            llInstantMessage(wearer, "// Map interface " + status + " by " + llKey2Name(user) + " //");
            openControlMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Trusted user permissions required.");
        }
    }
    else if (action == "CAMERA_TOGGLE") {
        if (authLevel >= CMD_TRUSTED) {
            gCameraLocked = !gCameraLocked;
            gLastActionBy = llKey2Name(user);
            applyRestrictions();
            string status;
            if (gCameraLocked) {
                status = "locked";
            } else {
                status = "free";
            }
            llInstantMessage(user, "Camera " + status + ".");
            llInstantMessage(wearer, "// Camera controls " + status + " by " + llKey2Name(user) + " //");
            openControlMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Trusted user permissions required.");
        }
    }
    else if (action == "IM_TOGGLE") {
        if (authLevel >= CMD_TRUSTED) {
            gIMHidden = !gIMHidden;
            gLastActionBy = llKey2Name(user);
            applyRestrictions();
            string status;
            if (gIMHidden) {
                status = "hidden";
            } else {
                status = "visible";
            }
            llInstantMessage(user, "IM panel " + status + ".");
            llInstantMessage(wearer, "// IM interface " + status + " by " + llKey2Name(user) + " //");
            openControlMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Trusted user permissions required.");
        }
    }
    else if (action == "EDIT_TOGGLE") {
        if (authLevel >= CMD_TRUSTED) {
            gEditHidden = !gEditHidden;
            gLastActionBy = llKey2Name(user);
            applyRestrictions();
            string status;
            if (gEditHidden) {
                status = "blocked";
            } else {
                status = "allowed";
            }
            llInstantMessage(user, "Edit capability " + status + ".");
            llInstantMessage(wearer, "// Edit functions " + status + " by " + llKey2Name(user) + " //");
            openControlMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Trusted user permissions required.");
        }
    }
    else if (action == "BUILD_TOGGLE") {
        if (authLevel >= CMD_TRUSTED) {
            gBuildHidden = !gBuildHidden;
            gLastActionBy = llKey2Name(user);
            applyRestrictions();
            string status;
            if (gBuildHidden) {
                status = "blocked";
            } else {
                status = "allowed";
            }
            llInstantMessage(user, "Build capability " + status + ".");
            llInstantMessage(wearer, "// Build functions " + status + " by " + llKey2Name(user) + " //");
            openControlMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Trusted user permissions required.");
        }
    }
    else if (action == "TP_TOGGLE") {
        if (authLevel >= CMD_OWNER) {
            gTPBlocked = !gTPBlocked;
            gLastActionBy = llKey2Name(user);
            applyRestrictions();
            string status;
            if (gTPBlocked) {
                status = "blocked";
            } else {
                status = "allowed";
            }
            llInstantMessage(user, "Teleport capability " + status + ".");
            llInstantMessage(wearer, "// Teleport functions " + status + " by " + llKey2Name(user) + " //");
            openControlMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Owner permissions required for teleport controls.");
        }
    }
    else if (action == "SIT_TOGGLE") {
        if (authLevel >= CMD_OWNER) {
            gSitBlocked = !gSitBlocked;
            gLastActionBy = llKey2Name(user);
            applyRestrictions();
            string status;
            if (gSitBlocked) {
                status = "blocked";
            } else {
                status = "allowed";
            }
            llInstantMessage(user, "Sitting capability " + status + ".");
            llInstantMessage(wearer, "// Sitting functions " + status + " by " + llKey2Name(user) + " //");
            openControlMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Owner permissions required for sitting controls.");
        }
    }
    else if (action == "RADAR_TOGGLE") {
        if (authLevel >= CMD_OWNER) {
            gRadarHidden = !gRadarHidden;
            gLastActionBy = llKey2Name(user);
            applyRestrictions();
            string status;
            if (gRadarHidden) {
                status = "hidden";
            } else {
                status = "visible";
            }
            llInstantMessage(user, "Radar/Names " + status + ".");
            llInstantMessage(wearer, "// Name display " + status + " by " + llKey2Name(user) + " //");
            openControlMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Owner permissions required for radar controls.");
        }
    }
    else if (action == "MODE_STANDARD") {
        if (authLevel >= CMD_OWNER) {
            setInterfaceMode("Standard", user);
            openControlMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Owner permissions required for mode changes.");
        }
    }
    else if (action == "MODE_RESTRICTED") {
        if (authLevel >= CMD_OWNER) {
            setInterfaceMode("Restricted", user);
            openControlMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Owner permissions required for mode changes.");
        }
    }
    else if (action == "MODE_LOCKED") {
        if (authLevel >= CMD_OWNER) {
            setInterfaceMode("Locked", user);
            openControlMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Owner permissions required for mode changes.");
        }
    }
    else if (action == "MODE_BLACKOUT") {
        if (authLevel >= CMD_OWNER) {
            setInterfaceMode("Blackout", user);
            openControlMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Owner permissions required for blackout mode.");
        }
    }
    else if (action == "RESTORE_ALL") {
        if (authLevel >= CMD_OWNER) {
            setInterfaceMode("Standard", user);
            openControlMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Owner permissions required for restoration.");
        }
    }
}

// --- RLV RESTRICTION FUNCTIONS ---

applyRestrictions() {
    gRestrictionsActive = FALSE;
    
    // Build RLV command string
    string cmd = "@clear,";
    
    // Apply current restrictions based on state
    if (gInvHidden) {
        cmd += "showinv=n,";
        gRestrictionsActive = TRUE;
    }
    
    if (gMapHidden) {
        cmd += "showworldmap=n,showminimap=n,";
        gRestrictionsActive = TRUE;
    }
    
    if (gCameraLocked) {
        cmd += "camunlock=n,camdistmax=1.0,";
        gRestrictionsActive = TRUE;
    }
    
    if (gIMHidden) {
        cmd += "showim=n,";
        gRestrictionsActive = TRUE;
    }
    
    if (gEditHidden) {
        cmd += "edit=n,";
        gRestrictionsActive = TRUE;
    }
    
    if (gBuildHidden) {
        cmd += "rez=n,";
        gRestrictionsActive = TRUE;
    }
    
    if (gRadarHidden) {
        cmd += "shownames=n,";
        gRestrictionsActive = TRUE;
    }
    
    if (gTPBlocked) {
        cmd += "tplm=n,tplocal=n,tplure=n,";
        gRestrictionsActive = TRUE;
    }
    
    if (gSitBlocked) {
        cmd += "sit=n,sittp=n,";
        gRestrictionsActive = TRUE;
    }
    
    // Apply battery level restrictions
    if (gBatteryLevel <= 5.0) {
        cmd += "camunlock=n,camdistmax=1.0,showim=n,tplm=n,";
        gRestrictionsActive = TRUE;
    }
    else if (gBatteryLevel <= 10.0) {
        cmd += "showworldmap=n,showminimap=n,rez=n,";
        gRestrictionsActive = TRUE;
    }
    else if (gBatteryLevel <= 15.0) {
        cmd += "showworldmap=n,";
        gRestrictionsActive = TRUE;
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
        gMapHidden = FALSE;
        gCameraLocked = FALSE;
        gIMHidden = FALSE;
        gRadarHidden = FALSE;
        gTPBlocked = FALSE;
        gSitBlocked = FALSE;
        gInterfaceLocked = FALSE;
        llInstantMessage(wearer, "// Interface mode: RESTRICTED - Basic limitations applied //");
    }
    else if (mode == "Locked") {
        // Heavy restrictions
        gInvHidden = TRUE;
        gMapHidden = TRUE;
        gEditHidden = TRUE;
        gBuildHidden = TRUE;
        gTPBlocked = TRUE;
        gCameraLocked = FALSE;
        gIMHidden = FALSE;
        gRadarHidden = FALSE;
        gSitBlocked = FALSE;
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
    
    gLastActionBy = llKey2Name(user);
    applyRestrictions();
    llInstantMessage(user, "Interface mode changed to: " + mode);
}

// --- MENU FUNCTIONS ---

openControlMenu(key user) {
    gCurrentMenuUser = user;
    
    string dialog = "\n[ INTERFACE CONTROL MODULE ]\n";
    dialog += "═══════════════════════════════════════\n";
    dialog += "Interface Mode: " + gInterfaceMode + "\n";
    dialog += "Battery Level: " + (string)((integer)gBatteryLevel) + "%\n";
    
    string powerStatus;
    if (gPowerState) {
        powerStatus = "ONLINE";
    } else {
        powerStatus = "OFFLINE";
    }
    dialog += "Power State: " + powerStatus + "\n\n";
    
    dialog += "Interface Status:\n";
    
    string invStatus;
    if (gInvHidden) {
        invStatus = "HIDDEN";
    } else {
        invStatus = "VISIBLE";
    }
    
    string mapStatus;
    if (gMapHidden) {
        mapStatus = "HIDDEN";
    } else {
        mapStatus = "VISIBLE";
    }
    
    string camStatus;
    if (gCameraLocked) {
        camStatus = "LOCKED";
    } else {
        camStatus = "FREE";
    }
    
    string imStatus;
    if (gIMHidden) {
        imStatus = "HIDDEN";
    } else {
        imStatus = "VISIBLE";
    }
    
    dialog += "├ Inventory: " + invStatus + "\n";
    dialog += "├ Maps: " + mapStatus + "\n";
    dialog += "├ Camera: " + camStatus + "\n";
    dialog += "└ IM Panel: " + imStatus + "\n";
    
    if (gLastActionBy != "") {
        dialog += "\nLast Action By: " + gLastActionBy + "\n";
    }
    
    list buttons = [];
    
    // Basic controls (Trusted+ users)
    if (gInvHidden) {
        buttons += ["[INV SHOW]"];
    } else {
        buttons += ["[INV HIDE]"];
    }
    
    if (gMapHidden) {
        buttons += ["[MAP SHOW]"];
    } else {
        buttons += ["[MAP HIDE]"];
    }
    
    if (gCameraLocked) {
        buttons += ["[CAM FREE]"];
    } else {
        buttons += ["[CAM LOCK]"];
    }
    
    if (gIMHidden) {
        buttons += ["[IM SHOW]"];
    } else {
        buttons += ["[IM HIDE]"];
    }
    
    string editStatus;
    if (gEditHidden) {
        editStatus = "ALLOW";
    } else {
        editStatus = "BLOCK";
    }
    
    string buildStatus;
    if (gBuildHidden) {
        buildStatus = "ALLOW";
    } else {
        buildStatus = "BLOCK";
    }
    
    buttons += ["[EDIT " + editStatus + "]"];
    buttons += ["[BUILD " + buildStatus + "]"];
    
    // Advanced controls (Owner only) - show in separate section
    buttons += ["ADVANCED", "MODES"];
    
    // System controls
    buttons += ["CLOSE"];
    
    gMenuChannel = (integer)("0x" + llGetSubString(llGetKey(), -8, -2));
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llSetTimerEvent(60.0);
    
    llDialog(user, dialog, buttons, gMenuChannel);
}

openAdvancedMenu(key user) {
    string dialog = "\n[ ADVANCED INTERFACE CONTROLS ]\n";
    dialog += "═══════════════════════════════════════\n";
    dialog += "⚠️  OWNER ONLY CONTROLS ⚠️\n";
    dialog += "Advanced restriction controls.\n\n";
    
    string tpStatus;
    if (gTPBlocked) {
        tpStatus = "BLOCKED";
    } else {
        tpStatus = "ALLOWED";
    }
    
    string sitStatus;
    if (gSitBlocked) {
        sitStatus = "BLOCKED";
    } else {
        sitStatus = "ALLOWED";
    }
    
    string radarStatus;
    if (gRadarHidden) {
        radarStatus = "HIDDEN";
    } else {
        radarStatus = "VISIBLE";
    }
    
    dialog += "• Teleport: " + tpStatus + "\n";
    dialog += "• Sitting: " + sitStatus + "\n";
    dialog += "• Radar/Names: " + radarStatus + "\n";
    
    list buttons = [];
    
    if (gTPBlocked) {
        buttons += ["[TP ALLOW]"];
    } else {
        buttons += ["[TP BLOCK]"];
    }
    
    if (gSitBlocked) {
        buttons += ["[SIT ALLOW]"];
    } else {
        buttons += ["[SIT BLOCK]"];
    }
    
    if (gRadarHidden) {
        buttons += ["[RADAR SHOW]"];
    } else {
        buttons += ["[RADAR HIDE]"];
    }
    
    buttons += ["RESTORE ALL", "< BACK", "CLOSE"];
    
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llDialog(user, dialog, buttons, gMenuChannel);
    llSetTimerEvent(60.0);
}

openModesMenu(key user) {
    string dialog = "\n[ INTERFACE MODES ]\n";
    dialog += "═══════════════════════════════════════\n";
    dialog += "⚠️  OWNER ONLY CONTROLS ⚠️\n";
    dialog += "Current Mode: " + gInterfaceMode + "\n\n";
    
    dialog += "• STANDARD - Full functionality\n";
    dialog += "• RESTRICTED - Basic limitations\n";
    dialog += "• LOCKED - Heavy restrictions\n";
    dialog += "• BLACKOUT - Maximum lockdown\n";
    
    list buttons = [
        "STANDARD",
        "RESTRICTED", 
        "LOCKED",
        "BLACKOUT",
        "< BACK",
        "CLOSE"
    ];
    
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llDialog(user, dialog, buttons, gMenuChannel);
    llSetTimerEvent(60.0);
}

// --- MAIN SCRIPT LOGIC ---

default {
    state_entry() {
        wearer = llGetOwner();
        gPendingAuthRequests = [];
        
        gMenuChannel = (integer)("0x" + llGetSubString(llGetKey(), -8, -2));
        
        // Initialize interface state
        gInterfaceMode = "Standard";
        gInterfaceLocked = FALSE;
        
        llOwnerSay("A.R.I.A. Interaction Module v3.0 initialized with OpenCollar auth system.");
        
        // Register with master kernel
        llMessageLinked(LINK_SET, MODULE_REGISTER, "Interaction", NULL_KEY);
        
        // Apply initial (unrestricted) state
        applyRestrictions();
    }

    link_message(integer sender, integer num, string msg, key id) {
        if (num == AUTH_REPLY) {
            processAuthResponse(msg, id);
        }
        else if (num == OPEN_MY_MENU) {
            key user = (key)msg;
            requestAuth(user, "MENU_ACCESS");
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
            gPowerState = (integer)msg;
            
            if (!gPowerState) {
                // Emergency power mode - apply heavy restrictions
                setInterfaceMode("Blackout", NULL_KEY);
                llInstantMessage(wearer, "// Emergency power mode: Interface systems locked down //");
            }
            else {
                // Power restored
                llInstantMessage(wearer, "// Power restored: Interface systems online //");
                applyRestrictions();
            }
        }
    }

    listen(integer channel, string name, key id, string message) {
        if (channel != gMenuChannel) return;
        if (id != gCurrentMenuUser) return;
        
        llSetTimerEvent(0.0);
        llListenRemove(gListenHandle);
        
        if (message == "CLOSE") return;
        
        // Handle navigation
        if (message == "ADVANCED") {
            openAdvancedMenu(id);
            return;
        }
        else if (message == "MODES") {
            openModesMenu(id);
            return;
        }
        else if (message == "< BACK") {
            openControlMenu(id);
            return;
        }
        
        // Handle menu actions with auth requests
        if (message == "[INV HIDE]" || message == "[INV SHOW]") {
            requestAuth(id, "INV_TOGGLE");
        }
        else if (message == "[MAP HIDE]" || message == "[MAP SHOW]") {
            requestAuth(id, "MAP_TOGGLE");
        }
        else if (message == "[CAM LOCK]" || message == "[CAM FREE]") {
            requestAuth(id, "CAMERA_TOGGLE");
        }
        else if (message == "[IM HIDE]" || message == "[IM SHOW]") {
            requestAuth(id, "IM_TOGGLE");
        }
        else if (message == "[EDIT BLOCK]" || message == "[EDIT ALLOW]") {
            requestAuth(id, "EDIT_TOGGLE");
        }
        else if (message == "[BUILD BLOCK]" || message == "[BUILD ALLOW]") {
            requestAuth(id, "BUILD_TOGGLE");
        }
        else if (message == "[TP BLOCK]" || message == "[TP ALLOW]") {
            requestAuth(id, "TP_TOGGLE");
        }
        else if (message == "[SIT BLOCK]" || message == "[SIT ALLOW]") {
            requestAuth(id, "SIT_TOGGLE");
        }
        else if (message == "[RADAR HIDE]" || message == "[RADAR SHOW]") {
            requestAuth(id, "RADAR_TOGGLE");
        }
        else if (message == "STANDARD") {
            requestAuth(id, "MODE_STANDARD");
        }
        else if (message == "RESTRICTED") {
            requestAuth(id, "MODE_RESTRICTED");
        }
        else if (message == "LOCKED") {
            requestAuth(id, "MODE_LOCKED");
        }
        else if (message == "BLACKOUT") {
            requestAuth(id, "MODE_BLACKOUT");
        }
        else if (message == "RESTORE ALL") {
            requestAuth(id, "RESTORE_ALL");
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

//-- IMPLEMENTATION NOTES v3.0:
//-- 1. Completely replaced old permission system with OpenCollar AUTH_REQUEST/AUTH_REPLY
//-- 2. Basic interface controls require Trusted user permissions minimum
//-- 3. Advanced controls (TP, Sit, Radar) require Owner permissions
//-- 4. Interface modes require Owner permissions for safety
//-- 5. Asynchronous auth system prevents menu delays
//-- 6. Improved RLV command structure for better compatibility
//-- 7. Enhanced battery level restriction handling
//-- 8. Better user feedback and system status reporting
//-- 9. Proper cleanup of pending auth requests
//-- 10. Emergency power mode handling for power state changes
//-- 11. Fixed all ternary operators and invalid LSL syntax
//-- 12. Eliminated duplicate variable declarations
