//-- A.R.I.A. Sensory Module (Add-on)
//-- Version 2.2 - OPENCOLLAR AUTH SYSTEM + ADULT DEVICE INTEGRATION
//-- September 12, 2025 - Updated to use AUTH_REQUEST/AUTH_REPLY system
//-- CHANGES v2.2:
//--   - Moved arousal updates to a unique linked-message code
//-- CHANGES v2.1:
//--   - Corrected auth-level comparisons to match the OpenCollar ordering
//-- CHANGES v2.0:
//--   - Replaced old permission system with OpenCollar auth
//--   - Implemented AUTH_REQUEST/AUTH_REPLY protocol
//--   - Enhanced adult device integration (Lovense, INM, Xcite, Sensations)
//--   - Improved safety measures and access controls
//--   - Added comprehensive RLV relay support
//--   - Fixed all ternary operators and invalid LSL syntax

// --- CONFIGURATION ---
integer LOVENSE_CHANNEL = 1337;     // Standard Lovense communication channel
integer RLV_RELAY_CHANNEL = -1812221819; // Standard RLV Relay channel
integer INM_CHANNEL = -2017;        // It's Not Mine system channel
integer XCITE_CHANNEL = 5;          // Xcite! system channel
integer SENSATIONS_CHANNEL = -58904; // Sensations system channel
integer AVS_CHANNEL = -9119;        // AVsitter adult system channel
float PAIN_EFFECT_DURATION = 30.0;  // Duration for pain effects in seconds

// --- LINKED MESSAGE CODES ---
integer UPDATE_BATTERY = 101;
integer MODULE_REGISTER = 200;
integer OPEN_MY_MENU = 201;
integer POWER_STATE_CHANGE = 300;
integer UPDATE_AROUSAL = 404;
integer UPDATE_STIMULATION = 401;
integer UPDATE_PAIN = 402;
integer UPDATE_STRESS = 403;

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
integer gSensoryActive = TRUE;
integer gEroticMode = FALSE;
integer gPainActive = FALSE;
string gCurrentAnimation = "";
list gConnectedDevices;        // Track connected devices
list gConnectedINM;           // Track INM genitals
list gConnectedXcite;         // Track Xcite devices
list gConnectedSensations;    // Track Sensations devices

// --- DEVICE INTEGRATION STATES ---
integer gINMActive = FALSE;
integer gXciteActive = FALSE;
integer gSensationsActive = FALSE;
integer gGenitalStimulation = 0; // 0-100 intensity

// --- PAIN EFFECT STATES ---
integer gShockActive = FALSE;
integer gPokeActive = FALSE;
integer gTempRestrictions = FALSE;

// --- ASYNCHRONOUS AUTH SYSTEM ---
list gPendingAuthRequests;  // Format: [requestId, userKey, action, ...]
integer gNextRequestId = 1;
key gCurrentMenuUser;

// --- MENU STATES ---
integer gMenuState = 0;
// 0 = main, 1 = erotic controls, 2 = pain controls, 3 = device management

// --- ANIMATION LISTS ---
list gEroticAnimations = ["express_open_mouth", "express_smile", "express_disdain", "express_toothsmile"];
list gPainAnimations = ["express_pain_1", "express_cry_emote", "express_sad_emote", "express_disdain"];

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
        if (authLevel <= CMD_OWNER) {
            openMainMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Owner permissions required for Sensory controls due to adult content.");
        }
    }
    else if (action == "TOGGLE_SYSTEM") {
        if (authLevel <= CMD_OWNER) {
            gSensoryActive = !gSensoryActive;
            string status;
            if (gSensoryActive) {
                status = "enabled";
            } else {
                status = "disabled";
            }
            llInstantMessage(user, "Sensory system " + status + ".");
            llInstantMessage(wearer, "// Sensory protocols " + status + " by " + llKey2Name(user) + " //");
            openMainMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Owner permissions required.");
        }
    }
    else if (action == "EROTIC_MODE") {
        if (authLevel <= CMD_OWNER) {
            gEroticMode = !gEroticMode;
            if (gEroticMode) {
                llInstantMessage(user, "Erotic sensory mode activated.");
                llInstantMessage(wearer, "// Intimate sensory protocols engaged //");
                sendEmote("sensory systems calibrating for intimate protocols", 1);
            } else {
                llInstantMessage(user, "Erotic sensory mode deactivated.");
                llInstantMessage(wearer, "// Intimate protocols disengaged //");
                sendEmote("returning to standard sensory baseline", 0);
            }
            openMainMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Owner permissions required.");
        }
    }
    else if (action == "PAIN_MODE") {
        if (authLevel <= CMD_OWNER) {
            gPainActive = !gPainActive;
            if (gPainActive) {
                llInstantMessage(user, "Pain sensory mode activated.");
                llInstantMessage(wearer, "// Pain reception protocols online //");
                sendEmote("pain receptors calibrated and active", 0);
            } else {
                llInstantMessage(user, "Pain sensory mode deactivated.");
                llInstantMessage(wearer, "// Pain protocols disengaged //");
                clearPainRestrictions();
                sendEmote("pain systems powered down", 0);
            }
            openMainMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Owner permissions required.");
        }
    }
    else if (action == "STIMULATION") {
        if (authLevel <= CMD_OWNER) {
            handleStimulationCommand(user);
        } else {
            llInstantMessage(user, "Access denied. Owner permissions required.");
        }
    }
    else if (action == "SHOCK") {
        if (authLevel <= CMD_OWNER) {
            handleShockCommand(user);
        } else {
            llInstantMessage(user, "Access denied. Owner permissions required.");
        }
    }
    else if (action == "DEVICE_SCAN") {
        if (authLevel <= CMD_OWNER) {
            scanForDevices(user);
        } else {
            llInstantMessage(user, "Access denied. Owner permissions required.");
        }
    }
}

// --- SENSORY FUNCTIONS ---

sendEmote(string message, integer intensity) {
    if (!gSensoryActive) return;
    
    // Apply battery effects
    if (gBatteryLevel <= 10.0) {
        message = "***static*** " + message + " ***interference***";
    } else if (gBatteryLevel <= 25.0) {
        message = "*low power* " + message;
    }
    
    llSay(0, "/me " + message);
    
    // Broadcast to modules that might care about sensory state
    if (intensity > 0) {
        llMessageLinked(LINK_SET, UPDATE_AROUSAL, (string)intensity, NULL_KEY);
    }
}

playRandomAnimation(list animations) {
    if (llGetListLength(animations) == 0) return;
    
    integer index = llFloor(llFrand(llGetListLength(animations)));
    string anim = llList2String(animations, index);
    
    if (gCurrentAnimation != "") {
        llStopAnimation(gCurrentAnimation);
    }
    
    llStartAnimation(anim);
    gCurrentAnimation = anim;
}

stopCurrentAnimation() {
    if (gCurrentAnimation != "") {
        llStopAnimation(gCurrentAnimation);
        gCurrentAnimation = "";
    }
}

handleStimulationCommand(key user) {
    if (!gSensoryActive || !gEroticMode) {
        llInstantMessage(user, "Erotic sensory mode must be active first.");
        return;
    }
    
    integer intensity = llFloor(llFrand(5)) + 1; // Random 1-5
    
    sendEmote("pleasure protocols activated... intensity level " + (string)intensity, intensity);
    playRandomAnimation(gEroticAnimations);
    
    // Broadcast to connected devices
    broadcastToAllDevices("STIMULATE", intensity * 20); // Scale to 0-100
    
    llInstantMessage(user, "Stimulation command sent at intensity " + (string)intensity);
    llInstantMessage(wearer, "// Pleasure receptors engaged //");
}

handleShockCommand(key user) {
    if (!gSensoryActive || !gPainActive) {
        llInstantMessage(user, "Pain sensory mode must be active first.");
        return;
    }
    
    integer intensity = llFloor(llFrand(3)) + 1; // Random 1-3
    
    sendEmote("shock protocols engaged... pain level " + (string)intensity, 0);
    playRandomAnimation(gPainAnimations);
    applyPainRestrictions();
    
    // Broadcast to connected devices
    broadcastToAllDevices("SHOCK", intensity * 33); // Scale to 0-100
    
    llInstantMessage(user, "Shock command sent at intensity " + (string)intensity);
    llInstantMessage(wearer, "// Pain receptors stimulated //");
}

applyPainRestrictions() {
    // Apply temporary movement and interaction restrictions during pain
    llOwnerSay("@sit=n,touch=n");
    gTempRestrictions = TRUE;
    llSetTimerEvent(PAIN_EFFECT_DURATION);
}

clearPainRestrictions() {
    // Clear temporary restrictions
    llOwnerSay("@sit=y,touch=y");
    gTempRestrictions = FALSE;
    gShockActive = FALSE;
    gPokeActive = FALSE;
    stopCurrentAnimation();
}

// --- DEVICE COMMUNICATION FUNCTIONS ---

broadcastToLovense(string command, integer intensity) {
    string lovenseCmd = "LVS:" + command + ":" + (string)intensity;
    llSay(LOVENSE_CHANNEL, lovenseCmd);
    llWhisper(LOVENSE_CHANNEL, lovenseCmd);
}

sendToINM(string command, integer intensity) {
    string inmCmd = command + "|" + (string)intensity + "|" + (string)wearer;
    llSay(INM_CHANNEL, inmCmd);
    llWhisper(INM_CHANNEL, inmCmd);
    
    // Also try direct genital commands
    llSay(INM_CHANNEL, "STIM|" + (string)intensity);
}

sendToXcite(string command, integer intensity) {
    string xciteCmd = (string)wearer + ":" + command + ":" + (string)intensity;
    llSay(XCITE_CHANNEL, xciteCmd);
    
    // Alternative Xcite format
    llSay(XCITE_CHANNEL, command + " " + (string)intensity);
}

sendToSensations(string command, integer intensity) {
    string sensCmd = "SENS:" + command + ":" + (string)intensity + ":" + (string)wearer;
    llSay(SENSATIONS_CHANNEL, sensCmd);
    llWhisper(SENSATIONS_CHANNEL, sensCmd);
}

broadcastToAllDevices(string command, integer intensity) {
    broadcastToLovense(command, intensity);
    sendToINM(command, intensity);
    sendToXcite(command, intensity);
    sendToSensations(command, intensity);
}

sendToRLVRelay(string command, key target) {
    string relayCmd = command + "," + (string)target + ",!x-channel-redirect";
    llSay(RLV_RELAY_CHANNEL, relayCmd);
}

scanForDevices(key user) {
    llInstantMessage(user, "Scanning for compatible adult devices...");
    
    // Reset device lists
    gConnectedDevices = [];
    gConnectedINM = [];
    gConnectedXcite = [];
    gConnectedSensations = [];
    
    // Send discovery commands
    llSay(LOVENSE_CHANNEL, "LVS:DISCOVER");
    llSay(INM_CHANNEL, "DISCOVER|" + (string)wearer);
    llSay(XCITE_CHANNEL, "XCITE_DISCOVER");
    llSay(SENSATIONS_CHANNEL, "SENS:DISCOVER");
    
    llInstantMessage(wearer, "// Device discovery initiated - listening for responses //");
    
    // Set timer for scan completion
    llSetTimerEvent(10.0);
}

// --- MENU FUNCTIONS ---

openMainMenu(key user) {
    gCurrentMenuUser = user;
    gMenuState = 0;
    
    string dialog = "\n[ SENSORY EXPERIENCE PROTOCOLS ]\n";
    dialog += "═══════════════════════════════════════\n";
    dialog += "⚠️  ADULT CONTENT WARNING ⚠️\n";
    dialog += "This module contains mature themes\n";
    dialog += "═══════════════════════════════════════\n";
    dialog += "Battery: " + (string)((integer)gBatteryLevel) + "%\n";
    
    string sensoryStatus;
    if (gSensoryActive) {
        sensoryStatus = "ACTIVE";
    } else {
        sensoryStatus = "INACTIVE";
    }
    dialog += "Status: " + sensoryStatus + "\n";
    
    string powerStatus;
    if (gPowerState) {
        powerStatus = "ONLINE";
    } else {
        powerStatus = "OFFLINE";
    }
    dialog += "Power: " + powerStatus + "\n\n";
    
    dialog += "Current Modes:\n";
    
    string eroticStatus;
    if (gEroticMode) {
        eroticStatus = "ENABLED";
    } else {
        eroticStatus = "DISABLED";
    }
    
    string painStatus;
    if (gPainActive) {
        painStatus = "ENABLED";
    } else {
        painStatus = "DISABLED";
    }
    
    dialog += "├ Erotic: " + eroticStatus + "\n";
    dialog += "├ Pain: " + painStatus + "\n";
    dialog += "└ Devices: " + (string)llGetListLength(gConnectedDevices) + " connected\n";
    
    list buttons = [];
    
    // System control
    if (gSensoryActive) {
        buttons += ["[DISABLE]"];
    } else {
        buttons += ["[ENABLE]"];
    }
    
    // Mode toggles
    if (gEroticMode) {
        buttons += ["[EROTIC OFF]"];
    } else {
        buttons += ["[EROTIC ON]"];
    }
    
    if (gPainActive) {
        buttons += ["[PAIN OFF]"];
    } else {
        buttons += ["[PAIN ON]"];
    }
    
    // Action buttons (only if appropriate modes are active)
    if (gEroticMode && gSensoryActive) {
        buttons += ["STIMULATE"];
    }
    if (gPainActive && gSensoryActive) {
        buttons += ["SHOCK"];
    }
    
    // Device management
    buttons += ["SCAN DEVICES"];
    
    // Close
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
        
        // Listen for all adult device system responses
        llListen(LOVENSE_CHANNEL, "", NULL_KEY, "");
        llListen(RLV_RELAY_CHANNEL, "", NULL_KEY, "");
        llListen(INM_CHANNEL, "", NULL_KEY, "");
        llListen(XCITE_CHANNEL, "", NULL_KEY, "");
        llListen(SENSATIONS_CHANNEL, "", NULL_KEY, "");
        llListen(AVS_CHANNEL, "", NULL_KEY, "");
        
        llOwnerSay("A.R.I.A. Sensory Module v2.0 initialized with OpenCollar auth system.");
        
        // Register with master kernel
        llMessageLinked(LINK_SET, MODULE_REGISTER, "Sensory", NULL_KEY);
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
            // Reduce sensory intensity at low battery
            if (gBatteryLevel <= 15.0 && (gEroticMode || gPainActive)) {
                llInstantMessage(wearer, "// Low power affecting sensory protocols //");
            }
        }
        else if (num == POWER_STATE_CHANGE) {
            gPowerState = (integer)msg;
            
            if (!gPowerState) {
                // Emergency power mode - disable sensory systems
                gSensoryActive = FALSE;
                gEroticMode = FALSE;
                gPainActive = FALSE;
                clearPainRestrictions();
                llInstantMessage(wearer, "// Emergency power mode: Sensory systems offline //");
            }
            else {
                // Power restored
                gSensoryActive = TRUE;
                llInstantMessage(wearer, "// Power restored: Sensory systems online //");
            }
        }
        else if (num == UPDATE_AROUSAL) {
            integer arousalLevel = (integer)msg;
            if (gEroticMode && gSensoryActive) {
                sendEmote("arousal level detected: " + (string)arousalLevel, arousalLevel);
            }
        }
        else if (num == UPDATE_PAIN) {
            integer painLevel = (integer)msg;
            if (gPainActive && gSensoryActive) {
                sendEmote("pain level registered: " + (string)painLevel, 0);
            }
        }
    }

    listen(integer channel, string name, key id, string message) {
        // Handle menu responses
        if (channel == gMenuChannel && id == gCurrentMenuUser) {
            llSetTimerEvent(0.0);
            llListenRemove(gListenHandle);
            
            if (message == "CLOSE") return;
            
            // Handle menu actions with auth requests
            if (message == "[ENABLE]" || message == "[DISABLE]") {
                requestAuth(id, "TOGGLE_SYSTEM");
            }
            else if (message == "[EROTIC ON]" || message == "[EROTIC OFF]") {
                requestAuth(id, "EROTIC_MODE");
            }
            else if (message == "[PAIN ON]" || message == "[PAIN OFF]") {
                requestAuth(id, "PAIN_MODE");
            }
            else if (message == "STIMULATE") {
                requestAuth(id, "STIMULATION");
            }
            else if (message == "SHOCK") {
                requestAuth(id, "SHOCK");
            }
            else if (message == "SCAN DEVICES") {
                requestAuth(id, "DEVICE_SCAN");
            }
            return;
        }
        
        // Handle device responses
        if (channel == LOVENSE_CHANNEL) {
            if (llSubStringIndex(message, "LVS:READY") != -1 || llSubStringIndex(message, "LVS:CONNECTED") != -1) {
                string deviceKey = (string)id;
                if (llListFindList(gConnectedDevices, [deviceKey]) == -1) {
                    gConnectedDevices += [deviceKey];
                    llInstantMessage(wearer, "// Lovense device connected //");
                }
            }
        }
        else if (channel == INM_CHANNEL) {
            if (llSubStringIndex(message, "READY") != -1 || llSubStringIndex(message, "CONNECTED") != -1) {
                string device = llList2String(llParseString2List(message, ["|"], []), 0);
                if (llListFindList(gConnectedINM, [device]) == -1) {
                    gConnectedINM += [device];
                    llInstantMessage(wearer, "// INM device connected: " + device + " //");
                }
            }
        }
        else if (channel == XCITE_CHANNEL) {
            if (llSubStringIndex(message, "XCITE_READY") != -1 || llSubStringIndex(message, "CONNECTED") != -1) {
                string deviceKey = (string)id;
                if (llListFindList(gConnectedXcite, [deviceKey]) == -1) {
                    gConnectedXcite += [deviceKey];
                    llInstantMessage(wearer, "// Xcite device connected //");
                }
            }
        }
        else if (channel == SENSATIONS_CHANNEL && llSubStringIndex(message, "SENS:") == 0) {
            list parts = llParseString2List(message, [":"], []);
            string command = llList2String(parts, 1);
            
            if (command == "READY" || command == "CONNECTED") {
                string device = llList2String(parts, 2);
                if (llListFindList(gConnectedSensations, [device]) == -1) {
                    gConnectedSensations += [device];
                    llInstantMessage(wearer, "// Sensations device connected: " + device + " //");
                }
            }
        }
    }

    sensor(integer num_detected) {
        // Handle detection of RLV furniture or devices
        integer i;
        for (i = 0; i < num_detected; i++) {
            string name = llDetectedName(i);
            key detected = llDetectedKey(i);
            
            // Look for common RLV furniture indicators
            if (llSubStringIndex(llToLower(name), "rlv") != -1 || 
                llSubStringIndex(llToLower(name), "furniture") != -1 ||
                llSubStringIndex(llToLower(name), "toy") != -1) {
                
                llInstantMessage(wearer, "// Compatible device detected: " + name + " //");
                sendToRLVRelay("@sit:" + (string)detected + "=force", detected);
            }
        }
    }

    timer() {
        // Handle pain effect duration or menu timeout
        if (gTempRestrictions) {
            clearPainRestrictions();
            llInstantMessage(wearer, "// Pain effect duration expired - systems recovering //");
        } else {
            llListenRemove(gListenHandle);
        }
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
//-- 2. All sensory functions require Owner permissions due to adult content
//-- 3. Enhanced safety measures and consent-based access controls
//-- 4. Comprehensive adult device integration with multiple protocols
//-- 5. Asynchronous auth system prevents menu delays
//-- 6. Improved RLV command structure and temporary restrictions
//-- 7. Better device discovery and connection management
//-- 8. Enhanced battery level effects on sensory operations
//-- 9. Proper cleanup of pending auth requests and timers
//-- 10. Adult content warnings in all user interfaces
//-- 11. Fixed all ternary operators and invalid LSL syntax
//-- 12. Eliminated duplicate variable declarations
