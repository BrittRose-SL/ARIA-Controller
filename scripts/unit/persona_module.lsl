//-- A.R.I.A. Persona Module (Add-on)
//-- Version 4.1 - FIXED PERMISSIONS SYSTEM + NOTECARD-BASED PERSONAS
//-- CHANGELOG v4.1:
//-- - Added new standardized permissions system from template
//-- - Fixed permission validation in all menu functions
//-- - Added proper config synchronization with master kernel
//-- - Improved access level checking for trusted users
//-- - Added permission status display in menus

// --- CONFIGURATION ---
string gRlvRootFolder = "#RLV/~A.R.I.A.";
string gPersonaPrefix = "Persona_";  // Notecard naming convention: Persona_Default, Persona_Maid, etc.

// --- CONSTANTS ---
string EOF_REACHED = "EOF";

// --- LINKED MESSAGE CODES ---
integer SET_SPEECH_MODE = 100;
integer UPDATE_BATTERY = 101;
integer UPDATE_CONFIG = 102;
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

// --- PERMISSION VARIABLES (REQUIRED) ---
list gAdministrators;
list gTrustedUsers;
key wearer;
integer gWearerAdminMode = TRUE;
integer gConfigReceived = FALSE;

// --- PERMISSION LEVELS (REQUIRED) ---
integer ACCESS_ADMIN = 4;
integer ACCESS_TRUSTED = 3;
integer ACCESS_WEARER = 2;
integer ACCESS_PUBLIC = 1;

// --- STATE VARIABLES ---
float gBatteryLevel = 100.0;
integer gMenuChannel;
integer gListenHandle;
integer gChatListenHandle;
integer gChatListenActive = TRUE;
key gAdministrator;
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

// --- PERMISSION FUNCTIONS (REQUIRED) ---

integer getAccessLevel(key id) {
    // Check administrator list first
    if (llListFindList(gAdministrators, [id]) != -1) return ACCESS_ADMIN;
    
    // Check trusted users list
    if (llListFindList(gTrustedUsers, [id]) != -1) return ACCESS_TRUSTED;
    
    // Check if it's the wearer
    if (id == wearer) {
        // Wearer access depends on wearer admin mode
        if (gWearerAdminMode) {
            return ACCESS_ADMIN;
        } else {
            return ACCESS_WEARER;
        }
    }
    
    // Everyone else gets public access
    return ACCESS_PUBLIC;
}

integer checkModuleAccess(key user, integer requiredLevel, string moduleName) {
    integer access = getAccessLevel(user);
    
    if (access < requiredLevel) {
        string levelName = "Public";
        if (requiredLevel == ACCESS_WEARER) levelName = "Wearer";
        else if (requiredLevel == ACCESS_TRUSTED) levelName = "Trusted User";
        else if (requiredLevel == ACCESS_ADMIN) levelName = "Administrator";
        
        llInstantMessage(user, "Access denied. " + levelName + " permissions required for " + moduleName + ".");
        return FALSE;
    }
    
    if (!gConfigReceived) {
        llInstantMessage(user, "Module permissions not synchronized. Please try again in a moment.");
        return FALSE;
    }
    
    return TRUE;
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

openPersonaMenu(key user) {
    // Check permissions first
    if (!checkModuleAccess(user, ACCESS_TRUSTED, "Persona Module")) {
        return;
    }
    
    integer access = getAccessLevel(user);
    
    string dialog = "\n[ PERSONA MANAGEMENT ]\n";
    dialog += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
    dialog += "Unit: " + gUnitName + "\n";
    dialog += "Current: " + gCurrentPersona + "\n";
    dialog += "Mode: " + gCurrentResponseTone + "\n";
    dialog += "Access Level: ";
    if (access >= ACCESS_ADMIN) {
        dialog += "ADMINISTRATOR\n";
    } else if (access >= ACCESS_TRUSTED) {
        dialog += "TRUSTED USER\n";
    } else {
        dialog += "WEARER\n";
    }
    
    dialog += "Config Status: ";
    if (gConfigReceived) {
        dialog += "SYNCHRONIZED";
    } else {
        dialog += "WAITING";
    }
    dialog += "\n\nSelect persona to load:";
    
    // Create buttons with available personas
    list buttons = gAvailablePersonas;
    
    // Add management options based on access level
    if (access >= ACCESS_TRUSTED) {
        buttons += ["Emotes", "Levels"];
    }
    
    if (access >= ACCESS_ADMIN) {
        buttons += ["Reload"];
    }
    
    buttons += ["Close"];
    
    // Limit to 12 buttons for dialog
    if (llGetListLength(buttons) > 12) {
        buttons = llList2List(buttons, 0, 11);
    }
    
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llDialog(user, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

openEmoteMenu(key user) {
    // Check permissions
    if (!checkModuleAccess(user, ACCESS_TRUSTED, "Persona Emotes")) {
        return;
    }
    
    string dialog = "\n[ PERSONA EMOTES ]\n";
    dialog += "Current Persona: " + gCurrentPersona + "\n\n";
    dialog += "Select emote to trigger:";
    
    list buttons = ["Greeting", "Acknowledge", "Confusion"];
    buttons += ["Error", "Idle", "Compliment"];
    buttons += ["Task Done", "Happy", "-Back-"];
    
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llDialog(user, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

openLevelsMenu(key user) {
    // Check permissions
    if (!checkModuleAccess(user, ACCESS_TRUSTED, "Persona Levels")) {
        return;
    }
    
    string dialog = "\n[ INDICATOR LEVELS ]\n";
    dialog += "Current levels:\n";
    dialog += "Arousal: " + (string)((integer)gArousalLevel) + "%\n";
    dialog += "Stimulation: " + (string)((integer)gStimulationLevel) + "%\n";
    dialog += "Pain: " + (string)((integer)gPainLevel) + "%\n";
    dialog += "Stress: " + (string)((integer)gStressLevel) + "%\n\n";
    dialog += "Select level to view:";
    
    list buttons = ["Arousal Info", "Stim Info", "Pain Info"];
    buttons += ["Stress Info", "Reset All", "Show All"];
    buttons += ["-Back-", "Close"];
    
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llDialog(user, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

processPersonalityResponse(string message) {
    // Look for triggers in the message
    string lowerMsg = llToLower(message);
    
    // Check for personality responses
    list triggers = ["thank", "sorry", "compliment", "good", "bad", "yes", "no"];
    integer i;
    for (i = 0; i < llGetListLength(triggers); i++) {
        string trigger = llList2String(triggers, i);
        if (llSubStringIndex(lowerMsg, trigger) != -1) {
            string response = getPersonaResponse(trigger);
            if (response != "") {
                llSay(0, response);
                return;
            }
        }
    }
    
    // Random personality responses based on current tone
    if (llFrand(100.0) < 25.0) { // 25% chance of personality response
        if (gCurrentResponseTone == "polite") {
            string response = getPersonaResponse("polite_random");
            if (response != "") llSay(0, response);
        }
        else if (gCurrentResponseTone == "playful") {
            string response = getPersonaResponse("playful_random");
            if (response != "") llSay(0, response);
        }
    }
}

loadEmergencyDefaults() {
    gCurrentPersona = "Emergency";
    gCurrentChatPrefix = "[A.R.I.A.]";
    gCurrentOutfitFolder = "";
    
    gPersonaEmotes = [
        "greeting", "*system initialization complete*",
        "acknowledgment", "*confirms*",
        "confusion", "*processes request*",
        "error", "*error detected, attempting recovery*",
        "idle", "*status lights blink steadily*"
    ];
    
    gPersonaResponses = [
        "thank", "You are welcome.",
        "sorry", "No apology necessary.",
        "compliment", "*acknowledges* Thank you for the feedback."
    ];
    
    updateHoverText();
    llOwnerSay("Using emergency default persona configuration.");
}

loadPersonaFromNotecard(string personaName) {
    string notecardName = gPersonaPrefix + personaName;
    
    if (llGetInventoryType(notecardName) != INVENTORY_NOTECARD) {
        llOwnerSay("ERROR: Persona notecard '" + notecardName + "' not found!");
        return;
    }
    
    gCurrentNotecardName = notecardName;
    gNotecardLine = 0;
    gPersonaLoadStep = 0;
    
    // Reset current persona data
    gPersonaEmotes = [];
    gPersonaResponses = [];
    
    llOwnerSay("Loading persona '" + personaName + "' from notecard...");
    gNotecardQuery = llGetNotecardLine(notecardName, gNotecardLine);
}

processNotecardLine(string line) {
    // Remove leading/trailing whitespace and skip empty lines and comments
    line = llStringTrim(line, STRING_TRIM);
    if (line == "" || llSubStringIndex(line, "#") == 0) {
        gNotecardLine++;
        gNotecardQuery = llGetNotecardLine(gCurrentNotecardName, gNotecardLine);
        return;
    }
    
    // Check for section headers
    if (line == "[CONFIG]") {
        gPersonaLoadStep = 0;
        gNotecardLine++;
        gNotecardQuery = llGetNotecardLine(gCurrentNotecardName, gNotecardLine);
        return;
    }
    else if (line == "[EMOTES]") {
        gPersonaLoadStep = 1;
        gNotecardLine++;
        gNotecardQuery = llGetNotecardLine(gCurrentNotecardName, gNotecardLine);
        return;
    }
    else if (line == "[RESPONSES]") {
        gPersonaLoadStep = 2;
        gNotecardLine++;
        gNotecardQuery = llGetNotecardLine(gCurrentNotecardName, gNotecardLine);
        return;
    }
    
    // Process line based on current section
    if (gPersonaLoadStep == 0) {
        // CONFIG section
        list parts = llParseString2List(line, ["="], []);
        if (llGetListLength(parts) == 2) {
            string configKey = llStringTrim(llList2String(parts, 0), STRING_TRIM);
            string value = llStringTrim(llList2String(parts, 1), STRING_TRIM);
            
            if (configKey == "Name") {
                gCurrentPersona = value;
            }
            else if (configKey == "OutfitFolder") {
                gCurrentOutfitFolder = gRlvRootFolder + "/" + value;
            }
            else if (configKey == "ChatPrefix") {
                gCurrentChatPrefix = value;
            }
            else if (configKey == "EmoteStyle") {
                gCurrentEmoteStyle = value;
            }
            else if (configKey == "ResponseTone") {
                gCurrentResponseTone = value;
            }
        }
    }
    else if (gPersonaLoadStep == 1) {
        // EMOTES section
        list parts = llParseString2List(line, ["="], []);
        if (llGetListLength(parts) == 2) {
            string emoteType = llStringTrim(llList2String(parts, 0), STRING_TRIM);
            string emoteText = llStringTrim(llList2String(parts, 1), STRING_TRIM);
            gPersonaEmotes += [emoteType, emoteText];
        }
    }
    else if (gPersonaLoadStep == 2) {
        // RESPONSES section
        list parts = llParseString2List(line, ["="], []);
        if (llGetListLength(parts) == 2) {
            string trigger = llStringTrim(llList2String(parts, 0), STRING_TRIM);
            string response = llStringTrim(llList2String(parts, 1), STRING_TRIM);
            gPersonaResponses += [trigger, response];
        }
    }
    
    // Continue reading
    gNotecardLine++;
    gNotecardQuery = llGetNotecardLine(gCurrentNotecardName, gNotecardLine);
}

finishPersonaLoad() {
    // Apply outfit changes if specified
    if (gCurrentOutfitFolder != "") {
        llOwnerSay("@detachfolder:" + gCurrentOutfitFolder + "=force");
        llSleep(1.0);
        llOwnerSay("@attachfolder=" + gCurrentOutfitFolder + "=force");
        llOwnerSay("@unsharedwear:" + gCurrentOutfitFolder + "=add");
    }
    
    // Update other systems
    llMessageLinked(LINK_SET, SET_SPEECH_MODE, gCurrentResponseTone, NULL_KEY);
    llMessageLinked(LINK_ROOT, UPDATE_PERSONA_STATUS, gCurrentPersona, NULL_KEY);
    
    updateHoverText();
    
    // Trigger greeting emote
    llSleep(2.0);
    triggerPersonaEmote("greeting");
    
    llOwnerSay("Persona '" + gCurrentPersona + "' loaded successfully!");
    llOwnerSay("// Persona Protocol '" + gCurrentPersona + "' engaged. //");
    
    if (gAdministrator != NULL_KEY) {
        llInstantMessage(gAdministrator, "Persona '" + gCurrentPersona + "' activated with " + gCurrentResponseTone + " personality mode.");
    }
}

string getLevelCategory(float level) {
    if (level <= 25.0) return "low";
    else if (level <= 75.0) return "medium";
    else return "high";
}

string getPersonaEmote(string emoteType) {
    integer index = llListFindList(gPersonaEmotes, [emoteType]);
    if (index != -1 && index + 1 < llGetListLength(gPersonaEmotes)) {
        return llList2String(gPersonaEmotes, index + 1);
    }
    return "";
}

string getPersonaEmoteByLevel(string emoteType, float level) {
    string levelCat = getLevelCategory(level);
    string searchKey = emoteType + "_" + levelCat;
    
    // Try level-specific emote first
    string emote = getPersonaEmote(searchKey);
    if (emote != "") return emote;
    
    // Fallback to basic emote
    return getPersonaEmote(emoteType);
}

string getPersonaResponse(string trigger) {
    integer index = llListFindList(gPersonaResponses, [trigger]);
    if (index != -1 && index + 1 < llGetListLength(gPersonaResponses)) {
        return llList2String(gPersonaResponses, index + 1);
    }
    return "";
}

triggerPersonaEmote(string emoteType) {
    string emoteText = getPersonaEmote(emoteType);
    if (emoteText != "") {
        llOwnerSay(emoteText);
    }
}

processIndicatorLevels() {
    // Check for critical levels and trigger appropriate responses
    if (gArousalLevel >= 75.0) {
        string emote = getPersonaEmoteByLevel("arousal", gArousalLevel);
        if (emote != "") llOwnerSay(emote);
    }
    else if (gArousalLevel >= 25.0 && llFrand(100.0) < 15.0) {
        string emote = getPersonaEmoteByLevel("arousal", gArousalLevel);
        if (emote != "") llOwnerSay(emote);
    }
    
    if (gPainLevel >= 75.0) {
        string emote = getPersonaEmoteByLevel("pain", gPainLevel);
        if (emote != "") llOwnerSay(emote);
    }
    
    if (gStressLevel >= 75.0) {
        string emote = getPersonaEmoteByLevel("stress", gStressLevel);
        if (emote != "") llOwnerSay(emote);
    }
    
    if (gStimulationLevel >= 75.0) {
        string emote = getPersonaEmoteByLevel("stimulation", gStimulationLevel);
        if (emote != "") llOwnerSay(emote);
    }
}

// --- MAIN SCRIPT LOGIC ---

default {
    state_entry() {
        wearer = llGetOwner();
        gConfigReceived = FALSE;
        
        // Initialize with owner as admin (backup measure)
        gAdministrators = [wearer];
        gTrustedUsers = [];
        
        gMenuChannel = (integer)("0x" + llGetSubString(llGetKey(), -8, -2));
        gCurrentPersona = "Default";
        gCurrentChatPrefix = "[A.R.I.A.]";
        gCurrentEmoteStyle = "neutral";
        gCurrentResponseTone = "standard";
        
        // Initialize indicator levels
        gArousalLevel = 0.0;
        gStimulationLevel = 0.0;
        gPainLevel = 0.0;
        gStressLevel = 0.0;
        
        // Register this module
        llMessageLinked(LINK_ROOT, MODULE_REGISTER, "Persona", NULL_KEY);
        
        // Set up chat listening for personality responses
        gChatListenHandle = llListen(0, "", wearer, "");
        gChatListenActive = TRUE;
        
        llOwnerSay("Persona module v4.1 initializing with notecard-based persona system...");
        
        // Scan for persona notecards
        scanForPersonaNotecards();
    }

    dataserver(key query_id, string data) {
        if (query_id == gNotecardQuery) {
            if (data != EOF_REACHED) {
                processNotecardLine(data);
            } else {
                // Finished reading notecard
                finishPersonaLoad();
            }
        }
    }

    link_message(integer sender, integer num, string msg, key id) {
        if (num == UPDATE_BATTERY) {
            gBatteryLevel = (float)msg;
            updateHoverText();
        } 
        else if (num == UPDATE_CONFIG) {
            // Receive configuration from master kernel
            list parts = llParseString2List(msg, ["|"], []);
            if (llGetListLength(parts) >= 2) {
                string adminCsv = llList2String(parts, 0);
                string trustedCsv = llList2String(parts, 1);
                
                // Update local lists from master kernel
                if (adminCsv != "") {
                    gAdministrators = llCSV2List(adminCsv);
                } else {
                    gAdministrators = [wearer]; // Ensure owner is always admin
                }
                
                if (trustedCsv != "") {
                    gTrustedUsers = llCSV2List(trustedCsv);
                } else {
                    gTrustedUsers = [];
                }
                
                gConfigReceived = TRUE;
                llOwnerSay("Persona Module permissions updated from master kernel.");
                llOwnerSay("Administrators: " + (string)llGetListLength(gAdministrators));
                llOwnerSay("Trusted Users: " + (string)llGetListLength(gTrustedUsers));
            }
        } 
        else if (num == UPDATE_UNIT_INFO) {
            gUnitName = msg;
            updateHoverText();
        } 
        else if (num == OPEN_MY_MENU) {
            key user = (key)msg;
            
            // Check permissions using new system
            if (checkModuleAccess(user, ACCESS_TRUSTED, "Persona Module")) {
                gAdministrator = user;
                openPersonaMenu(user);
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

    listen(integer chan, string name, key id, string msg) {
        if (chan == 0 && id == wearer && gChatListenActive) {
            // Process wearer's chat for personality responses
            processPersonalityResponse(msg);
        }
        else if (chan == gMenuChannel) {
            llListenRemove(gListenHandle);
            
            // Always check permissions in listen events
            integer access = getAccessLevel(id);
            
            if (msg == "Close") {
                llInstantMessage(id, "Persona module menu closed.");
                return;
            }
            
            if (llListFindList(gAvailablePersonas, [msg]) != -1) {
                if (access >= ACCESS_TRUSTED) {
                    loadPersonaFromNotecard(msg);
                } else {
                    llInstantMessage(id, "Access denied. Trusted user permissions required to change personas.");
                }
            }
            else if (msg == "Emotes") {
                if (access >= ACCESS_TRUSTED) {
                    openEmoteMenu(id);
                } else {
                    llInstantMessage(id, "Access denied. Trusted user permissions required for emotes.");
                }
            }
            else if (msg == "Levels") {
                if (access >= ACCESS_TRUSTED) {
                    openLevelsMenu(id);
                } else {
                    llInstantMessage(id, "Access denied. Trusted user permissions required for levels.");
                }
            }
            else if (msg == "Reload") {
                if (access >= ACCESS_ADMIN) {
                    llOwnerSay("Rescanning for persona notecards...");
                    scanForPersonaNotecards();
                    llInstantMessage(id, "Persona notecards reloaded.");
                } else {
                    llInstantMessage(id, "Access denied. Administrator permissions required to reload personas.");
                }
            }
            else if (msg == "Greeting") {
                if (access >= ACCESS_TRUSTED) {
                    triggerPersonaEmote("greeting");
                    llInstantMessage(id, "Greeting emote triggered.");
                } else {
                    llInstantMessage(id, "Access denied. Trusted user permissions required.");
                }
            }
            else if (msg == "Acknowledge") {
                if (access >= ACCESS_TRUSTED) {
                    triggerPersonaEmote("acknowledgment");
                    llInstantMessage(id, "Acknowledgment emote triggered.");
                } else {
                    llInstantMessage(id, "Access denied. Trusted user permissions required.");
                }
            }
            else if (msg == "Confusion") {
                if (access >= ACCESS_TRUSTED) {
                    triggerPersonaEmote("confusion");
                    llInstantMessage(id, "Confusion emote triggered.");
                } else {
                    llInstantMessage(id, "Access denied. Trusted user permissions required.");
                }
            }
            else if (msg == "Error") {
                if (access >= ACCESS_TRUSTED) {
                    triggerPersonaEmote("error");
                    llInstantMessage(id, "Error emote triggered.");
                } else {
                    llInstantMessage(id, "Access denied. Trusted user permissions required.");
                }
            }
            else if (msg == "Idle") {
                if (access >= ACCESS_TRUSTED) {
                    triggerPersonaEmote("idle");
                    llInstantMessage(id, "Idle emote triggered.");
                } else {
                    llInstantMessage(id, "Access denied. Trusted user permissions required.");
                }
            }
            else if (msg == "Compliment") {
                if (access >= ACCESS_TRUSTED) {
                    triggerPersonaEmote("compliment");
                    llInstantMessage(id, "Compliment emote triggered.");
                } else {
                    llInstantMessage(id, "Access denied. Trusted user permissions required.");
                }
            }
            else if (msg == "Task Done") {
                if (access >= ACCESS_TRUSTED) {
                    triggerPersonaEmote("task_complete");
                    llInstantMessage(id, "Task complete emote triggered.");
                } else {
                    llInstantMessage(id, "Access denied. Trusted user permissions required.");
                }
            }
            else if (msg == "Happy") {
                if (access >= ACCESS_TRUSTED) {
                    triggerPersonaEmote("happy");
                    llInstantMessage(id, "Happy emote triggered.");
                } else {
                    llInstantMessage(id, "Access denied. Trusted user permissions required.");
                }
            }
            else if (msg == "Arousal Info") {
                if (access >= ACCESS_TRUSTED) {
                    llInstantMessage(id, "Arousal Level: " + (string)((integer)gArousalLevel) + "% (" + getLevelCategory(gArousalLevel) + ")");
                } else {
                    llInstantMessage(id, "Access denied. Trusted user permissions required.");
                }
            }
            else if (msg == "Stim Info") {
                if (access >= ACCESS_TRUSTED) {
                    llInstantMessage(id, "Stimulation Level: " + (string)((integer)gStimulationLevel) + "% (" + getLevelCategory(gStimulationLevel) + ")");
                } else {
                    llInstantMessage(id, "Access denied. Trusted user permissions required.");
                }
            }
            else if (msg == "Pain Info") {
                if (access >= ACCESS_TRUSTED) {
                    llInstantMessage(id, "Pain Level: " + (string)((integer)gPainLevel) + "% (" + getLevelCategory(gPainLevel) + ")");
                } else {
                    llInstantMessage(id, "Access denied. Trusted user permissions required.");
                }
            }
            else if (msg == "Stress Info") {
                if (access >= ACCESS_TRUSTED) {
                    llInstantMessage(id, "Stress Level: " + (string)((integer)gStressLevel) + "% (" + getLevelCategory(gStressLevel) + ")");
                } else {
                    llInstantMessage(id, "Access denied. Trusted user permissions required.");
                }
            }
            else if (msg == "Reset All") {
                if (access >= ACCESS_ADMIN) {
                    gArousalLevel = 0.0;
                    gStimulationLevel = 0.0;
                    gPainLevel = 0.0;
                    gStressLevel = 0.0;
                    llInstantMessage(id, "All indicator levels reset to 0%.");
                    llOwnerSay("Indicator levels reset by " + llKey2Name(id));
                } else {
                    llInstantMessage(id, "Access denied. Administrator permissions required to reset levels.");
                }
            }
            else if (msg == "Show All") {
                if (access >= ACCESS_TRUSTED) {
                    string report = "CURRENT INDICATOR LEVELS:\n";
                    report += "Arousal: " + (string)((integer)gArousalLevel) + "%\n";
                    report += "Stimulation: " + (string)((integer)gStimulationLevel) + "%\n";
                    report += "Pain: " + (string)((integer)gPainLevel) + "%\n";
                    report += "Stress: " + (string)((integer)gStressLevel) + "%";
                    llInstantMessage(id, report);
                } else {
                    llInstantMessage(id, "Access denied. Trusted user permissions required.");
                }
            }
            else if (msg == "-Back-") {
                // Return to main menu
                openPersonaMenu(id);
                return;
            }
            
            // Reopen appropriate menu after action
            if (msg == "Arousal Info" || msg == "Stim Info" || msg == "Pain Info" || 
                msg == "Stress Info" || msg == "Reset All" || msg == "Show All") {
                openLevelsMenu(id);
            }
            else if (msg == "Greeting" || msg == "Acknowledge" || msg == "Confusion" || 
                     msg == "Error" || msg == "Idle" || msg == "Compliment" || 
                     msg == "Task Done" || msg == "Happy") {
                openEmoteMenu(id);
            }
            else if (llListFindList(gAvailablePersonas, [msg]) == -1 && 
                     msg != "Emotes" && msg != "Levels" && msg != "Reload") {
                // Unknown option, reopen main menu
                openPersonaMenu(id);
            }
        }
    }
    
    timer() {
        // Clean up listen handles
        llListenRemove(gListenHandle);
        llSetTimerEvent(0.0);
    }
}

//-- IMPLEMENTATION NOTES v4.1:
//-- 1. Added complete permissions system from template
//-- 2. All menu functions now check permissions before execution
//-- 3. Permissions are synchronized from master kernel via UPDATE_CONFIG
//-- 4. Access levels displayed in menus for transparency
//-- 5. Config status shows synchronization state
//-- 6. Owner automatically has admin access as backup measure
//-- 7. All sensitive operations require at least trusted user access
//-- 8. Administrative functions (reload, reset) require admin access
//-- 9. Permission checks added to all listen event handlers
//-- 10. Proper error messages when access is denied
