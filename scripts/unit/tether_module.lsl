//-- A.R.I.A. Tether RLV Module (Add-on)
//-- Version 3.1 - OPENCOLLAR AUTH SYSTEM INTEGRATION
//-- September 12, 2025 - Updated to use AUTH_REQUEST/AUTH_REPLY system
//-- CHANGES v3.1:
//--   - Corrected auth-level comparisons to match the OpenCollar ordering
//-- CHANGES v3.0:
//--   - Replaced old permission system with OpenCollar auth
//--   - Implemented AUTH_REQUEST/AUTH_REPLY protocol
//--   - Removed old permission variables and functions
//--   - Fixed RLV tether commands and leash effects
//--   - Enhanced follow distance and target management
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
integer gTextBoxHandle;
integer gPowerState = TRUE;
key wearer;

// --- MODULE STATE ---
integer gTetherActive = FALSE;
key gFollowTarget = NULL_KEY;
float gFollowDistance = 2.0;
integer gLeashVisible = FALSE;
integer gAutoFollow = FALSE;

// --- LEASH EFFECT VARIABLES ---
integer gParticleHandle = 0;

// --- ASYNCHRONOUS AUTH SYSTEM ---
list gPendingAuthRequests;  // Format: [requestId, userKey, action, ...]
integer gNextRequestId = 1;
key gCurrentMenuUser;

// --- MENU STATES ---
integer MENU_STATE_NONE = 0;
integer MENU_STATE_SET_TARGET = 1;
integer MENU_STATE_SET_DISTANCE = 2;
integer gMenuState = 0;

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
            llInstantMessage(user, "Access denied. Trusted user permissions required for Tether controls.");
        }
    }
    else if (action == "TETHER_TOGGLE") {
        if (authLevel <= CMD_TRUSTED) {
            gTetherActive = !gTetherActive;
            if (gTetherActive) {
                if (gFollowTarget != NULL_KEY) {
                    llInstantMessage(wearer, "// Follow protocol engaged. Target: " + llKey2Name(gFollowTarget) + " //");
                } else {
                    llInstantMessage(wearer, "// Follow protocol engaged. No target set. //");
                }
            } else {
                llInstantMessage(wearer, "// Follow protocol disengaged. //");
            }
            updateFollow();
            llInstantMessage(user, "Tether setting updated.");
            openControlMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Trusted user permissions required.");
        }
    }
    else if (action == "LEASH_TOGGLE") {
        if (authLevel <= CMD_TRUSTED) {
            gLeashVisible = !gLeashVisible;
            if (gLeashVisible) {
                llInstantMessage(wearer, "// Leash effect enabled. //");
            } else {
                llInstantMessage(wearer, "// Leash effect disabled. //");
            }
            updateFollow();
            llInstantMessage(user, "Leash visibility updated.");
            openControlMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Trusted user permissions required.");
        }
    }
    else if (action == "AUTO_FOLLOW_TOGGLE") {
        if (authLevel <= CMD_TRUSTED) {
            gAutoFollow = !gAutoFollow;
            if (gAutoFollow) {
                llInstantMessage(wearer, "// Auto-follow mode enabled. //");
            } else {
                llInstantMessage(wearer, "// Auto-follow mode disabled. //");
            }
            llInstantMessage(user, "Auto-follow setting updated.");
            openControlMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Trusted user permissions required.");
        }
    }
    else if (action == "FOLLOW_SELF") {
        if (authLevel <= CMD_TRUSTED) {
            gFollowTarget = user;
            llInstantMessage(wearer, "// Follow target set to: " + llKey2Name(user) + " //");
            updateFollow();
            llInstantMessage(user, "Follow target set to yourself.");
            openControlMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Trusted user permissions required.");
        }
    }
    else if (action == "RELEASE_ALL") {
        if (authLevel <= CMD_TRUSTED) {
            gTetherActive = FALSE;
            gFollowTarget = NULL_KEY;
            gLeashVisible = FALSE;
            gAutoFollow = FALSE;
            llInstantMessage(wearer, "// All follow protocols released. //");
            updateFollow();
            llInstantMessage(user, "All tether protocols released.");
            openControlMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Trusted user permissions required.");
        }
    }
    else if (action == "SCAN_NEARBY") {
        if (authLevel <= CMD_TRUSTED) {
            scanNearbyAvatars(user);
        } else {
            llInstantMessage(user, "Access denied. Trusted user permissions required.");
        }
    }
    else if (action == "SET_DISTANCE") {
        if (authLevel <= CMD_TRUSTED) {
            gMenuState = MENU_STATE_SET_DISTANCE;
            openDistanceInput(user);
        } else {
            llInstantMessage(user, "Access denied. Trusted user permissions required.");
        }
    }
}

// --- HELPER FUNCTIONS ---

updateFollow() {
    if (gTetherActive && gFollowTarget != NULL_KEY) {
        // Apply RLV follow command
        llOwnerSay("@follow:" + (string)gFollowTarget + "=" + (string)gFollowDistance);
        
        if (gLeashVisible) {
            startLeashEffect();
        }
    } else {
        // Clear follow command
        llOwnerSay("@follow=clear");
        stopLeashEffect();
    }
}

startLeashEffect() {
    if (gFollowTarget != NULL_KEY) {
        llParticleSystem([
            PSYS_PART_FLAGS, 
            PSYS_PART_EMISSIVE_MASK | 
            PSYS_PART_INTERP_COLOR_MASK | 
            PSYS_PART_INTERP_SCALE_MASK | 
            PSYS_PART_TARGET_POS_MASK,
            
            PSYS_PART_START_COLOR, <0.1, 0.5, 1.0>,
            PSYS_PART_END_COLOR, <0.8, 0.1, 1.0>,
            PSYS_PART_START_SCALE, <0.05, 0.05, 0>,
            PSYS_PART_END_SCALE, <0.02, 0.02, 0>,
            PSYS_PART_START_ALPHA, 0.8,
            PSYS_PART_END_ALPHA, 0.2,
            
            PSYS_SRC_PATTERN, PSYS_SRC_PATTERN_EXPLODE,
            PSYS_SRC_BURST_RATE, 0.05,
            PSYS_SRC_BURST_PART_COUNT, 2,
            PSYS_SRC_BURST_RADIUS, 0.0,
            PSYS_SRC_BURST_SPEED_MIN, 0.1,
            PSYS_SRC_BURST_SPEED_MAX, 0.2,
            PSYS_PART_MAX_AGE, 3.0,
            PSYS_SRC_TARGET_KEY, gFollowTarget
        ]);
        gParticleHandle = 1;
    }
}

stopLeashEffect() {
    if (gParticleHandle) {
        llParticleSystem([]);
        gParticleHandle = 0;
    }
}

scanNearbyAvatars(key user) {
    gCurrentMenuUser = user;
    gMenuState = MENU_STATE_SET_TARGET;
    llSensor("", NULL_KEY, AGENT, 20.0, PI);
}

openDistanceInput(key user) {
    string dialog = "\n[ SET FOLLOW DISTANCE ]\n";
    dialog += "═══════════════════════════════════════\n";
    dialog += "Current distance: " + (string)gFollowDistance + "m\n\n";
    dialog += "Enter a new follow distance between 1.0 and 20.0 meters:";
    
    gTextBoxHandle = llListen(gMenuChannel + 1, "", user, "");
    llTextBox(user, dialog, gMenuChannel + 1);
    llSetTimerEvent(60.0);
}

handleTextInput(key user, string input) {
    if (gMenuState == MENU_STATE_SET_DISTANCE) {
        float distance = (float)input;
        if (distance >= 1.0 && distance <= 20.0) {
            gFollowDistance = distance;
            llInstantMessage(user, "Follow distance set to " + (string)distance + "m");
            llInstantMessage(wearer, "// Follow distance updated to " + (string)distance + "m //");
            updateFollow();
        } else {
            llInstantMessage(user, "Invalid distance. Please enter a value between 1.0 and 20.0 meters.");
        }
    }
    
    gMenuState = MENU_STATE_NONE;
    updateFollow();
    openControlMenu(user);
}

// --- MENU FUNCTIONS ---

openControlMenu(key user) {
    gCurrentMenuUser = user;
    
    string dialog = "\n[ TETHER & FOLLOW PROTOCOLS ]\n";
    dialog += "═══════════════════════════════════════\n";
    
    string tetherStatus;
    if (gTetherActive) {
        tetherStatus = "ON";
    } else {
        tetherStatus = "OFF";
    }
    
    string leashStatus;
    if (gLeashVisible) {
        leashStatus = "ON";
    } else {
        leashStatus = "OFF";
    }
    
    string autoStatus;
    if (gAutoFollow) {
        autoStatus = "ON";
    } else {
        autoStatus = "OFF";
    }
    
    dialog += "Battery: " + (string)((integer)gBatteryLevel) + "%\n";
    
    string powerStatus;
    if (gPowerState) {
        powerStatus = "ONLINE";
    } else {
        powerStatus = "OFFLINE";
    }
    dialog += "Power: " + powerStatus + "\n\n";
    
    dialog += "Current Status:\n";
    dialog += "├ Tether: " + tetherStatus + "\n";
    dialog += "├ Leash Effect: " + leashStatus + "\n";
    dialog += "├ Auto-Follow: " + autoStatus + "\n";
    dialog += "├ Distance: " + (string)gFollowDistance + "m\n";
    
    if (gFollowTarget != NULL_KEY) {
        dialog += "└ Target: " + llKey2Name(gFollowTarget) + "\n";
    } else {
        dialog += "└ Target: None Set\n";
    }
    
    list buttons = [];
    
    // Tether controls
    if (gTetherActive) {
        buttons += ["[TETHER OFF]"];
    } else {
        buttons += ["[TETHER ON]"];
    }
    
    if (gLeashVisible) {
        buttons += ["[LEASH OFF]"];
    } else {
        buttons += ["[LEASH ON]"];
    }
    
    if (gAutoFollow) {
        buttons += ["[AUTO OFF]"];
    } else {
        buttons += ["[AUTO ON]"];
    }
    
    // Target and distance controls
    buttons += ["Follow Self", "Nearby", "Distance"];
    
    // System controls
    buttons += ["RELEASE ALL", "CLOSE"];
    
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
        gTetherActive = FALSE;
        gFollowTarget = NULL_KEY;
        gFollowDistance = 2.0;
        gLeashVisible = FALSE;
        gAutoFollow = FALSE;
        gMenuState = MENU_STATE_NONE;
        
        llOwnerSay("A.R.I.A. Tether Module v3.0 initialized with OpenCollar auth system.");
        
        // Register with master kernel
        llMessageLinked(LINK_SET, MODULE_REGISTER, "Tether", NULL_KEY);
        
        // Apply initial (unrestricted) state
        updateFollow();
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
            
            // Disable tether if battery is critically low
            if (gBatteryLevel <= 5.0 && gTetherActive) {
                gTetherActive = FALSE;
                updateFollow();
                llInstantMessage(wearer, "// Tether connection lost due to low power. //");
            }
        }
        else if (num == POWER_STATE_CHANGE) {
            gPowerState = (integer)msg;
            
            if (!gPowerState) {
                // Emergency power mode - disable tether
                gTetherActive = FALSE;
                updateFollow();
                llInstantMessage(wearer, "// Emergency power mode: Tether systems offline //");
            }
            else {
                // Power restored
                llInstantMessage(wearer, "// Power restored: Tether systems online //");
            }
        }
    }

    listen(integer channel, string name, key id, string message) {
        if (channel == gMenuChannel && id == gCurrentMenuUser) {
            llSetTimerEvent(0.0);
            llListenRemove(gListenHandle);
            
            if (message == "CLOSE") return;
            
            // Handle menu actions with auth requests
            if (message == "[TETHER ON]" || message == "[TETHER OFF]") {
                requestAuth(id, "TETHER_TOGGLE");
            }
            else if (message == "[LEASH ON]" || message == "[LEASH OFF]") {
                requestAuth(id, "LEASH_TOGGLE");
            }
            else if (message == "[AUTO ON]" || message == "[AUTO OFF]") {
                requestAuth(id, "AUTO_FOLLOW_TOGGLE");
            }
            else if (message == "Follow Self") {
                requestAuth(id, "FOLLOW_SELF");
            }
            else if (message == "RELEASE ALL") {
                requestAuth(id, "RELEASE_ALL");
            }
            else if (message == "Nearby") {
                requestAuth(id, "SCAN_NEARBY");
            }
            else if (message == "Distance") {
                requestAuth(id, "SET_DISTANCE");
            }
            return;
        }
        else if (channel == gMenuChannel + 1 && id == gCurrentMenuUser) {
            // Handle text input
            llListenRemove(gTextBoxHandle);
            handleTextInput(id, message);
            return;
        }
    }

    sensor(integer num_detected) {
        if (gMenuState == MENU_STATE_SET_TARGET) {
            string dialog = "\n[ SELECT FOLLOW TARGET ]\n";
            dialog += "═══════════════════════════════════════\n";
            dialog += "Select an avatar to follow:\n\n";
            
            list buttons = [];
            integer i;
            for (i = 0; i < num_detected && i < 9; i++) {
                string name = llDetectedName(i);
                buttons += [name];
                
                // Also handle if they select this person directly
                if (llDetectedKey(i) == gCurrentMenuUser) {
                    // Auto-select if they scanned for themselves
                    return;
                }
            }
            
            if (llGetListLength(buttons) == 0) {
                llInstantMessage(gCurrentMenuUser, "No other avatars found in range.");
                openControlMenu(gCurrentMenuUser);
                return;
            }
            
            buttons += ["CANCEL"];
            
            llListenRemove(gListenHandle);
            gListenHandle = llListen(gMenuChannel, "", gCurrentMenuUser, "");
            llDialog(gCurrentMenuUser, dialog, buttons, gMenuChannel);
            llSetTimerEvent(30.0);
        }
    }
    
    no_sensor() {
        if (gMenuState == MENU_STATE_SET_TARGET) {
            llInstantMessage(gCurrentMenuUser, "No avatars found in range.");
            openControlMenu(gCurrentMenuUser);
        }
    }
    
    timer() {
        llListenRemove(gListenHandle);
        llListenRemove(gTextBoxHandle);
        gMenuState = MENU_STATE_NONE;
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
//-- 2. All tether functions require Trusted user permissions minimum
//-- 3. Asynchronous auth system prevents menu delays
//-- 4. Improved RLV follow command structure
//-- 5. Enhanced leash particle effect system
//-- 6. Better target selection and distance management
//-- 7. Battery level integration with automatic tether disable
//-- 8. Emergency power mode handling
//-- 9. Fixed all ternary operators and invalid LSL syntax
//-- 10. Proper cleanup of pending auth requests and listeners
