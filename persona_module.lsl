//-- A.R.I.A. Persona Module (Add-on)
//-- Version 4.0 - NOTECARD-BASED PERSONA SYSTEM
//-- Complete rewrite to use notecard-based personas for easy customization and sharing
//-- Supports custom persona creation through standardized notecard templates

// --- CONFIGURATION ---
string gRlvRootFolder = "#RLV/~A.R.I.A.";
string gPersonaPrefix = "Persona_";  // Notecard naming convention: Persona_Default, Persona_Maid, etc.

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
list gAdministrators;
list gTrustedUsers;
key wearer;

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

// --- HELPER FUNCTIONS ---
updateHoverText() {
    string status = "A.R.I.A. Unit: " + gUnitName + "\n";
    status += "Persona: " + gCurrentPersona + " | Mode: " + gCurrentResponseTone + "\n";
    status += "Power: " + (string)((integer)gBatteryLevel) + "%\n";
    status += "A:" + (string)((integer)gArousalLevel) + "% S:" + (string)((integer)gStimulationLevel) + "% P:" + (string)((integer)gPainLevel) + "% St:" + (string)((integer)gStressLevel) + "%";
    
    vector color = <0.2, 1.0, 0.8>;
    if (gBatteryLevel <= 25.0) color = <1.0, 0.5, 0.0>;
    if (gBatteryLevel <= 10.0) color = <1.0, 0.0, 0.0>;
    
    if (gStressLevel >= 75.0 || gPainLevel >= 75.0) color = <1.0, 0.0, 0.0>;
    else if (gArousalLevel >= 75.0) color = <1.0, 0.5, 1.0>;
    
    llSetText(status, color, 1.0);
}

scanForPersonaNotecards() {
    gAvailablePersonas = [];
    gInitializationStep = 0;
    
    integer count = llGetInventoryNumber(INVENTORY_NOTECARD);
    integer i;
    
    for (i = 0; i < count; i++) {
        string cardName = llGetInventoryName(INVENTORY_NOTECARD, i);
        if (llSubStringIndex(cardName, gPersonaPrefix) == 0) {
            string personaName = llGetSubString(cardName, llStringLength(gPersonaPrefix), -1);
            gAvailablePersonas += [personaName];
        }
    }
    
    llOwnerSay("Found " + (string)llGetListLength(gAvailablePersonas) + " persona notecards: " + llDumpList2String(gAvailablePersonas, ", "));
    
    // Load default persona if available
    if (llListFindList(gAvailablePersonas, ["Default"]) != -1) {
        loadPersonaFromNotecard("Default");
    } else if (llGetListLength(gAvailablePersonas) > 0) {
        loadPersonaFromNotecard(llList2String(gAvailablePersonas, 0));
    } else {
        llOwnerSay("ERROR: No persona notecards found! Please add persona notecards with format 'Persona_[Name]'");
        createDefaultPersona();
    }
}

createDefaultPersona() {
    // Emergency fallback - create basic default persona
    gCurrentPersona = "Default";
    gCurrentChatPrefix = "[A.R.I.A.]";
    gCurrentEmoteStyle = "neutral";
    gCurrentResponseTone = "standard";
    gCurrentOutfitFolder = "";
    
    gPersonaEmotes = [
        "greeting", "*systems online* Hello.",
        "acknowledgment", "*nods* Understood.",
        "confusion", "*processing* Please clarify.",
        "error", "*error tone* System malfunction detected.",
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
            string key = llStringTrim(llList2String(parts, 0), STRING_TRIM);
            string value = llStringTrim(llList2String(parts, 1), STRING_TRIM);
            
            if (key == "Name") {
                gCurrentPersona = value;
            }
            else if (key == "OutfitFolder") {
                gCurrentOutfitFolder = gRlvRootFolder + "/" + value;
            }
            else if (key == "ChatPrefix") {
                gCurrentChatPrefix = value;
            }
            else if (key == "EmoteStyle") {
                gCurrentEmoteStyle = value;
            }
            else if (key == "ResponseTone") {
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
    else if (gPainLevel >= 50.0 && llFrand(100.0) < 20.0) {
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
    
    updateHoverText();
}

processPersonalityResponse(string message) {
    string lowerMsg = llToLower(message);
    string response = "";
    
    // Check for common response triggers
    if (llSubStringIndex(lowerMsg, "thank") != -1) {
        response = getPersonaResponse("thank");
    }
    else if (llSubStringIndex(lowerMsg, "sorry") != -1 || llSubStringIndex(lowerMsg, "apologize") != -1) {
        response = getPersonaResponse("sorry");
    }
    else if (llSubStringIndex(lowerMsg, "good") != -1 || llSubStringIndex(lowerMsg, "great") != -1 || 
             llSubStringIndex(lowerMsg, "nice") != -1 || llSubStringIndex(lowerMsg, "excellent") != -1) {
        response = getPersonaResponse("compliment");
    }
    
    // Check for custom triggers defined in the persona
    integer i;
    for (i = 0; i < llGetListLength(gPersonaResponses); i += 2) {
        string trigger = llList2String(gPersonaResponses, i);
        if (llSubStringIndex(lowerMsg, trigger) != -1) {
            response = llList2String(gPersonaResponses, i + 1);
            break;
        }
    }
    
    if (response != "") {
        llOwnerSay(response);
    }
}

openPersonaMenu(key admin_id) {
    string dialog = "\n[ PERSONA MANAGEMENT ]\nActive: " + gCurrentPersona + " (" + gCurrentResponseTone + ")\n";
    dialog += "Chat Style: " + gCurrentChatPrefix + "\n";
    dialog += "Levels - A:" + (string)((integer)gArousalLevel) + "% S:" + (string)((integer)gStimulationLevel) + "% P:" + (string)((integer)gPainLevel) + "% St:" + (string)((integer)gStressLevel) + "%\n";
    dialog += "Available personas: " + (string)llGetListLength(gAvailablePersonas) + "\n";
    dialog += "Select a persona to activate:";
    
    list buttons = [];
    integer i;
    for (i = 0; i < llGetListLength(gAvailablePersonas) && i < 9; i++) {
        buttons += [llList2String(gAvailablePersonas, i)];
    }
    buttons += ["Emotes", "Levels", "Reload"];
    if (llGetListLength(gAvailablePersonas) > 9) {
        buttons += ["More..."];
    }
    buttons += ["-Main-"];
    
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", admin_id, "");
    llDialog(admin_id, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

openEmoteMenu(key admin_id) {
    string dialog = "\n[ EMOTE TESTING ]\nCurrent Persona: " + gCurrentPersona + "\n";
    dialog += "Available emotes: " + (string)(llGetListLength(gPersonaEmotes) / 2) + "\n";
    dialog += "Test different personality emotes:";
    
    list buttons = ["Greeting", "Happy", "Confused", "Error", "Idle", "Arousal", "Pain", "Stress", "-Back-"];
    
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", admin_id, "");
    llDialog(admin_id, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

openLevelsMenu(key admin_id) {
    string dialog = "\n[ INDICATOR LEVELS ]\n";
    dialog += "Arousal: " + (string)((integer)gArousalLevel) + "%\n";
    dialog += "Stimulation: " + (string)((integer)gStimulationLevel) + "%\n";
    dialog += "Pain: " + (string)((integer)gPainLevel) + "%\n";
    dialog += "Stress: " + (string)((integer)gStressLevel) + "%\n\n";
    dialog += "Test different level responses:";
    
    list buttons = ["A+25", "A-25", "S+25", "S-25", "P+25", "P-25", "St+25", "St-25", "-Back-"];
    
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", admin_id, "");
    llDialog(admin_id, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

// --- MAIN LOGIC ---
default {
    state_entry() {
        wearer = llGetOwner();
        gMenuChannel = (integer)("0x" + llGetSubString(llGetKey(), -8, -2));
        
        // Initialize default values
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
        
        llOwnerSay("Persona module v4.0 initializing with notecard-based persona system...");
        
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
            list parts = llParseString2List(msg, ["|"], []);
            if (llGetListLength(parts) >= 2) {
                gAdministrators = llCSV2List(llList2String(parts, 0));
                gTrustedUsers = llCSV2List(llList2String(parts, 1));
            }
        } 
        else if (num == UPDATE_UNIT_INFO) {
            gUnitName = msg;
            updateHoverText();
        } 
        else if (num == OPEN_MY_MENU) {
            key user = (key)msg;
            if (llListFindList(gAdministrators, [user]) != -1 || 
                llListFindList(gTrustedUsers, [user]) != -1) {
                gAdministrator = user;
                openPersonaMenu(user);
            } else {
                llInstantMessage(user, "Access denied. Trusted user or Administrator permissions required.");
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
            
            if (llListFindList(gAvailablePersonas, [msg]) != -1) {
                loadPersonaFromNotecard(msg);
            }
            else if (msg == "Emotes") {
                openEmoteMenu(id);
            }
            else if (msg == "Levels") {
                openLevelsMenu(id);
            }
            else if (msg == "Reload") {
                llOwnerSay("Rescanning for persona notecards...");
                scanForPersonaNotecards();
                llInstantMessage(id, "Persona notecards reloaded.");
                openPersonaMenu(id);
            }
            else if (msg == "Greeting") {
                triggerPersonaEmote("greeting");
                llInstantMessage(id, "Triggered greeting emote for " + gCurrentPersona);
                openEmoteMenu(id);
            }
            else if (msg == "Happy") {
                string emoteType = "happy";
                if (gCurrentPersona == "Maid") emoteType = "compliment";
                else if (gCurrentPersona == "Guardian") emoteType = "alert";
                else if (gCurrentPersona == "Sexbot") emoteType = "pleasure";
                else if (gCurrentPersona == "Companion") emoteType = "excited";
                triggerPersonaEmote(emoteType);
                openEmoteMenu(id);
            }
            else if (msg == "Confused") {
                triggerPersonaEmote("confusion");
                openEmoteMenu(id);
            }
            else if (msg == "Error") {
                triggerPersonaEmote("error");
                openEmoteMenu(id);
            }
            else if (msg == "Idle") {
                triggerPersonaEmote("idle");
                openEmoteMenu(id);
            }
            else if (msg == "Arousal") {
                string emote = getPersonaEmoteByLevel("arousal", gArousalLevel);
                if (emote != "") llOwnerSay(emote);
                else llInstantMessage(id, "No arousal emote found for current level");
                openEmoteMenu(id);
            }
            else if (msg == "Pain") {
                string emote = getPersonaEmoteByLevel("pain", gPainLevel);
                if (emote != "") llOwnerSay(emote);
                else llInstantMessage(id, "No pain emote found for current level");
                openEmoteMenu(id);
            }
            else if (msg == "Stress") {
                string emote = getPersonaEmoteByLevel("stress", gStressLevel);
                if (emote != "") llOwnerSay(emote);
                else llInstantMessage(id, "No stress emote found for current level");
                openEmoteMenu(id);
            }
            // Level adjustment buttons
            else if (msg == "A+25") {
                gArousalLevel += 25.0;
                if (gArousalLevel > 100.0) gArousalLevel = 100.0;
                processIndicatorLevels();
                llInstantMessage(id, "Arousal increased to " + (string)((integer)gArousalLevel) + "%");
                openLevelsMenu(id);
            }
            else if (msg == "A-25") {
                gArousalLevel -= 25.0;
                if (gArousalLevel < 0.0) gArousalLevel = 0.0;
                updateHoverText();
                llInstantMessage(id, "Arousal decreased to " + (string)((integer)gArousalLevel) + "%");
                openLevelsMenu(id);
            }
            else if (msg == "S+25") {
                gStimulationLevel += 25.0;
                if (gStimulationLevel > 100.0) gStimulationLevel = 100.0;
                processIndicatorLevels();
                llInstantMessage(id, "Stimulation increased to " + (string)((integer)gStimulationLevel) + "%");
                openLevelsMenu(id);
            }
            else if (msg == "S-25") {
                gStimulationLevel -= 25.0;
                if (gStimulationLevel < 0.0) gStimulationLevel = 0.0;
                updateHoverText();
                llInstantMessage(id, "Stimulation decreased to " + (string)((integer)gStimulationLevel) + "%");
                openLevelsMenu(id);
            }
            else if (msg == "P+25") {
                gPainLevel += 25.0;
                if (gPainLevel > 100.0) gPainLevel = 100.0;
                processIndicatorLevels();
                llInstantMessage(id, "Pain increased to " + (string)((integer)gPainLevel) + "%");
                openLevelsMenu(id);
            }
            else if (msg == "P-25") {
                gPainLevel -= 25.0;
                if (gPainLevel < 0.0) gPainLevel = 0.0;
                updateHoverText();
                llInstantMessage(id, "Pain decreased to " + (string)((integer)gPainLevel) + "%");
                openLevelsMenu(id);
            }
            else if (msg == "St+25") {
                gStressLevel += 25.0;
                if (gStressLevel > 100.0) gStressLevel = 100.0;
                processIndicatorLevels();
                llInstantMessage(id, "Stress increased to " + (string)((integer)gStressLevel) + "%");
                openLevelsMenu(id);
            }
            else if (msg == "St-25") {
                gStressLevel -= 25.0;
                if (gStressLevel < 0.0) gStressLevel = 0.0;
                updateHoverText();
                llInstantMessage(id, "Stress decreased to " + (string)((integer)gStressLevel) + "%");
                openLevelsMenu(id);
            }
            else if (msg == "-Back-") {
                openPersonaMenu(id);
            }
            else if (msg == "-Main-") {
                llInstantMessage(id, "Returning to main menu.");
            }
        }
    }
    
    timer() {
        llListenRemove(gListenHandle);
        llSetTimerEvent(0.0);
        
        // Random idle behavior based on current levels
        if (llFrand(100.0) < 5.0) {  // 5% chance every timer cycle
            string emote = "";
            if (gArousalLevel >= 50.0) {
                emote = getPersonaEmoteByLevel("arousal", gArousalLevel);
                if (emote != "") llOwnerSay(emote);
            }
            else if (gStressLevel >= 50.0) {
                emote = getPersonaEmoteByLevel("stress", gStressLevel);
                if (emote != "") llOwnerSay(emote);
            }
            else if (gPainLevel >= 25.0) {
                emote = getPersonaEmoteByLevel("pain", gPainLevel);
                if (emote != "") llOwnerSay(emote);
            }
            else {
                triggerPersonaEmote("idle");
            }
        }
        
        // Set next idle timer (30-60 seconds)
        llSetTimerEvent(30.0 + llFrand(30.0));
    }
    
    changed(integer c) {
        if (c & CHANGED_OWNER) {
            llResetScript();
        }
        if (c & CHANGED_INVENTORY) {
            // Inventory changed - rescan for persona notecards
            llOwnerSay(EMOJI_GEAR + " Inventory changed - rescanning for persona notecards...");
            scanForPersonaNotecards();
        }
    }
}
