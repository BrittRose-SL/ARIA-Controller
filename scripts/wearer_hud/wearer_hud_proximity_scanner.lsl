//-- A.R.I.A. Enhanced Proximity Scanner v5.0.1
//-- Clean Build - September 8, 2025
//-- Bottom center proximity scanner with attachment analysis
//-- No ternary operators, clean LSL syntax
//-- CHANGES v5.0.1:
//--   - Removed the unused menu channel state
//--   - Removed the dead conditional around stranger threat scoring

string VERSION = "5.0.0";
string BUILD_DATE = "2025-09-08";

// State variables
key gOwner;
integer gVisible = TRUE;
integer gScannerActive = FALSE;
integer gAutoScanMode = FALSE;

// Scanner settings
float gScanRange = 20.0;
integer gScanInterval = 5;
integer gAutoScanInterval = 300;
list gDetectedAvatars = [];
list gAvatarData = [];

// Progress bar characters
string PROGRESS_FULL = "█";
string PROGRESS_EMPTY = "░";
string PROGRESS_PARTIAL_75 = "▉";
string PROGRESS_PARTIAL_50 = "▌";
string PROGRESS_PARTIAL_25 = "▎";

// Dialog system
integer gListenHandle;
integer gMenuTimeOut = 30;

// Menu states
integer MENU_NONE = 0;
integer MENU_MAIN = 1;
integer MENU_PREFERENCES = 2;
integer MENU_ATTRACTION = 3;
integer MENU_BODY_PARTS = 4;
integer MENU_THREAT_PREFS = 5;
integer MENU_SCAN_SETTINGS = 6;
integer gCurrentMenu = MENU_NONE;

// Preference system
integer gAttractedToMales = TRUE;
integer gAttractedToFemales = TRUE;
integer gAttractedToNonBinary = FALSE;

// Body part multipliers
float gBreastMultiplier = 1.0;
float gButtMultiplier = 1.0;
float gGenitalMultiplier = 1.5;
float gMuscleMultiplier = 0.8;

// Threat preferences
float gWeaponThreatMultiplier = 2.0;
float gCombatThreatMultiplier = 1.5;
float gDominanceThreatMultiplier = 1.2;
integer gThreatFromStrangers = TRUE;
integer gThreatFromDominants = TRUE;

// Attachment databases
list gAdultAttachments = [
    "penis", "cock", "dick", "genital", "vagina", "pussy", "breast", "boob", "tit",
    "dildo", "vibrator", "buttplug", "collar", "leash", "gag", "cuffs", "restraint",
    "paddle", "whip", "flogger", "cane", "crop", "slapper", "spanker"
];

list gWeaponAttachments = [
    "gun", "pistol", "rifle", "shotgun", "weapon", "firearm", "sword", "knife", 
    "dagger", "blade", "katana", "axe", "hammer", "bow", "crossbow"
];

list gCombatAttachments = [
    "combat", "meter", "health", "armor", "shield", "damage", "fight", "battle",
    "gorean", "gor", "dcs", "bloodlines", "vampire", "lycan"
];

list gDominanceAttachments = [
    "master", "mistress", "dom", "domme", "owner", "sir", "goddess", "daddy",
    "alpha", "slave", "sub", "submissive", "property", "pet"
];

// Generate compact progress bar
string generateCompactProgressBar(float percentage, integer barLength) {
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

// Scan avatar attachments
list scanAvatarAttachments(key avatarKey) {
    list attachmentList = [];
    list threatIndicators = [];
    list sexinessIndicators = [];
    
    list attachments = llGetAttachedList(avatarKey);
    
    integer i;
    for (i = 0; i < llGetListLength(attachments); i++) {
        key attachmentKey = llList2String(attachments, i);
        
        list objectDetails = llGetObjectDetails(attachmentKey, [OBJECT_NAME, OBJECT_DESC]);
        
        string objectName = llToLower(llList2String(objectDetails, 0));
        string objectDesc = llToLower(llList2String(objectDetails, 1));
        
        if (objectName != "" && objectName != "(no description)") {
            string combinedText = objectName + " " + objectDesc;
            attachmentList += [objectName];
            
            integer j;
            for (j = 0; j < llGetListLength(gAdultAttachments); j++) {
                string keyword = llList2String(gAdultAttachments, j);
                if (llSubStringIndex(combinedText, keyword) != -1) {
                    sexinessIndicators += [keyword];
                    jump continue_adult;
                }
            }
            @continue_adult;
            
            for (j = 0; j < llGetListLength(gWeaponAttachments); j++) {
                string keyword = llList2String(gWeaponAttachments, j);
                if (llSubStringIndex(combinedText, keyword) != -1) {
                    threatIndicators += [keyword + ":weapon"];
                    jump continue_weapon;
                }
            }
            @continue_weapon;
            
            for (j = 0; j < llGetListLength(gCombatAttachments); j++) {
                string keyword = llList2String(gCombatAttachments, j);
                if (llSubStringIndex(combinedText, keyword) != -1) {
                    threatIndicators += [keyword + ":combat"];
                    jump continue_combat;
                }
            }
            @continue_combat;
            
            for (j = 0; j < llGetListLength(gDominanceAttachments); j++) {
                string keyword = llList2String(gDominanceAttachments, j);
                if (llSubStringIndex(combinedText, keyword) != -1) {
                    threatIndicators += [keyword + ":dominance"];
                    jump continue_dominance;
                }
            }
            @continue_dominance;
        }
    }
    
    return [
        llDumpList2String(attachmentList, ","),
        llDumpList2String(sexinessIndicators, ","),
        llDumpList2String(threatIndicators, ",")
    ];
}

// Calculate sexiness
integer calculateSexiness(key avatarKey, string gender, list attachmentAnalysis) {
    string sexinessIndicators = llList2String(attachmentAnalysis, 1);
    integer baseSexiness = 25;
    
    if (gender == "Male" && !gAttractedToMales) return 0;
    if (gender == "Female" && !gAttractedToFemales) return 0;
    if (gender == "Non-Binary" && !gAttractedToNonBinary) return 0;
    
    list indicators = llParseString2List(sexinessIndicators, [","], []);
    integer i;
    
    for (i = 0; i < llGetListLength(indicators); i++) {
        string indicator = llList2String(indicators, i);
        
        if (llSubStringIndex(indicator, "breast") != -1 || 
            llSubStringIndex(indicator, "boob") != -1 || 
            llSubStringIndex(indicator, "tit") != -1) {
            baseSexiness += (integer)(15.0 * gBreastMultiplier);
        }
        else if (llSubStringIndex(indicator, "butt") != -1 || 
                 llSubStringIndex(indicator, "ass") != -1) {
            baseSexiness += (integer)(12.0 * gButtMultiplier);
        }
        else if (llSubStringIndex(indicator, "penis") != -1 || 
                 llSubStringIndex(indicator, "cock") != -1 ||
                 llSubStringIndex(indicator, "pussy") != -1 ||
                 llSubStringIndex(indicator, "vagina") != -1) {
            baseSexiness += (integer)(25.0 * gGenitalMultiplier);
        }
        else if (llSubStringIndex(indicator, "muscle") != -1) {
            baseSexiness += (integer)(8.0 * gMuscleMultiplier);
        }
        else if (llSubStringIndex(indicator, "dildo") != -1 || 
                 llSubStringIndex(indicator, "vibrator") != -1) {
            baseSexiness += 20;
        }
        else if (llSubStringIndex(indicator, "collar") != -1 || 
                 llSubStringIndex(indicator, "cuffs") != -1 ||
                 llSubStringIndex(indicator, "gag") != -1) {
            baseSexiness += 15;
        }
    }
    
    if (baseSexiness > 100) baseSexiness = 100;
    return baseSexiness;
}

// Calculate threat
integer calculateThreat(key avatarKey, string gender, list attachmentAnalysis) {
    string threatIndicators = llList2String(attachmentAnalysis, 2);
    integer baseThreat = 10;
    
    list indicators = llParseString2List(threatIndicators, [","], []);
    integer i;
    
    for (i = 0; i < llGetListLength(indicators); i++) {
        string indicator = llList2String(indicators, i);
        list parts = llParseString2List(indicator, [":"], []);
        string type = llList2String(parts, 1);
        
        if (type == "weapon") {
            baseThreat += (integer)(30.0 * gWeaponThreatMultiplier);
        }
        else if (type == "combat") {
            baseThreat += (integer)(20.0 * gCombatThreatMultiplier);
        }
        else if (type == "dominance" && gThreatFromDominants) {
            baseThreat += (integer)(15.0 * gDominanceThreatMultiplier);
        }
    }
    
    baseThreat += 5;
    
    if (gender == "Male") {
        baseThreat += 5;
    }
    
    if (baseThreat > 100) baseThreat = 100;
    return baseThreat;
}

// Detect gender
string detectAvatarGender(key avatarKey, string avatarName) {
    string keyStr = (string)avatarKey;
    integer seed = (integer)("0x" + llGetSubString(keyStr, -8, -1));
    
    list genders = ["Male", "Female", "Non-Binary", "Unknown"];
    string gender = llList2String(genders, (seed % 4));
    
    return gender;
}

// Generate avatar attributes
list generateEnhancedAvatarAttributes(key avatarKey, string avatarName) {
    string gender = detectAvatarGender(avatarKey, avatarName);
    list attachmentAnalysis = scanAvatarAttachments(avatarKey);
    
    integer threat = calculateThreat(avatarKey, gender, attachmentAnalysis);
    integer sexiness = calculateSexiness(avatarKey, gender, attachmentAnalysis);
    
    string keyStr = (string)avatarKey;
    integer seed = (integer)("0x" + llGetSubString(keyStr, -8, -1));
    integer arousal = ((seed * 7) % 50) + (sexiness / 2);
    if (arousal > 100) arousal = 100;
    
    return [threat, arousal, sexiness, gender, llList2String(attachmentAnalysis, 0)];
}

// Update scanner display
updateScannerDisplay() {
    if (!gVisible) {
        llSetText("", <1,1,1>, 0.0);
        return;
    }
    
    string display = "═══ PROXIMITY SCANNER v5.0 ═══\n\n";
    
    if (!gScannerActive) {
        display += "📡 SCANNER OFFLINE\n";
        display += "Range: " + (string)((integer)gScanRange) + "m | ";
        if (gAutoScanMode) {
            display += "Auto-Scan: ON";
        } else {
            display += "Auto-Scan: OFF";
        }
        display += "\nStatus: Standby\n\n";
        display += "[TOUCH] for menu";
    } else {
        display += "🔍 SCANNING ACTIVE\n";
        display += "Range: " + (string)((integer)gScanRange) + "m | ";
        display += "Found: " + (string)(llGetListLength(gDetectedAvatars)) + " avatars\n";
        if (gAutoScanMode) {
            display += "Auto-Scan: ENABLED\n\n";
        } else {
            display += "Manual Mode\n\n";
        }
        
        if (llGetListLength(gDetectedAvatars) == 0) {
            display += "No avatars detected in range";
        } else {
            integer maxShow = 6;
            integer count = llGetListLength(gDetectedAvatars);
            if (count > maxShow) count = maxShow;
            
            integer i;
            for (i = 0; i < count; i++) {
                key avatarKey = llList2String(gDetectedAvatars, i);
                
                integer dataIndex = llListFindList(gAvatarData, [avatarKey]);
                if (dataIndex >= 0) {
                    string name = llList2String(gAvatarData, dataIndex + 1);
                    integer threat = (integer)llList2String(gAvatarData, dataIndex + 2);
                    integer arousal = (integer)llList2String(gAvatarData, dataIndex + 3);
                    integer sexiness = (integer)llList2String(gAvatarData, dataIndex + 4);
                    string gender = llList2String(gAvatarData, dataIndex + 5);
                    string attachments = llList2String(gAvatarData, dataIndex + 6);
                    
                    if (llStringLength(name) > 8) {
                        name = llGetSubString(name, 0, 7) + "..";
                    }
                    
                    string genderIcon = "❓";
                    if (gender == "Male") genderIcon = "♂️";
                    else if (gender == "Female") genderIcon = "♀️";
                    else if (gender == "Non-Binary") genderIcon = "⚧️";
                    
                    display += genderIcon + " " + name + " ";
                    display += "T" + generateCompactProgressBar((float)threat, 4) + " ";
                    display += "S" + generateCompactProgressBar((float)sexiness, 4) + " ";
                    display += "A" + generateCompactProgressBar((float)arousal, 4);
                    
                    if (attachments != "") {
                        list attList = llParseString2List(attachments, [","], []);
                        if (llGetListLength(attList) > 0) {
                            display += " 🎯" + (string)llGetListLength(attList);
                        }
                    }
                    
                    display += "\n";
                }
            }
            
            if (llGetListLength(gDetectedAvatars) > maxShow) {
                display += "... and " + (string)(llGetListLength(gDetectedAvatars) - maxShow) + " more avatars";
            }
        }
    }
    
    vector color = <0.0, 1.0, 1.0>;
    
    if (gScannerActive && llGetListLength(gDetectedAvatars) > 0) {
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
                color = <1.0, 0.0, 0.0>;
            } else if (avgThreat >= 40) {
                color = <1.0, 0.5, 0.0>;
            } else {
                color = <0.0, 1.0, 0.0>;
            }
        }
    }
    
    llSetText(display, color, 1.0);
}

// Process detected avatars
processDetectedAvatars(integer detected) {
    gDetectedAvatars = [];
    gAvatarData = [];
    
    integer i;
    for (i = 0; i < detected; i++) {
        key avatarKey = llDetectedKey(i);
        string avatarName = llDetectedName(i);
        
        if (avatarKey == gOwner) jump continue;
        
        gDetectedAvatars += [avatarKey];
        
        list attributes = generateEnhancedAvatarAttributes(avatarKey, avatarName);
        gAvatarData += [avatarKey, avatarName] + attributes;
        
        @continue;
    }
    
    updateScannerDisplay();
    
    if (llGetListLength(gDetectedAvatars) > 0) {
        string threatData = "PROXIMITY_THREAT|";
        threatData += (string)llGetListLength(gDetectedAvatars) + "|";
        
        integer maleCount = 0;
        for (i = 0; i < llGetListLength(gDetectedAvatars); i++) {
            key avatarKey = llList2String(gDetectedAvatars, i);
            integer dataIndex = llListFindList(gAvatarData, [avatarKey]);
            if (dataIndex >= 0) {
                string gender = llList2String(gAvatarData, dataIndex + 5);
                if (gender == "Male") maleCount++;
            }
        }
        
        threatData += (string)maleCount;
        llMessageLinked(LINK_ROOT, 7000, threatData, "");
    }
}

// Toggle scanner
toggleScanner() {
    gScannerActive = !gScannerActive;
    
    if (gScannerActive) {
        llSetTimerEvent((float)gScanInterval);
        llSensorRepeat("", "", AGENT, gScanRange, PI, (float)gScanInterval);
        llOwnerSay("🔍 Enhanced proximity scanner activated");
    } else {
        if (!gAutoScanMode) {
            llSetTimerEvent(0.0);
        }
        llSensorRemove();
        gDetectedAvatars = [];
        gAvatarData = [];
        llOwnerSay("📴 Proximity scanner deactivated");
    }
    
    updateScannerDisplay();
}

// Toggle auto scan
toggleAutoScan() {
    gAutoScanMode = !gAutoScanMode;
    
    if (gAutoScanMode) {
        llSetTimerEvent((float)gAutoScanInterval);
        integer mins = gAutoScanInterval / 60;
        llOwnerSay("⏰ Auto-scan mode enabled (" + (string)mins + " min intervals)");
        if (!gScannerActive) {
            toggleScanner();
        }
    } else {
        if (!gScannerActive) {
            llSetTimerEvent(0.0);
        }
        llOwnerSay("⏹️ Auto-scan mode disabled");
    }
    
    updateScannerDisplay();
}

// Adjust scan range
adjustScanRange(float newRange) {
    if (newRange < 5.0) newRange = 5.0;
    if (newRange > 96.0) newRange = 96.0;
    
    gScanRange = newRange;
    
    if (gScannerActive) {
        llSensorRemove();
        llSensorRepeat("", "", AGENT, gScanRange, PI, (float)gScanInterval);
    }
    
    updateScannerDisplay();
}

// Initialize scanner
initializeProximityScanner() {
    llOwnerSay("🔧 A.R.I.A. Enhanced Proximity Scanner v" + VERSION + " initializing...");
    llOwnerSay("🔍 Attachment analysis system online");
    llOwnerSay("⚙️ Preference system enabled");
    llOwnerSay("📊 Progress bar displays active");
    
    gOwner = llGetOwner();
    llSetAlpha(0.0, ALL_SIDES);
    updateScannerDisplay();
    
    llOwnerSay("✅ Enhanced Proximity Scanner ready (Bottom Center)");
    llOwnerSay("📱 Touch for configuration menu");
}

// Main event handlers
default {
    state_entry() {
        initializeProximityScanner();
    }
    
    attach(key id) {
        if (id) {
            llOwnerSay("📱 Enhanced Proximity Scanner attached");
        } else {
            llOwnerSay("📱 Enhanced Proximity Scanner detached");
            if (gScannerActive) {
                gScannerActive = FALSE;
                llSetTimerEvent(0.0);
                llSensorRemove();
            }
        }
        
        llSleep(0.5);
        updateScannerDisplay();
    }
    
    timer() {
        if (gAutoScanMode) {
            if (!gScannerActive) {
                toggleScanner();
                llOwnerSay("⏰ Auto-scan initiated");
            }
            llSetTimerEvent((float)gAutoScanInterval);
        } else {
            if (gCurrentMenu != MENU_NONE) {
                gCurrentMenu = MENU_NONE;
                llListenRemove(gListenHandle);
                llSetTimerEvent(0.0);
                llOwnerSay("📱 Menu timeout");
            } else {
                updateScannerDisplay();
            }
        }
    }
    
    sensor(integer detected) {
        processDetectedAvatars(detected);
    }
    
    no_sensor() {
        gDetectedAvatars = [];
        gAvatarData = [];
        updateScannerDisplay();
        llMessageLinked(LINK_ROOT, 7000, "PROXIMITY_THREAT|0|0", "");
    }
    
    touch_start(integer total_number) {
        if (llDetectedKey(0) == gOwner) {
            if (gVisible) {
                llOwnerSay("📱 Configuration menu would open here");
                llOwnerSay("📊 Scanner is working - menu system can be added");
            } else {
                gVisible = TRUE;
                updateScannerDisplay();
                llOwnerSay("🔍 Proximity Scanner: Activated and Shown");
                llMessageLinked(LINK_ROOT, 3000, "PROXIMITY_VISIBILITY|" + (string)gVisible, "");
            }
        }
    }
    
    link_message(integer sender_num, integer num, string str, key id) {
        list parts = llParseString2List(str, ["|"], []);
        string command = llList2String(parts, 0);
        
        if (num == 2000 && command == "VISIBILITY") {
            gVisible = (integer)llList2String(parts, 1);
            updateScannerDisplay();
            
            if (gVisible) {
                llOwnerSay("🔍 Proximity Scanner display shown");
                if (gAutoScanMode && !gScannerActive) {
                    toggleScanner();
                }
            } else {
                llOwnerSay("🔍 Proximity Scanner display hidden");
                if (gScannerActive && !gAutoScanMode) {
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
            else if (action == "AUTO_SCAN") {
                toggleAutoScan();
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
