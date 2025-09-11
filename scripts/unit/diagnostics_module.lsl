//-- A.R.I.A. Diagnostics RLV Module (Add-on)
//-- Version 1.3 - FIXED PERMISSIONS & SYNTAX ERROR FIX
//-- Administrator tool for querying viewer status and managing RLV Relay.
//-- CHANGELOG v1.3: Fixed permissions system - now properly receives and uses admin lists from master kernel
//-- CHANGELOG v1.2: Fixed syntax error on line 59 - corrected function definition and calls

// --- LINKED MESSAGE CODES ---
integer UPDATE_CONFIG = 102;
integer MODULE_REGISTER = 200;
integer OPEN_MY_MENU = 201;

// --- STATE VARIABLES ---
integer gMenuChannel;
integer gListenHandle;
list gAdministrators;
list gTrustedUsers;
key wearer;

//-- Module State
integer gRelayMode = 0; // 0=Off, 1=Ask, 2=Trusted, 3=Everyone
list gRelayModes = ["Off", "Ask", "Trusted", "Everyone"];

// --- PERMISSION LEVELS ---
integer ACCESS_ADMIN = 4;
integer ACCESS_TRUSTED = 3;
integer ACCESS_WEARER = 2;
integer ACCESS_PUBLIC = 1;

// --- INITIALIZATION CONTROL ---
integer gConfigReceived = FALSE;

// --- HELPER FUNCTIONS ---
integer getAccessLevel(key id) {
    if (llListFindList(gAdministrators, [id]) != -1) return ACCESS_ADMIN;
    if (llListFindList(gTrustedUsers, [id]) != -1) return ACCESS_TRUSTED;
    if (id == wearer) return ACCESS_WEARER;
    return ACCESS_PUBLIC;
}

applyRestrictions() {
    if (gRelayMode == 0) llOwnerSay("@relay_off");
    else if (gRelayMode == 1) llOwnerSay("@relay_ask");
    else if (gRelayMode == 2) llOwnerSay("@relay_trusted");
    else if (gRelayMode == 3) llOwnerSay("@relay_everyone");
}

openControlMenu(key user_id) {
    integer access = getAccessLevel(user_id);
    
    if (access < ACCESS_TRUSTED) {
        llInstantMessage(user_id, "Access denied. Trusted user or Administrator permissions required for Diagnostics.");
        return;
    }
    
    string dialog = "\n[ DIAGNOSTICS & RELAY ]\n";
    dialog += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
    dialog += "Access Level: ";
    if (access >= ACCESS_ADMIN) {
        dialog += "ADMINISTRATOR\n";
    } else {
        dialog += "TRUSTED USER\n";
    }
    
    string relayStatus = llList2String(gRelayModes, gRelayMode);
    dialog += "Current RLV Relay: " + relayStatus + "\n";
    dialog += "Config Status: ";
    if (gConfigReceived) {
        dialog += "SYNCHRONIZED";
    } else {
        dialog += "WAITING";
    }
    dialog += "\n\nSelect option:";
    
    list buttons = [];
    
    // Core diagnostics available to trusted users and above
    buttons += ["Get Version", "Get Attachments", "Get Status"];
    
    // RLV Relay control for administrators only
    if (access >= ACCESS_ADMIN) {
        buttons += ["RLV Relay: " + relayStatus];
    }
    
    buttons += ["Refresh", "-Main-", "Close"];

    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", user_id, "");
    llDialog(user_id, dialog, buttons, gMenuChannel);
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
        
        llMessageLinked(LINK_ROOT, MODULE_REGISTER, "Diagnostics", NULL_KEY);
        llOwnerSay("Diagnostics module v1.3 initialized successfully.");
        llOwnerSay("CHANGELOG v1.3: Fixed permissions system integration");
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
                llOwnerSay("Diagnostics permissions updated from master kernel.");
                llOwnerSay("Administrators: " + (string)llGetListLength(gAdministrators));
                llOwnerSay("Trusted Users: " + (string)llGetListLength(gTrustedUsers));
            }
        } 
        else if (num == OPEN_MY_MENU) {
            key user = (key)msg;
            openControlMenu(user);
        }
    }

    listen(integer chan, string name, key id, string msg) {
        if (chan != gMenuChannel) return;
        
        llSetTimerEvent(0.0);
        llListenRemove(gListenHandle);

        integer access = getAccessLevel(id);
        
        if (msg == "-Main-" || msg == "Close") { 
            if (msg == "Close") {
                llInstantMessage(id, "Diagnostics menu closed.");
            }
            return; 
        }
        
        if (msg == "Refresh") {
            llInstantMessage(id, "Refreshing diagnostics data...");
            openControlMenu(id);
            return;
        }

        // Check permissions for each action
        if (llSubStringIndex(msg, "RLV Relay:") != -1) {
            if (access >= ACCESS_ADMIN) {
                gRelayMode = (gRelayMode + 1) % 4; // Cycle through the 4 modes
                string newStatus = llList2String(gRelayModes, gRelayMode);
                llInstantMessage(id, "RLV Relay mode changed to: " + newStatus);
                applyRestrictions();
            } else {
                llInstantMessage(id, "Access denied. Administrator permissions required for RLV Relay control.");
            }
        } 
        else if (msg == "Get Version") {
            if (access >= ACCESS_TRUSTED) {
                llOwnerSay("@version");
                llInstantMessage(id, "Version query sent. Response will be delivered via IM from the main unit.");
            } else {
                llInstantMessage(id, "Access denied. Trusted user permissions required.");
            }
        } 
        else if (msg == "Get Attachments") {
            if (access >= ACCESS_TRUSTED) {
                llOwnerSay("@getattachlist");
                llInstantMessage(id, "Attachment list query sent. Response will be delivered via IM from the main unit.");
            } else {
                llInstantMessage(id, "Access denied. Trusted user permissions required.");
            }
        }
        else if (msg == "Get Status") {
            if (access >= ACCESS_TRUSTED) {
                llOwnerSay("@getstatus");
                llInstantMessage(id, "Status query sent. Response will be delivered via IM from the main unit.");
            } else {
                llInstantMessage(id, "Access denied. Trusted user permissions required.");
            }
        }
        else {
            llInstantMessage(id, "Unknown command: " + msg);
        }
        
        // Reopen menu after action
        openControlMenu(id);
    }
    
    timer() {
        llListenRemove(gListenHandle);
    }
    
    changed(integer change) {
        if (change & CHANGED_OWNER) {
            llResetScript();
        }
    }
}
