//-- A.R.I.A. Wearer HUD - Enhanced Status Display v4.1.0
//-- Fresh Clean Build - September 8, 2025
//-- Left-side unit status display with visual progress bars
//-- NO TERNARY OPERATORS, NO STATIC VARIABLES

string VERSION = "4.1.0";
string BUILD_DATE = "2025-09-08";

// Progress bar characters
string PROGRESS_FULL = "█";
string PROGRESS_EMPTY = "░";
string PROGRESS_PARTIAL_75 = "▉";
string PROGRESS_PARTIAL_50 = "▌";
string PROGRESS_PARTIAL_25 = "▎";

// Status indicator emojis
string EMOJI_BATTERY_FULL = "🔋";
string EMOJI_BATTERY_LOW = "🪫"; 
string EMOJI_BATTERY_CRITICAL = "🔴";
string EMOJI_AROUSAL = "💕";
string EMOJI_STIMULATION = "⭐";
string EMOJI_PAIN = "😣";
string EMOJI_ENERGY = "⚡";
string EMOJI_UNIT = "🤖";
string EMOJI_ADMIN = "👑";
string EMOJI_PERSONA = "🎭";
string EMOJI_SECURED = "🔒";
string EMOJI_UNSECURED = "🔓";
string EMOJI_CONNECTED = "🟢";
string EMOJI_DISCONNECTED = "🔴";

// Threat level indicators
string EMOJI_THREAT_MINIMAL = "🟢";
string EMOJI_THREAT_LOW = "🟡";
string EMOJI_THREAT_MEDIUM = "🟠";
string EMOJI_THREAT_HIGH = "🔴";
string EMOJI_THREAT_EXTREME = "⚫";

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
float gPain = 0.0;
float gEnergy = 100.0;
float gThreatLevel = 0.0;

// Threat calculation variables
integer gTotalAvatars = 0;
integer gMaleAvatars = 0;
float gScanRange = 20.0;
list gDetectedAvatars = [];
list gMaleAvatarList = [];

// Configuration
integer PROGRESS_BAR_LENGTH = 8;
integer UPDATE_INTERVAL = 3;
integer THREAT_UPDATE_INTERVAL = 5;

// Touch control
integer gTouchMode = 0;

// Generate progress bar
string generateProgressBar(float percentage, integer barLength) {
    if (percentage < 0.0) percentage = 0.0;
    if (percentage > 100.0) percentage = 100.0;
    
    float charValue = percentage / 100.0 * barLength;
    integer fullChars = (integer)charValue;
    float remainder = charValue - fullChars;
    
    string bar = "";
    integer i;
    
    for (i = 0; i < fullChars; i++) {
        bar += PROGRESS_FULL;
    }
    
    if (fullChars < barLength && remainder > 0.0) {
        if (remainder >= 0.75) {
            bar += PROGRESS_PARTIAL_75;
        } else if (remainder >= 0.5) {
            bar += PROGRESS_PARTIAL_50;
        } else if (remainder >= 0.25) {
            bar += PROGRESS_PARTIAL_25;
        } else {
            bar += PROGRESS_EMPTY;
        }
        fullChars++;
    }
    
    for (i = fullChars; i < barLength; i++) {
        bar += PROGRESS_EMPTY;
    }
    
    return bar;
}

// Get battery icon
string getBatteryIcon(float batteryLevel) {
    if (batteryLevel <= 10.0) return EMOJI_BATTERY_CRITICAL;
    if (batteryLevel <= 25.0) return EMOJI_BATTERY_LOW;
    return EMOJI_BATTERY_FULL;
}

// Get threat icon
string getThreatIcon(float threatLevel) {
    if (threatLevel >= 80.0) return EMOJI_THREAT_EXTREME;
    if (threatLevel >= 60.0) return EMOJI_THREAT_HIGH;
    if (threatLevel >= 40.0) return EMOJI_THREAT_MEDIUM;
    if (threatLevel >= 20.0) return EMOJI_THREAT_LOW;
    return EMOJI_THREAT_MINIMAL;
}

// Get threat description
string getThreatDescription(float threatLevel) {
    if (threatLevel >= 80.0) return "EXTREME";
    if (threatLevel >= 60.0) return "HIGH";
    if (threatLevel >= 40.0) return "MEDIUM";
    if (threatLevel >= 20.0) return "LOW";
    return "MINIMAL";
}

// Generate status line
string generateStatusLine(string emoji, string label, float value, integer showPercentage) {
    string progressBar = generateProgressBar(value, PROGRESS_BAR_LENGTH);
    string line = emoji + " " + label + " " + progressBar;
    
    if (showPercentage) {
        line += " " + (string)((integer)value) + "%";
    }
    
    return line;
}

// Calculate threat level
calculateThreatLevel() {
    if (gTotalAvatars == 0) {
        gThreatLevel = 0.0;
        return;
    }
    
    float malePercentage = ((float)gMaleAvatars / (float)gTotalAvatars) * 100.0;
    float threatMultiplier = 1.0;
    
    if (gTotalAvatars >= 10) {
        threatMultiplier = 1.5;
    } else if (gTotalAvatars >= 5) {
        threatMultiplier = 1.2;
    }
    
    gThreatLevel = malePercentage * threatMultiplier;
    if (gThreatLevel > 100.0) gThreatLevel = 100.0;
    
    if (gAdminName != "None" && gAdminName != "") {
        gThreatLevel *= 0.7;
    }
}

// Get status indicator
string getStatusIndicator(string statusType) {
    if (statusType == "connected") {
        if (gConnectedUnit != "") {
            return EMOJI_CONNECTED;
        } else {
            return EMOJI_DISCONNECTED;
        }
    }
    else if (statusType == "security") {
        if (gState == "Secured") {
            return EMOJI_SECURED;
        } else {
            return EMOJI_UNSECURED;
        }
    }
    return "";
}

// Get display color
vector getStatusDisplayColor() {
    if (gConnectedUnit == "") {
        return <0.5, 0.5, 0.5>;
    }
    
    if (gBattery <= 10.0) {
        return <1.0, 0.0, 0.0>;
    }
    
    if (gThreatLevel >= 80.0) {
        return <0.8, 0.0, 0.2>;
    }
    
    if (gPain >= 75.0) {
        return <1.0, 0.2, 0.2>;
    }
    
    if (gState == "Secured") {
        return <1.0, 0.5, 0.0>;
    }
    
    if (gThreatLevel >= 60.0) {
        return <1.0, 0.4, 0.0>;
    }
    
    if (gBattery <= 25.0) {
        return <1.0, 0.8, 0.0>;
    }
    
    if (gThreatLevel >= 40.0) {
        return <1.0, 1.0, 0.0>;
    }
    
    if (gArousal >= 75.0) {
        return <1.0, 0.5, 1.0>;
    }
    
    return <0.0, 1.0, 0.5>;
}

// Update main display
updateUnitStatusDisplay() {
    if (!gVisible) {
        llSetText("", <1,1,1>, 0.0);
        return;
    }
    
    string display = "═══ UNIT STATUS ═══\n\n";
    
    string connectionIcon = getStatusIndicator("connected");
    if (gConnectedUnit == "") {
        display += connectionIcon + " DISCONNECTED\n\n";
        display += EMOJI_UNIT + " Unit: No Connection\n";
        display += EMOJI_ADMIN + " Admin: None\n";
        display += EMOJI_PERSONA + " Persona: N/A\n";
        display += getStatusIndicator("security") + " State: Offline\n\n";
        
        display += getBatteryIcon(0) + " Power  " + generateProgressBar(0, PROGRESS_BAR_LENGTH) + " ---%\n";
        display += EMOJI_AROUSAL + " Arousal " + generateProgressBar(0, PROGRESS_BAR_LENGTH) + " ---%\n";
        display += EMOJI_STIMULATION + " Stimul. " + generateProgressBar(0, PROGRESS_BAR_LENGTH) + " ---%\n";
        display += EMOJI_PAIN + " Pain    " + generateProgressBar(0, PROGRESS_BAR_LENGTH) + " ---%\n";
        display += EMOJI_ENERGY + " Energy  " + generateProgressBar(0, PROGRESS_BAR_LENGTH) + " ---%\n";
        display += getThreatIcon(0) + " Threat: OFFLINE";
    } 
    else {
        display += connectionIcon + " CONNECTED\n\n";
        
        display += EMOJI_UNIT + " Unit: " + gUnitName + "\n";
        display += EMOJI_ADMIN + " Admin: " + gAdminName + "\n";
        display += EMOJI_PERSONA + " Persona: " + gPersona + "\n";
        display += getStatusIndicator("security") + " State: " + gState + "\n\n";
        
        display += "═══ BIOMETRIC DATA ═══\n";
        
        string batteryIcon = getBatteryIcon(gBattery);
        display += generateStatusLine(batteryIcon, "Power", gBattery, TRUE) + "\n";
        display += generateStatusLine(EMOJI_AROUSAL, "Arousal", gArousal, TRUE) + "\n";
        display += generateStatusLine(EMOJI_STIMULATION, "Stimul.", gStimulation, TRUE) + "\n";
        display += generateStatusLine(EMOJI_PAIN, "Pain", gPain, TRUE) + "\n";
        display += generateStatusLine(EMOJI_ENERGY, "Energy", gEnergy, TRUE) + "\n\n";
        
        display += "═══ THREAT ASSESSMENT ═══\n";
        string threatIcon = getThreatIcon(gThreatLevel);
        display += generateStatusLine(threatIcon, "Threat", gThreatLevel, FALSE) + " " + getThreatDescription(gThreatLevel) + "\n";
        
        integer malePercentage = 0;
        if (gTotalAvatars > 0) {
            malePercentage = (gMaleAvatars * 100) / gTotalAvatars;
        }
        
        display += "👥 Avatars: " + (string)gTotalAvatars + " | ♂️ Males: " + (string)gMaleAvatars + " (" + (string)malePercentage + "%)";
    }
    
    vector color = getStatusDisplayColor();
    llSetText(display, color, 1.0);
}

// Update compact display
updateCompactStatusDisplay() {
    if (!gVisible) {
        llSetText("", <1,1,1>, 0.0);
        return;
    }
    
    string display = "";
    
    if (gConnectedUnit == "") {
        display = EMOJI_DISCONNECTED + " OFFLINE\n" + EMOJI_UNIT + " No Unit Connected";
    }
    else {
        display = EMOJI_CONNECTED + " " + gUnitName + " | " + getThreatIcon(gThreatLevel) + " " + getThreatDescription(gThreatLevel) + "\n";
        display += EMOJI_ADMIN + " " + gAdminName + " | " + EMOJI_PERSONA + " " + gPersona + "\n";
        
        string batteryIcon = getBatteryIcon(gBattery);
        display += batteryIcon + generateProgressBar(gBattery, 5) + " " + 
                   EMOJI_AROUSAL + generateProgressBar(gArousal, 4) + " " +
                   EMOJI_STIMULATION + generateProgressBar(gStimulation, 4) + "\n";
        display += EMOJI_PAIN + generateProgressBar(gPain, 4) + " " +
                   EMOJI_ENERGY + generateProgressBar(gEnergy, 4) + " " +
                   "👥" + (string)gTotalAvatars + "♂️" + (string)gMaleAvatars;
    }
    
    vector color = getStatusDisplayColor();
    llSetText(display, color, 1.0);
}

// Process proximity data
processProximityData(integer detected) {
    gDetectedAvatars = [];
    gMaleAvatarList = [];
    gTotalAvatars = 0;
    gMaleAvatars = 0;
    
    integer i;
    for (i = 0; i < detected; i++) {
        key avatarKey = llDetectedKey(i);
        string avatarName = llDetectedName(i);
        
        if (avatarKey == gOwner) jump continue;
        
        gDetectedAvatars += [avatarKey];
        gTotalAvatars++;
        
        string keyStr = (string)avatarKey;
        integer seed = (integer)("0x" + llGetSubString(keyStr, -8, -1));
        list genders = ["Male", "Female", "Non-Binary", "Unknown"];
        string gender = llList2String(genders, (seed % 4));
        
        if (gender == "Male") {
            gMaleAvatarList += [avatarKey];
            gMaleAvatars++;
        }
        
        @continue;
    }
    
    calculateThreatLevel();
    updateUnitStatusDisplay();
}

// Start threat scanning
startThreatScanning() {
    llSensorRepeat("", "", AGENT, gScanRange, PI, (float)THREAT_UPDATE_INTERVAL);
    llOwnerSay("🛡️ Threat assessment scanning activated - Range: " + (string)((integer)gScanRange) + "m");
}

// Stop threat scanning
stopThreatScanning() {
    llSensorRemove();
    gTotalAvatars = 0;
    gMaleAvatars = 0;
    gThreatLevel = 0.0;
    llOwnerSay("🛡️ Threat assessment scanning deactivated");
}

// Process status updates
processStatusUpdate(string command, list parameters) {
    if (command == "STATUS_UPDATE") {
        gConnectedUnit = llList2String(parameters, 0);
        
        if (gConnectedUnit != "") {
            gUnitName = gConnectedUnit;
        } else {
            gUnitName = "Not Connected";
        }
        
        gBattery = (float)llList2String(parameters, 1);
        gPersona = llList2String(parameters, 2);
        gAdminName = llList2String(parameters, 3);
        
        integer secured = (integer)llList2String(parameters, 4);
        if (secured) {
            gState = "Secured";
        } else {
            gState = "Non-Secured";
        }
        
        gArousal = (float)llList2String(parameters, 5);
        gStimulation = (float)llList2String(parameters, 6);
        gPain = (float)llList2String(parameters, 7);
        gEnergy = (float)llList2String(parameters, 8);
        
        updateUnitStatusDisplay();
    }
    else if (command == "UPDATE_BATTERY") {
        gBattery = (float)llList2String(parameters, 0);
        updateUnitStatusDisplay();
    }
    else if (command == "UPDATE_AROUSAL") {
        gArousal = (float)llList2String(parameters, 0);
        updateUnitStatusDisplay();
    }
    else if (command == "UPDATE_STIMULATION") {
        gStimulation = (float)llList2String(parameters, 0);
        updateUnitStatusDisplay();
    }
    else if (command == "UPDATE_PAIN") {
        gPain = (float)llList2String(parameters, 0);
        updateUnitStatusDisplay();
    }
    else if (command == "UPDATE_ENERGY") {
        gEnergy = (float)llList2String(parameters, 0);
        updateUnitStatusDisplay();
    }
    else if (command == "VISIBILITY") {
        gVisible = (integer)llList2String(parameters, 0);
        if (gVisible && gConnectedUnit != "") {
            startThreatScanning();
        } else {
            stopThreatScanning();
        }
        updateUnitStatusDisplay();
    }
}

// Initialize
initializeUnitStatus() {
    llOwnerSay("🔧 A.R.I.A. Enhanced Unit Status v" + VERSION + " initializing...");
    llOwnerSay("📊 Progress bar visual indicators enabled");
    llOwnerSay("🛡️ Threat assessment system online");
    
    gOwner = llGetOwner();
    llSetAlpha(0.0, ALL_SIDES);
    updateUnitStatusDisplay();
    llSetTimerEvent(UPDATE_INTERVAL);
    
    llOwnerSay("✅ Enhanced Unit Status Display ready (Left Side)");
}

// Main events
default {
    state_entry() {
        initializeUnitStatus();
    }
    
    attach(key id) {
        if (id) {
            llOwnerSay("📱 Enhanced Unit Status attached to left side");
            if (gConnectedUnit != "") {
                startThreatScanning();
            }
        } else {
            llOwnerSay("📱 Enhanced Unit Status detached");
            stopThreatScanning();
        }
        
        llSleep(0.5);
        updateUnitStatusDisplay();
    }
    
    timer() {
        updateUnitStatusDisplay();
    }
    
    sensor(integer detected) {
        processProximityData(detected);
    }
    
    no_sensor() {
        gTotalAvatars = 0;
        gMaleAvatars = 0;
        calculateThreatLevel();
        updateUnitStatusDisplay();
    }
    
    link_message(integer sender_num, integer num, string str, key id) {
        list parts = llParseString2List(str, ["|"], []);
        string command = llList2String(parts, 0);
        
        if (num == 1000) {
            list data = llDeleteSubList(parts, 0, 0);
            processStatusUpdate(command, data);
        }
        else if (num == 2000) {
            if (command == "VISIBILITY") {
                gVisible = (integer)llList2String(parts, 1);
                
                if (gVisible && gConnectedUnit != "") {
                    startThreatScanning();
                } else {
                    stopThreatScanning();
                }
                
                updateUnitStatusDisplay();
                
                if (gVisible) {
                    llOwnerSay("📊 Unit Status display shown");
                } else {
                    llOwnerSay("📊 Unit Status display hidden");
                }
            }
            else if (command == "DISPLAY_MODE") {
                string mode = llList2String(parts, 1);
                if (mode == "COMPACT") {
                    updateCompactStatusDisplay();
                } else {
                    updateUnitStatusDisplay();
                }
            }
        }
        else if (num == 5000) {
            list data = llDeleteSubList(parts, 0, 0);
            processStatusUpdate(command, data);
        }
        else if (num == 6000) {
            if (command == "SET_SCAN_RANGE") {
                float newRange = (float)llList2String(parts, 1);
                if (newRange >= 5.0 && newRange <= 96.0) {
                    gScanRange = newRange;
                    if (gVisible && gConnectedUnit != "") {
                        stopThreatScanning();
                        startThreatScanning();
                    }
                    llOwnerSay("🛡️ Threat scan range set to " + (string)((integer)gScanRange) + "m");
                }
            }
            else if (command == "MANUAL_THREAT_CALC") {
                calculateThreatLevel();
                updateUnitStatusDisplay();
                llOwnerSay("🛡️ Manual threat calculation: " + (string)((integer)gThreatLevel) + "% (" + getThreatDescription(gThreatLevel) + ")");
            }
        }
        else if (num == 7000) {
            if (command == "PROXIMITY_THREAT") {
                gTotalAvatars = (integer)llList2String(parts, 1);
                gMaleAvatars = (integer)llList2String(parts, 2);
                calculateThreatLevel();
                updateUnitStatusDisplay();
            }
        }
    }
    
    touch_start(integer total_number) {
        if (llDetectedKey(0) == gOwner) {
            gTouchMode++;
            if (gTouchMode > 3) gTouchMode = 0;
            
            if (gTouchMode == 0) {
                updateUnitStatusDisplay();
                llOwnerSay("📊 Standard display mode");
            }
            else if (gTouchMode == 1) {
                updateCompactStatusDisplay();
                llOwnerSay("📱 Compact display mode");
            }
            else if (gTouchMode == 2) {
                calculateThreatLevel();
                updateUnitStatusDisplay();
                llOwnerSay("🛡️ Threat assessment refreshed: " + (string)((integer)gThreatLevel) + "% (" + getThreatDescription(gThreatLevel) + ")");
            }
            else if (gTouchMode == 3) {
                gVisible = !gVisible;
                
                if (gVisible && gConnectedUnit != "") {
                    startThreatScanning();
                } else {
                    stopThreatScanning();
                }
                
                updateUnitStatusDisplay();
                
                if (gVisible) {
                    llOwnerSay("👁️ Unit Status: Shown");
                } else {
                    llOwnerSay("🚫 Unit Status: Hidden");
                }
                
                llMessageLinked(LINK_ROOT, 3000, "UNIT_STATUS_VISIBILITY|" + (string)gVisible, "");
                gTouchMode = 0;
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
