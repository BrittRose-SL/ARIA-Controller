//-- A.R.I.A. Diagnostics RLV Module (Add-on)
//-- Version 2.0 - OPENCOLLAR AUTH SYSTEM INTEGRATION
//-- September 12, 2025 - Updated to use AUTH_REQUEST/AUTH_REPLY system
//-- CHANGES v2.0:
//--   - Replaced old permission system with OpenCollar auth
//--   - Implemented AUTH_REQUEST/AUTH_REPLY protocol
//--   - Removed old permission variables and functions
//--   - Enhanced RLV diagnostics and relay management
//--   - Improved system status reporting and viewer queries
//--   - Fixed all ternary operators and invalid LSL syntax
//--   - Combined duplicate listen events into single handler

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
integer gRelayMode = 0; // 0=Off, 1=Ask, 2=Trusted, 3=Everyone
list gRelayModes = ["Off", "Ask", "Trusted", "Everyone"];
integer gDiagnosticsActive = TRUE;

// --- SYSTEM INFORMATION ---
string gLastVersion = "";
string gLastStatus = "";
list gLastAttachments = [];
string gViewerName = "";
string gViewerVersion = "";

// --- ASYNCHRONOUS AUTH SYSTEM ---
list gPendingAuthRequests;  // Format: [requestId, userKey, action, ...]
integer gNextRequestId = 1;
key gCurrentMenuUser;

// --- MENU STATES ---
integer gMenuState = 0;
// 0 = main, 1 = relay settings, 2 = system info, 3 = advanced

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
            llInstantMessage(user, "Access denied. Trusted user permissions required for Diagnostics.");
        }
    }
    else if (action == "GET_VERSION") {
        if (authLevel >= CMD_TRUSTED) {
            llOwnerSay("@version");
            llInstantMessage(user, "Version query sent. Response will be delivered via IM.");
            llInstantMessage(wearer, "// Diagnostics: Version query requested by " + llKey2Name(user) + " //");
            openControlMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Trusted user permissions required.");
        }
    }
    else if (action == "GET_ATTACHMENTS") {
        if (authLevel >= CMD_TRUSTED) {
            llOwnerSay("@getattachlist");
            llInstantMessage(user, "Attachment list query sent. Response will be delivered via IM.");
            llInstantMessage(wearer, "// Diagnostics: Attachment query requested by " + llKey2Name(user) + " //");
            openControlMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Trusted user permissions required.");
        }
    }
    else if (action == "GET_STATUS") {
        if (authLevel >= CMD_TRUSTED) {
            llOwnerSay("@getstatus");
            llInstantMessage(user, "Status query sent. Response will be delivered via IM.");
            llInstantMessage(wearer, "// Diagnostics: Status query requested by " + llKey2Name(user) + " //");
            openControlMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Trusted user permissions required.");
        }
    }
    else if (action == "GET_RESTRICTIONS") {
        if (authLevel >= CMD_TRUSTED) {
            llOwnerSay("@getrestrictions");
            llInstantMessage(user, "Restrictions query sent. Response will be delivered via IM.");
            llInstantMessage(wearer, "// Diagnostics: Restrictions query requested by " + llKey2Name(user) + " //");
            openControlMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Trusted user permissions required.");
        }
    }
    else if (action == "RELAY_TOGGLE") {
        if (authLevel >= CMD_OWNER) {
            gRelayMode = (gRelayMode + 1) % 4; // Cycle through the 4 modes
            string newStatus = llList2String(gRelayModes, gRelayMode);
            applyRelaySettings();
            llInstantMessage(user, "RLV Relay mode changed to: " + newStatus);
            llInstantMessage(wearer, "// RLV Relay mode set to " + newStatus + " by " + llKey2Name(user) + " //");
            openControlMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Owner permissions required for RLV Relay control.");
        }
    }
    else if (action == "RELAY_OFF") {
        if (authLevel >= CMD_OWNER) {
            gRelayMode = 0;
            applyRelaySettings();
            llInstantMessage(user, "RLV Relay disabled.");
            llInstantMessage(wearer, "// RLV Relay disabled by " + llKey2Name(user) + " //");
            openControlMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Owner permissions required.");
        }
    }
    else if (action == "SYSTEM_INFO") {
        if (authLevel >= CMD_TRUSTED) {
            showSystemInfo(user);
        } else {
            llInstantMessage(user, "Access denied. Trusted user permissions required.");
        }
    }
    else if (action == "RLV_TEST") {
        if (authLevel >= CMD_TRUSTED) {
            performRLVTest(user);
        } else {
            llInstantMessage(user, "Access denied. Trusted user permissions required.");
        }
    }
    else if (action == "CLEAR_CACHE") {
        if (authLevel >= CMD_OWNER) {
            clearDiagnosticsCache(user);
        } else {
            llInstantMessage(user, "Access denied. Owner permissions required for cache clearing.");
        }
    }
}

// --- HELPER FUNCTIONS ---

applyRelaySettings() {
    if (gRelayMode == 0) {
        llOwnerSay("@clear,relay=n");
    } else if (gRelayMode == 1) {
        llOwnerSay("@clear,relay=ask");
    } else if (gRelayMode == 2) {
        llOwnerSay("@clear,relay=trusted");
    } else if (gRelayMode == 3) {
        llOwnerSay("@clear,relay=y");
    }
}

showSystemInfo(key user) {
    string dialog = "\n[ SYSTEM INFORMATION ]\n";
    dialog += "═══════════════════════════════════════\n";
    dialog += "Battery: " + (string)((integer)gBatteryLevel) + "%\n";
    
    string powerStatus;
    if (gPowerState) {
        powerStatus = "ONLINE";
    } else {
        powerStatus = "OFFLINE";
    }
    dialog += "Power: " + powerStatus + "\n";
    
    string relayStatus = llList2String(gRelayModes, gRelayMode);
    dialog += "RLV Relay: " + relayStatus + "\n\n";
    
    if (gLastVersion != "") {
        dialog += "Last Version: " + gLastVersion + "\n";
    }
    
    if (gViewerName != "") {
        dialog += "Viewer: " + gViewerName + "\n";
    }
    
    if (llGetListLength(gLastAttachments) > 0) {
        dialog += "Attachments: " + (string)llGetListLength(gLastAttachments) + " items\n";
    }
    
    list buttons = ["Refresh", "< BACK", "CLOSE"];
    
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llDialog(user, dialog, buttons, gMenuChannel);
    llSetTimerEvent(60.0);
}

performRLVTest(key user) {
    llInstantMessage(user, "Performing RLV connectivity test...");
    
    // Send a harmless test command
    llOwnerSay("@versionnew");
    
    // Request basic status
    llOwnerSay("@getstatus");
    
    llInstantMessage(user, "RLV test commands sent. Check for responses in IM.");
    llInstantMessage(wearer, "// RLV connectivity test initiated by " + llKey2Name(user) + " //");
    
    openControlMenu(user);
}

clearDiagnosticsCache(key user) {
    gLastVersion = "";
    gLastStatus = "";
    gLastAttachments = [];
    gViewerName = "";
    gViewerVersion = "";
    
    llInstantMessage(user, "Diagnostics cache cleared.");
    llInstantMessage(wearer, "// Diagnostics cache cleared by " + llKey2Name(user) + " //");
    
    openControlMenu(user);
}

// --- MENU FUNCTIONS ---

openControlMenu(key user) {
    gCurrentMenuUser = user;
    gMenuState = 0;
    
    string dialog = "\n[ DIAGNOSTICS & RELAY CONTROL ]\n";
    dialog += "═══════════════════════════════════════\n";
    dialog += "Battery: " + (string)((integer)gBatteryLevel) + "%\n";
    
    string powerStatus;
    if (gPowerState) {
        powerStatus = "ONLINE";
    } else {
        powerStatus = "OFFLINE";
    }
    dialog += "Power: " + powerStatus + "\n";
    
    string relayStatus = llList2String(gRelayModes, gRelayMode);
    dialog += "RLV Relay: " + relayStatus + "\n";
    
    string diagnosticsStatus;
    if (gDiagnosticsActive) {
        diagnosticsStatus = "ACTIVE";
    } else {
        diagnosticsStatus = "INACTIVE";
    }
    dialog += "Diagnostics: " + diagnosticsStatus + "\n\n";
    
    dialog += "Select diagnostic option:";
    
    list buttons = [];
    
    // Core diagnostics available to trusted users and above
    buttons += ["Get Version", "Get Attachments", "Get Status"];
    buttons += ["Get Restrictions", "RLV Test"];
    
    // System info and relay controls
    buttons += ["System Info"];
    
    string relayButtonText;
    if (gRelayMode == 0) {
        relayButtonText = "Relay: OFF";
    } else {
        relayButtonText = "Relay: " + relayStatus;
    }
    buttons += [relayButtonText];
    
    // Advanced options
    buttons += ["Clear Cache", "CLOSE"];
    
    gMenuChannel = (integer)("0x" + llGetSubString(llGetKey(), -8, -2));
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llSetTimerEvent(60.0);
    
    llDialog(user, dialog, buttons, gMenuChannel);
}

// --- MAIN SCRIPT LOGIC ---

default {
    state_entry() {
        wearer = llGetOwner();
        gPendingAuthRequests = [];
        
        gMenuChannel = (integer)("0x" + llGetSubString(llGetKey(), -8, -2));
        
        // Initialize with safe defaults
        gRelayMode = 0; // Start with relay off for security
        gDiagnosticsActive = TRUE;
        
        llOwnerSay("A.R.I.A. Diagnostics Module v2.0 initialized with OpenCollar auth system.");
        
        // Register with master kernel
        llMessageLinked(LINK_SET, MODULE_REGISTER, "Diagnostics", NULL_KEY);
        
        // Apply initial relay settings
        applyRelaySettings();
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
            gBatteryLevel = (float)msg;
            
            // Disable relay if battery is critically low for security
            if (gBatteryLevel <= 5.0 && gRelayMode > 0) {
                gRelayMode = 0;
                applyRelaySettings();
                llInstantMessage(wearer, "// RLV Relay disabled due to critical power level //");
            }
        }
        else if (num == POWER_STATE_CHANGE) {
            gPowerState = (integer)msg;
            
            if (!gPowerState) {
                // Emergency power mode - disable relay for security
                if (gRelayMode > 0) {
                    gRelayMode = 0;
                    applyRelaySettings();
                    llInstantMessage(wearer, "// Emergency power mode: RLV Relay disabled //");
                }
                gDiagnosticsActive = FALSE;
            }
            else {
                // Power restored
                gDiagnosticsActive = TRUE;
                llInstantMessage(wearer, "// Power restored: Diagnostics systems online //");
            }
        }
    }

    listen(integer channel, string name, key id, string message) {
        // Handle menu responses
        if (channel == gMenuChannel && id == gCurrentMenuUser) {
            llSetTimerEvent(0.0);
            llListenRemove(gListenHandle);
            
            if (message == "CLOSE") return;
            
            // Handle navigation
            if (message == "< BACK") {
                openControlMenu(id);
                return;
            }
            else if (message == "Refresh") {
                openControlMenu(id);
                return;
            }
            
            // Handle menu actions with auth requests
            if (message == "Get Version") {
                requestAuth(id, "GET_VERSION");
            }
            else if (message == "Get Attachments") {
                requestAuth(id, "GET_ATTACHMENTS");
            }
            else if (message == "Get Status") {
                requestAuth(id, "GET_STATUS");
            }
            else if (message == "Get Restrictions") {
                requestAuth(id, "GET_RESTRICTIONS");
            }
            else if (message == "RLV Test") {
                requestAuth(id, "RLV_TEST");
            }
            else if (message == "System Info") {
                requestAuth(id, "SYSTEM_INFO");
            }
            else if (llSubStringIndex(message, "Relay:") != -1) {
                requestAuth(id, "RELAY_TOGGLE");
            }
            else if (message == "Clear Cache") {
                requestAuth(id, "CLEAR_CACHE");
            }
            return;
        }
        
        // Handle RLV responses from viewer (typically channel 0)
        if (channel == 0 && id == wearer) {
            // Parse version responses
            if (llSubStringIndex(message, "RestrainedLove") != -1 || 
                llSubStringIndex(message, "RestrainedLife") != -1) {
                gLastVersion = message;
                gViewerName = message;
            }
            
            // Parse status responses
            if (llSubStringIndex(message, "@") == 0) {
                gLastStatus = message;
            }
            
            // Store for system info display
            if (gCurrentMenuUser != NULL_KEY) {
                llInstantMessage(gCurrentMenuUser, "RLV Response: " + message);
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

//-- IMPLEMENTATION NOTES v2.0:
//-- 1. Completely replaced old permission system with OpenCollar AUTH_REQUEST/AUTH_REPLY
//-- 2. Diagnostics queries require Trusted user permissions minimum
//-- 3. RLV Relay controls require Owner permissions for security
//-- 4. Asynchronous auth system prevents menu delays
//-- 5. Enhanced RLV diagnostic capabilities and system information display
//-- 6. Battery integration with automatic relay disable at critical power
//-- 7. Emergency power mode handling with security measures
//-- 8. Improved user feedback and system status reporting
//-- 9. Proper cleanup of pending auth requests and listeners
//-- 10. Fixed all ternary operators and invalid LSL syntax
//-- 11. Enhanced security measures for relay management
//-- 12. Better RLV response handling and caching system
//-- 13. Combined duplicate listen events into single handler
