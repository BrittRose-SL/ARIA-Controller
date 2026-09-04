//-- A.R.I.A. Mobility RLV Module (Add-on)
//-- Version 3.1 - OPENCOLLAR AUTH SYSTEM INTEGRATION
//-- September 12, 2025 - Updated to use AUTH_REQUEST/AUTH_REPLY system
//-- CHANGES v3.1:
//--   - Corrected auth-level comparisons to match the OpenCollar ordering
//-- CHANGES v3.0: 
//--   - Replaced old permission system with OpenCollar auth
//--   - Implemented AUTH_REQUEST/AUTH_REPLY protocol
//--   - Removed old permission variables and functions
//--   - Fixed RLV commands, improved movement restrictions
//--   - Enhanced teleport whitelist/blacklist management
//--   - Improved user feedback and restriction tracking
//--   - Fixed all ternary operators and invalid LSL syntax

// --- LINKED MESSAGE CODES ---
integer UPDATE_BATTERY = 101;
integer UPDATE_CONFIG = 102;
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
integer gIsGrounded = FALSE;      // No flying
integer gIsFrozen = FALSE;        // No movement at all
integer gIsTPBlocked = FALSE;     // No teleporting
integer gIsJumpBlocked = FALSE;   // No jumping
integer gIsSitBlocked = FALSE;    // No sitting
integer gIsRunBlocked = FALSE;    // Walking only

// --- TELEPORT PERMISSION MANAGEMENT ---
list gTPWhitelist = [];
list gTPBlacklist = [];

// --- RESTRICTION TRACKING ---
integer gRestrictionsActive = FALSE;
string gLastActionBy = "";

// --- ASYNCHRONOUS AUTH SYSTEM ---
list gPendingAuthRequests;  // Format: [requestId, userKey, action, ...]
integer gNextRequestId = 1;
key gCurrentMenuUser;

// --- MENU STATES ---
integer gMenuState = 0;
// 0 = main, 1 = movement restrictions, 2 = teleport management, 3 = advanced

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
        if (authLevel <= CMD_TRUSTED) {
            openControlMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Trusted user permissions required for Mobility controls.");
        }
    }
    else if (action == "FREEZE_TOGGLE") {
        if (authLevel <= CMD_TRUSTED) {
            gIsFrozen = !gIsFrozen;
            gLastActionBy = llKey2Name(user);
            applyRestrictions();
            string status;
            if (gIsFrozen) {
                status = "enabled";
            } else {
                status = "disabled";
            }
            llInstantMessage(user, "Movement freeze " + status + ".");
            llInstantMessage(wearer, "// Movement systems " + status + " by " + llKey2Name(user) + " //");
            openControlMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Trusted user permissions required.");
        }
    }
    else if (action == "GROUND_TOGGLE") {
        if (authLevel <= CMD_TRUSTED) {
            gIsGrounded = !gIsGrounded;
            gLastActionBy = llKey2Name(user);
            applyRestrictions();
            string status;
            if (gIsGrounded) {
                status = "enabled";
            } else {
                status = "disabled";
            }
            llInstantMessage(user, "Flight restrictions " + status + ".");
            llInstantMessage(wearer, "// Flight systems " + status + " by " + llKey2Name(user) + " //");
            openControlMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Trusted user permissions required.");
        }
    }
    else if (action == "TP_TOGGLE") {
        if (authLevel <= CMD_TRUSTED) {
            gIsTPBlocked = !gIsTPBlocked;
            gLastActionBy = llKey2Name(user);
            applyRestrictions();
            string status;
            if (gIsTPBlocked) {
                status = "disabled";
            } else {
                status = "enabled";
            }
            llInstantMessage(user, "Teleport access " + status + ".");
            llInstantMessage(wearer, "// Teleport systems " + status + " by " + llKey2Name(user) + " //");
            openControlMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Trusted user permissions required.");
        }
    }
    else if (action == "JUMP_TOGGLE") {
        if (authLevel <= CMD_TRUSTED) {
            gIsJumpBlocked = !gIsJumpBlocked;
            gLastActionBy = llKey2Name(user);
            applyRestrictions();
            string status;
            if (gIsJumpBlocked) {
                status = "disabled";
            } else {
                status = "enabled";
            }
            llInstantMessage(user, "Jump capability " + status + ".");
            llInstantMessage(wearer, "// Jump systems " + status + " by " + llKey2Name(user) + " //");
            openControlMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Trusted user permissions required.");
        }
    }
    else if (action == "SIT_TOGGLE") {
        if (authLevel <= CMD_TRUSTED) {
            gIsSitBlocked = !gIsSitBlocked;
            gLastActionBy = llKey2Name(user);
            applyRestrictions();
            string status;
            if (gIsSitBlocked) {
                status = "disabled";
            } else {
                status = "enabled";
            }
            llInstantMessage(user, "Sitting capability " + status + ".");
            llInstantMessage(wearer, "// Sitting systems " + status + " by " + llKey2Name(user) + " //");
            openControlMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Trusted user permissions required.");
        }
    }
    else if (action == "RUN_TOGGLE") {
        if (authLevel <= CMD_TRUSTED) {
            gIsRunBlocked = !gIsRunBlocked;
            gLastActionBy = llKey2Name(user);
            applyRestrictions();
            string status;
            if (gIsRunBlocked) {
                status = "disabled";
            } else {
                status = "enabled";
            }
            llInstantMessage(user, "Running capability " + status + ".");
            llInstantMessage(wearer, "// Running systems " + status + " by " + llKey2Name(user) + " //");
            openControlMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Trusted user permissions required.");
        }
    }
    else if (action == "RELEASE_ALL") {
        if (authLevel <= CMD_TRUSTED) {
            releaseAllRestrictions(user);
        } else {
            llInstantMessage(user, "Access denied. Trusted user permissions required.");
        }
    }
    else if (action == "LOCKDOWN") {
        if (authLevel <= CMD_OWNER) {
            applyLockdown(user);
        } else {
            llInstantMessage(user, "Access denied. Owner permissions required for lockdown.");
        }
    }
}

// --- RLV RESTRICTION FUNCTIONS ---

applyRestrictions() {
    gRestrictionsActive = FALSE;
    
    // Clear all restrictions first
    llOwnerSay("@clear");
    
    // Apply current restrictions based on state
    if (gIsFrozen) {
        llOwnerSay("@temprun=n,alwaysrun=n,fly=n,jump=n,sit=n,sittp=n,tplocal=n,tplure=n,tplm=n");
        gRestrictionsActive = TRUE;
    }
    
    if (gIsGrounded && !gIsFrozen) {
        llOwnerSay("@fly=n");
        gRestrictionsActive = TRUE;
    }
    
    if (gIsTPBlocked && !gIsFrozen) {
        llOwnerSay("@tplocal=n,tplure=n,tplm=n");
        gRestrictionsActive = TRUE;
    }
    
    if (gIsJumpBlocked && !gIsFrozen) {
        llOwnerSay("@jump=n");
        gRestrictionsActive = TRUE;
    }
    
    if (gIsSitBlocked && !gIsFrozen) {
        llOwnerSay("@sit=n,sittp=n");
        gRestrictionsActive = TRUE;
    }
    
    if (gIsRunBlocked && !gIsFrozen) {
        llOwnerSay("@temprun=n,alwaysrun=n");
        gRestrictionsActive = TRUE;
    }
    
    // Apply battery level restrictions
    if (gBatteryLevel <= 5.0) {
        llOwnerSay("@fly=n,temprun=n,alwaysrun=n,jump=n");
        llInstantMessage(wearer, "// Critical power: Mobility severely limited //");
        gRestrictionsActive = TRUE;
    }
    else if (gBatteryLevel <= 10.0) {
        llOwnerSay("@fly=n,temprun=n,alwaysrun=n");
        llInstantMessage(wearer, "// Low power: Movement capabilities reduced //");
        gRestrictionsActive = TRUE;
    }
    else if (gBatteryLevel <= 15.0) {
        llOwnerSay("@fly=n");
        gRestrictionsActive = TRUE;
    }
}

releaseAllRestrictions(key user) {
    gIsFrozen = FALSE;
    gIsGrounded = FALSE;
    gIsTPBlocked = FALSE;
    gIsJumpBlocked = FALSE;
    gIsSitBlocked = FALSE;
    gIsRunBlocked = FALSE;
    gLastActionBy = llKey2Name(user);
    
    llOwnerSay("@clear");
    gRestrictionsActive = FALSE;
    
    llInstantMessage(user, "All mobility restrictions released.");
    llInstantMessage(wearer, "// All movement systems restored by " + llKey2Name(user) + " //");
    
    // Reapply battery restrictions if needed
    if (gBatteryLevel <= 15.0) {
        applyRestrictions();
    }
    
    openControlMenu(user);
}

applyLockdown(key user) {
    gIsFrozen = TRUE;
    gIsGrounded = TRUE;
    gIsTPBlocked = TRUE;
    gIsJumpBlocked = TRUE;
    gIsSitBlocked = TRUE;
    gIsRunBlocked = TRUE;
    gLastActionBy = llKey2Name(user);
    
    applyRestrictions();
    
    llInstantMessage(user, "Emergency lockdown activated.");
    llInstantMessage(wearer, "// EMERGENCY LOCKDOWN - ALL MOVEMENT SYSTEMS DISABLED by " + llKey2Name(user) + " //");
    
    openControlMenu(user);
}

// --- MENU FUNCTIONS ---

openControlMenu(key user) {
    gCurrentMenuUser = user;
    
    string dialog = "\n[ MOBILITY CONTROL SYSTEM ]\n";
    dialog += "═══════════════════════════════════════\n";
    dialog += "Battery: " + (string)((integer)gBatteryLevel) + "%\n";
    
    string powerStatus;
    if (gPowerState) {
        powerStatus = "ONLINE";
    } else {
        powerStatus = "OFFLINE";
    }
    dialog += "Power: " + powerStatus + "\n\n";
    
    dialog += "Movement Status:\n";
    
    string frozenStatus;
    if (gIsFrozen) {
        frozenStatus = "YES";
    } else {
        frozenStatus = "NO";
    }
    
    string groundedStatus;
    if (gIsGrounded) {
        groundedStatus = "YES";
    } else {
        groundedStatus = "NO";
    }
    
    string tpBlockedStatus;
    if (gIsTPBlocked) {
        tpBlockedStatus = "YES";
    } else {
        tpBlockedStatus = "NO";
    }
    
    string jumpBlockedStatus;
    if (gIsJumpBlocked) {
        jumpBlockedStatus = "YES";
    } else {
        jumpBlockedStatus = "NO";
    }
    
    string sitBlockedStatus;
    if (gIsSitBlocked) {
        sitBlockedStatus = "YES";
    } else {
        sitBlockedStatus = "NO";
    }
    
    string runBlockedStatus;
    if (gIsRunBlocked) {
        runBlockedStatus = "YES";
    } else {
        runBlockedStatus = "NO";
    }
    
    dialog += "├ Frozen: " + frozenStatus + "\n";
    dialog += "├ Grounded: " + groundedStatus + "\n";
    dialog += "├ TP Blocked: " + tpBlockedStatus + "\n";
    dialog += "├ Jump Blocked: " + jumpBlockedStatus + "\n";
    dialog += "├ Sit Blocked: " + sitBlockedStatus + "\n";
    dialog += "└ Run Blocked: " + runBlockedStatus + "\n";
    
    if (gLastActionBy != "") {
        dialog += "\nLast Action By: " + gLastActionBy + "\n";
    }
    
    list buttons = [];
    
    // Movement toggles
    if (gIsFrozen) {
        buttons += ["[UNFREEZE]"];
    } else {
        buttons += ["[FREEZE]"];
    }
    
    if (gIsGrounded) {
        buttons += ["[ALLOW FLY]"];
    } else {
        buttons += ["[GROUND]"];
    }
    
    if (gIsTPBlocked) {
        buttons += ["[ALLOW TP]"];
    } else {
        buttons += ["[BLOCK TP]"];
    }
    
    if (gIsJumpBlocked) {
        buttons += ["[ALLOW JUMP]"];
    } else {
        buttons += ["[BLOCK JUMP]"];
    }
    
    if (gIsSitBlocked) {
        buttons += ["[ALLOW SIT]"];
    } else {
        buttons += ["[BLOCK SIT]"];
    }
    
    if (gIsRunBlocked) {
        buttons += ["[ALLOW RUN]"];
    } else {
        buttons += ["[BLOCK RUN]"];
    }
    
    // Control options
    buttons += ["RELEASE ALL", "LOCKDOWN"];
    buttons += ["CLOSE"];
    
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
        
        llOwnerSay("A.R.I.A. Mobility Module v3.0 initialized with OpenCollar auth system.");
        
        // Register with master kernel
        llMessageLinked(LINK_SET, MODULE_REGISTER, "Mobility", NULL_KEY);
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
                // Emergency power mode - apply severe restrictions
                gIsFrozen = TRUE;
                gLastActionBy = "System";
                llInstantMessage(wearer, "// Emergency power mode: Movement systems offline //");
                applyRestrictions();
            }
            else {
                // Power restored
                llInstantMessage(wearer, "// Power restored: Movement systems online //");
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
        
        // Handle menu actions with auth requests
        if (message == "[FREEZE]" || message == "[UNFREEZE]") {
            requestAuth(id, "FREEZE_TOGGLE");
        }
        else if (message == "[GROUND]" || message == "[ALLOW FLY]") {
            requestAuth(id, "GROUND_TOGGLE");
        }
        else if (message == "[BLOCK TP]" || message == "[ALLOW TP]") {
            requestAuth(id, "TP_TOGGLE");
        }
        else if (message == "[BLOCK JUMP]" || message == "[ALLOW JUMP]") {
            requestAuth(id, "JUMP_TOGGLE");
        }
        else if (message == "[BLOCK SIT]" || message == "[ALLOW SIT]") {
            requestAuth(id, "SIT_TOGGLE");
        }
        else if (message == "[BLOCK RUN]" || message == "[ALLOW RUN]") {
            requestAuth(id, "RUN_TOGGLE");
        }
        else if (message == "RELEASE ALL") {
            requestAuth(id, "RELEASE_ALL");
        }
        else if (message == "LOCKDOWN") {
            requestAuth(id, "LOCKDOWN");
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
//-- 2. All menu functions now request authorization before execution
//-- 3. Movement restrictions require trusted user access minimum
//-- 4. Lockdown functionality requires owner permissions for safety
//-- 5. Asynchronous auth system prevents menu delays
//-- 6. Improved RLV command structure for better compatibility
//-- 7. Enhanced battery level restriction handling
//-- 8. Better user feedback and system status reporting
//-- 9. Proper cleanup of pending auth requests
//-- 10. Emergency power mode handling for power state changes
//-- 11. Fixed all ternary operators and invalid LSL syntax
//-- 12. Eliminated duplicate variable declarations
