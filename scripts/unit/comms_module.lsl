//-- A.R.I.A. Comms Module (The "Vocalizer")
//-- Version 3.0 - OPENCOLLAR AUTH INTEGRATION
//-- September 12, 2025 - Refactored to use AUTH_REQUEST/AUTH_REPLY system
//-- CHANGES v3.0:
//--   - Removed synchronous getAccessLevel() and checkModuleAccess() functions
//--   - Implemented asynchronous AUTH_REQUEST/AUTH_REPLY protocol
//--   - Added pending auth request management for communication operations
//--   - Removed old permission variables and UPDATE_CONFIG handling
//--   - All menu functions now use async auth checks
//--   - Enhanced communication control security with persona integration

// --- CONFIGURATION ---
integer comms_channel = 9974;

// --- LINKED MESSAGE CODES ---
integer SET_SPEECH_MODE = 100;
integer UPDATE_BATTERY = 101;
integer UPDATE_UNIT_INFO = 103;
integer UPDATE_PERSONA_STATUS = 104;
integer MODULE_REGISTER = 200;
integer OPEN_MY_MENU = 201;
integer RELAY_CHAT_MESSAGE = 300;
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
integer gPowerState = TRUE;
string gSpeechMode = "Standard";
string gUnitName = "A.R.I.A.";
string gCurrentPersona = "Default";
string gPersonaChatPrefix = "[A.R.I.A.]";

// --- MENU VARIABLES ---
integer gMenuChannel;
integer gListenHandle;
integer gCommsListenHandle;

// --- COMMS CONFIGURATION ---
integer gCommsEnabled = TRUE;
integer gPersonaFilterEnabled = TRUE;
integer gBatteryEffectsEnabled = TRUE;
string gActiveCommChannel = "Public";

// --- ASYNCHRONOUS AUTH SYSTEM ---
list gPendingAuthRequests;  // Format: [requestId, userKey, action, timestamp, ...]
integer gNextRequestId = 1;
integer gAuthTimeoutSeconds = 30;

// --- MENU VARIABLES ---
key gCurrentMenuUser;

// --- AUTH MANAGEMENT FUNCTIONS ---

// Request auth for a specific comms action
requestCommsAuth(key user, string action) {
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
processCommsAuth(key user, integer authLevel, string action) {
    // Find and remove the pending request
    integer idx = llListFindList(gPendingAuthRequests, [user]);
    if (idx == -1) return; // Request not found
    
    string originalAction = llList2String(gPendingAuthRequests, idx + 1);
    gPendingAuthRequests = llDeleteSubList(gPendingAuthRequests, idx - 1, idx + 2);
    
    // Most comms operations require wearer access minimum
    if (authLevel <= CMD_WEARER) {
        executeCommsAction(user, action);
    } else {
        llInstantMessage(user, "Access denied. Wearer permissions required for Communications Module.");
    }
}

// Execute the requested comms action after auth confirmation
executeCommsAction(key user, string action) {
    if (action == "COMMS_MENU") {
        openCommsMenu(user);
    }
    else if (action == "TOGGLE_COMMS") {
        gCommsEnabled = !gCommsEnabled;
        if (gCommsEnabled) {
            llInstantMessage(g_kWearer, "// Communications enabled. Voice protocols active. //");
            llInstantMessage(user, "Communications enabled.");
        } else {
            llInstantMessage(g_kWearer, "// Communications disabled. Voice protocols offline. //");
            llInstantMessage(user, "Communications disabled.");
        }
        openCommsMenu(user);
    }
    else if (action == "TOGGLE_PERSONA_FILTER") {
        gPersonaFilterEnabled = !gPersonaFilterEnabled;
        if (gPersonaFilterEnabled) {
            llInstantMessage(user, "Persona speech filtering enabled.");
        } else {
            llInstantMessage(user, "Persona speech filtering disabled.");
        }
        openCommsMenu(user);
    }
    else if (action == "TOGGLE_BATTERY_EFFECTS") {
        gBatteryEffectsEnabled = !gBatteryEffectsEnabled;
        if (gBatteryEffectsEnabled) {
            llInstantMessage(user, "Battery-based communication effects enabled.");
        } else {
            llInstantMessage(user, "Battery-based communication effects disabled.");
        }
        openCommsMenu(user);
    }
    else if (action == "SET_CHANNEL") {
        gMenuChannel = (integer)("0x" + llGetSubString((string)user, -7, -1));
        llListenRemove(gListenHandle);
        gListenHandle = llListen(gMenuChannel, "", user, "");
        llTextBox(user, "\nEnter new communications channel (integer):\n\nCurrent channel: " + (string)comms_channel + "\n\nNote: Valid range is 1-2147483647", gMenuChannel);
        llSetTimerEvent(60.0);
    }
    else if (action == "RESET_CONFIG") {
        gCommsEnabled = TRUE;
        gPersonaFilterEnabled = TRUE;
        gBatteryEffectsEnabled = TRUE;
        gActiveCommChannel = "Public";
        llInstantMessage(user, "Communications configuration reset to defaults.");
        openCommsMenu(user);
    }
    else if (action == "TEST_COMMS") {
        if (gPowerState && gCommsEnabled) {
            string testMsg = getPersonaPrefix(gCurrentPersona, gSpeechMode) + " Communications test successful.";
            llSay(0, applyBatteryEffects(testMsg));
            llInstantMessage(user, "Test message transmitted.");
        } else {
            llInstantMessage(user, "Communications offline or disabled.");
        }
    }
    else if (action == "REFRESH") {
        llInstantMessage(user, "Refreshing communications data...");
        openCommsMenu(user);
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

// --- COMMS MODULE FUNCTIONS ---

// Get persona-appropriate chat prefix
string getPersonaPrefix(string persona, string speechMode) {
    if (persona == "Default") {
        return "[" + gUnitName + "]";
    } else {
        return "[" + gUnitName + ":" + persona + "]";
    }
}

// Apply personality-based filtering to messages
string applyPersonalityFilter(string message, string persona, string speechMode) {
    if (!gPersonaFilterEnabled) return message;
    
    // Basic personality filtering based on persona
    if (persona == "Professional") {
        // More formal speech patterns
        message = llDumpList2String(llParseString2List(message, ["gonna"], []), "going to");
        message = llDumpList2String(llParseString2List(message, ["wanna"], []), "want to");
        message = llDumpList2String(llParseString2List(message, ["kinda"], []), "kind of");
    }
    else if (persona == "Casual") {
        // More relaxed speech patterns (minimal changes)
        return message;
    }
    else if (persona == "Technical") {
        // Add technical precision
        if (llSubStringIndex(llToLower(message), "error") != -1) {
            message = "System alert: " + message;
        }
    }
    
    return message;
}

// Apply battery-based effects to communication
string applyBatteryEffects(string message) {
    if (!gBatteryEffectsEnabled) return message;
    
    if (gBatteryLevel <= 5.0) {
        // Critical power - garbled/cut messages
        return "...sys...fail..." + llGetSubString(message, 0, 10) + "...";
    }
    else if (gBatteryLevel <= 10.0) {
        // Low power - shorter messages
        return llGetSubString(message, 0, llStringLength(message) / 2) + "...";
    }
    else if (gBatteryLevel <= 15.0) {
        // Warning power - occasional glitches
        if (llFrand(1.0) < 0.3) {
            return message + " ...signal weak...";
        }
    }
    
    return message;
}

// Handle channel changes
processChannelChange(key user, string newChannelStr) {
    integer newChannel = (integer)newChannelStr;
    
    if (newChannel < 1 || newChannel > 2147483647) {
        llInstantMessage(user, "Invalid channel. Must be between 1 and 2147483647.");
        return;
    }
    
    // Remove old listener and set up new one
    llListenRemove(gCommsListenHandle);
    comms_channel = newChannel;
    gCommsListenHandle = llListen(comms_channel, "", g_kWearer, "");
    
    llInstantMessage(user, "Communications channel changed to: " + (string)comms_channel);
    llInstantMessage(g_kWearer, "// Chat redirection active. Type on channel " + (string)comms_channel + " to speak as " + gUnitName + " //");
}

// Build and display the communications control menu
openCommsMenu(key user) {
    gCurrentMenuUser = user;
    gMenuChannel = (integer)("0x" + llGetSubString((string)user, -7, -1));
    
    string dialog = "\n[ COMMUNICATIONS MODULE ]\n";
    dialog += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
    dialog += "Battery: " + (string)((integer)gBatteryLevel) + "%\n";
    dialog += "Power: " + (string)gPowerState + "\n";
    dialog += "Channel: " + (string)comms_channel + "\n";
    dialog += "Persona: " + gCurrentPersona + "\n";
    dialog += "Speech Mode: " + gSpeechMode + "\n\n";
    
    // Status indicators
    string commsStatus = "ENABLED";
    if (!gCommsEnabled) commsStatus = "DISABLED";
    
    string filterStatus = "ENABLED";
    if (!gPersonaFilterEnabled) filterStatus = "DISABLED";
    
    string effectsStatus = "ENABLED";
    if (!gBatteryEffectsEnabled) effectsStatus = "DISABLED";
    
    dialog += "Communications Status:\n";
    dialog += "• Voice Protocol: " + commsStatus + "\n";
    dialog += "• Persona Filter: " + filterStatus + "\n";
    dialog += "• Battery Effects: " + effectsStatus + "\n";
    dialog += "• Active Channel: " + gActiveCommChannel + "\n";
    
    // Battery warnings
    if (gBatteryLevel <= 15.0) {
        dialog += "\n⚠️ LOW POWER AFFECTS COMMUNICATION\n";
    }
    
    dialog += "\nType on channel " + (string)comms_channel + " to transmit.";
    
    list buttons = [
        "[COMMS: " + commsStatus + "]",
        "[FILTER: " + filterStatus + "]",
        "[EFFECTS: " + effectsStatus + "]",
        "Set Channel",
        "Test Comms",
        "Reset Config",
        "Refresh",
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
        
        // Register this module with the main system
        llMessageLinked(LINK_SET, MODULE_REGISTER, "Comms", NULL_KEY);
        
        // Set up listening on the comms channel
        gCommsListenHandle = llListen(comms_channel, "", g_kWearer, "");
        
        llOwnerSay("🤖 Comms Module v3.0 initialized with OpenCollar auth system.");
        llInstantMessage(g_kWearer, "// Chat redirection active. Type on channel " + (string)comms_channel + " to speak as " + gUnitName + " //");
    }

    link_message(integer sender, integer num, string msg, key id) {
        if (num == AUTH_REPLY) {
            // Parse auth reply: "AuthReply|userKey|authLevel"
            list parts = llParseString2List(msg, ["|"], []);
            if (llList2String(parts, 0) == "AuthReply") {
                key user = (key)llList2String(parts, 1);
                integer authLevel = (integer)llList2String(parts, 2);
                string originalAction = (string)id; // The action from AUTH_REQUEST
                
                processCommsAuth(user, authLevel, originalAction);
            }
        }
        else if (num == OPEN_MY_MENU) {
            key user = (key)msg;
            // Request auth for comms menu access
            requestCommsAuth(user, "COMMS_MENU");
        }
        else if (num == UPDATE_BATTERY) {
            gBatteryLevel = (float)msg;
        } 
        else if (num == UPDATE_UNIT_INFO) {
            gUnitName = msg;
        }
        else if (num == UPDATE_PERSONA_STATUS) {
            gCurrentPersona = msg;
            gPersonaChatPrefix = getPersonaPrefix(gCurrentPersona, gSpeechMode);
            llInstantMessage(g_kWearer, "// Speech patterns updated for persona: " + gCurrentPersona + " //");
        }
        else if (num == SET_SPEECH_MODE) {
            gSpeechMode = msg;
            gPersonaChatPrefix = getPersonaPrefix(gCurrentPersona, gSpeechMode);
            llInstantMessage(g_kWearer, "// Speech protocol updated to: " + gSpeechMode + " //");
        } 
        else if (num == POWER_STATE_CHANGE) {
            if (msg == "ON") {
                gPowerState = TRUE;
                llInstantMessage(g_kWearer, "// Communications online //");
            }
            else {
                gPowerState = FALSE;
                llInstantMessage(g_kWearer, "// Communications offline //");
            }
        }
        else if (num == RELAY_CHAT_MESSAGE) {
            // Handle chat messages from other modules (like persona responses)
            if (gPowerState && gCommsEnabled) {
                string prefix = getPersonaPrefix(gCurrentPersona, gSpeechMode);
                string filtered = applyPersonalityFilter(msg, gCurrentPersona, gSpeechMode);
                string final_message = applyBatteryEffects(filtered);
                
                if (final_message != "") {
                    llSay(0, prefix + " " + final_message);
                }
            }
        }
    }

    listen(integer channel, string name, key id, string message) {
        // Handle comms channel messages
        if (channel == comms_channel) {
            if (!gPowerState) {
                llInstantMessage(g_kWearer, "// Communications offline - unable to transmit //");
                return;
            }
            
            if (!gCommsEnabled) {
                llInstantMessage(g_kWearer, "// Communications disabled by administrator //");
                return;
            }
            
            // Only process messages from the wearer
            if (id != g_kWearer) return;
            
            // Get persona-appropriate prefix
            string prefix = getPersonaPrefix(gCurrentPersona, gSpeechMode);
            
            // Apply personality filters
            string filtered_message = applyPersonalityFilter(message, gCurrentPersona, gSpeechMode);
            
            // Apply battery-based effects
            string final_message = applyBatteryEffects(filtered_message);
            
            // Output the message if it survived battery effects
            if (final_message != "") {
                llSay(0, prefix + " " + final_message);
                
                // Notify persona module that chat was sent (for potential responses)
                llMessageLinked(LINK_SET, RELAY_CHAT_MESSAGE, message, g_kWearer);
            } else {
                llInstantMessage(g_kWearer, "// Transmission failed - insufficient power //");
            }
            
            // Special commands
            if (llToLower(message) == "status") {
                string status = prefix + " Unit status: " + gCurrentPersona + " persona active, ";
                status += "power at " + (string)((integer)gBatteryLevel) + "%, ";
                if (gPowerState) status += "all systems operational.";
                else status += "systems offline.";
                
                llSay(0, applyBatteryEffects(status));
            }
            
            return;
        }
        
        // Handle menu interactions
        if (channel == gMenuChannel) {
            llListenRemove(gListenHandle);
            
            if (message == "Close") {
                llInstantMessage(id, "Communications menu closed.");
                return;
            }
            
            // Handle textbox input for channel change
            integer newChannel = (integer)message;
            if (newChannel > 0) {
                processChannelChange(id, message);
                return;
            }
            
            // Handle menu button selections - all require auth
            if (llSubStringIndex(message, "[COMMS:") != -1) {
                requestCommsAuth(id, "TOGGLE_COMMS");
            }
            else if (llSubStringIndex(message, "[FILTER:") != -1) {
                requestCommsAuth(id, "TOGGLE_PERSONA_FILTER");
            }
            else if (llSubStringIndex(message, "[EFFECTS:") != -1) {
                requestCommsAuth(id, "TOGGLE_BATTERY_EFFECTS");
            }
            else if (message == "Set Channel") {
                requestCommsAuth(id, "SET_CHANNEL");
            }
            else if (message == "Reset Config") {
                requestCommsAuth(id, "RESET_CONFIG");
            }
            else if (message == "Test Comms") {
                requestCommsAuth(id, "TEST_COMMS");
            }
            else if (message == "Refresh") {
                requestCommsAuth(id, "REFRESH");
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
