//-- A.R.I.A. Wearer HUD Main Controller v3.0.1
//-- Clean Rewrite - September 6, 2025
//-- Controls visibility of all HUD components via hovertext interface
//-- Attach to TOP CENTER HUD position

string VERSION = "3.0.1";
string BUILD_DATE = "2025-09-06";

// Communication channels
integer gCmdChannel = -18795462;
integer gMenuChannel;
integer gListener;

// HUD state variables
key gOwner;
integer gAttached = FALSE;
string gConnectedUnit = "";
list gUnits = [];
integer gScanning = FALSE;
integer gState = 0; // 0=disconnected, 1=scanning, 2=connected

// Component visibility states
integer gShowUnitStatus = TRUE;
integer gShowAppStatus = TRUE;
integer gShowProximityScanner = TRUE;

// Status data to share with other components
float gBattery = 100.0;
string gPersona = "Default";
string gMode = "Standard";
string gStatus = "Ready";
string gAdminName = "None";
integer gSecured = FALSE;
float gArousal = 0.0;
float gStimulation = 0.0;
float gEnergy = 100.0;
integer gTreatLevel = 0;

// Module and restriction tracking
list gActiveModules = ["Core System"];
list gActiveRestrictions = [];

// HUD component link numbers (set these when you link the prims)
integer UNIT_STATUS_LINK = 2;      // Left side component
integer APP_STATUS_LINK = 3;       // Right side component  
integer PROXIMITY_SCANNER_LINK = 4; // Bottom center component

// Main controller display
updateMainDisplay() {
    string display = "A.R.I.A. HUD v" + VERSION + "\n";
    
    if (gState == 0) {
        display += "STATUS: DISCONNECTED\n";
        display += "Ready to scan for units\n";
    }
    else if (gState == 1) {
        display += "STATUS: SCANNING...\n";
        display += "Found: " + (string)(llGetListLength(gUnits)/3) + " units\n";
    }
    else if (gState == 2) {
        display += "STATUS: CONNECTED\n";
        display += "Unit: " + gConnectedUnit + "\n";
    }
    
    display += "\nCOMPONENT CONTROLS\n";
    
    if (gShowUnitStatus) {
        display += "< HIDE UNIT STATUS\n";
    } else {
        display += "< SHOW UNIT STATUS\n";
    }
    
    if (gShowAppStatus) {
        display += "> HIDE APP STATUS\n";
    } else {
        display += "> SHOW APP STATUS\n";
    }
    
    if (gShowProximityScanner) {
        display += "v HIDE PROXIMITY\n";
    } else {
        display += "v SHOW PROXIMITY\n";
    }
    
    if (gState == 0) {
        display += "\n[TOUCH] Scan for Units";
    } else if (gState == 2) {
        display += "\n[TOUCH] Module Menu";
    }
    
    // Set hovertext - cyan color for main controller
    llSetText(display, <0.0, 1.0, 1.0>, 1.0);
}

// Send status updates to all components
broadcastStatusUpdate() {
    string statusData = "STATUS_UPDATE|" + 
                       gConnectedUnit + "|" +
                       (string)gBattery + "|" +
                       gPersona + "|" +
                       gAdminName + "|" +
                       (string)gSecured + "|" +
                       (string)gArousal + "|" +
                       (string)gStimulation + "|" +
                       (string)gEnergy + "|" +
                       (string)gTreatLevel;
    
    // Send to all linked components
    llMessageLinked(LINK_ALL_OTHERS, 1000, statusData, "");
    
    // Send module list
    string moduleData = "MODULES_UPDATE|" + llDumpList2String(gActiveModules, "|");
    llMessageLinked(LINK_ALL_OTHERS, 1001, moduleData, "");
    
    // Send restrictions list
    string restrictionData = "RESTRICTIONS_UPDATE|" + llDumpList2String(gActiveRestrictions, "|");
    llMessageLinked(LINK_ALL_OTHERS, 1002, restrictionData, "");
}

// Send visibility commands to components
updateComponentVisibility() {
    // Send visibility states to components
    llMessageLinked(UNIT_STATUS_LINK, 2000, "VISIBILITY|" + (string)gShowUnitStatus, "");
    llMessageLinked(APP_STATUS_LINK, 2000, "VISIBILITY|" + (string)gShowAppStatus, "");
    llMessageLinked(PROXIMITY_SCANNER_LINK, 2000, "VISIBILITY|" + (string)gShowProximityScanner, "");
}

// Core initialization function
initializeMainController() {
    llOwnerSay("A.R.I.A. Wearer HUD v" + VERSION + " initializing...");
    llOwnerSay("Hovertext Interface - Main Controller");
    
    gOwner = llGetOwner();
    gMenuChannel = -1000 - (integer)("0x" + llGetSubString((string)gOwner, -7, -1));
    
    // Check attachment status
    gAttached = (llGetAttached() > 0);
    
    if (gAttached) {
        llOwnerSay("Main Controller attached");
    } else {
        llOwnerSay("Main Controller in world mode");
    }
    
    // Make prim invisible but keep hovertext
    llSetAlpha(0.0, ALL_SIDES);
    
    // Set initial state
    gState = 0;
    updateMainDisplay();
    updateComponentVisibility();
    broadcastStatusUpdate();
    setupListeners();
    
    llOwnerSay("A.R.I.A. Main Controller ready");
    llOwnerSay("Touch to scan for units or access modules");
}

// Set up communication listeners
setupListeners() {
    llListenRemove(gListener);
    gListener = llListen(gMenuChannel, "", gOwner, "");
    llListen(gCmdChannel, "", "", "");
}

// Show main menu dialog
showMainMenu() {
    string menuText = "A.R.I.A. MAIN CONTROLLER\n\n";
    
    if (gState == 2) {
        menuText += "Connected: " + gConnectedUnit + "\n";
        menuText += "Battery: " + (string)((integer)gBattery) + "%\n\n";
        menuText += "Select function:";
        
        list buttons = ["MODULES", "SECURITY", "DISCONNECT", "COMPONENTS", "SCAN", "CLOSE"];
        llDialog(gOwner, menuText, buttons, gMenuChannel);
    } else {
        menuText += "Status: DISCONNECTED\n\n";
        menuText += "Select function:";
        
        list buttons = ["SCAN", "COMPONENTS", "CONFIG", "CLOSE"];
        llDialog(gOwner, menuText, buttons, gMenuChannel);
    }
}

// Show component visibility menu
showComponentMenu() {
    string menuText = "HUD COMPONENT CONTROL\n\n";
    menuText += "Toggle component visibility:\n\n";
    
    if (gShowUnitStatus) {
        menuText += "Unit Status: VISIBLE\n";
    } else {
        menuText += "Unit Status: HIDDEN\n";
    }
    
    if (gShowAppStatus) {
        menuText += "App Status: VISIBLE\n";
    } else {
        menuText += "App Status: HIDDEN\n";
    }
    
    if (gShowProximityScanner) {
        menuText += "Proximity: VISIBLE\n";
    } else {
        menuText += "Proximity: HIDDEN\n";
    }
    
    list buttons = ["TOGGLE UNIT", "TOGGLE APP", "TOGGLE PROX", "ALL ON", "ALL OFF", "BACK"];
    llDialog(gOwner, menuText, buttons, gMenuChannel);
}

// Show module selection menu
showModuleMenu() {
    string menuText = "MODULE SELECTION\n\n";
    menuText += "Current Modules: " + (string)llGetListLength(gActiveModules) + "\n\n";
    menuText += "Select module to toggle:";
    
    list buttons = ["DIAGNOSTIC", "SECURITY", "PERSONALITY", "RLV", "SENSORS", "BACK"];
    llDialog(gOwner, menuText, buttons, gMenuChannel);
}

// Start scanning for A.R.I.A. units
startUnitScan() {
    if (gScanning) {
        llOwnerSay("Scan already in progress");
        return;
    }
    
    gScanning = TRUE;
    gUnits = [];
    gState = 1;
    
    updateMainDisplay();
    
    // Broadcast scan request
    llRegionSay(gCmdChannel, "ARIA_SCAN|" + (string)gOwner);
    
    // Set scan timeout
    llSetTimerEvent(30.0);
    
    llOwnerSay("Scanning for A.R.I.A. units within 20m...");
}

// Stop current scan
stopUnitScan() {
    if (!gScanning) return;
    
    gScanning = FALSE;
    llSetTimerEvent(0.0);
    
    if (llGetListLength(gUnits) > 0) {
        showUnitSelectionMenu();
    } else {
        gState = 0;
        updateMainDisplay();
        llOwnerSay("No A.R.I.A. units found nearby");
    }
}

// Show unit selection menu
showUnitSelectionMenu() {
    if (llGetListLength(gUnits) == 0) {
        gState = 0;
        updateMainDisplay();
        return;
    }
    
    string menuText = "UNITS FOUND\n\nSelect unit to connect:\n\n";
    
    list buttons = [];
    integer i;
    for (i = 0; i < llGetListLength(gUnits) && i < 27; i += 3) {
        string unitName = llList2String(gUnits, i + 1);
        buttons += [unitName];
        menuText += "• " + unitName + "\n";
    }
    buttons += ["CANCEL"];
    
    llDialog(gOwner, menuText, buttons, gMenuChannel);
}

// Connect to selected unit
connectToUnit(string unitName) {
    integer i;
    for (i = 0; i < llGetListLength(gUnits); i += 3) {
        if (llList2String(gUnits, i + 1) == unitName) {
            key unitKey = llList2String(gUnits, i);
            string unitChannel = llList2String(gUnits, i + 2);
            
            gConnectedUnit = unitName;
            gState = 2;
            gAdminName = llGetDisplayName(gOwner);
            
            // Add some default modules when connected
            gActiveModules = ["Core System", "Security", "Diagnostics"];
            
            updateMainDisplay();
            broadcastStatusUpdate();
            
            // Request initial status
            llRegionSay((integer)unitChannel, "ARIA_STATUS_REQUEST|" + (string)gOwner);
            
            llOwnerSay("Connected to " + unitName);
            return;
        }
    }
    
    llOwnerSay("Unit not found: " + unitName);
}

// Disconnect from current unit
disconnectFromUnit() {
    if (gConnectedUnit == "") {
        llOwnerSay("Not connected to any unit");
        return;
    }
    
    string oldUnit = gConnectedUnit;
    gConnectedUnit = "";
    gState = 0;
    gActiveModules = ["Core System"];
    gActiveRestrictions = [];
    
    updateMainDisplay();
    broadcastStatusUpdate();
    
    llOwnerSay("Disconnected from " + oldUnit);
}

// Toggle module in active list
toggleModule(string moduleName) {
    integer index = llListFindList(gActiveModules, [moduleName]);
    if (index >= 0) {
        gActiveModules = llDeleteSubList(gActiveModules, index, index);
        llOwnerSay(moduleName + " module disabled");
    } else {
        gActiveModules += [moduleName];
        llOwnerSay(moduleName + " module enabled");
    }
    broadcastStatusUpdate();
}

// Process menu responses
processMenuResponse(string message) {
    if (message == "SCAN") {
        startUnitScan();
    }
    else if (message == "COMPONENTS") {
        showComponentMenu();
    }
    else if (message == "MODULES") {
        showModuleMenu();
    }
    else if (message == "DISCONNECT") {
        disconnectFromUnit();
    }
    else if (message == "TOGGLE UNIT") {
        gShowUnitStatus = !gShowUnitStatus;
        updateComponentVisibility();
        updateMainDisplay();
        showComponentMenu();
    }
    else if (message == "TOGGLE APP") {
        gShowAppStatus = !gShowAppStatus;
        updateComponentVisibility();
        updateMainDisplay();
        showComponentMenu();
    }
    else if (message == "TOGGLE PROX") {
        gShowProximityScanner = !gShowProximityScanner;
        updateComponentVisibility();
        updateMainDisplay();
        showComponentMenu();
    }
    else if (message == "ALL ON") {
        gShowUnitStatus = TRUE;
        gShowAppStatus = TRUE;
        gShowProximityScanner = TRUE;
        updateComponentVisibility();
        updateMainDisplay();
        showComponentMenu();
    }
    else if (message == "ALL OFF") {
        gShowUnitStatus = FALSE;
        gShowAppStatus = FALSE;
        gShowProximityScanner = FALSE;
        updateComponentVisibility();
        updateMainDisplay();
        showComponentMenu();
    }
    else if (message == "DIAGNOSTIC") {
        toggleModule("Diagnostics");
        showModuleMenu();
    }
    else if (message == "SECURITY") {
        toggleModule("Security");
        showModuleMenu();
    }
    else if (message == "PERSONALITY") {
        toggleModule("Personality");
        showModuleMenu();
    }
    else if (message == "RLV") {
        toggleModule("RLV Control");
        showModuleMenu();
    }
    else if (message == "SENSORS") {
        toggleModule("Sensors");
        showModuleMenu();
    }
    else if (message == "BACK") {
        showMainMenu();
    }
    else if (message == "CANCEL") {
        gState = 0;
        updateMainDisplay();
    }
    else if (message == "CLOSE") {
        llOwnerSay("Menu closed");
    }
    else if (message == "CONFIG") {
        llOwnerSay("Configuration not yet implemented");
    }
    else {
        // Assume it's a unit name
        connectToUnit(message);
    }
}

// Simulate status changes for demo
simulateStatusChanges() {
    if (gState == 2) {
        // Slowly change battery
        gBattery -= 0.1;
        if (gBattery < 0) gBattery = 100.0;
        
        // Randomly adjust other values
        gArousal = 25.0 + llFrand(50.0);
        gStimulation = 10.0 + llFrand(30.0);
        gEnergy = 80.0 + llFrand(20.0);
        gTreatLevel = (integer)llFrand(10);
        
        broadcastStatusUpdate();
        updateMainDisplay();
    }
}

// Main event handlers
default {
    state_entry() {
        initializeMainController();
    }
    
    attach(key id) {
        if (id) {
            gAttached = TRUE;
            llOwnerSay("Main Controller attached");
        } else {
            gAttached = FALSE;
            llOwnerSay("Main Controller detached");
        }
        
        llSleep(1.0);
        updateMainDisplay();
        updateComponentVisibility();
    }
    
    listen(integer channel, string name, key id, string message) {
        if (channel == gMenuChannel && id == gOwner) {
            processMenuResponse(message);
        }
        else if (channel == gCmdChannel) {
            // A.R.I.A. unit responses
            list parts = llParseString2List(message, ["|"], []);
            string command = llList2String(parts, 0);
            
            if (command == "ARIA_RESPONSE" && gScanning) {
                key unitKey = llList2String(parts, 1);
                string unitName = llList2String(parts, 2);
                string unitChannel = llList2String(parts, 3);
                
                gUnits += [unitKey, unitName, unitChannel];
                updateMainDisplay();
                
                llOwnerSay("Found: " + unitName);
            }
            else if (command == "ARIA_STATUS" && gConnectedUnit != "") {
                if (llGetListLength(parts) >= 5) {
                    gBattery = (float)llList2String(parts, 2);
                    gPersona = llList2String(parts, 3);
                    gMode = llList2String(parts, 4);
                    gStatus = llList2String(parts, 5);
                    
                    broadcastStatusUpdate();
                    updateMainDisplay();
                }
            }
        }
    }
    
    timer() {
        if (gScanning) {
            stopUnitScan();
        } else {
            // Periodic status simulation
            simulateStatusChanges();
            llSetTimerEvent(5.0); // Update every 5 seconds
        }
    }
    
    touch_start(integer total_number) {
        if (llDetectedKey(0) == gOwner) {
            showMainMenu();
        } else {
            llSay(0, "This is " + llGetDisplayName(gOwner) + "'s A.R.I.A. Wearer HUD");
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
}
