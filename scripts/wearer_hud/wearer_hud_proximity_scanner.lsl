//-- A.R.I.A. Wearer HUD - Proximity Scanner v3.0.2
//-- Final Clean Version - September 6, 2025
//-- Bottom center proximity scanner with avatar analysis
//-- Attach to BOTTOM CENTER HUD position

string VERSION = "3.0.2";
string BUILD_DATE = "2025-09-06";

// State variables
key gOwner;
integer gVisible = TRUE;
integer gScannerActive = FALSE;

// Scanner settings
float gScanRange = 20.0;
integer gScanInterval = 5; // seconds
list gDetectedAvatars = [];

// Avatar data structure: [key, name, threat, arousal, sexiness, gender]
list gAvatarData = [];

// Scanner control
toggleScanner() {
    gScannerActive = !gScannerActive;
    
    if (gScannerActive) {
        llSetTimerEvent((float)gScanInterval);
        llSensorRepeat("", "", AGENT, gScanRange, PI, (float)gScanInterval);
        llOwnerSay("Proximity scanner activated");
    } else {
        llSetTimerEvent(0.0);
        llSensorRemove();
        gDetectedAvatars = [];
        gAvatarData = [];
        llOwnerSay("Proximity scanner deactivated");
    }
    
    updateScannerDisplay();
}

// Generate random attributes for detected avatars
list generateAvatarAttributes(key avatarKey, string avatarName) {
    // Use key for consistent randomization
    string keyStr = (string)avatarKey;
    integer seed = (integer)("0x" + llGetSubString(keyStr, -8, -1));
    
    // Generate consistent random values based on avatar key
    integer threat = (seed % 100);
    integer arousal = ((seed * 7) % 100);
    integer sexiness = ((seed * 13) % 100);
    
    // Determine gender (simplified random assignment)
    list genders = ["Male", "Female", "Non-Binary", "Unknown"];
    string gender = llList2String(genders, (seed % 4));
    
    return [threat, arousal, sexiness, gender];
}

// Format threat level with indicators
string formatThreatLevel(integer threat) {
    if (threat >= 80) return "EXTREME";
    else if (threat >= 60) return "HIGH";
    else if (threat >= 40) return "MEDIUM";
    else if (threat >= 20) return "LOW";
    else return "MINIMAL";
}

// Enhanced scanner display
updateScannerDisplay() {
    if (!gVisible) {
        llSetText("", <1,1,1>, 0.0);
        return;
    }
    
    string display = "PROXIMITY SCANNER\n\n";
    
    if (!gScannerActive) {
        display += "SCANNER OFFLINE\n";
        display += "Range: " + (string)((integer)gScanRange) + "m\n";
        display += "Status: Standby\n\n";
        display += "[TOUCH] to activate";
    } else {
        display += "SCANNING ACTIVE\n";
        display += "Range: " + (string)((integer)gScanRange) + "m\n";
        display += "Detected: " + (string)(llGetListLength(gDetectedAvatars)) + " avatars\n\n";
        
        if (llGetListLength(gDetectedAvatars) == 0) {
            display += "No avatars in range";
        } else {
            // Show up to 5 avatars to keep display manageable
            integer maxShow = 5;
            integer count = llGetListLength(gDetectedAvatars);
            if (count > maxShow) count = maxShow;
            
            integer i;
            for (i = 0; i < count; i++) {
                key avatarKey = llList2String(gDetectedAvatars, i);
                
                // Find avatar data
                integer dataIndex = llListFindList(gAvatarData, [avatarKey]);
                if (dataIndex >= 0) {
                    string name = llList2String(gAvatarData, dataIndex + 1);
                    integer threat = (integer)llList2String(gAvatarData, dataIndex + 2);
                    integer arousal = (integer)llList2String(gAvatarData, dataIndex + 3);
                    integer sexiness = (integer)llList2String(gAvatarData, dataIndex + 4);
                    string gender = llList2String(gAvatarData, dataIndex + 5);
                    
                    // Truncate long names
                    if (llStringLength(name) > 12) {
                        name = llGetSubString(name, 0, 11) + "...";
                    }
                    
                    display += "> " + name + "\n";
                    display += "  " + formatThreatLevel(threat) + "\n";
                    display += "  A:" + (string)arousal + "% S:" + (string)sexiness + "% " + gender + "\n";
                    
                    if (i < count - 1) display += "\n";
                }
            }
            
            if (llGetListLength(gDetectedAvatars) > maxShow) {
                display += "\n... and " + (string)(llGetListLength(gDetectedAvatars) - maxShow) + " more";
            }
        }
    }
    
    // Color coding based on threat levels
    vector color = <0.0, 1.0, 1.0>; // Default cyan
    
    if (gScannerActive && llGetListLength(gDetectedAvatars) > 0) {
        // Calculate average threat level
        integer totalThreat = 0;
        integer i;
        for (i = 0; i < llGetListLength(gDetectedAvatars); i++) {
            key avatarKey = llList2String(gDetectedAvatars, i);
            integer dataIndex = llListFindList(gAvatarData, [avatarKey]);
            if (dataIndex >= 0) {
                totalThreat += (integer)llList2String(gAvatarData, dataIndex + 2);
            }
        }
        
        if (llGetListLength(gDetectedAvatars) > 0) {
            integer avgThreat = totalThreat / llGetListLength(gDetectedAvatars);
            
            if (avgThreat >= 70) {
                color = <1.0, 0.0, 0.0>; // Red for high threat
            } else if (avgThreat >= 40) {
                color = <1.0, 0.5, 0.0>; // Orange for medium threat
            } else {
                color = <0.0, 1.0, 0.0>; // Green for low threat
            }
        }
    }
    
    llSetText(display, color, 1.0);
}

// Process detected avatars from sensor event
processDetectedAvatars(integer detected) {
    gDetectedAvatars = [];
    gAvatarData = [];
    
    integer i;
    for (i = 0; i < detected; i++) {
        key avatarKey = llDetectedKey(i);
        string avatarName = llDetectedName(i);
        
        // Skip owner
        if (avatarKey == gOwner) jump continue;
        
        gDetectedAvatars += [avatarKey];
        
        // Generate attributes for this avatar
        list attributes = generateAvatarAttributes(avatarKey, avatarName);
        
        // Store avatar data: [key, name, threat, arousal, sexiness, gender]
        gAvatarData += [avatarKey, avatarName] + attributes;
        
        @continue;
    }
    
    updateScannerDisplay();
}

// Core initialization
initializeProximityScanner() {
    llOwnerSay("A.R.I.A. Proximity Scanner v" + VERSION + " initializing...");
    
    gOwner = llGetOwner();
    
    // Make prim invisible but keep hovertext
    llSetAlpha(0.0, ALL_SIDES);
    
    // Set initial display
    updateScannerDisplay();
    
    llOwnerSay("Proximity Scanner ready (Bottom Center)");
    llOwnerSay("Touch to activate/deactivate scanner");
}

// Adjust scan range
adjustScanRange(float newRange) {
    if (newRange < 5.0) newRange = 5.0;
    if (newRange > 96.0) newRange = 96.0; // SL sensor limit
    
    gScanRange = newRange;
    
    if (gScannerActive) {
        // Restart sensor with new range
        llSensorRemove();
        llSensorRepeat("", "", AGENT, gScanRange, PI, (float)gScanInterval);
    }
    
    updateScannerDisplay();
    llOwnerSay("Scan range set to " + (string)((integer)gScanRange) + "m");
}

// Main event handlers
default {
    state_entry() {
        initializeProximityScanner();
    }
    
    attach(key id) {
        if (id) {
            llOwnerSay("Proximity Scanner attached to bottom center");
        } else {
            llOwnerSay("Proximity Scanner detached");
            
            // Stop scanning when detached
            if (gScannerActive) {
                gScannerActive = FALSE;
                llSetTimerEvent(0.0);
                llSensorRemove();
            }
        }
        
        llSleep(0.5);
        updateScannerDisplay();
    }
    
    sensor(integer detected) {
        processDetectedAvatars(detected);
    }
    
    no_sensor() {
        gDetectedAvatars = [];
        gAvatarData = [];
        updateScannerDisplay();
    }
    
    timer() {
        // Timer for additional updates if needed
        updateScannerDisplay();
    }
    
    link_message(integer sender_num, integer num, string str, key id) {
        list parts = llParseString2List(str, ["|"], []);
        string command = llList2String(parts, 0);
        
        if (num == 2000 && command == "VISIBILITY") {
            // Toggle visibility
            gVisible = (integer)llList2String(parts, 1);
            updateScannerDisplay();
            
            if (gVisible) {
                llOwnerSay("Proximity Scanner display shown");
            } else {
                llOwnerSay("Proximity Scanner display hidden");
                
                // Stop scanning when hidden
                if (gScannerActive) {
                    gScannerActive = FALSE;
                    llSetTimerEvent(0.0);
                    llSensorRemove();
                }
            }
        }
        else if (num == 4000 && command == "SCANNER_CONTROL") {
            string action = llList2String(parts, 1);
            
            if (action == "TOGGLE") {
                toggleScanner();
            }
            else if (action == "ACTIVATE") {
                if (!gScannerActive) toggleScanner();
            }
            else if (action == "DEACTIVATE") {
                if (gScannerActive) toggleScanner();
            }
            else if (action == "SET_RANGE") {
                float newRange = (float)llList2String(parts, 2);
                adjustScanRange(newRange);
            }
        }
    }
    
    touch_start(integer total_number) {
        if (llDetectedKey(0) == gOwner) {
            if (gVisible) {
                toggleScanner();
            } else {
                // Make visible and activate if hidden
                gVisible = TRUE;
                updateScannerDisplay();
                
                if (!gScannerActive) {
                    toggleScanner();
                }
                
                llOwnerSay("Proximity Scanner: Activated and Shown");
                
                // Notify main controller of visibility change
                llMessageLinked(LINK_ROOT, 3000, "PROXIMITY_VISIBILITY|" + (string)gVisible, "");
            }
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
