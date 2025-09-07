//-- A.R.I.A. Comms Module (The "Vocalizer")
//-- Version 2.0 - PERSONA INTEGRATION + ENHANCED CHAT REDIRECTION
//-- Handles chat redirection with dynamic persona-based speech modes and improved user feedback
//-- Integrates with persona module for dynamic chat prefixes and response tones

// --- CONFIGURATION ---
integer comms_channel = 9974;

// --- LINKED MESSAGE CODES ---
integer SET_SPEECH_MODE = 100;
integer UPDATE_BATTERY = 101;
integer UPDATE_CONFIG = 102;
integer UPDATE_UNIT_INFO = 103;
integer UPDATE_PERSONA_STATUS = 104;
integer MODULE_REGISTER = 200;
integer RELAY_CHAT_MESSAGE = 300;
integer POWER_STATE_CHANGE = 300;

// --- STATE VARIABLES ---
float gBatteryLevel = 100.0;
key gWearer;
list gAdministrators;
list gTrustedUsers;
integer gPowerState = TRUE;
string gSpeechMode = "Standard";
string gUnitName = "A.R.I.A.";
string gCurrentPersona = "Default";
string gPersonaChatPrefix = "[A.R.I.A.]";

// --- PERSONA-BASED SPEECH PATTERNS ---
string getPersonaPrefix(string persona, string speechMode) {
    // Return appropriate prefix based on current persona and speech mode
    if (persona == "Maid") {
        if (speechMode == "polite") return "🎀";
        return "*curtseys politely*";
    }
    else if (persona == "Assistant") {
        if (speechMode == "efficient") return "💼 //Professional//";
        return "//Professional mode engaged//";
    }
    else if (persona == "Guardian") {
        if (speechMode == "authoritative") return "🛡️ **GUARDIAN**";
        return "**GUARDIAN PROTOCOL ACTIVE**";
    }
    else if (persona == "Sexbot") {
        if (speechMode == "intimate") return "💋";
        return "*purrs softly*";
    }
    else if (persona == "Companion") {
        if (speechMode == "casual") return "😊";
        return "^_^";
    }
    else {
        // Default persona
        return "🤖 [A.R.I.A.]";
    }
}

string applyPersonalityFilter(string message, string persona, string speechMode) {
    // Apply persona-specific speech modifications
    string filtered = message;
    string lowerMsg = llToLower(filtered);
    
    if (persona == "Maid" && speechMode == "polite") {
        // Add polite flourishes occasionally
        if (llSubStringIndex(lowerMsg, "yes") != -1) {
            filtered = "yes, of course";
        }
        if (llSubStringIndex(lowerMsg, "no") != -1) {
            filtered = "no, I'm afraid not";
        }
    }
    else if (persona == "Assistant" && speechMode == "efficient") {
        // Make speech more technical and brief
        if (llSubStringIndex(lowerMsg, "i think") != -1) {
            filtered = "Analysis indicates " + llGetSubString(filtered, 8, -1);
        }
        if (llSubStringIndex(lowerMsg, "maybe") != -1) {
            filtered = "Probability suggests " + llGetSubString(filtered, 6, -1);
        }
    }
    else if (persona == "Guardian" && speechMode == "authoritative") {
        // Make speech more commanding
        if (llSubStringIndex(lowerMsg, "please") != -1) {
            filtered = "DIRECTIVE: " + llGetSubString(filtered, 7, -1);
        }
        if (llSubStringIndex(lowerMsg, "i will") != -1) {
            filtered = "EXECUTING: " + llGetSubString(filtered, 7, -1);
        }
    }
    else if (persona == "Sexbot" && speechMode == "intimate") {
        // Add subtle intimate touches
        if (llSubStringIndex(lowerMsg, "thank") != -1) {
            filtered += " ~";
        }
    }
    else if (persona == "Companion" && speechMode == "casual") {
        // Add friendly enthusiasm
        if (llSubStringIndex(lowerMsg, "okay") != -1) {
            filtered = "okay! :D";
        }
        if (llSubStringIndex(lowerMsg, "sure") != -1) {
            filtered = "sure thing!";
        }
    }
    
    return filtered;
}

string applyBatteryEffects(string message) {
    string output = message;
    
    if (gBatteryLevel <= 15.0) {
        // Static/garbled effect
        if (llFrand(1.0) > 0.6) {
            output = "...ksshh... " + message + " ...bzzzrt...";
        }
    }
    
    if (gBatteryLevel <= 10.0) {
        // Stuttering effect
        list words = llParseString2List(message, [" "], []);
        if (llGetListLength(words) > 1) {
            string firstWord = llList2String(words, 0);
            output = firstWord + "-" + firstWord + " " + llDumpList2String(llDeleteSubList(words, 0, 0), " ");
        }
    }
    
    if (gBatteryLevel <= 5.0) {
        // Random communication failures
        if (llFrand(1.0) > 0.4) {
            return ""; // Message lost due to power failure
        }
        output = "...low power... " + output + " ...system failing...";
    }
    
    return output;
}

// --- MAIN SCRIPT LOGIC ---
default {
    state_entry() {
        gWearer = llGetOwner();
        
        // Register this module with the main system
        llMessageLinked(LINK_ROOT, MODULE_REGISTER, "Comms", NULL_KEY);
        
        // Set up listening on the comms channel
        llListen(comms_channel, "", gWearer, "");
        
        llOwnerSay("🤖 Comms Module v2.0 initialized. Speech redirection active on channel " + (string)comms_channel);
        llInstantMessage(gWearer, "// Chat redirection active. Type on channel " + (string)comms_channel + " to speak as " + gUnitName + " //");
    }

    link_message(integer sender, integer num, string msg, key id) {
        if (num == UPDATE_BATTERY) {
            gBatteryLevel = (float)msg;
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
        }
        else if (num == UPDATE_PERSONA_STATUS) {
            gCurrentPersona = msg;
            llInstantMessage(gWearer, "// Speech patterns updated for persona: " + gCurrentPersona + " //");
        }
        else if (num == SET_SPEECH_MODE) {
            gSpeechMode = msg;
            llInstantMessage(gWearer, "// Speech protocol updated to: " + gSpeechMode + " //");
        } 
        else if (num == POWER_STATE_CHANGE) {
            if (msg == "ON") {
                gPowerState = TRUE;
                llInstantMessage(gWearer, "// Communications online //");
            }
            else {
                gPowerState = FALSE;
                llInstantMessage(gWearer, "// Communications offline //");
            }
        }
        else if (num == RELAY_CHAT_MESSAGE) {
            // Handle chat messages from other modules (like persona responses)
            if (gPowerState) {
                string prefix = getPersonaPrefix(gCurrentPersona, gSpeechMode);
                string filtered = applyPersonalityFilter(msg, gCurrentPersona, gSpeechMode);
                string final_message = applyBatteryEffects(filtered);
                
                if (final_message != "") {
                    llSay(0, prefix + " " + final_message);
                }
            }
        }
    }

    on_rez(integer start_param) {
        llListen(comms_channel, "", llGetOwner(), "");
    }

    listen(integer channel, string name, key id, string message) {
        if (!gPowerState) {
            llInstantMessage(gWearer, "// Communications offline - unable to transmit //");
            return;
        }
        
        // Only process messages from the wearer
        if (id != gWearer) return;
        
        // Permission check - ensure wearer is authorized to use comms
        integer hasPermission = FALSE;
        if (llListFindList(gAdministrators, [gWearer]) != -1) hasPermission = TRUE;
        if (llListFindList(gTrustedUsers, [gWearer]) != -1) hasPermission = TRUE;
        if (gWearer == llGetOwner()) hasPermission = TRUE; // Owner always has permission
        
        if (!hasPermission) {
            llInstantMessage(gWearer, "// Communication access denied - insufficient permissions //");
            return;
        }
        
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
            llMessageLinked(LINK_SET, RELAY_CHAT_MESSAGE, message, gWearer);
        } else {
            llInstantMessage(gWearer, "// Transmission failed - insufficient power //");
        }
        
        // Special commands
        if (llToLower(message) == "status") {
            string status = prefix + " Unit status: " + gCurrentPersona + " persona active, ";
            status += "power at " + (string)((integer)gBatteryLevel) + "%, ";
            if (gPowerState) status += "all systems operational.";
            else status += "systems offline.";
            
            llSay(0, applyBatteryEffects(status));
        }
    }
    
    changed(integer c) {
        if (c & CHANGED_OWNER) {
            llResetScript();
        }
    }
}
