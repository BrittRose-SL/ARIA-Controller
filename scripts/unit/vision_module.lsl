//-- A.R.I.A. Vision RLV Module (Add-on)
//-- Version 3.0 - OPENCOLLAR AUTH INTEGRATION
//-- September 12, 2025 - Refactored to use AUTH_REQUEST/AUTH_REPLY system
//-- CHANGES v3.0:
//--   - Removed synchronous getAccessLevel() and checkModuleAccess() functions
//--   - Implemented asynchronous AUTH_REQUEST/AUTH_REPLY protocol
//--   - Added pending auth request management for vision operations
//--   - Removed old permission variables and UPDATE_CONFIG handling
//--   - All menu functions now use async auth checks
//--   - Enhanced vision control security with granular actions

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
integer gIsBlindfolded = FALSE;
integer gHasOverlay = FALSE;
integer gIsCensored = FALSE;
integer gIsBlurred = FALSE;
integer gShowNamesBlocked = FALSE;

// --- OVERLAY MANAGEMENT ---
string gCurrentOverlay = "";
list gAvailableOverlays = [
    "aria_hud_overlay",
    "aria_tactical_overlay", 
    "aria_night_vision",
    "aria_glitch_overlay",
    "aria_static_overlay"
];

// --- PERMISSION MANAGEMENT ---
list gNameWhitelist;
list gNameBlacklist;

// --- ASYNCHRONOUS AUTH SYSTEM ---
list gPendingAuthRequests;  // Format: [requestId, userKey, action, timestamp, ...]
integer gNextRequestId = 1;
integer gAuthTimeoutSeconds = 30;

// --- MENU VARIABLES ---
key gCurrentMenuUser;
string gCurrentMenuContext = ""; // Track which menu context we're in

// --- AUTH MANAGEMENT FUNCTIONS ---

// Request auth for a specific vision action
requestVisionAuth(key user, string action) {
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
processVisionAuth(key user, integer authLevel, string action) {
    // Find and remove the pending request
    integer idx = llListFindList(gPendingAuthRequests, [user]);
    if (idx == -1) return; // Request not found
    
    string originalAction = llList2String(gPendingAuthRequests, idx + 1);
    gPendingAuthRequests = llDeleteSubList(gPendingAuthRequests, idx - 1, idx + 2);
    
    // Vision operations require trusted access minimum
    if (authLevel >= CMD_TRUSTED) {
        executeVisionAction(user, action);
    } else {
        llInstantMessage(user, "Access denied. Trusted User permissions required for Vision RLV Module.");
    }
}

// Execute the requested vision action after auth confirmation
executeVisionAction(key user, string action) {
    if (action == "VISION_MENU") {
        openControlMenu(user);
    }
    else if (action == "TOGGLE_BLINDFOLD") {
        gIsBlindfolded = !gIsBlindfolded;
        if (gIsBlindfolded) {
            llInstantMessage(g_kWearer, "// Visual sensor array offline. Vision restricted. //");
        } else {
            llInstantMessage(g_kWearer, "// Visual sensor array online. //");
        }
        applyRestrictions();
        llInstantMessage(user, "Blindfold setting updated.");
        openControlMenu(user);
    }
    else if (action == "TOGGLE_BLUR") {
        gIsBlurred = !gIsBlurred;
        if (gIsBlurred) {
            llInstantMessage(g_kWearer, "// Visual clarity degraded. Image processing compromised. //");
        } else {
            llInstantMessage(g_kWearer, "// Visual clarity restored. //");
        }
        applyRestrictions();
        llInstantMessage(user, "Blur setting updated.");
        openControlMenu(user);
    }
    else if (action == "TOGGLE_CENSOR") {
        gIsCensored = !gIsCensored;
        if (gIsCensored) {
            llInstantMessage(g_kWearer, "// Content filtering engaged. Adult content censored. //");
        } else {
            llInstantMessage(g_kWearer, "// Content filtering disengaged. //");
        }
        applyRestrictions();
        llInstantMessage(user, "Censor setting updated.");
        openControlMenu(user);
    }
    else if (action == "TOGGLE_NAMES") {
        gShowNamesBlocked = !gShowNamesBlocked;
        if (gShowNamesBlocked) {
            llInstantMessage(g_kWearer, "// Identity recognition offline. Names obscured. //");
        } else {
            llInstantMessage(g_kWearer, "// Identity recognition online. //");
        }
        applyRestrictions();
        llInstantMessage(user, "Name visibility setting updated.");
        openControlMenu(user);
    }
    else if (action == "OVERLAY_MENU") {
        gCurrentMenuContext = "OVERLAY";
        openOverlayMenu(user);
    }
    else if (action == "NAME_PERMS_MENU") {
        gCurrentMenuContext = "NAME_PERMS";
        openNamePermissionsMenu(user);
    }
    else if (action == "CLEAR_ALL") {
        gIsBlindfolded = FALSE;
        gIsBlurred = FALSE;
        gIsCensored = FALSE;
        gShowNamesBlocked = FALSE;
        gHasOverlay = FALSE;
        gCurrentOverlay = "";
        llInstantMessage(g_kWearer, "// All visual restrictions cleared. Full optical systems online. //");
        applyRestrictions();
        llInstantMessage(user, "All vision restrictions cleared.");
        openControlMenu(user);
    }
    else if (action == "BLACKOUT_ALL") {
        gIsBlindfolded = TRUE;
        gIsBlurred = TRUE;
        gIsCensored = TRUE;
        gShowNamesBlocked = TRUE;
        llInstantMessage(g_kWearer, "// TOTAL VISUAL BLACKOUT: All optical systems offline. //");
        applyRestrictions();
        llInstantMessage(user, "Total vision blackout activated.");
        openControlMenu(user);
    }
    else if (action == "CLEAR_OVERLAY") {
        gCurrentOverlay = "";
        gHasOverlay = FALSE;
        llInstantMessage(user, "Visual overlay cleared.");
        openOverlayMenu(user);
    }
    else if (action == "CLEAR_WHITELIST") {
        gNameWhitelist = [];
        llInstantMessage(user, "Name visibility whitelist cleared.");
        openNamePermissionsMenu(user);
    }
    else if (action == "CLEAR_BLACKLIST") {
        gNameBlacklist = [];
        llInstantMessage(user, "Name visibility blacklist cleared.");
        openNamePermissionsMenu(user);
    }
    else if (action == "ADD_ADMIN_TO_WL") {
        if (llListFindList(gNameWhitelist, [user]) == -1) {
            gNameWhitelist += [user];
            llInstantMessage(user, "You have been added to the name visibility whitelist.");
        } else {
            llInstantMessage(user, "You are already on the name visibility whitelist.");
        }
        openNamePermissionsMenu(user);
    }
    else if (action == "SHOW_LISTS") {
        showNameLists(user);
        openNamePermissionsMenu(user);
    }
    else if (llSubStringIndex(action, "OVERLAY:") == 0) {
        // Handle overlay selection: "OVERLAY:overlay_name"
        string overlayName = llGetSubString(action, 8, -1);
        if (llGetInventoryType(overlayName) == INVENTORY_TEXTURE) {
            gCurrentOverlay = overlayName;
            gHasOverlay = TRUE;
            llInstantMessage(user, "Overlay '" + overlayName + "' applied.");
        } else {
            llInstantMessage(user, "Overlay texture '" + overlayName + "' not found in inventory.");
        }
        openOverlayMenu(user);
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

// --- VISION MODULE FUNCTIONS ---

// Apply current vision restrictions based on module state and battery level
applyRestrictions() {
    if (!gPowerState) {
        // When powered off, remove all restrictions
        llOwnerSay("@camunlock=y,shownames=y,viewnote=y,edit=y");
        return;
    }
    
    string restrictions = "";
    
    // Apply user-set restrictions
    if (gIsBlindfolded) {
        restrictions += "@viewnote=n,";
    } else {
        restrictions += "@viewnote=y,";
    }
    
    if (gIsBlurred) {
        restrictions += "@setcam_blur=10,";
    } else {
        restrictions += "@setcam_blur=0,";
    }
    
    if (gIsCensored) {
        restrictions += "@edit=n,";
    } else {
        restrictions += "@edit=y,";
    }
    
    if (gShowNamesBlocked) {
        restrictions += "@shownames=n,";
    } else {
        restrictions += "@shownames=y,";
    }
    
    // Battery-based restrictions override user settings when critical
    if (gBatteryLevel <= 5.0) {
        restrictions += "@viewnote=n,shownames=n,edit=n,";
        llInstantMessage(g_kWearer, "// CRITICAL POWER: All visual systems offline. //");
    } else if (gBatteryLevel <= 10.0) {
        restrictions += "@viewnote=n,edit=n,";
        llInstantMessage(g_kWearer, "// LOW POWER: Visual display systems restricted. //");
    } else if (gBatteryLevel <= 15.0) {
        restrictions += "@edit=n,";
        llInstantMessage(g_kWearer, "// WARNING: Advanced visual functions disabled to preserve power. //");
    }
    
    // Remove trailing comma and apply
    if (llStringLength(restrictions) > 0) {
        restrictions = llGetSubString(restrictions, 0, -2);
        llOwnerSay(restrictions);
    }
}

// Build and display the main vision control menu
openControlMenu(key user) {
    gCurrentMenuUser = user;
    gCurrentMenuContext = "MAIN";
    gMenuChannel = (integer)("0x" + llGetSubString((string)user, -7, -1));
    
    string dialog = "\n[ VISION RLV CONTROL ]\n\n";
    dialog += "Battery: " + (string)((integer)gBatteryLevel) + "%\n";
    dialog += "Power: " + (string)gPowerState + "\n\n";
    
    // Status indicators
    string blindStatus = "OFF";
    string blurStatus = "OFF";
    string censorStatus = "OFF";
    string nameStatus = "OFF";
    string overlayStatus = "NONE";
    
    if (gIsBlindfolded) blindStatus = "ON";
    if (gIsBlurred) blurStatus = "ON";
    if (gIsCensored) censorStatus = "ON";
    if (gShowNamesBlocked) nameStatus = "ON";
    if (gHasOverlay) overlayStatus = "ACTIVE";
    
    dialog += "Blindfold: " + blindStatus + "\n";
    dialog += "Blur: " + blurStatus + "\n";
    dialog += "Censor: " + censorStatus + "\n";
    dialog += "Hide Names: " + nameStatus + "\n";
    dialog += "Overlay: " + overlayStatus + "\n\n";
    
    // Battery warnings
    if (gBatteryLevel <= 15.0) {
        dialog += "⚠️ LOW POWER RESTRICTIONS ACTIVE\n\n";
    }
    
    dialog += "Select option to toggle:";
    
    list buttons = [
        "[BLIND: " + blindStatus + "]",
        "[BLUR: " + blurStatus + "]", 
        "[CENSOR: " + censorStatus + "]",
        "[NAMES: " + nameStatus + "]",
        "Overlays",
        "Name Perms",
        "CLEAR ALL",
        "BLACKOUT",
        "Close"
    ];
    
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llDialog(user, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

// Build and display the overlay selection menu
openOverlayMenu(key user) {
    string dialog = "\n[ VISUAL OVERLAYS ]\n\n";
    dialog += "Current: ";
    if (gHasOverlay) {
        dialog += gCurrentOverlay;
    } else {
        dialog += "None";
    }
    dialog += "\n\nAvailable overlays:";
    
    list buttons = [];
    string buttonName;
    string overlayName;
    integer i;
    
    for (i = 0; i < llGetListLength(gAvailableOverlays) && i < 8; i++) {
        overlayName = llList2String(gAvailableOverlays, i);
        if (llGetInventoryType(overlayName) == INVENTORY_TEXTURE) {
            buttonName = overlayName;
            if (llStringLength(buttonName) > 12) {
                buttonName = llGetSubString(buttonName, 0, 11);
            }
            buttons += [buttonName];
        }
    }
    
    buttons += ["Clear Overlay", "-Back-"];
    
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llDialog(user, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

// Build and display the name permissions menu
openNamePermissionsMenu(key user) {
    string dialog = "\n[ NAME VISIBILITY PERMISSIONS ]\n";
    dialog += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
    dialog += "Whitelist (" + (string)llGetListLength(gNameWhitelist) + " users)\n";
    dialog += "Blacklist (" + (string)llGetListLength(gNameBlacklist) + " users)\n\n";
    dialog += "Note: Use main Permissions module\nto manage detailed user lists.";
    
    list buttons = [
        "Clear Whitelist",
        "Clear Blacklist", 
        "Add Admin to WL",
        "Show Lists",
        "-Back-"
    ];
    
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llDialog(user, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

// Show detailed name lists to user
showNameLists(key user) {
    string report = "\nName Visibility Whitelist:\n";
    integer i;
    if (llGetListLength(gNameWhitelist) == 0) {
        report += "  (empty)\n";
    } else {
        for (i = 0; i < llGetListLength(gNameWhitelist) && i < 5; i++) {
            report += "  " + llKey2Name((key)llList2String(gNameWhitelist, i)) + "\n";
        }
        if (llGetListLength(gNameWhitelist) > 5) {
            report += "  ... and " + (string)(llGetListLength(gNameWhitelist) - 5) + " more\n";
        }
    }
    
    report += "\nName Visibility Blacklist:\n";
    if (llGetListLength(gNameBlacklist) == 0) {
        report += "  (empty)";
    } else {
        for (i = 0; i < llGetListLength(gNameBlacklist) && i < 5; i++) {
            report += "  " + llKey2Name((key)llList2String(gNameBlacklist, i)) + "\n";
        }
        if (llGetListLength(gNameBlacklist) > 5) {
            report += "  ... and " + (string)(llGetListLength(gNameBlacklist) - 5) + " more";
        }
    }
    
    llInstantMessage(user, report);
}

// --- MAIN SCRIPT LOGIC ---
default {
    state_entry() {
        g_kWearer = llGetOwner();
        gPendingAuthRequests = [];
        
        gMenuChannel = (integer)("0x" + llGetSubString(llGetKey(), -8, -2));
        
        // Initialize with safe defaults
        gIsBlindfolded = FALSE;
        gHasOverlay = FALSE;
        gIsCensored = FALSE;
        gIsBlurred = FALSE;
        gShowNamesBlocked = FALSE;
        gCurrentOverlay = "";
        
        // Initialize permission lists
        gNameWhitelist = [];
        gNameBlacklist = [];
        
        // Register with main module
        llMessageLinked(LINK_SET, MODULE_REGISTER, "Vision RLV", NULL_KEY);
        
        // Apply initial (unrestricted) state
        applyRestrictions();
        
        llOwnerSay("Vision RLV Module v3.0 initialized with OpenCollar auth system.");
    }

    link_message(integer sender, integer num, string msg, key id) {
        if (num == AUTH_REPLY) {
            // Parse auth reply: "AuthReply|userKey|authLevel"
            list parts = llParseString2List(msg, ["|"], []);
            if (llList2String(parts, 0) == "AuthReply") {
                key user = (key)llList2String(parts, 1);
                integer authLevel = (integer)llList2String(parts, 2);
                string originalAction = (string)id; // The action from AUTH_REQUEST
                
                processVisionAuth(user, authLevel, originalAction);
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
                llOwnerSay("@camunlock=y,shownames=y,viewnote=y,edit=y");
            }
        }
        else if (num == OPEN_MY_MENU) {
            key user = (key)msg;
            // Request auth for vision menu access
            requestVisionAuth(user, "VISION_MENU");
        }
    }

    listen(integer chan, string name, key id, string msg) {
        if (chan != gMenuChannel) return;
        
        llListenRemove(gListenHandle);
        
        if (msg == "Close") {
            llInstantMessage(id, "Vision RLV module menu closed.");
            return;
        }
        
        if (msg == "-Back-") {
            if (gCurrentMenuContext == "OVERLAY" || gCurrentMenuContext == "NAME_PERMS") {
                requestVisionAuth(id, "VISION_MENU");
            }
            return;
        }

        // Handle menu actions based on context
        if (gCurrentMenuContext == "MAIN") {
            // Main menu actions
            if (llSubStringIndex(msg, "[BLIND:") != -1) {
                requestVisionAuth(id, "TOGGLE_BLINDFOLD");
            }
            else if (llSubStringIndex(msg, "[BLUR:") != -1) {
                requestVisionAuth(id, "TOGGLE_BLUR");
            }
            else if (llSubStringIndex(msg, "[CENSOR:") != -1) {
                requestVisionAuth(id, "TOGGLE_CENSOR");
            }
            else if (llSubStringIndex(msg, "[NAMES:") != -1) {
                requestVisionAuth(id, "TOGGLE_NAMES");
            }
            else if (msg == "Overlays") {
                requestVisionAuth(id, "OVERLAY_MENU");
            }
            else if (msg == "Name Perms") {
                requestVisionAuth(id, "NAME_PERMS_MENU");
            }
            else if (msg == "CLEAR ALL") {
                requestVisionAuth(id, "CLEAR_ALL");
            }
            else if (msg == "BLACKOUT") {
                requestVisionAuth(id, "BLACKOUT_ALL");
            }
        }
        else if (gCurrentMenuContext == "OVERLAY") {
            // Overlay menu actions
            if (msg == "Clear Overlay") {
                requestVisionAuth(id, "CLEAR_OVERLAY");
            }
            else {
                // Check if it's an overlay selection
                integer i;
                for (i = 0; i < llGetListLength(gAvailableOverlays); i++) {
                    string overlayName = llList2String(gAvailableOverlays, i);
                    string buttonName = overlayName;
                    if (llStringLength(buttonName) > 12) {
                        buttonName = llGetSubString(buttonName, 0, 11);
                    }
                    if (msg == buttonName) {
                        requestVisionAuth(id, "OVERLAY:" + overlayName);
                        return;
                    }
                }
            }
        }
        else if (gCurrentMenuContext == "NAME_PERMS") {
            // Name permissions menu actions
            if (msg == "Clear Whitelist") {
                requestVisionAuth(id, "CLEAR_WHITELIST");
            }
            else if (msg == "Clear Blacklist") {
                requestVisionAuth(id, "CLEAR_BLACKLIST");
            }
            else if (msg == "Add Admin to WL") {
                requestVisionAuth(id, "ADD_ADMIN_TO_WL");
            }
            else if (msg == "Show Lists") {
                requestVisionAuth(id, "SHOW_LISTS");
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
