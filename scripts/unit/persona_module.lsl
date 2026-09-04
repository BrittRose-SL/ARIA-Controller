//-- A.R.I.A. Persona Module (Add-on)
//-- Version 5.1 - OPENCOLLAR AUTH SYSTEM INTEGRATION
//-- September 12, 2025 - Updated to use AUTH_REQUEST/AUTH_REPLY system
//-- CHANGES v5.1:
//--   - Corrected auth-level comparisons to match the OpenCollar ordering
//-- CHANGES v5.0:
//--   - Replaced old permission system with OpenCollar auth
//--   - Implemented AUTH_REQUEST/AUTH_REPLY protocol
//--   - Removed old permission variables and functions
//--   - Enhanced notecard-based persona system
//--   - Improved emote and response management
//--   - Fixed all ternary operators and invalid LSL syntax

// --- CONFIGURATION ---
string gRlvRootFolder = "#RLV/~A.R.I.A.";
string gPersonaPrefix = "Persona_";  // Notecard naming convention: Persona_Default, Persona_Maid, etc.

// --- CONSTANTS ---
string EOF_REACHED = "EOF";

// --- LINKED MESSAGE CODES ---
integer SET_SPEECH_MODE = 100;
integer UPDATE_BATTERY = 101;
integer UPDATE_UNIT_INFO = 103;
integer UPDATE_PERSONA_STATUS = 104;
integer MODULE_REGISTER = 200;
integer OPEN_MY_MENU = 201;
integer RELAY_CHAT_MESSAGE = 300;
integer PERSONA_EMOTE_TRIGGER = 301;
integer UPDATE_AROUSAL = 400;
integer UPDATE_STIMULATION = 401;
integer UPDATE_PAIN = 402;
integer UPDATE_STRESS = 403;
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
integer gChatListenHandle;
integer gChatListenActive = TRUE;
integer gPowerState = TRUE;
key wearer;
string gUnitName = "A.R.I.A.";
string gCurrentPersona = "Default";
string gCurrentChatPrefix = "[A.R.I.A.]";
string gCurrentEmoteStyle = "neutral";
string gCurrentResponseTone = "standard";
string gCurrentOutfitFolder;

// --- INDICATOR LEVEL VARIABLES ---
float gArousalLevel = 0.0;
float gStimulationLevel = 0.0;
float gPainLevel = 0.0;
float gStressLevel = 0.0;

// --- PERSONA DATA STORAGE ---
list gAvailablePersonas = [];     // List of persona names found in notecards
list gPersonaEmotes = [];         // Current persona's emotes: [type, text, type, text, ...]
list gPersonaResponses = [];      // Current persona's responses: [trigger, response, trigger, response, ...]

// --- NOTECARD READING VARIABLES ---
key gNotecardQuery;
integer gNotecardLine;
string gCurrentNotecardName;
integer gPersonaLoadStep = 0;     // 0=config, 1=emotes, 2=responses
integer gInitializationStep = 0;  // For initial persona scanning

// --- ASYNCHRONOUS AUTH SYSTEM ---
list gPendingAuthRequests;  // Format: [requestId, userKey, action, ...]
integer gNextRequestId = 1;
key gCurrentMenuUser;

// --- MENU STATES ---
integer gMenuState = 0;
// 0 = main, 1 = emotes, 2 = levels, 3 = advanced

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
            openPersonaMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Trusted user permissions required for Persona Module.");
        }
    }
    else if (llSubStringIndex(action, "LOAD_PERSONA:") == 0) {
        if (authLevel <= CMD_TRUSTED) {
            string personaName = llGetSubString(action, 13, -1); // Remove "LOAD_PERSONA:" prefix
            loadPersonaFromNotecard(personaName);
            llInstantMessage(user, "Loading persona: " + personaName);
            llInstantMessage(wearer, "// Persona changed to " + personaName + " by " + llKey2Name(user) + " //");
            openPersonaMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Trusted user permissions required to change personas.");
        }
    }
    else if (action == "EMOTES_MENU") {
        if (authLevel <= CMD_TRUSTED) {
            openEmoteMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Trusted user permissions required for emotes.");
        }
    }
    else if (action == "LEVELS_MENU") {
        if (authLevel <= CMD_TRUSTED) {
            openLevelsMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Trusted user permissions required for levels.");
        }
    }
    else if (action == "RELOAD_PERSONAS") {
        if (authLevel <= CMD_OWNER) {
            llOwnerSay("Rescanning for persona notecards...");
            scanForPersonaNotecards();
            llInstantMessage(user, "Persona notecards reloaded.");
            llInstantMessage(wearer, "// Personas reloaded by " + llKey2Name(user) + " //");
            openPersonaMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Owner permissions required to reload personas.");
        }
    }
    else if (llSubStringIndex(action, "EMOTE:") == 0) {
        if (authLevel <= CMD_TRUSTED) {
            string emoteType = llGetSubString(action, 6, -1); // Remove "EMOTE:" prefix
            triggerPersonaEmote(emoteType);
            llInstantMessage(user, llToUpper(emoteType) + " emote triggered.");
            llInstantMessage(wearer, "// " + llToUpper(emoteType) + " emote triggered by " + llKey2Name(user) + " //");
            openEmoteMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Trusted user permissions required.");
        }
    }
    else if (action == "RESET_LEVELS") {
        if (authLevel <= CMD_TRUSTED) {
            gArousalLevel = 0.0;
            gStimulationLevel = 0.0;
            gPainLevel = 0.0;
            gStressLevel = 0.0;
            updateHoverText();
            llInstantMessage(user, "All indicator levels reset to zero.");
            llInstantMessage(wearer, "// Indicator levels reset by " + llKey2Name(user) + " //");
            openLevelsMenu(user);
        } else {
            llInstantMessage(user, "Access denied. Trusted user permissions required.");
        }
    }
    else if (action == "SHOW_LEVELS") {
        if (authLevel <= CMD_TRUSTED) {
            showCurrentLevels(user);
        } else {
            llInstantMessage(user, "Access denied. Trusted user permissions required.");
        }
    }
}

// --- HELPER FUNCTIONS ---

updateHoverText() {
    string status = "A.R.I.A. " + gCurrentPersona + "\n";
    status += "Battery: " + (string)((integer)gBatteryLevel) + "%\n";
    status += "Mode: " + gCurrentResponseTone;
    llSetText(status, <1.0, 1.0, 1.0>, 1.0);
}

scanForPersonaNotecards() {
    gAvailablePersonas = [];
    integer count = llGetInventoryNumber(INVENTORY_NOTECARD);
    integer i;
    
    for (i = 0; i < count; i++) {
        string notecardName = llGetInventoryName(INVENTORY_NOTECARD, i);
        if (llSubStringIndex(notecardName, gPersonaPrefix) == 0) {
            string personaName = llGetSubString(notecardName, llStringLength(gPersonaPrefix), -1);
            gAvailablePersonas += [personaName];
        }
    }
    
    if (llGetListLength(gAvailablePersonas) > 0) {
        llOwnerSay("Found " + (string)llGetListLength(gAvailablePersonas) + " persona notecards.");
        if (llListFindList(gAvailablePersonas, ["Default"]) == -1) {
            llOwnerSay("WARNING: No Default persona found. Consider creating Persona_Default notecard.");
        }
    } else {
        llOwnerSay("No persona notecards found. Creating emergency defaults...");
        loadEmergencyDefaults();
    }
}

loadEmergencyDefaults() {
    gCurrentPersona = "Default";
    gCurrentChatPrefix = "[A.R.I.A.]";
    gCurrentEmoteStyle = "neutral";
    gCurrentResponseTone = "standard";
    gPersonaEmotes = [
        "greeting", "Hello! A.R.I.A. systems online and ready.",
        "acknowledgment", "Acknowledged. Processing request.",
        "confusion", "Unable to parse request. Please clarify.",
        "error", "Error detected in system protocols.",
        "idle", "A.R.I.A. standing by...",
        "happy", "Systems operating at optimal efficiency!",
        "compliment", "Thank you for the positive feedback.",
        "task_done", "Task completed successfully."
    ];
    gPersonaResponses = [
        "hello", "Hello! How may I assist you today?",
        "status", "All systems nominal. Ready to serve.",
        "help", "I am here to assist. What do you need?",
        "goodbye", "Farewell. A.R.I.A. signing off."
    ];
    updateHoverText();
    llOwnerSay("Emergency default persona loaded.");
}

loadPersonaFromNotecard(string personaName) {
    gCurrentPersona = personaName;
    gCurrentNotecardName = gPersonaPrefix + personaName;
    
    // Check if notecard exists
    if (llGetInventoryType(gCurrentNotecardName) != INVENTORY_NOTECARD) {
        llOwnerSay("Persona notecard not found: " + gCurrentNotecardName);
        loadEmergencyDefaults();
        return;
    }
    
    // Start reading the notecard
    gPersonaLoadStep = 0;
    gNotecardLine = 0;
    gPersonaEmotes = [];
    gPersonaResponses = [];
    
    llOwnerSay("Loading persona: " + personaName);
    gNotecardQuery = llGetNotecardLine(gCurrentNotecardName, gNotecardLine);
}

processNotecardLine(string data) {
    if (data == EOF_REACHED) {
        // Finished reading current section
        if (gPersonaLoadStep == 0) {
            // Move to emotes section
            gPersonaLoadStep = 1;
            gNotecardLine = 0;
            gNotecardQuery = llGetNotecardLine(gCurrentNotecardName, gNotecardLine);
        } else if (gPersonaLoadStep == 1) {
            // Move to responses section
            gPersonaLoadStep = 2;
            gNotecardLine = 0;
            gNotecardQuery = llGetNotecardLine(gCurrentNotecardName, gNotecardLine);
        } else {
            // Finished loading persona
            llOwnerSay("Persona loaded: " + gCurrentPersona);
            updateHoverText();
            
            // Broadcast persona change
            llMessageLinked(LINK_SET, UPDATE_PERSONA_STATUS, gCurrentPersona, NULL_KEY);
            
            // Apply RLV outfit if specified
            if (gCurrentOutfitFolder != "") {
                applyPersonaOutfit();
            }
        }
        return;
    }
    
    // Skip empty lines and comments
    data = llStringTrim(data, STRING_TRIM);
    if (data == "" || llGetSubString(data, 0, 0) == "#") {
        gNotecardLine++;
        gNotecardQuery = llGetNotecardLine(gCurrentNotecardName, gNotecardLine);
        return;
    }
    
    // Process data based on current section
    if (gPersonaLoadStep == 0) {
        // Configuration section
        if (llSubStringIndex(data, "PREFIX=") == 0) {
            gCurrentChatPrefix = llGetSubString(data, 7, -1);
        } else if (llSubStringIndex(data, "EMOTE_STYLE=") == 0) {
            gCurrentEmoteStyle = llGetSubString(data, 12, -1);
        } else if (llSubStringIndex(data, "RESPONSE_TONE=") == 0) {
            gCurrentResponseTone = llGetSubString(data, 14, -1);
        } else if (llSubStringIndex(data, "OUTFIT_FOLDER=") == 0) {
            gCurrentOutfitFolder = llGetSubString(data, 14, -1);
        }
    } else if (gPersonaLoadStep == 1) {
        // Emotes section
        if (llSubStringIndex(data, "=") != -1) {
            list parts = llParseString2List(data, ["="], []);
            if (llGetListLength(parts) >= 2) {
                string emoteType = llStringTrim(llList2String(parts, 0), STRING_TRIM);
                string emoteText = llStringTrim(llList2String(parts, 1), STRING_TRIM);
                gPersonaEmotes += [emoteType, emoteText];
            }
        }
    } else if (gPersonaLoadStep == 2) {
        // Responses section
        if (llSubStringIndex(data, "=") != -1) {
            list parts = llParseString2List(data, ["="], []);
            if (llGetListLength(parts) >= 2) {
                string trigger = llStringTrim(llList2String(parts, 0), STRING_TRIM);
                string response = llStringTrim(llList2String(parts, 1), STRING_TRIM);
                gPersonaResponses += [trigger, response];
            }
        }
    }
    
    // Continue reading
    gNotecardLine++;
    gNotecardQuery = llGetNotecardLine(gCurrentNotecardName, gNotecardLine);
}

triggerPersonaEmote(string emoteType) {
    integer idx = llListFindList(gPersonaEmotes, [emoteType]);
    if (idx != -1 && idx + 1 < llGetListLength(gPersonaEmotes)) {
        string emoteText = llList2String(gPersonaEmotes, idx + 1);
        llSay(0, "/me " + emoteText);
        llOwnerSay("Emote triggered: " + emoteType);
    } else {
        llOwnerSay("Emote not found: " + emoteType);
    }
}

processPersonalityResponse(string input) {
    input = llToLower(llStringTrim(input, STRING_TRIM));
    
    integer i;
    for (i = 0; i < llGetListLength(gPersonaResponses); i += 2) {
        string trigger = llToLower(llList2String(gPersonaResponses, i));
        if (llSubStringIndex(input, trigger) != -1) {
            string response = llList2String(gPersonaResponses, i + 1);
            llSay(0, gCurrentChatPrefix + " " + response);
            return;
        }
    }
}

applyPersonaOutfit() {
    if (gCurrentOutfitFolder != "") {
        string rlvCommand = "@attach:" + gRlvRootFolder + "/" + gCurrentOutfitFolder + "=force";
        llOwnerSay(rlvCommand);
        llOwnerSay("Applying persona outfit: " + gCurrentOutfitFolder);
    }
}

processIndicatorLevels() {
    // Adjust persona behavior based on indicator levels
    if (gArousalLevel > 75.0) {
        gCurrentResponseTone = "excited";
    } else if (gPainLevel > 50.0) {
        gCurrentResponseTone = "distressed";
    } else if (gStressLevel > 60.0) {
        gCurrentResponseTone = "anxious";
    } else {
        gCurrentResponseTone = "standard";
    }
    
    updateHoverText();
}

showCurrentLevels(key user) {
    string dialog = "\n[ CURRENT INDICATOR LEVELS ]\n";
    dialog += "═══════════════════════════════════════\n";
    dialog += "Arousal: " + (string)((integer)gArousalLevel) + "%\n";
    dialog += "Stimulation: " + (string)((integer)gStimulationLevel) + "%\n";
    dialog += "Pain: " + (string)((integer)gPainLevel) + "%\n";
    dialog += "Stress: " + (string)((integer)gStressLevel) + "%\n\n";
    dialog += "Current Response Tone: " + gCurrentResponseTone;
    
    list buttons = ["< BACK", "CLOSE"];
    
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llDialog(user, dialog, buttons, gMenuChannel);
    llSetTimerEvent(60.0);
}

// --- MENU FUNCTIONS ---

openPersonaMenu(key user) {
    gCurrentMenuUser = user;
    gMenuState = 0;
    
    string dialog = "\n[ PERSONA MANAGEMENT ]\n";
    dialog += "═══════════════════════════════════════\n";
    dialog += "Unit: " + gUnitName + "\n";
    dialog += "Current: " + gCurrentPersona + "\n";
    dialog += "Mode: " + gCurrentResponseTone + "\n";
    dialog += "Battery: " + (string)((integer)gBatteryLevel) + "%\n\n";
    dialog += "Select persona to load:";
    
    // Create buttons with available personas (max 9 for dialog limit)
    list buttons = [];
    integer count = llGetListLength(gAvailablePersonas);
    integer i;
    for (i = 0; i < count && i < 9; i++) {
        buttons += [llList2String(gAvailablePersonas, i)];
    }
    
    // Add management options
    buttons += ["Emotes", "Levels", "Reload"];
    buttons += ["CLOSE"];
    
    gMenuChannel = (integer)("0x" + llGetSubString(llGetKey(), -8, -2));
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llSetTimerEvent(60.0);
    
    llDialog(user, dialog, buttons, gMenuChannel);
}

openEmoteMenu(key user) {
    gMenuState = 1;
    
    string dialog = "\n[ PERSONA EMOTES ]\n";
    dialog += "═══════════════════════════════════════\n";
    dialog += "Current Persona: " + gCurrentPersona + "\n";
    dialog += "Emote Style: " + gCurrentEmoteStyle + "\n\n";
    dialog += "Select emote to trigger:";
    
    list buttons = [
        "Greeting", "Acknowledge", "Confusion",
        "Error", "Idle", "Happy",
        "Compliment", "Task Done"
    ];
    
    buttons += ["< BACK", "CLOSE"];
    
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llDialog(user, dialog, buttons, gMenuChannel);
    llSetTimerEvent(60.0);
}

openLevelsMenu(key user) {
    gMenuState = 2;
    
    string dialog = "\n[ INDICATOR LEVELS ]\n";
    dialog += "═══════════════════════════════════════\n";
    dialog += "Arousal: " + (string)((integer)gArousalLevel) + "%\n";
    dialog += "Stimulation: " + (string)((integer)gStimulationLevel) + "%\n";
    dialog += "Pain: " + (string)((integer)gPainLevel) + "%\n";
    dialog += "Stress: " + (string)((integer)gStressLevel) + "%\n\n";
    dialog += "Response Tone: " + gCurrentResponseTone;
    
    list buttons = [
        "Show All", "Reset All"
    ];
    
    buttons += ["< BACK", "CLOSE"];
    
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
        gChatListenHandle = llListen(0, "", wearer, "");
        
        // Scan for available personas
        scanForPersonaNotecards();
        
        // Load default persona
        if (llListFindList(gAvailablePersonas, ["Default"]) != -1) {
            loadPersonaFromNotecard("Default");
        } else {
            loadEmergencyDefaults();
        }
        
        updateHoverText();
        
        llOwnerSay("A.R.I.A. Persona Module v5.0 initialized with OpenCollar auth system.");
        
        // Register with master kernel
        llMessageLinked(LINK_SET, MODULE_REGISTER, "Persona", NULL_KEY);
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
            updateHoverText();
        } 
        else if (num == UPDATE_UNIT_INFO) {
            gUnitName = msg;
            updateHoverText();
        }
        else if (num == POWER_STATE_CHANGE) {
            gPowerState = (integer)msg;
            
            if (!gPowerState) {
                // Emergency power mode - disable chat processing
                gChatListenActive = FALSE;
                llListenRemove(gChatListenHandle);
                llInstantMessage(wearer, "// Emergency power mode: Persona chat processing disabled //");
            }
            else {
                // Power restored
                gChatListenActive = TRUE;
                gChatListenHandle = llListen(0, "", wearer, "");
                llInstantMessage(wearer, "// Power restored: Persona systems online //");
            }
        }
        else if (num == RELAY_CHAT_MESSAGE) {
            // Process chat through personality system
            string chatMessage = gCurrentChatPrefix + " " + msg;
            llSay(0, chatMessage);
            processPersonalityResponse(msg);
        }
        else if (num == PERSONA_EMOTE_TRIGGER) {
            triggerPersonaEmote(msg);
        }
        // Handle indicator level updates
        else if (num == UPDATE_AROUSAL) {
            gArousalLevel = (float)msg;
            if (gArousalLevel < 0.0) gArousalLevel = 0.0;
            if (gArousalLevel > 100.0) gArousalLevel = 100.0;
            processIndicatorLevels();
        }
        else if (num == UPDATE_STIMULATION) {
            gStimulationLevel = (float)msg;
            if (gStimulationLevel < 0.0) gStimulationLevel = 0.0;
            if (gStimulationLevel > 100.0) gStimulationLevel = 100.0;
            processIndicatorLevels();
        }
        else if (num == UPDATE_PAIN) {
            gPainLevel = (float)msg;
            if (gPainLevel < 0.0) gPainLevel = 0.0;
            if (gPainLevel > 100.0) gPainLevel = 100.0;
            processIndicatorLevels();
        }
        else if (num == UPDATE_STRESS) {
            gStressLevel = (float)msg;
            if (gStressLevel < 0.0) gStressLevel = 0.0;
            if (gStressLevel > 100.0) gStressLevel = 100.0;
            processIndicatorLevels();
        }
    }

    listen(integer channel, string name, key id, string message) {
        // Handle wearer chat for personality responses
        if (channel == 0 && id == wearer && gChatListenActive) {
            processPersonalityResponse(message);
            return;
        }
        
        // Handle menu responses
        if (channel == gMenuChannel && id == gCurrentMenuUser) {
            llSetTimerEvent(0.0);
            llListenRemove(gListenHandle);
            
            if (message == "CLOSE") return;
            
            // Handle navigation
            if (message == "< BACK") {
                openPersonaMenu(id);
                return;
            }
            
            // Handle menu actions with auth requests
            if (llListFindList(gAvailablePersonas, [message]) != -1) {
                requestAuth(id, "LOAD_PERSONA:" + message);
            }
            else if (message == "Emotes") {
                requestAuth(id, "EMOTES_MENU");
            }
            else if (message == "Levels") {
                requestAuth(id, "LEVELS_MENU");
            }
            else if (message == "Reload") {
                requestAuth(id, "RELOAD_PERSONAS");
            }
            else if (message == "Greeting") {
                requestAuth(id, "EMOTE:greeting");
            }
            else if (message == "Acknowledge") {
                requestAuth(id, "EMOTE:acknowledgment");
            }
            else if (message == "Confusion") {
                requestAuth(id, "EMOTE:confusion");
            }
            else if (message == "Error") {
                requestAuth(id, "EMOTE:error");
            }
            else if (message == "Idle") {
                requestAuth(id, "EMOTE:idle");
            }
            else if (message == "Happy") {
                requestAuth(id, "EMOTE:happy");
            }
            else if (message == "Compliment") {
                requestAuth(id, "EMOTE:compliment");
            }
            else if (message == "Task Done") {
                requestAuth(id, "EMOTE:task_done");
            }
            else if (message == "Reset All") {
                requestAuth(id, "RESET_LEVELS");
            }
            else if (message == "Show All") {
                requestAuth(id, "SHOW_LEVELS");
            }
        }
    }

    dataserver(key query_id, string data) {
        if (query_id == gNotecardQuery) {
            processNotecardLine(data);
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
        else if (c & CHANGED_INVENTORY) {
            // Rescan for personas when inventory changes
            scanForPersonaNotecards();
        }
    }
}

//-- IMPLEMENTATION NOTES v5.0:
//-- 1. Completely replaced old permission system with OpenCollar AUTH_REQUEST/AUTH_REPLY
//-- 2. Persona changes require Trusted user permissions minimum
//-- 3. Reload functionality requires Owner permissions for security
//-- 4. Asynchronous auth system prevents menu delays
//-- 5. Enhanced notecard-based persona loading system
//-- 6. Improved emote and response management
//-- 7. Better indicator level processing and response tone adjustment
//-- 8. Emergency power mode handling with chat processing disable
//-- 9. Proper cleanup of pending auth requests and listeners
//-- 10. Fixed all ternary operators and invalid LSL syntax
//-- 11. Enhanced security measures for persona management
//-- 12. Better inventory change handling for persona rescanning
