//-- A.R.I.A. Diagnostics RLV Module (Add-on)
//-- Version 1.2 - Syntax Error Fix
//-- Administrator tool for querying viewer status and managing RLV Relay.
//-- CHANGELOG: Fixed syntax error on line 59 - corrected function definition and calls

// --- LINKED MESSAGE CODES ---
integer UPDATE_CONFIG = 102;
integer MODULE_REGISTER = 200;
integer OPEN_MY_MENU = 201;

// --- STATE VARIABLES ---
integer gMenuChannel;
integer gListenHandle;
key gAdministrator;

//-- Module State
integer gRelayMode = 0; // 0=Off, 1=Ask, 2=Trusted, 3=Everyone
list gRelayModes = ["Off", "Ask", "Trusted", "Everyone"];

// --- HELPER FUNCTIONS ---
applyRestrictions() {
    if (gRelayMode == 0) llOwnerSay("@relay_off");
    else if (gRelayMode == 1) llOwnerSay("@relay_ask");
    else if (gRelayMode == 2) llOwnerSay("@relay_trusted");
    else if (gRelayMode == 3) llOwnerSay("@relay_everyone");
}

openControlMenu(key admin_id) {
    //-- UX REFINEMENT: Menu provides clear status feedback
    string dialog = "\n[ DIAGNOSTICS & RELAY ]\n[---------------------]\n";
    list buttons;
    
    string relayStatus = llList2String(gRelayModes, gRelayMode);

    buttons += ["RLV Relay: " + relayStatus];
    buttons += ["Get Version", "Get Attachments", "-Main-"];

    gListenHandle = llListen(gMenuChannel, "", admin_id, "");
    llDialog(admin_id, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

// --- MAIN SCRIPT LOGIC ---
default {
    state_entry() {
        gMenuChannel = (integer)("0x" + llGetSubString(llGetKey(), -8, -2));
        llMessageLinked(LINK_ROOT, MODULE_REGISTER, "Diagnostics RLV", NULL_KEY);
    }

    link_message(integer sender, integer num, string msg, key id) {
        if (num == UPDATE_CONFIG) {
            list parts = llParseString2List(msg, ["|"], []);
            gAdministrator = (key)llList2String(parts, 0);
        } else if (num == OPEN_MY_MENU) {
            if (llGetLinkName(sender) == "main_module") {
                 openControlMenu((key)msg);
            }
        }
    }

    listen(integer chan, string name, key id, string msg) {
        llSetTimerEvent(0.0);
        llListenRemove(gListenHandle);

        if (msg == "-Main-") { return; }

        if (llSubStringIndex(msg, "RLV Relay:") != -1) {
            gRelayMode = (gRelayMode + 1) % 4; // Cycle through the 4 modes
        } else if (msg == "Get Version") {
            llOwnerSay("@version");
            llInstantMessage(id, "Version query sent. Response will be delivered via IM from the main unit.");
        } else if (msg == "Get Attachments") {
            llOwnerSay("@getattachlist");
            llInstantMessage(id, "Attachment list query sent. Response will be delivered via IM from the main unit.");
        }
        
        applyRestrictions();
        llInstantMessage(id, "Diagnostics & Relay protocols updated.");
        openControlMenu(id);
    }
    
    timer() {
        llListenRemove(gListenHandle);
    }
}
