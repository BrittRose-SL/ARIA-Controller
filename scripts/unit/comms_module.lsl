//-- A.R.I.A. Comms Module (The "Vocalizer")
//-- Version 2.1 - FIXED PERMISSIONS + PERSONA INTEGRATION + ENHANCED CHAT REDIRECTION
//-- CHANGELOG v2.1: Integrated proper permissions system with master kernel synchronization
//-- CHANGELOG v2.0: Handles chat redirection with dynamic persona-based speech modes and improved user feedback
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
integer OPEN_MY_MENU = 201;
integer RELAY_CHAT_MESSAGE = 300;
integer POWER_STATE_CHANGE = 300;

// --- PERMISSION VARIABLES ---
list gAdministrators;
list gTrustedUsers;
key wearer;
integer gWearerAdminMode = TRUE;
integer gConfigReceived = FALSE;

// --- PERMISSION LEVELS ---
integer ACCESS_ADMIN = 4;
integer ACCESS_TRUSTED = 3;
integer ACCESS_WEARER = 2;
integer ACCESS_PUBLIC = 1;

// --- STATE VARIABLES ---
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

// --- PERMISSION FUNCTIONS ---
integer getAccessLevel(key id) {
    if (llListFindList(gAdministrators, [id]) != -1) return ACCESS_ADMIN;
    if (llListFindList(gTrustedUsers, [id]) != -1) return ACCESS_TRUSTED;
    
    if (id == wearer) {
        if (gWearerAdminMode) {
            return ACCESS_ADMIN;
        } else {
            return ACCESS_WEARER;
        }
    }
    
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
    if (!gPersonaFilterEnabled) return message;
    
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
    if (!gBatteryEffectsEnabled) return message;
    
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

// --- MENU FUNCTIONS ---
openCommsMenu(key user) {
    integer access = getAccessLevel(user);
    
    string dialog = "\n[ COMMUNICATIONS MODULE ]\n";
    dialog += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
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
        dialog += "SYNCHRONIZED\n";
    } else {
        dialog += "WAITING\n";
    }
    
    dialog += "Power State: " + (string)gPowerState + "\n";
    dialog += "Battery Level: " + (string)((integer)gBatteryLevel) + "%\n";
    dialog += "Current Persona: " + gCurrentPersona + "\n";
    dialog += "Speech Mode: " + gSpeechMode + "\n";
    dialog += "Channel: " + (string)comms_channel + "\n";
    dialog += "Status: ";
    if (gCommsEnabled) {
        dialog += "ACTIVE";
    } else {
        dialog += "DISABLED";
    }
    
    list buttons = [];
    
    // Basic controls available to wearer and above
    if (access >= ACCESS_WEARER) {
        buttons += ["Test Comms", "Channel Info"];
    }
    
    // Configuration controls for trusted users and above
    if (access >= ACCESS_TRUSTED) {
        string toggleText = "Disable Comms";
        if (!gCommsEnabled) toggleText = "Enable Comms";
        buttons += [toggleText];
        
        string filterText = "Disable Filter";
        if (!gPersonaFilterEnabled) filterText = "Enable Filter";
        buttons += [filterText];
        
        string effectsText = "Disable Effects";
        if (!gBatteryEffectsEnabled) effectsText = "Enable Effects";
        buttons += [effectsText];
    }
    
    // Admin-only controls
    if (access >= ACCESS_ADMIN) {
        buttons += ["Set Channel", "Reset Config"];
    }
    
    buttons += ["Refresh", "Close", "-Main-"];
    
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llDialog(user, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

// --- MAIN SCRIPT LOGIC ---
default {
    state_entry() {
        wearer = llGetOwner();
        gMenuChannel = (integer)("0x" + llGetSubString(llGetKey(), -8, -2));
        gConfigReceived = FALSE;
        
        // Initialize with owner as admin (backup measure)
        gAdministrators = [wearer];
        gTrustedUsers = [];
        
        // Register this module with the main system
        llMessageLinked(LINK_ROOT, MODULE_REGISTER, "Comms", NULL_KEY);
        
        // Set up listening on the comms channel
        gCommsListenHandle = llListen(comms_channel, "", wearer, "");
        
        llOwnerSay("🤖 Comms Module v2.1 initialized. Speech redirection active on channel " + (string)comms_channel);
        llOwnerSay("CHANGELOG v2.1: Integrated proper permissions system");
        llInstantMessage(wearer, "// Chat redirection active. Type on channel " + (string)comms_channel + " to speak as " + gUnitName + " //");
    }

    link_message(integer sender, integer num, string msg, key id) {
        if (num == UPDATE_CONFIG) {
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
                llOwnerSay("Comms permissions updated from master kernel.");
                llOwnerSay("Administrators: " + (string)llGetListLength(gAdministrators));
                llOwnerSay("Trusted Users: " + (string)llGetListLength(gTrustedUsers));
            }
        }
        else if (num == OPEN_MY_MENU) {
            key user = (key)msg;
            if (checkModuleAccess(user, ACCESS_WEARER, "Communications")) {
                openCommsMenu(user);
            }
        }
        else if (num == UPDATE_BATTERY) {
            gBatteryLevel = (float)msg;
        } 
        else if (num == UPDATE_UNIT_INFO) {
            gUnitName = msg;
        }
        else if (num == UPDATE_PERSONA_STATUS) {
            gCurrentPersona = msg;
            llInstantMessage(wearer, "// Speech patterns updated for persona: " + gCurrentPersona + " //");
        }
        else if (num == SET_SPEECH_MODE) {
            gSpeechMode = msg;
            llInstantMessage(wearer, "// Speech protocol updated to: " + gSpeechMode + " //");
        } 
        else if (num == POWER_STATE_CHANGE) {
            if (msg == "ON") {
                gPowerState = TRUE;
                llInstantMessage(wearer, "// Communications online //");
            }
            else {
                gPowerState = FALSE;
                llInstantMessage(wearer, "// Communications offline //");
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
                llInstantMessage(wearer, "// Communications offline - unable to transmit //");
                return;
            }
            
            if (!gCommsEnabled) {
                llInstantMessage(wearer, "// Communications disabled by administrator //");
                return;
            }
            
            // Only process messages from the wearer
            if (id != wearer) return;
            
            // Permission check - ensure wearer is authorized to use comms
            integer access = getAccessLevel(wearer);
            if (access < ACCESS_WEARER) {
                llInstantMessage(wearer, "// Communication access denied - insufficient permissions //");
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
                llMessageLinked(LINK_SET, RELAY_CHAT_MESSAGE, message, wearer);
            } else {
                llInstantMessage(wearer, "// Transmission failed - insufficient power //");
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
            
            integer access = getAccessLevel(id);
            
            if (message == "-Main-" || message == "Close") {
                if (message == "Close") {
                    llInstantMessage(id, "Communications menu closed.");
                }
                return;
            }
            
            if (message == "Refresh") {
                llInstantMessage(id, "Refreshing communications data...");
                openCommsMenu(id);
                return;
            }
            
            // Handle menu options with permission checks
            if (message == "Test Comms") {
                if (access >= ACCESS_WEARER) {
                    if (gPowerState && gCommsEnabled) {
                        string testMsg = getPersonaPrefix(gCurrentPersona, gSpeechMode) + " Communications test successful.";
                        llSay(0, applyBatteryEffects(testMsg));
                        llInstantMessage(id, "Test message transmitted.");
                    } else {
                        llInstantMessage(id, "Communications offline or disabled.");
                    }
                } else {
                    llInstantMessage(id, "Access denied. Wearer permissions required.");
                }
            }
            else if (message == "Channel Info") {
                if (access >= ACCESS_WEARER) {
                    llInstantMessage(id, "Communications Channel: " + (string)comms_channel + "\nType on this channel to speak as " + gUnitName + ".");
                } else {
                    llInstantMessage(id, "Access denied. Wearer permissions required.");
                }
            }
            else if (message == "Enable Comms" || message == "Disable Comms") {
                if (access >= ACCESS_TRUSTED) {
                    gCommsEnabled = !gCommsEnabled;
                    string status = "enabled";
                    if (!gCommsEnabled) status = "disabled";
                    llInstantMessage(id, "Communications " + status + ".");
                    llInstantMessage(wearer, "// Communications " + status + " by administrator //");
                } else {
                    llInstantMessage(id, "Access denied. Trusted user permissions required.");
                }
            }
            else if (message == "Enable Filter" || message == "Disable Filter") {
                if (access >= ACCESS_TRUSTED) {
                    gPersonaFilterEnabled = !gPersonaFilterEnabled;
                    string status = "enabled";
                    if (!gPersonaFilterEnabled) status = "disabled";
                    llInstantMessage(id, "Persona filtering " + status + ".");
                } else {
                    llInstantMessage(id, "Access denied. Trusted user permissions required.");
                }
            }
            else if (message == "Enable Effects" || message == "Disable Effects") {
                if (access >= ACCESS_TRUSTED) {
                    gBatteryEffectsEnabled = !gBatteryEffectsEnabled;
                    string status = "enabled";
                    if (!gBatteryEffectsEnabled) status = "disabled";
                    llInstantMessage(id, "Battery effects " + status + ".");
                } else {
                    llInstantMessage(id, "Access denied. Trusted user permissions required.");
                }
            }
            else if (message == "Set Channel") {
                if (access >= ACCESS_ADMIN) {
                    llInstantMessage(id, "Channel change feature not yet implemented. Current channel: " + (string)comms_channel);
                } else {
                    llInstantMessage(id, "Access denied. Administrator permissions required.");
                }
            }
            else if (message == "Reset Config") {
                if (access >= ACCESS_ADMIN) {
                    gCommsEnabled = TRUE;
                    gPersonaFilterEnabled = TRUE;
                    gBatteryEffectsEnabled = TRUE;
                    llInstantMessage(id, "Communications configuration reset to defaults.");
                    llInstantMessage(wearer, "// Communications settings reset by administrator //");
                } else {
                    llInstantMessage(id, "Access denied. Administrator permissions required.");
                }
            }
            else {
                llInstantMessage(id, "Unknown command: " + message);
            }
            
            // Reopen menu after action
            openCommsMenu(id);
        }
    }

    on_rez(integer start_param) {
        // Re-establish comms channel listener
        llListenRemove(gCommsListenHandle);
        gCommsListenHandle = llListen(comms_channel, "", llGetOwner(), "");
    }
    
    timer() {
        llListenRemove(gListenHandle);
    }
    
    changed(integer c) {
        if (c & CHANGED_OWNER) {
            llResetScript();
        }
    }
}
