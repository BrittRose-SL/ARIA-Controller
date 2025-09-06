//-- A.R.I.A. Persona Module (Add-on)
//-- Version 2.1 - FUNCTION ORDER FIX
//-- Fixed function declarations and variable scoping

// --- CONFIGURATION ---
string gRlvRootFolder = "#RLV/~A.R.I.A.";

// --- HARDCODED PERSONA CONFIGURATIONS ---
list gPersonaConfigs = [
    "Default|OUTFIT/Default|HUD/Default|Standard",
    "Maid|OUTFIT/Maid|HUD/Maid|Polite", 
    "Assistant|OUTFIT/Assistant|HUD/Assistant|Professional",
    "Guardian|OUTFIT/Guardian|HUD/Guardian|Guardian",
    "Sexbot|OUTFIT/Sexbot|HUD/Sexbot|Seductive",
    "Companion|OUTFIT/Companion|HUD/Companion|Friendly"
];

// --- HARDCODED ANIMATION TRIGGERS ---
list gAnimationConfigs = [
    "kneels|kneel|loop|0",
    "stands|kneel|stop|0", 
    "dances|dance_01|loop|0",
    "stops dancing|dance_01|stop|0",
    "sits|sit_ground|loop|0",
    "poses|pose_casual|loop|0"
];

// --- LINKED MESSAGE CODES ---
integer SET_SPEECH_MODE = 100;
integer UPDATE_BATTERY = 101;
integer UPDATE_CONFIG = 102;
integer UPDATE_UNIT_INFO = 103;
integer UPDATE_PERSONA_STATUS = 104;
integer MODULE_REGISTER = 200;
integer OPEN_MY_MENU = 201;

// --- STATE VARIABLES ---
float gBatteryLevel = 100.0;
integer gMenuChannel;
integer gListenHandle;
integer gAnimListenHandle;
integer gAnimListenActive = FALSE;
key gAdministrator;
string gUnitName = "A.R.I.A.";
string gCurrentPersona = "Default";
string gCurrentMode = "Standard";
string gCurrentOutfitFolder;
string gCurrentHudFolder;
list gAnimTriggers;
list gAdministrators;
list gTrustedUsers;
key wearer;

// --- HELPER FUNCTIONS ---
updateHoverText() {
    string status = "A.R.I.A. Unit: " + gUnitName + "\n";
    status += "Persona: " + gCurrentPersona + " | Mode: " + gCurrentMode + "\n";
    status += "Power: " + (string)((integer)gBatteryLevel) + "%";
    
    vector color = <0.2, 1.0, 0.8>;
    if (gBatteryLevel <= 25.0) color = <1.0, 0.5, 0.0>;
    if (gBatteryLevel <= 10.0) color = <1.0, 0.0, 0.0>;
    
    llSetText(status, color, 1.0);
}

list getPersonaNames() {
    list names = [];
    integer i;
    for (i = 0; i < llGetListLength(gPersonaConfigs); i++) {
        list parts = llParseString2List(llList2String(gPersonaConfigs, i), ["|"], []);
        names += [llList2String(parts, 0)];
    }
    return names;
}

loadPersona(string personaName) {
    integer found = FALSE;
    integer i;
    string outfitFolder;
    string hudFolder;
    string speechMode;
    list parts;
    
    for (i = 0; i < llGetListLength(gPersonaConfigs); i++) {
        parts = llParseString2List(llList2String(gPersonaConfigs, i), ["|"], []);
        if (llList2String(parts, 0) == personaName) {
            found = TRUE;
            
            if (gCurrentOutfitFolder != "") {
                llOwnerSay("@detachfolder=" + gCurrentOutfitFolder + "=force");
            }
            if (gCurrentHudFolder != "") {
                llOwnerSay("@detachfolder=" + gCurrentHudFolder + "=force");
            }
            
            outfitFolder = llList2String(parts, 1);
            hudFolder = llList2String(parts, 2);
            speechMode = llList2String(parts, 3);
            
            gCurrentOutfitFolder = gRlvRootFolder + "/" + outfitFolder;
            gCurrentHudFolder = gRlvRootFolder + "/" + hudFolder;
            gCurrentMode = speechMode;
            
            llOwnerSay("@attachfolder=" + gCurrentOutfitFolder + "=force");
            llOwnerSay("@unsharedwear:" + gCurrentOutfitFolder + "=add");
            llOwnerSay("@attachfolder=" + gCurrentHudFolder + "=force");
            
            llMessageLinked(LINK_SET, SET_SPEECH_MODE, speechMode, NULL_KEY);
            
            gCurrentPersona = personaName;
            llMessageLinked(LINK_ROOT, UPDATE_PERSONA_STATUS, gCurrentPersona, NULL_KEY);
            
            llInstantMessage(gAdministrator, "Persona '" + personaName + "' activated successfully.");
            llInstantMessage(wearer, "// Persona Protocol '" + personaName + "' engaged. //");
            
            updateHoverText();
            return;
        }
    }
    
    if (!found) {
        llInstantMessage(gAdministrator, "ERROR: Persona '" + personaName + "' not found in configuration.");
        gCurrentPersona = "Default";
        updateHoverText();
    }
}

loadAnimationTriggers() {
    gAnimTriggers = [];
    integer i;
    list parts;
    
    for (i = 0; i < llGetListLength(gAnimationConfigs); i++) {
        parts = llParseString2List(llList2String(gAnimationConfigs, i), ["|"], []);
        if (llGetListLength(parts) >= 4) {
            gAnimTriggers += [llList2String(gAnimationConfigs, i)];
        }
    }
    llOwnerSay("Loaded " + (string)llGetListLength(gAnimTriggers) + " animation triggers.");
}

openPersonaMenu(key admin_id) {
    string dialog = "\n[ PERSONA MANAGEMENT ]\nCurrent: " + gCurrentPersona + " (" + gCurrentMode + ")\nSelect a persona to activate:";
    list personaNames = getPersonaNames();
    list buttons = personaNames + ["Animations", "Refresh", "-Main-"];
    
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", admin_id, "");
    llDialog(admin_id, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

openAnimationMenu(key admin_id) {
    string dialog = "\n[ ANIMATION CONTROLS ]\nAnimation triggers are ";
    if (gAnimListenActive) {
        dialog += "ENABLED";
    } else {
        dialog += "DISABLED";
    }
    dialog += "\n\nAvailable triggers:\n";
    
    integer i;
    list parts;
    for (i = 0; i < llGetListLength(gAnimTriggers) && i < 5; i++) {
        parts = llParseString2List(llList2String(gAnimTriggers, i), ["|"], []);
        dialog += "'" + llList2String(parts, 0) + "' -> " + llList2String(parts, 1) + "\n";
    }
    if (llGetListLength(gAnimTriggers) > 5) {
        dialog += "... and " + (string)(llGetListLength(gAnimTriggers) - 5) + " more.";
    }
    
    list buttons;
    if (gAnimListenActive) {
        buttons = ["Disable Anims", "Test Kneel", "-Back-"];
    } else {
        buttons = ["Enable Anims", "Test Kneel", "-Back-"];
    }
    
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", admin_id, "");
    llDialog(admin_id, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

// --- MAIN LOGIC ---
default {
    state_entry() {
        wearer = llGetOwner();
        gMenuChannel = (integer)("0x" + llGetSubString(llGetKey(), -8, -2));
        
        gCurrentPersona = "Default";
        gCurrentMode = "Standard";
        
        loadAnimationTriggers();
        
        llMessageLinked(LINK_ROOT, MODULE_REGISTER, "Persona", NULL_KEY);
        
        gAnimListenHandle = llListen(0, "", wearer, "");
        gAnimListenActive = TRUE;
        
        updateHoverText();
        llOwnerSay("Persona module initialized. Current persona: " + gCurrentPersona);
    }

    link_message(integer sender, integer num, string msg, key id) {
        if (num == UPDATE_BATTERY) {
            gBatteryLevel = (float)msg;
            updateHoverText();
        } 
        else if (num == UPDATE_CONFIG) {
            list parts = llParseString2List(msg, ["|"], []);
            if (llGetListLength(parts) >= 2) {
                gAdministrators = llCSV2List(llList2String(parts, 0));
                gTrustedUsers = llCSV2List(llList2String(parts, 1));
            }
        } 
        else if (num == UPDATE_UNIT_INFO) {
            gUnitName = msg;
            updateHoverText();
        } 
        else if (num == OPEN_MY_MENU) {
            key user = (key)msg;
            if (llListFindList(gAdministrators, [user]) != -1 || 
                llListFindList(gTrustedUsers, [user]) != -1) {
                gAdministrator = user;
                openPersonaMenu(user);
            } else {
                llInstantMessage(user, "Access denied. Trusted user or Administrator permissions required.");
            }
        }
    }

    listen(integer chan, string name, key id, string msg) {
        if (chan == 0 && id == wearer && gAnimListenActive) {
            string lowerMsg = llToLower(msg);
            integer i;
            list parts;
            string trigger;
            string animName;
            string action;
            
            for (i = 0; i < llGetListLength(gAnimTriggers); i++) {
                parts = llParseString2List(llList2String(gAnimTriggers, i), ["|"], []);
                trigger = llToLower(llList2String(parts, 0));
                
                if (llSubStringIndex(lowerMsg, trigger) != -1) {
                    animName = llList2String(parts, 1);
                    action = llList2String(parts, 2);
                    
                    if (action == "loop") {
                        llStartAnimation(animName);
                        llOwnerSay("// Animation triggered: " + animName + " //");
                    } else if (action == "stop") {
                        llStopAnimation(animName);
                        llOwnerSay("// Animation stopped: " + animName + " //");
                    }
                    return;
                }
            }
        }
        else if (chan == gMenuChannel) {
            llListenRemove(gListenHandle);
            
            list personaNames = getPersonaNames();
            if (llListFindList(personaNames, [msg]) != -1) {
                loadPersona(msg);
            }
            else if (msg == "Animations") {
                openAnimationMenu(id);
            }
            else if (msg == "Enable Anims") {
                if (!gAnimListenActive) {
                    gAnimListenHandle = llListen(0, "", wearer, "");
                    gAnimListenActive = TRUE;
                    llInstantMessage(id, "Animation triggers ENABLED.");
                }
                openAnimationMenu(id);
            }
            else if (msg == "Disable Anims") {
                if (gAnimListenActive) {
                    llListenRemove(gAnimListenHandle);
                    gAnimListenActive = FALSE;
                    llInstantMessage(id, "Animation triggers DISABLED.");
                }
                openAnimationMenu(id);
            }
            else if (msg == "Test Kneel") {
                llStartAnimation("kneel");
                llInstantMessage(id, "Test animation: kneel started.");
                llSetTimerEvent(5.0);
            }
            else if (msg == "Refresh") {
                loadAnimationTriggers();
                updateHoverText();
                llInstantMessage(id, "Persona module refreshed.");
                openPersonaMenu(id);
            }
            else if (msg == "-Back-") {
                openPersonaMenu(id);
            }
            else if (msg == "-Main-") {
                llInstantMessage(id, "Returning to main menu.");
            }
        }
    }
    
    timer() {
        llListenRemove(gListenHandle);
        llStopAnimation("kneel");
    }
    
    changed(integer c) {
        if (c & CHANGED_OWNER) {
            llResetScript();
        }
    }
}
