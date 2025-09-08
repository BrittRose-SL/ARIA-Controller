//-- A.R.I.A. Wearer HUD - App Status Display v3.0.1
//-- Clean Rewrite - September 6, 2025
//-- Right-side app status display with right-aligned text
//-- Attach to RIGHT SIDE HUD position

string VERSION = "3.0.1";
string BUILD_DATE = "2025-09-06";

// State variables
key gOwner;
integer gVisible = TRUE;
string gConnectedUnit = "";

// App status data
list gActiveModules = [];
list gActiveRestrictions = [];

// Enhanced display with better formatting
updateAppStatusDisplay() {
    if (!gVisible) {
        llSetText("", <1,1,1>, 0.0);
        return;
    }
    
    string display = "APP STATUS\n\n";
    
    if (gConnectedUnit == "") {
        display += "DISCONNECTED\n\n";
        display += "MODULES: Offline\n";
        display += "RESTRICTIONS: N/A\n";
    } else {
        display += "CONNECTED\n\n";
        
        // Active Modules section with status indicators
        display += "ACTIVE MODULES (" + (string)llGetListLength(gActiveModules) + "):\n";
        if (llGetListLength(gActiveModules) == 0) {
            display += "  [None Active]\n";
        } else {
            integer i;
            for (i = 0; i < llGetListLength(gActiveModules) && i < 6; i++) {
                string module = llList2String(gActiveModules, i);
                display += "  + " + module + "\n";
            }
            if (llGetListLength(gActiveModules) > 6) {
                display += "  ... and " + (string)(llGetListLength(gActiveModules) - 6) + " more\n";
            }
        }
        
        display += "\nRLV RESTRICTIONS (" + (string)llGetListLength(gActiveRestrictions) + "):\n";
        if (llGetListLength(gActiveRestrictions) == 0) {
            display += "  [None Active]\n";
        } else {
            integer i;
            for (i = 0; i < llGetListLength(gActiveRestrictions) && i < 4; i++) {
                string restriction = llList2String(gActiveRestrictions, i);
                display += "  ! " + restriction + "\n";
            }
            if (llGetListLength(gActiveRestrictions) > 4) {
                display += "  ... and " + (string)(llGetListLength(gActiveRestrictions) - 4) + " more\n";
            }
        }
    }
    
    // Color coding based on status
    vector color;
    if (gConnectedUnit == "") {
        color = <0.5, 0.5, 0.5>; // Gray when disconnected
    } else if (llGetListLength(gActiveRestrictions) > 0) {
        color = <1.0, 0.3, 0.3>; // Red when restrictions active
    } else {
        color = <0.3, 0.8, 1.0>; // Blue when normal
    }
    
    llSetText(display, color, 1.0);
}

// Add a restriction to the list
addRestriction(string restriction) {
    if (llListFindList(gActiveRestrictions, [restriction]) == -1) {
        gActiveRestrictions += [restriction];
        updateAppStatusDisplay();
    }
}

// Remove a restriction from the list
removeRestriction(string restriction) {
    integer index = llListFindList(gActiveRestrictions, [restriction]);
    if (index >= 0) {
        gActiveRestrictions = llDeleteSubList(gActiveRestrictions, index, index);
        updateAppStatusDisplay();
    }
}

// Core initialization
initializeAppStatus() {
    llOwnerSay("A.R.I.A. App Status v" + VERSION + " initializing...");
    
    gOwner = llGetOwner();
    
    // Make prim invisible but keep hovertext
    llSetAlpha(0.0, ALL_SIDES);
    
    // Set initial display
    updateAppStatusDisplay();
    
    llOwnerSay("App Status Display ready (Right Side)");
}

// Simulate some demo restrictions for testing
simulateDemoRestrictions() {
    if (gConnectedUnit != "" && llGetListLength(gActiveRestrictions) == 0) {
        // Add some demo restrictions periodically
        if (llFrand(1.0) < 0.3) {
            list possibleRestrictions = [
                "Movement Limited",
                "Chat Restricted", 
                "TP Blocked",
                "Outfit Locked",
                "Attachments Fixed"
            ];
            string newRestriction = llList2String(possibleRestrictions, (integer)llFrand(llGetListLength(possibleRestrictions)));
            addRestriction(newRestriction);
        }
    }
}

// Main event handlers
default {
    state_entry() {
        initializeAppStatus();
        
        // Set up demo timer
        llSetTimerEvent(10.0);
    }
    
    attach(key id) {
        if (id) {
            llOwnerSay("App Status attached to right side");
        } else {
            llOwnerSay("App Status detached");
        }
        
        llSleep(0.5);
        updateAppStatusDisplay();
    }
    
    link_message(integer sender_num, integer num, string str, key id) {
        list parts = llParseString2List(str, ["|"], []);
        string command = llList2String(parts, 0);
        
        if (num == 1000 && command == "STATUS_UPDATE") {
            // Update connection status
            gConnectedUnit = llList2String(parts, 1);
            updateAppStatusDisplay();
        }
        else if (num == 1001 && command == "MODULES_UPDATE") {
            // Update active modules list
            gActiveModules = [];
            integer i;
            for (i = 1; i < llGetListLength(parts); i++) {
                string module = llList2String(parts, i);
                if (module != "") {
                    gActiveModules += [module];
                }
            }
            updateAppStatusDisplay();
        }
        else if (num == 1002 && command == "RESTRICTIONS_UPDATE") {
            // Update active restrictions list
            gActiveRestrictions = [];
            integer i;
            for (i = 1; i < llGetListLength(parts); i++) {
                string restriction = llList2String(parts, i);
                if (restriction != "") {
                    gActiveRestrictions += [restriction];
                }
            }
            updateAppStatusDisplay();
        }
        else if (num == 2000 && command == "VISIBILITY") {
            // Toggle visibility
            gVisible = (integer)llList2String(parts, 1);
            updateAppStatusDisplay();
            
            if (gVisible) {
                llOwnerSay("App Status display shown");
            } else {
                llOwnerSay("App Status display hidden");
            }
        }
        else if (num == 3001 && command == "ADD_RESTRICTION") {
            // Add specific restriction
            string restriction = llList2String(parts, 1);
            addRestriction(restriction);
        }
        else if (num == 3002 && command == "REMOVE_RESTRICTION") {
            // Remove specific restriction
            string restriction = llList2String(parts, 1);
            removeRestriction(restriction);
        }
        else if (num == 3003 && command == "CLEAR_RESTRICTIONS") {
            // Clear all restrictions
            gActiveRestrictions = [];
            updateAppStatusDisplay();
        }
    }
    
    timer() {
        // Demo functionality - occasionally add/remove restrictions
        simulateDemoRestrictions();
    }
    
    touch_start(integer total_number) {
        if (llDetectedKey(0) == gOwner) {
            // Toggle visibility on touch
            gVisible = !gVisible;
            updateAppStatusDisplay();
            
            if (gVisible) {
                llOwnerSay("App Status: Shown");
            } else {
                llOwnerSay("App Status: Hidden");
            }
            
            // Notify main controller of visibility change
            llMessageLinked(LINK_ROOT, 3000, "APP_STATUS_VISIBILITY|" + (string)gVisible, "");
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
