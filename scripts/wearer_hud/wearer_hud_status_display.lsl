//-- A.R.I.A. Wearer HUD - Unit Status Display v3.0.1
//-- Clean Rewrite - September 6, 2025
//-- Left-side unit status display with left-aligned text
//-- Attach to LEFT SIDE HUD position

string VERSION = "3.0.1";
string BUILD_DATE = "2025-09-06";

// State variables
key gOwner;
integer gVisible = TRUE;
string gConnectedUnit = "";

// Status data
string gUnitName = "Not Connected";
string gAdminName = "None";
string gPersona = "Default";
string gState = "Non-Secured";
float gBattery = 100.0;
float gArousal = 0.0;
float gStimulation = 0.0;
float gEnergy = 100.0;
integer gTreatLevel = 0;

// Format percentage with status indicators
string formatPercentage(float value, string label) {
    string result = label + ": " + (string)((integer)value) + "%";
    
    // Add status indicators
    if (value >= 80.0) {
        result += " HIGH";
    } else if (value >= 50.0) {
        result += " MED";
    } else if (value >= 20.0) {
        result += " LOW";
    } else {
        result += " CRIT";
    }
    
    return result;
}

// Enhanced display with indicators
updateUnitStatusDisplay() {
    if (!gVisible) {
        llSetText("", <1,1,1>, 0.0);
        return;
    }
    
    string display = "UNIT STATUS\n\n";
    
    // Connection status indicator
    if (gConnectedUnit == "") {
        display += "DISCONNECTED\n\n";
        display += "Name: No Unit\n";
        display += "Admin: None\n";
        display += "Persona: N/A\n";
        display += "State: Offline\n";
        display += "Battery: ---%\n";
        display += "Arousal: ---%\n";
        display += "Stimulation: ---%\n";
        display += "Energy: ---%\n";
        display += "Treat Level: ---";
    } else {
        display += "CONNECTED\n\n";
        display += "Name: " + gUnitName + "\n";
        display += "Admin: " + gAdminName + "\n";
        display += "Persona: " + gPersona + "\n";
        display += "State: " + gState + "\n\n";
        
        // Status bars with indicators
        display += formatPercentage(gBattery, "Battery") + "\n";
        display += formatPercentage(gArousal, "Arousal") + "\n";
        display += formatPercentage(gStimulation, "Stimulation") + "\n";
        display += formatPercentage(gEnergy, "Energy") + "\n";
        display += "Treat Level: " + (string)gTreatLevel + "/10";
    }
    
    // Color coding
    vector color;
    if (gConnectedUnit == "") {
        color = <0.5, 0.5, 0.5>; // Gray when disconnected
    } else if (gState == "Secured") {
        color = <1.0, 0.5, 0.0>; // Orange when secured
    } else {
        color = <0.0, 1.0, 0.5>; // Green when connected normal
    }
    
    llSetText(display, color, 1.0);
}

// Core initialization
initializeUnitStatus() {
    llOwnerSay("A.R.I.A. Unit Status v" + VERSION + " initializing...");
    
    gOwner = llGetOwner();
    
    // Make prim invisible but keep hovertext
    llSetAlpha(0.0, ALL_SIDES);
    
    // Set initial display
    updateUnitStatusDisplay();
    
    llOwnerSay("Unit Status Display ready (Left Side)");
}

// Main event handlers
default {
    state_entry() {
        initializeUnitStatus();
    }
    
    attach(key id) {
        if (id) {
            llOwnerSay("Unit Status attached to left side");
        } else {
            llOwnerSay("Unit Status detached");
        }
        
        llSleep(0.5);
        updateUnitStatusDisplay();
    }
    
    link_message(integer sender_num, integer num, string str, key id) {
        list parts = llParseString2List(str, ["|"], []);
        string command = llList2String(parts, 0);
        
        if (num == 1000 && command == "STATUS_UPDATE") {
            // Update all status values from main controller
            gConnectedUnit = llList2String(parts, 1);
            
            if (gConnectedUnit != "") {
                gUnitName = gConnectedUnit;
            } else {
                gUnitName = "Not Connected";
            }
            
            gBattery = (float)llList2String(parts, 2);
            gPersona = llList2String(parts, 3);
            gAdminName = llList2String(parts, 4);
            
            integer secured = (integer)llList2String(parts, 5);
            if (secured) {
                gState = "Secured";
            } else {
                gState = "Non-Secured";
            }
            
            gArousal = (float)llList2String(parts, 6);
            gStimulation = (float)llList2String(parts, 7);
            gEnergy = (float)llList2String(parts, 8);
            gTreatLevel = (integer)llList2String(parts, 9);
            
            updateUnitStatusDisplay();
        }
        else if (num == 2000 && command == "VISIBILITY") {
            // Toggle visibility
            gVisible = (integer)llList2String(parts, 1);
            updateUnitStatusDisplay();
            
            if (gVisible) {
                llOwnerSay("Unit Status display shown");
            } else {
                llOwnerSay("Unit Status display hidden");
            }
        }
    }
    
    touch_start(integer total_number) {
        if (llDetectedKey(0) == gOwner) {
            // Toggle visibility on touch
            gVisible = !gVisible;
            updateUnitStatusDisplay();
            
            if (gVisible) {
                llOwnerSay("Unit Status: Shown");
            } else {
                llOwnerSay("Unit Status: Hidden");
            }
            
            // Notify main controller of visibility change
            llMessageLinked(LINK_ROOT, 3000, "UNIT_STATUS_VISIBILITY|" + (string)gVisible, "");
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
