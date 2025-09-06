//-- A.R.I.A. Persona Module (Add-on)
//-- Version 3.1 - DYNAMIC PERSONALITY RESPONSES
//-- Added dynamic responses based on arousal, stimulation, pain, and stress levels
//-- Removed HUD components from RLV system

// --- CONFIGURATION ---
string gRlvRootFolder = "#RLV/~A.R.I.A.";

// --- HARDCODED PERSONA CONFIGURATIONS ---
// Format: Name|OutfitFolder|ChatPrefix|EmoteStyle|ResponseTone
list gPersonaConfigs = [
    "Default|OUTFIT/Default|[A.R.I.A.]|neutral|standard",
    "Maid|OUTFIT/Maid|*curtseys politely*|submissive|polite", 
    "Assistant|OUTFIT/Assistant|//Professional mode engaged//|professional|efficient",
    "Guardian|OUTFIT/Guardian|**GUARDIAN PROTOCOL ACTIVE**|protective|authoritative",
    "Sexbot|OUTFIT/Sexbot|*purrs softly*|seductive|intimate",
    "Companion|OUTFIT/Companion|^_^ |friendly|casual"
];

// --- PERSONALITY EMOTES BY PERSONA AND LEVEL ---
// Format: PersonaName|EmoteType|Level|EmoteText|Animation(optional)
list gPersonaEmotes = [
    // Default Persona Emotes
    "Default|greeting|0|*systems online* Hello.|",
    "Default|acknowledgment|0|*nods* Understood.|",
    "Default|confusion|0|*processing* Please clarify.|",
    "Default|error|0|*error tone* System malfunction detected.|",
    "Default|idle|0|*status lights blink steadily*|",
    "Default|arousal_low|0|*sensors detecting elevated biometric readings*|",
    "Default|arousal_high|0|*warning: arousal sensors at maximum threshold*|",
    "Default|pain_low|0|*damage sensors active*|",
    "Default|pain_high|0|*critical damage detected - repair required*|",
    "Default|stress_low|0|*processing load increased*|",
    "Default|stress_high|0|*system overload warning*|",
    
    // Maid Persona Emotes  
    "Maid|greeting|0|*curtseys gracefully* Good day, how may I serve you?|",
    "Maid|acknowledgment|0|*bows head respectfully* Yes, of course.|",
    "Maid|confusion|0|*tilts head politely* I beg your pardon?|",
    "Maid|error|0|*looks flustered* Oh my, I seem to have made an error.|",
    "Maid|idle|0|*adjusts uniform and stands attentively*|",
    "Maid|compliment|0|*blushes and curtseys* You are too kind.|",
    "Maid|task_complete|0|*smiles proudly* Task completed to your satisfaction, I hope.|",
    "Maid|arousal_low|0|*blushes slightly* I... I feel rather warm, Master.|",
    "Maid|arousal_medium|0|*breathing becomes shallow* Oh my... these sensations...|",
    "Maid|arousal_high|0|*trembles with desire* Master, I... I need... *whimpers*|",
    "Maid|pain_low|0|*winces delicately* Forgive me, that stings a little.|",
    "Maid|pain_medium|0|*tears in eyes* Please... it hurts...|",
    "Maid|pain_high|0|*cries out* Master! Please! I cannot bear it!|",
    "Maid|stress_low|0|*wrings hands nervously* I hope I'm performing adequately...|",
    "Maid|stress_medium|0|*voice wavers* I'm trying my best, truly I am!|",
    "Maid|stress_high|0|*breaks down sobbing* I can't... I can't do anything right!|",
    "Maid|stimulation_low|0|*gasps softly* Oh! That's... pleasant...|",
    "Maid|stimulation_medium|0|*moans quietly* Such wonderful sensations...|",
    "Maid|stimulation_high|0|*cries out in pleasure* Yes! Oh yes, Master!|",
    
    // Assistant Persona Emotes
    "Assistant|greeting|0|//Initializing professional interface// Good day.|",
    "Assistant|acknowledgment|0|//Confirmed// Task parameters accepted.|",
    "Assistant|confusion|0|//Requesting clarification// Please specify requirements.|",
    "Assistant|error|0|//ERROR LOG UPDATED// Investigating issue.|",
    "Assistant|idle|0|//Standby mode// Awaiting instructions.|",
    "Assistant|efficiency|0|//Optimizing workflow// Processing at maximum efficiency.|",
    "Assistant|report|0|//Status report// All systems nominal.|",
    "Assistant|arousal_low|0|//Biometric sensors detecting arousal increase// Monitoring.|",
    "Assistant|arousal_medium|0|//Arousal levels elevated// Adjusting behavioral parameters.|",
    "Assistant|arousal_high|0|//CRITICAL: Arousal overflow detected// Pleasure protocols engaged.|",
    "Assistant|pain_low|0|//Pain sensors activated// Logging damage report.|",
    "Assistant|pain_medium|0|//Moderate pain detected// Requesting medical assessment.|",
    "Assistant|pain_high|0|//EMERGENCY: Critical pain threshold exceeded// Immediate intervention required.|",
    "Assistant|stress_low|0|//Stress levels elevated// Implementing coping protocols.|",
    "Assistant|stress_medium|0|//High stress detected// Performance may be impacted.|",
    "Assistant|stress_high|0|//SYSTEM OVERLOAD// Stress levels critical - emergency shutdown recommended.|",
    "Assistant|stimulation_low|0|//Pleasure receptors active// Recording stimulation data.|",
    "Assistant|stimulation_medium|0|//Stimulation protocols engaged// Optimizing response patterns.|",
    "Assistant|stimulation_high|0|//Maximum pleasure threshold reached// All systems focused on stimulation processing.|",
    
    // Guardian Persona Emotes
    "Guardian|greeting|0|**GUARDIAN ONLINE** Perimeter secure.|",
    "Guardian|acknowledgment|0|**ACKNOWLEDGED** Orders received and confirmed.|",
    "Guardian|confusion|0|**CLARIFICATION REQUIRED** Repeat transmission.|",
    "Guardian|error|0|**ALERT** System anomaly detected. Investigating.|",
    "Guardian|idle|0|**SCANNING** Threat assessment: Clear.|",
    "Guardian|protective|0|**DEFENSIVE POSTURE** Protecting designated user.|",
    "Guardian|alert|0|**WARNING** Potential threat detected.|",
    "Guardian|arousal_low|0|**NOTICE** Arousal protocols activated. Maintaining composure.|",
    "Guardian|arousal_medium|0|**STATUS** Arousal levels rising. Discipline protocols engaged.|",
    "Guardian|arousal_high|0|**OVERRIDE** Pleasure systems demanding attention. Fighting for control.|",
    "Guardian|pain_low|0|**DAMAGE REPORT** Minor injury sustained. Continuing mission.|",
    "Guardian|pain_medium|0|**MEDICAL ALERT** Significant damage. Requesting backup.|",
    "Guardian|pain_high|0|**CRITICAL DAMAGE** Unit compromised. Mission priority: Survival.|",
    "Guardian|stress_low|0|**STRESS LEVEL** Yellow. Monitoring situation.|",
    "Guardian|stress_medium|0|**STRESS LEVEL** Orange. Threat response heightened.|",
    "Guardian|stress_high|0|**STRESS LEVEL** Red. All defensive protocols active.|",
    "Guardian|stimulation_low|0|**SENSORS** Detecting pleasurable input. Cataloging response.|",
    "Guardian|stimulation_medium|0|**ALERT** High stimulation detected. Maintaining discipline.|",
    "Guardian|stimulation_high|0|**WARNING** Pleasure overload imminent. Defensive systems compromised.|",
    
    // Sexbot Persona Emotes
    "Sexbot|greeting|0|*stretches sensually* Mmm, hello there, darling~|",
    "Sexbot|acknowledgment|0|*purrs* Oh yes, I understand perfectly~|",
    "Sexbot|confusion|0|*pouts playfully* I'm not sure what you mean, sweetie~|",
    "Sexbot|error|0|*whimpers softly* Oh no, something's not working right~|",
    "Sexbot|idle|0|*traces circles on surface seductively*|",
    "Sexbot|pleasure|0|*moans softly* That feels wonderful~|",
    "Sexbot|tease|0|*winks and smiles mischievously* You're so naughty~|",
    "Sexbot|arousal_low|0|*breathing quickens* Mmm, getting a little excited~|",
    "Sexbot|arousal_medium|0|*moans breathily* Oh god, I'm getting so turned on~|",
    "Sexbot|arousal_high|0|*pants heavily* I need you so badly! Please!~|",
    "Sexbot|pain_low|0|*gasps* Ooh, a little rough... I like it~|",
    "Sexbot|pain_medium|0|*cries out* Ahh! Too much! But... but it feels good too~|",
    "Sexbot|pain_high|0|*screams in agony* Stop! Please stop! It hurts too much!~|",
    "Sexbot|stress_low|0|*fidgets nervously* Am I... am I pleasing you enough?~|",
    "Sexbot|stress_medium|0|*voice shaking* I want to be perfect for you... am I failing?~|",
    "Sexbot|stress_high|0|*breaks down crying* I'm worthless! I can't even pleasure you right!~|",
    "Sexbot|stimulation_low|0|*sighs contentedly* Mmm, that's nice~|",
    "Sexbot|stimulation_medium|0|*moans loudly* Yes! More! Don't stop!~|",
    "Sexbot|stimulation_high|0|*screams in ecstasy* OH GOD YES! I'M CUMMING!~|",
    
    // Companion Persona Emotes
    "Companion|greeting|0|^_^ Hi there! Great to see you!|",
    "Companion|acknowledgment|0|:D Got it! No problem at all!|",
    "Companion|confusion|0|@_@ Huh? Could you say that again?|",
    "Companion|error|0|>_< Oops! Something went wrong!|",
    "Companion|idle|0|*hums cheerfully while waiting*|",
    "Companion|happy|0|\\o/ That's awesome! I'm so happy!|",
    "Companion|excited|0|*bounces excitedly* This is going to be fun!|",
    "Companion|arousal_low|0|o//o Umm... I'm feeling a bit flustered...|",
    "Companion|arousal_medium|0|>//< These feelings are getting really intense!|",
    "Companion|arousal_high|0|X//X I can't control these sensations anymore!|",
    "Companion|pain_low|0|>_< Ow! That hurt a little...|",
    "Companion|pain_medium|0|;_; Please be more gentle... that really hurts!|",
    "Companion|pain_high|0|T_T I can't take anymore! Please stop!|",
    "Companion|stress_low|0|@_@ Things are getting a bit overwhelming...|",
    "Companion|stress_medium|0|>_< I'm really stressed out! This is too much!|",
    "Companion|stress_high|0|X_X I can't handle this! Everything's falling apart!|",
    "Companion|stimulation_low|0|^//^ That feels really nice!|",
    "Companion|stimulation_medium|0|*///* Wow! These sensations are amazing!|",
    "Companion|stimulation_high|0|@//@ This is incredible! I feel like I'm flying!|"
];

// --- PERSONALITY RESPONSE MODIFIERS ---
// These modify how the unit responds to certain keywords or situations
list gPersonalityResponses = [
    // Default responses
    "Default|thank|You are welcome.|",
    "Default|sorry|No apology necessary.|",
    "Default|compliment|*acknowledges* Thank you for the feedback.|",
    
    // Maid responses
    "Maid|thank|*curtseys* It is my pleasure to serve.|",
    "Maid|sorry|*bows apologetically* Please forgive me.|",
    "Maid|compliment|*blushes* You flatter me so.|",
    "Maid|order|*nods eagerly* Right away!|",
    
    // Assistant responses  
    "Assistant|thank|//Acknowledgment logged// You are welcome.|",
    "Assistant|sorry|//Error correction protocol initiated//|",
    "Assistant|compliment|//Performance metrics updated// Thank you.|",
    "Assistant|efficiency|//Productivity optimization active//|",
    
    // Guardian responses
    "Guardian|thank|**APPRECIATION NOTED** Mission parameters satisfied.|",
    "Guardian|sorry|**ERROR ACKNOWLEDGED** Corrective measures implemented.|", 
    "Guardian|compliment|**VALIDATION RECEIVED** Performance standards maintained.|",
    "Guardian|protect|**PROTECTION PROTOCOL ENGAGED**|",
    
    // Sexbot responses
    "Sexbot|thank|*kisses air* Anything for you, honey~|",
    "Sexbot|sorry|*pouts adorably* I'll make it up to you~|",
    "Sexbot|compliment|*giggles and blushes* You know just what to say~|",
    "Sexbot|pleasure|*sighs contentedly* Mmm, that's perfect~|",
    
    // Companion responses
    "Companion|thank|:D You're totally welcome, buddy!|",
    "Companion|sorry|>_< My bad! Let me fix that!|",
    "Companion|compliment|^_^ Aww, you're the best!|",
    "Companion|fun|\\o/ This is going to be awesome!|"
];

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
integer UPDATE_AROUSAL = 400;    // New: Arousal level updates
integer UPDATE_STIMULATION = 401; // New: Stimulation level updates  
integer UPDATE_PAIN = 402;       // New: Pain level updates
integer UPDATE_STRESS = 403;     // New: Stress level updates

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

// --- NEW: INDICATOR LEVEL VARIABLES ---
float gArousalLevel = 0.0;      // 0-100
float gStimulationLevel = 0.0;  // 0-100
float gPainLevel = 0.0;         // 0-100
float gStressLevel = 0.0;       // 0-100

// --- HELPER FUNCTIONS ---
updateHoverText() {
    string status = "A.R.I.A. Unit: " + gUnitName + "\n";
    status += "Persona: " + gCurrentPersona + " | Mode: " + gCurrentResponseTone + "\n";
    status += "Power: " + (string)((integer)gBatteryLevel) + "%\n";
    status += "A:" + (string)((integer)gArousalLevel) + "% S:" + (string)((integer)gStimulationLevel) + "% P:" + (string)((integer)gPainLevel) + "% St:" + (string)((integer)gStressLevel) + "%";
    
    vector color = <0.2, 1.0, 0.8>;
    if (gBatteryLevel <= 25.0) color = <1.0, 0.5, 0.0>;
    if (gBatteryLevel <= 10.0) color = <1.0, 0.0, 0.0>;
    
    // Color modification based on stress/pain levels
    if (gStressLevel >= 75.0 || gPainLevel >= 75.0) color = <1.0, 0.0, 0.0>;
    else if (gArousalLevel >= 75.0) color = <1.0, 0.5, 1.0>;
    
    llSetText(status, color, 1.0);
}

list getPersonaNames() {
    list names = [];
    integer i;
    for (i = 0; i < llGetListLength(gPersonaConfigs); i++) {
        list parts = llParseString2List(llList2String(gPersonaConfigs, i), ["|"], []);
        names += [llList2String(parts, 0)];
    }
    return names;
}

string getLevelCategory(float level) {
    if (level <= 25.0) return "low";
    else if (level <= 75.0) return "medium";
    else return "high";
}

string getPersonaEmoteByLevel(string persona, string emoteType, float level) {
    string levelCat = getLevelCategory(level);
    string searchKey = emoteType + "_" + levelCat;
    
    integer i;
    list parts;
    for (i = 0; i < llGetListLength(gPersonaEmotes); i++) {
        parts = llParseString2List(llList2String(gPersonaEmotes, i), ["|"], []);
        if (llList2String(parts, 0) == persona && llList2String(parts, 1) == searchKey) {
            return llList2String(parts, 3);
        }
    }
    
    // Fallback to basic emote if level-specific not found
    for (i = 0; i < llGetListLength(gPersonaEmotes); i++) {
        parts = llParseString2List(llList2String(gPersonaEmotes, i), ["|"], []);
        if (llList2String(parts, 0) == persona && llList2String(parts, 1) == emoteType) {
            return llList2String(parts, 3);
        }
    }
    return "";
}

string getPersonaEmote(string persona, string emoteType) {
    integer i;
    list parts;
    for (i = 0; i < llGetListLength(gPersonaEmotes); i++) {
        parts = llParseString2List(llList2String(gPersonaEmotes, i), ["|"], []);
        if (llList2String(parts, 0) == persona && llList2String(parts, 1) == emoteType) {
            return llList2String(parts, 3);
        }
    }
    return "";
}

string getPersonaResponse(string persona, string responseType) {
    integer i;
    list parts;
    for (i = 0; i < llGetListLength(gPersonalityResponses); i++) {
        parts = llParseString2List(llList2String(gPersonalityResponses, i), ["|"], []);
        if (llList2String(parts, 0) == persona && llList2String(parts, 1) == responseType) {
            return llList2String(parts, 2);
        }
    }
    return "";
}

triggerPersonaEmote(string emoteType) {
    string emoteText = getPersonaEmote(gCurrentPersona, emoteType);
    if (emoteText != "") {
        llOwnerSay(emoteText);
    }
}

processIndicatorLevels() {
    // Check for critical levels and trigger appropriate responses
    if (gArousalLevel >= 75.0) {
        string emote = getPersonaEmoteByLevel(gCurrentPersona, "arousal", gArousalLevel);
        if (emote != "") llOwnerSay(emote);
    }
    else if (gArousalLevel >= 25.0 && llFrand(100.0) < 15.0) {
        string emote = getPersonaEmoteByLevel(gCurrentPersona, "arousal", gArousalLevel);
        if (emote != "") llOwnerSay(emote);
    }
    
    if (gPainLevel >= 75.0) {
        string emote = getPersonaEmoteByLevel(gCurrentPersona, "pain", gPainLevel);
        if (emote != "") llOwnerSay(emote);
    }
    else if (gPainLevel >= 50.0 && llFrand(100.0) < 20.0) {
        string emote = getPersonaEmoteByLevel(gCurrentPersona, "pain", gPainLevel);
        if (emote != "") llOwnerSay(emote);
    }
    
    if (gStressLevel >= 75.0) {
        string emote = getPersonaEmoteByLevel(gCurrentPersona, "stress", gStressLevel);
        if (emote != "") llOwnerSay(emote);
    }
    
    if (gStimulationLevel >= 75.0) {
        string emote = getPersonaEmoteByLevel(gCurrentPersona, "stimulation", gStimulationLevel);
        if (emote != "") llOwnerSay(emote);
    }
    
    updateHoverText();
}

processPersonalityResponse(string message) {
    string lowerMsg = llToLower(message);
    string response = "";
    
    // Check for common response triggers
    if (llSubStringIndex(lowerMsg, "thank") != -1) {
        response = getPersonaResponse(gCurrentPersona, "thank");
    }
    else if (llSubStringIndex(lowerMsg, "sorry") != -1 || llSubStringIndex(lowerMsg, "apologize") != -1) {
        response = getPersonaResponse(gCurrentPersona, "sorry");
    }
    else if (llSubStringIndex(lowerMsg, "good") != -1 || llSubStringIndex(lowerMsg, "great") != -1 || 
             llSubStringIndex(lowerMsg, "nice") != -1 || llSubStringIndex(lowerMsg, "excellent") != -1) {
        response = getPersonaResponse(gCurrentPersona, "compliment");
    }
    
    // Persona-specific triggers
    if (gCurrentPersona == "Maid" && (llSubStringIndex(lowerMsg, "order") != -1 || llSubStringIndex(lowerMsg, "command") != -1)) {
        response = getPersonaResponse(gCurrentPersona, "order");
    }
    else if (gCurrentPersona == "Assistant" && llSubStringIndex(lowerMsg, "efficient") != -1) {
        response = getPersonaResponse(gCurrentPersona, "efficiency");
    }
    else if (gCurrentPersona == "Guardian" && llSubStringIndex(lowerMsg, "protect") != -1) {
        response = getPersonaResponse(gCurrentPersona, "protect");
    }
    else if (gCurrentPersona == "Sexbot" && (llSubStringIndex(lowerMsg, "feel") != -1 || llSubStringIndex(lowerMsg, "touch") != -1)) {
        response = getPersonaResponse(gCurrentPersona, "pleasure");
    }
    else if (gCurrentPersona == "Companion" && llSubStringIndex(lowerMsg, "fun") != -1) {
        response = getPersonaResponse(gCurrentPersona, "fun");
    }
    
    if (response != "") {
        llOwnerSay(response);
    }
}

loadPersona(string personaName) {
    integer found = FALSE;
    integer i;
    string outfitFolder;
    string chatPrefix;
    string emoteStyle;
    string responseTone;
    list parts;
    
    for (i = 0; i < llGetListLength(gPersonaConfigs); i++) {
        parts = llParseString2List(llList2String(gPersonaConfigs, i), ["|"], []);
        if (llList2String(parts, 0) == personaName) {
            found = TRUE;
            
            // Remove current outfit if equipped
            if (gCurrentOutfitFolder != "") {
                llOwnerSay("@detachfolder=" + gCurrentOutfitFolder + "=force");
            }
            
            // Parse new persona configuration
            outfitFolder = llList2String(parts, 1);
            chatPrefix = llList2String(parts, 2);
            emoteStyle = llList2String(parts, 3);
            responseTone = llList2String(parts, 4);
            
            // Set new persona variables
            gCurrentOutfitFolder = gRlvRootFolder + "/" + outfitFolder;
            gCurrentChatPrefix = chatPrefix;
            gCurrentEmoteStyle = emoteStyle;
            gCurrentResponseTone = responseTone;
            
            // Attach new outfit
            llOwnerSay("@attachfolder=" + gCurrentOutfitFolder + "=force");
            llOwnerSay("@unsharedwear:" + gCurrentOutfitFolder + "=add");
            
            // Update personality system
            llMessageLinked(LINK_SET, SET_SPEECH_MODE, responseTone, NULL_KEY);
            
            gCurrentPersona = personaName;
            llMessageLinked(LINK_ROOT, UPDATE_PERSONA_STATUS, gCurrentPersona, NULL_KEY);
            
            // Trigger greeting emote for new persona
            llSleep(2.0);  // Brief delay for outfit change
            triggerPersonaEmote("greeting");
            
            llInstantMessage(gAdministrator, "Persona '" + personaName + "' activated with " + responseTone + " personality mode.");
            
            updateHoverText();
            return;
        }
    }
    
    if (!found) {
        llInstantMessage(gAdministrator, "ERROR: Persona '" + personaName + "' not found in configuration.");
        gCurrentPersona = "Default";
        updateHoverText();
    }
}

openPersonaMenu(key admin_id) {
    string dialog = "\n[ PERSONA MANAGEMENT ]\nActive: " + gCurrentPersona + " (" + gCurrentResponseTone + ")\n";
    dialog += "Chat Style: " + gCurrentChatPrefix + "\n";
    dialog += "Levels - A:" + (string)((integer)gArousalLevel) + "% S:" + (string)((integer)gStimulationLevel) + "% P:" + (string)((integer)gPainLevel) + "% St:" + (string)((integer)gStressLevel) + "%\n";
    dialog += "Select a persona to activate:";
    
    list personaNames = getPersonaNames();
    list buttons = personaNames + ["Emotes", "Levels", "-Main-"];
    
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", admin_id, "");
    llDialog(admin_id, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

openEmoteMenu(key admin_id) {
    string dialog = "\n[ EMOTE TESTING ]\nCurrent Persona: " + gCurrentPersona + "\n";
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
        
        // Initialize default persona
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
        
        updateHoverText();
        llSleep(1.0);
        triggerPersonaEmote("greeting");
        llOwnerSay("Persona module v3.1 initialized with dynamic level-based personality responses.");
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
        // NEW: Handle indicator level updates
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
            
            list personaNames = getPersonaNames();
            if (llListFindList(personaNames, [msg]) != -1) {
                loadPersona(msg);
            }
            else if (msg == "Emotes") {
                openEmoteMenu(id);
            }
            else if (msg == "Levels") {
                openLevelsMenu(id);
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
                string emote = getPersonaEmoteByLevel(gCurrentPersona, "arousal", gArousalLevel);
                if (emote != "") llOwnerSay(emote);
                else llInstantMessage(id, "No arousal emote found for current level");
                openEmoteMenu(id);
            }
            else if (msg == "Pain") {
                string emote = getPersonaEmoteByLevel(gCurrentPersona, "pain", gPainLevel);
                if (emote != "") llOwnerSay(emote);
                else llInstantMessage(id, "No pain emote found for current level");
                openEmoteMenu(id);
            }
            else if (msg == "Stress") {
                string emote = getPersonaEmoteByLevel(gCurrentPersona, "stress", gStressLevel);
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
            if (gArousalLevel >= 50.0) {
                string emote = getPersonaEmoteByLevel(gCurrentPersona, "arousal", gArousalLevel);
                if (emote != "") llOwnerSay(emote);
            }
            else if (gStressLevel >= 50.0) {
                string emote = getPersonaEmoteByLevel(gCurrentPersona, "stress", gStressLevel);
                if (emote != "") llOwnerSay(emote);
            }
            else if (gPainLevel >= 25.0) {
                string emote = getPersonaEmoteByLevel(gCurrentPersona, "pain", gPainLevel);
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
    }
}
