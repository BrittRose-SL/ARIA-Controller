//-- A.R.I.A. Owner HUD Main Kernel
//-- Version 1.0 - MULTI-UNIT OWNER CONTROL
//-- Discovers, selects, monitors, and commands multiple A.R.I.A. units
//-- CHANGES v1.0:
//--   - Added owner HUD unit discovery and registry
//--   - Added targeted and broadcast command routing
//--   - Added per-unit status tracking and selection menus

// --- COMMUNICATION CHANNELS ---
integer OWNER_HUD_CHANNEL = -18795463;
integer gMenuChannel;
integer gListenHandle;

// --- OWNER HUD STATES ---
key gOwner;
integer gScanning = FALSE;
integer gMenuState = 0;
integer MENU_MAIN = 0;
integer MENU_UNIT_SELECT = 1;
integer MENU_UNIT_COMMAND = 2;
integer MENU_BROADCAST_COMMAND = 3;
integer gSelectedUnitIndex = -1;

// --- UNIT REGISTRY ---
// Each record contains: unit key, name, battery, persona, mode, status, last update.
list gUnits;
list gUnitNames;
list gUnitBatteries;
list gUnitPersonas;
list gUnitModes;
list gUnitStatuses;
list gUnitUpdated;
list gMenuUnitIndexes;
list gMenuUnitButtons;

// --- COMMANDS ---
list gCommandButtons = ["POWER ON", "POWER OFF", "EMERGENCY STOP", "REFRESH", "BACK"];

clearUnitRegistry() {
    gUnits = [];
    gUnitNames = [];
    gUnitBatteries = [];
    gUnitPersonas = [];
    gUnitModes = [];
    gUnitStatuses = [];
}

integer findUnit(key unitKey) {
    return llListFindList(gUnits, [unitKey]);
}

addOrUpdateUnit(key unitKey, string unitName, float battery, string persona, string mode, string status) {
    integer index = findUnit(unitKey);
    if (index == -1) {
        gUnits += [unitKey];
        gUnitNames += [unitName];
        gUnitBatteries += [battery];
        gUnitPersonas += [persona];
        gUnitModes += [mode];
        gUnitStatuses += [status];
    }
    else {
        gUnitNames = llListReplaceList(gUnitNames, [unitName], index, index);
        gUnitBatteries = llListReplaceList(gUnitBatteries, [battery], index, index);
        gUnitPersonas = llListReplaceList(gUnitPersonas, [persona], index, index);
        gUnitModes = llListReplaceList(gUnitModes, [mode], index, index);
        gUnitStatuses = llListReplaceList(gUnitStatuses, [status], index, index);
    }
}

string unitDisplayName(integer index) {
    string name = llList2String(gUnitNames, index);
    if (name == "") {
        name = (string)llList2Key(gUnits, index);
    }
    return name;
}

showMainMenu() {
    string text = "A.R.I.A. OWNER HUD\n\n";
    text += "Managed units: " + (string)llGetListLength(gUnits) + "\n";
    text += "Select an operation:";
    list buttons = ["SCAN UNITS", "SELECT UNIT", "BROADCAST", "STATUS", "CLOSE"];
    llDialog(gOwner, text, buttons, gMenuChannel);
    gMenuState = MENU_MAIN;
    llSetTimerEvent(30.0);
}

showUnitSelectionMenu() {
    if (llGetListLength(gUnits) == 0) {
        llInstantMessage(gOwner, "No units have responded to the scan.");
        showMainMenu();
        return;
    }

    string text = "SELECT A.R.I.A. UNIT\n\n";
    list buttons = [];
    gMenuUnitIndexes = [];
    gMenuUnitButtons = [];
    integer i;
    for (i = 0; i < llGetListLength(gUnits) && i < 11; i++) {
        string name = unitDisplayName(i);
        if (llStringLength(name) > 20) {
            name = llGetSubString(name, 0, 19);
        }
        buttons += [name];
        gMenuUnitIndexes += [i];
        gMenuUnitButtons += [name];
        text += name + "\n";
    }
    buttons += ["BACK", "CLOSE"];
    llDialog(gOwner, text, buttons, gMenuChannel);
    gMenuState = MENU_UNIT_SELECT;
    llSetTimerEvent(30.0);
}

showUnitCommandMenu(integer index) {
    gSelectedUnitIndex = index;
    string name = unitDisplayName(index);
    string text = "UNIT CONTROL\n\n" + name + "\n";
    text += "Battery: " + (string)((integer)llList2Float(gUnitBatteries, index)) + "%\n";
    text += "Persona: " + llList2String(gUnitPersonas, index) + "\n";
    text += "Status: " + llList2String(gUnitStatuses, index) + "\n\n";
    text += "Select command:";
    llDialog(gOwner, text, gCommandButtons, gMenuChannel);
    gMenuState = MENU_UNIT_COMMAND;
    llSetTimerEvent(30.0);
}

showBroadcastMenu() {
    string text = "BROADCAST CONTROL\n\n";
    text += "The command will be sent to all discovered units.\n";
    text += "Units authenticate the owner independently.\n\n";
    text += "Select command:";
    list buttons = ["POWER ON", "POWER OFF", "EMERGENCY STOP", "REFRESH", "BACK"];
    llDialog(gOwner, text, buttons, gMenuChannel);
    gMenuState = MENU_BROADCAST_COMMAND;
    llSetTimerEvent(30.0);
}

showStatus() {
    string report = "A.R.I.A. OWNER STATUS\n\n";
    if (llGetListLength(gUnits) == 0) {
        report += "No units discovered.";
    }
    else {
        integer i;
        for (i = 0; i < llGetListLength(gUnits); i++) {
            report += unitDisplayName(i) + " | ";
            report += (string)((integer)llList2Float(gUnitBatteries, i)) + "% | ";
            report += llList2String(gUnitStatuses, i) + "\n";
        }
    }
    llInstantMessage(gOwner, report);
    showMainMenu();
}

startUnitScan() {
    clearUnitRegistry();
    gScanning = TRUE;
    llRegionSay(OWNER_HUD_CHANNEL, "ARIA_OWNER_SCAN|" + (string)gOwner);
    llInstantMessage(gOwner, "Scanning for owner-authorized A.R.I.A. units...");
    llSetTimerEvent(15.0);
}

sendTargetedCommand(string command) {
    if (gSelectedUnitIndex < 0 || gSelectedUnitIndex >= llGetListLength(gUnits)) {
        showUnitSelectionMenu();
        return;
    }
    key unitKey = llList2Key(gUnits, gSelectedUnitIndex);
    string payload = "ARIA_OWNER_COMMAND|" + (string)unitKey + "|" + (string)gOwner + "|" + command;
    llRegionSayTo(unitKey, OWNER_HUD_CHANNEL, payload);
    llInstantMessage(gOwner, "Command sent to " + unitDisplayName(gSelectedUnitIndex) + ": " + command);
    showUnitCommandMenu(gSelectedUnitIndex);
}

sendBroadcastCommand(string command) {
    string payload = "ARIA_OWNER_BROADCAST|" + (string)gOwner + "|" + command;
    integer i;
    for (i = 0; i < llGetListLength(gUnits); i++) {
        llRegionSayTo(llList2Key(gUnits, i), OWNER_HUD_CHANNEL, payload);
    }
    llInstantMessage(gOwner, "Broadcast sent to " + (string)llGetListLength(gUnits) + " discovered units: " + command);
    showBroadcastMenu();
}

requestUnitStatus() {
    integer i;
    for (i = 0; i < llGetListLength(gUnits); i++) {
        key unitKey = llList2Key(gUnits, i);
        llRegionSayTo(unitKey, OWNER_HUD_CHANNEL, "ARIA_OWNER_STATUS_REQUEST|" + (string)gOwner);
    }
}

processMenuMessage(string message) {
    if (gMenuState == MENU_MAIN) {
        if (message == "SCAN UNITS") {
            startUnitScan();
        }
        else if (message == "SELECT UNIT") {
            showUnitSelectionMenu();
        }
        else if (message == "BROADCAST") {
            showBroadcastMenu();
        }
        else if (message == "STATUS") {
            showStatus();
        }
    }
    else if (gMenuState == MENU_UNIT_SELECT) {
        if (message == "BACK") {
            showMainMenu();
        }
        else if (message != "CLOSE") {
            integer i;
            for (i = 0; i < llGetListLength(gMenuUnitButtons); i++) {
                if (llList2String(gMenuUnitButtons, i) == message) {
                    showUnitCommandMenu(llList2Integer(gMenuUnitIndexes, i));
                }
            }
        }
    }
    else if (gMenuState == MENU_UNIT_COMMAND) {
        if (message == "BACK") {
            showUnitSelectionMenu();
        }
        else if (message != "CLOSE") {
            sendTargetedCommand(message);
        }
    }
    else if (gMenuState == MENU_BROADCAST_COMMAND) {
        if (message == "BACK") {
            showMainMenu();
        }
        else if (message != "CLOSE") {
            sendBroadcastCommand(message);
        }
    }
}

default {
    state_entry() {
        gOwner = llGetOwner();
        gMenuChannel = -1000 - (integer)("0x" + llGetSubString((string)gOwner, -7, -1));
        clearUnitRegistry();
        llSetAlpha(0.0, ALL_SIDES);
        llListen(gMenuChannel, "", gOwner, "");
        llListen(OWNER_HUD_CHANNEL, "", NULL_KEY, "");
        llSetTimerEvent(10.0);
        llOwnerSay("A.R.I.A. Owner HUD v1.0 ready.");
    }

    attach(key id) {
        if (id != NULL_KEY) {
            gOwner = id;
            llResetScript();
        }
    }

    changed(integer change) {
        if (change & CHANGED_OWNER) {
            llResetScript();
        }
    }

    on_rez(integer start_param) {
        llResetScript();
    }

    touch_start(integer total_number) {
        if (llDetectedKey(0) == gOwner) {
            showMainMenu();
        }
    }

    listen(integer channel, string name, key id, string message) {
        if (channel == gMenuChannel && id == gOwner) {
            if (message == "CLOSE") {
                gMenuState = MENU_MAIN;
                llSetTimerEvent(10.0);
            }
            else {
                processMenuMessage(message);
            }
            return;
        }

        if (channel == OWNER_HUD_CHANNEL) {
            list parts = llParseString2List(message, ["|"], []);
            string command = llList2String(parts, 0);
            if (command == "ARIA_OWNER_RESPONSE" && llGetListLength(parts) >= 3) {
                key unitKey = (key)llList2String(parts, 1);
                string unitName = llList2String(parts, 2);
                if (unitKey == id) {
                    addOrUpdateUnit(unitKey, unitName, 0.0, "Unknown", "Unknown", "Discovered");
                    if (gScanning) {
                        llInstantMessage(gOwner, "Found unit: " + unitName);
                    }
                }
            }
            else if (command == "ARIA_OWNER_STATUS" && llGetListLength(parts) >= 7) {
                key unitKey = (key)llList2String(parts, 1);
                string unitName = llList2String(parts, 2);
                float battery = (float)llList2String(parts, 3);
                string persona = llList2String(parts, 4);
                string mode = llList2String(parts, 5);
                string status = llList2String(parts, 6);
                if (unitKey == id && findUnit(unitKey) != -1) {
                    addOrUpdateUnit(unitKey, unitName, battery, persona, mode, status);
                }
            }
            else if (command == "ARIA_OWNER_COMMAND_RESPONSE" && llGetListLength(parts) >= 4) {
                string unitName = "Unknown Unit";
                integer unitIndex = findUnit((key)llList2String(parts, 1));
                if (unitIndex != -1) {
                    unitName = unitDisplayName(unitIndex);
                }
                llInstantMessage(gOwner, unitName + ": " + llList2String(parts, 2) + " - " + llList2String(parts, 3));
            }
        }
    }

    timer() {
        if (gScanning) {
            gScanning = FALSE;
            showUnitSelectionMenu();
        }
        else {
            requestUnitStatus();
            llSetTimerEvent(10.0);
        }
    }
}
