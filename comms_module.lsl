//-- A.R.I.A. Comms Module (The "Vocalizer")
//-- Version 1.2 - UX Refinement
//-- Handles chat redirection with dynamic speech modes and improved user feedback.

// --- CONFIGURATION ---
integer comms_channel = 9974;

// --- LINKED MESSAGE CODES ---
integer SET_SPEECH_MODE = 100;
integer UPDATE_BATTERY = 101;
integer UPDATE_CONFIG = 102;
integer POWER_STATE_CHANGE = 300;

// --- STATE VARIABLES ---
float gBatteryLevel = 100.0;
key gWearer;
list gAllowList;
list gBlacklist;
integer gPowerState = TRUE;
string gSpeechMode = "Standard";

// --- MAIN SCRIPT LOGIC ---
default {
    state_entry() {
        gWearer = llGetOwner();
        // The comms module does not need to register itself. It's a fundamental system.
    }

    link_message(integer sender, integer num, string msg, key id) {
        if (num == UPDATE_BATTERY) {
            gBatteryLevel = (float)msg;
        } else if (num == UPDATE_CONFIG) {
            list parts = llParseString2List(msg, ["|"], []);
            gAllowList = llCSV2List(llList2String(parts, 1));
            gBlacklist = llCSV2List(llList2String(parts, 2));
        } else if (num == SET_SPEECH_MODE) {
            gSpeechMode = msg;
            //-- UX REFINEMENT: Wearer Feedback
            llInstantMessage(gWearer, "// Speech protocol updated to: " + gSpeechMode + " //");
        } else if (num == POWER_STATE_CHANGE) {
            if (msg == "ON") gPowerState = TRUE;
            else gPowerState = FALSE;
        }
    }

    on_rez(integer start_param) {
        llListen(comms_channel, "", llGetOwner(), "");
    }

    listen(integer channel, string name, key id, string message) {
        if (!gPowerState) return; // Do nothing if power is off

        // --- Permission Checks ---
        if (llListFindList(gAllowList, [id]) == -1) {
            if (llListFindList(gBlacklist, [id]) != -1) {
                llInstantMessage(id, "// Your communication is blocked. //");
                return;
            }
        }

        // --- Battery-based Restrictions & Effects ---
        string prefix = "[// " + name + "]:";
        string output_message = message;
        
        if (gBatteryLevel <= 15.0) {
            // Static/garbled effect
            if (llFrand(1.0) > 0.6) output_message = "...ksshh... " + message + " ...bzzzrt...";
        }
        if (gBatteryLevel <= 10.0) {
            // Stuttering
            list words = llParseString2List(message, [" "], []);
            output_message = llList2String(words, "-");
        }
        if (gBatteryLevel <= 5.0) {
            // Fading out completely
            if (llFrand(1.0) > 0.4) { return; }
        }

        // --- Persona-based Speech Patterns ---
        if (gSpeechMode == "Guardian") {
            list prefixes = ["[Tactical] ", "[Acknowledged] ", "[Executing] "];
            prefix = llList2String(prefixes, (integer)llFrand(3));
        } else if (gSpeechMode == "Polite") {
            prefix = "[At your service]:";
        } // Add other persona prefixes here...

        llSay(0, prefix + " " + output_message);
    }
}

