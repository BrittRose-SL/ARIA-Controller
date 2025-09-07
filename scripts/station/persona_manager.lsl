//-- A.R.I.A. Station Persona Manager
//-- Version 1.0 - PERSONA INSTALLATION & MANAGEMENT
//-- Handles persona notecard transfer and activation for synced A.R.I.A. units

// --- COMMUNICATION CHANNELS ---
integer gUnitLinkChannel = -18795462; // Communication with A.R.I.A. units
integer gMenuChannel;

// --- LINKED MESSAGE CODES ---
integer STATION_MODULE_REGISTER = 500;
integer STATION_OPEN_MENU = 501;
integer STATION_UPDATE_DATA = 502;
integer STATION_UNIT_SYNC = 503;
integer STATION_UNIT_STATUS = 504;
integer STATION_REQUEST_DATA = 505;

// --- STATE VARIABLES ---
key gCurrentUser;
key gSyncedUnitKey;
string gSyncedUnitName = "";
string gCurrentPersona = "Unknown";
list gAvailablePersonas = [];
integer gListenHandle;

// --- HELPER FUNCTIONS ---
scanPersonaInventory() {
    gAvailablePersonas = [];
    integer count = llGetInventoryNumber(INVENTORY_NOTECARD);
    integer i;
    
    for (i = 0; i < count; i++) {
        string cardName = llGetInventoryName(INVENTORY_NOTECARD, i);
        if (llSubStringIndex(cardName, "Persona_") == 0) {
            string personaName = llGetSubString(cardName, 8, -1); // Remove "Persona_" prefix
            gAvailablePersonas += [personaName];
        }
    }
    
    llOwnerSay("Found " + (string)llGetListLength(gAvailablePersonas) + " personas in station inventory.");
}

openPersonaMenu(key user) {
    if (gSyncedUnitKey == NULL_KEY) {
        llInstantMessage(user, "No A.R.I.A. unit connected to station.");
        return;
    }
    
    string dialog = "\n[ PERSONA MANAGER ]\n";
    dialog += "Unit: " + gSyncedUnitName + "\n";
    dialog += "Current: " + gCurrentPersona + "\n";
    dialog += "Available: " + (string)llGetListLength(gAvailablePersonas) + "\n\n";
    dialog += "Select persona to install:";
    
    list buttons = [];
    integer i;
    
    // Add available personas (limit to 9 for dialog)
    for (i = 0; i < llGetListLength(gAvailablePersonas) && i < 9; i++) {
        string personaName = llList2String(gAvailablePersonas, i);
        // Truncate long names for buttons
        if (llStringLength(personaName) > 12) {
            personaName = llGetSubString(personaName, 0, 11);
        }
        buttons += [personaName];
    }
    
    // Add control buttons
    if (llGetListLength(gAvailablePersonas) == 0) {
        buttons += ["No Personas"];
    }
    
    buttons += ["Scan Station", "Unit Personas", "-Main-"];
    
    llListenRemove(gListenHandle);
    gMenuChannel = (integer)("0x" + llGetSubString(llGetKey(), -8, -2));
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llDialog(user, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

installPersona(string personaName, key user) {
    string notecardName = "Persona_" + personaName;
    
    if (llGetInventoryType(notecardName) != INVENTORY_NOTECARD) {
        llInstantMessage(user, "ERROR: Persona notecard '" + notecardName + "' not found in station inventory.");
        return;
    }
    
    if (gSyncedUnitKey == NULL_KEY) {
        llInstantMessage(user, "ERROR: No A.R.I.A. unit connected.");
        return;
    }
    
    llInstantMessage(user, "Installing persona '" + personaName + "' to " + gSyncedUnitName + "...");
    llSay(0, "PERSONA TRANSFER: Installing " + personaName + " to " + gSyncedUnitName);
    
    // Give the notecard to the unit
    llGiveInventory(gSyncedUnitKey, notecardName);
    
    // Send installation command to unit
    string command = "INSTALL_PERSONA|" + personaName + "|" + (string)user;
    llRegionSay(gUnitLinkChannel, command);
    
    // Also tell the unit to activate the new persona
    llSleep(2.0); // Give time for transfer
    string activateCommand = "ACTIVATE_PERSONA|" + personaName + "|" + (string)user;
    llRegionSay(gUnitLinkChannel, activateCommand);
}

showPersonaList(key user) {
    if (llGetListLength(gAvailablePersonas) == 0) {
        llInstantMessage(user, "No personas found in station inventory. Add Persona_[Name] notecards to station.");
        return;
    }
    
    string report = "AVAILABLE PERSONAS\n";
    report += "Station: " + llGetObjectName() + "\n";
    report += "═══════════════════════\n";
    
    integer i;
    for (i = 0; i < llGetListLength(gAvailablePersonas); i++) {
        string personaName = llList2String(gAvailablePersonas, i);
        string notecardName = "Persona_" + personaName;
        
        report += "• " + personaName;
        if (llGetInventoryType(notecardName) == INVENTORY_NOTECARD) {
            report += " ✓\n";
        } else {
            report += " ✗\n";
        }
    }
    
    report += "═══════════════════════\n";
    report += "Total: " + (string)llGetListLength(gAvailablePersonas) + " personas";
    
    llInstantMessage(user, report);
}

requestUnitPersonas(key user) {
    if (gSyncedUnitKey == NULL_KEY) {
        llInstantMessage(user, "No unit connected.");
        return;
    }
    
    llInstantMessage(user, "Requesting persona list from " + gSyncedUnitName + "...");
    llRegionSay(gUnitLinkChannel, "REQUEST_PERSONA_LIST|" + (string)user);
}

// --- MAIN SCRIPT LOGIC ---
default {
    state_entry() {
        gMenuChannel = (integer)("0x" + llGetSubString(llGetKey(), -8, -2));
        
        // Scan for personas in inventory
        scanPersonaInventory();
        
        // Register with main station
        llMessageLinked(LINK_ROOT, STATION_MODULE_REGISTER, "Persona Manager", NULL_KEY);
        
        // Listen for unit responses
        llListen(gUnitLinkChannel, "", NULL_KEY, "");
        
        llOwnerSay("Station Persona Manager v1.0 initialized.");
    }

    link_message(integer sender, integer num, string msg, key id) {
        if (num == STATION_OPEN_MENU) {
            // Parse: userkey|modulename
            list parts = llParseString2List(msg, ["|"], []);
            key user = (key)llList2String(parts, 0);
            string moduleName = llList2String(parts, 1);
            
            if (moduleName == "Persona Manager" || moduleName == "Persona" || moduleName == "Personas") {
                gCurrentUser = user;
                openPersonaMenu(user);
            }
        }
        else if (num == STATION_UNIT_SYNC) {
            list parts = llParseString2List(msg, ["|"], []);
            string syncCommand = llList2String(parts, 0);
            
            if (syncCommand == "SYNC_SUCCESS") {
                gSyncedUnitKey = (key)llList2String(parts, 1);
                gSyncedUnitName = llList2String(parts, 2);
                llOwnerSay("Persona Manager synced with: " + gSyncedUnitName);
            }
            else if (syncCommand == "DISCONNECT") {
                gSyncedUnitKey = NULL_KEY;
                gSyncedUnitName = "";
                gCurrentPersona = "Unknown";
                llOwnerSay("Persona Manager disconnected from unit.");
            }
        }
        else if (num == STATION_UPDATE_DATA) {
            list parts = llParseString2List(msg, ["|"], []);
            string dataType = llList2String(parts, 0);
            
            if (dataType == "INVENTORY_CHANGED") {
                scanPersonaInventory();
            }
        }
        else if (num == STATION_UNIT_STATUS) {
            // Parse unit status data
            list parts = llParseString2List(msg, ["|"], []);
            if (llGetListLength(parts) >= 4) {
                gSyncedUnitKey = (key)llList2String(parts, 0);
                gSyncedUnitName = llList2String(parts, 1);
                // parts[2] is battery, parts[3] is persona
                gCurrentPersona = llList2String(parts, 3);
            }
        }
    }

    listen(integer chan, string name, key id, string msg) {
        // Handle unit responses
        if (chan == gUnitLinkChannel) {
            list parts = llParseString2List(msg, ["|"], []);
            string command = llList2String(parts, 0);
            
            if (command == "PERSONA_INSTALL_RESPONSE") {
                if (llGetListLength(parts) >= 3) {
                    string personaName = llList2String(parts, 1);
                    string result = llList2String(parts, 2);
                    
                    if (result == "SUCCESS") {
                        llInstantMessage(gCurrentUser, "Persona '" + personaName + "' installed successfully!");
                        llSay(0, "PERSONA INSTALLED: " + personaName + " on " + gSyncedUnitName);
                        gCurrentPersona = personaName;
                    } else {
                        llInstantMessage(gCurrentUser, "Failed to install persona '" + personaName + "': " + result);
                    }
                }
                return;
            }
            else if (command == "PERSONA_ACTIVATE_RESPONSE") {
                if (llGetListLength(parts) >= 3) {
                    string personaName = llList2String(parts, 1);
                    string result = llList2String(parts, 2);
                    
                    if (result == "SUCCESS") {
                        llInstantMessage(gCurrentUser, "Persona '" + personaName + "' activated successfully!");
                        gCurrentPersona = personaName;
                    } else {
                        llInstantMessage(gCurrentUser, "Failed to activate persona '" + personaName + "': " + result);
                    }
                }
                return;
            }
            else if (command == "PERSONA_LIST_RESPONSE") {
                if (llGetListLength(parts) >= 2) {
                    list unitPersonas = llCSV2List(llList2String(parts, 1));
                    string report = "UNIT PERSONAS\n";
                    report += "Unit: " + gSyncedUnitName + "\n";
                    report += "Current: " + gCurrentPersona + "\n";
                    report += "═══════════════════════\n";
                    
                    integer i;
                    for (i = 0; i < llGetListLength(unitPersonas); i++) {
                        string personaName = llList2String(unitPersonas, i);
                        report += "• " + personaName;
                        if (personaName == gCurrentPersona) {
                            report += " (ACTIVE)";
                        }
                        report += "\n";
                    }
                    
                    report += "═══════════════════════\n";
                    report += "Total: " + (string)llGetListLength(unitPersonas) + " personas";
                    
                    llInstantMessage(gCurrentUser, report);
                }
                return;
            }
            return;
        }
        
        // Handle menu interactions
        if (chan == gMenuChannel) {
            llListenRemove(gListenHandle);
            
            if (msg == "-Main-") {
                llInstantMessage(id, "Returning to main station menu.");
                return;
            }
            else if (msg == "Scan Station") {
                scanPersonaInventory();
                showPersonaList(id);
                openPersonaMenu(id);
            }
            else if (msg == "Unit Personas") {
                requestUnitPersonas(id);
                openPersonaMenu(id);
            }
            else if (msg == "No Personas") {
                llInstantMessage(id, "No personas available. Add Persona_[Name] notecards to station inventory.");
                openPersonaMenu(id);
            }
            else {
                // Check if it's a persona name
                if (llListFindList(gAvailablePersonas, [msg]) != -1) {
                    installPersona(msg, id);
                    llSleep(3.0); // Give time for installation
                    openPersonaMenu(id);
                } else {
                    // Check for truncated names
                    integer i;
                    for (i = 0; i < llGetListLength(gAvailablePersonas); i++) {
                        string fullName = llList2String(gAvailablePersonas, i);
                        if (llSubStringIndex(fullName, msg) == 0) {
                            installPersona(fullName, id);
                            llSleep(3.0);
                            openPersonaMenu(id);
                            return;
                        }
                    }
                    
                    llInstantMessage(id, "Unknown persona: " + msg);
                    openPersonaMenu(id);
                }
            }
        }
    }
    
    timer() {
        llListenRemove(gListenHandle);
    }
    
    changed(integer change) {
        if (change & CHANGED_INVENTORY) {
            scanPersonaInventory();
            llOwnerSay("Persona inventory updated. Found " + (string)llGetListLength(gAvailablePersonas) + " personas.");
        }
        if (change & CHANGED_OWNER) {
            llResetScript();
        }
    }
}
