//-- A.R.I.A. Station Permission Manager
//-- Version 1.1 - USER PERMISSION MANAGEMENT
//-- Handles administrator and trusted user management for synced A.R.I.A. units
//-- CHANGES v1.1:
//--   - Added target unit keys to permission requests and updates

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
list gUnitAdministrators = [];
list gUnitTrustedUsers = [];
integer gWearerAdminMode = TRUE;
integer gListenHandle;
integer gTextBoxHandle;

// --- MENU STATES ---
integer MENU_MAIN = 0;
integer MENU_ADD_ADMIN = 1;
integer MENU_ADD_TRUSTED = 2;
integer MENU_REMOVE_ADMIN = 3;
integer MENU_REMOVE_TRUSTED = 4;
integer gMenuState = MENU_MAIN;

// --- HELPER FUNCTIONS ---
openPermissionMenu(key user) {
    if (gSyncedUnitKey == NULL_KEY) {
        llInstantMessage(user, "No A.R.I.A. unit connected to station.");
        return;
    }
    
    gMenuState = MENU_MAIN;
    string dialog = "\n[ PERMISSION MANAGER ]\n";
    dialog += "Unit: " + gSyncedUnitName + "\n";
    dialog += "Administrators: " + (string)llGetListLength(gUnitAdministrators) + "\n";
    dialog += "Trusted Users: " + (string)llGetListLength(gUnitTrustedUsers) + "\n";
    dialog += "Wearer Admin: ";
    if (gWearerAdminMode) {
        dialog += "ENABLED\n\n";
    } else {
        dialog += "DISABLED\n\n";
    }
    dialog += "Select operation:";
    
    list buttons = ["Add Admin", "Add Trusted", "Remove Admin"];
    buttons += ["Remove Trusted", "Show Lists", "Wearer Mode"];
    buttons += ["Sync Perms", "Reset Perms", "-Main-"];
    
    llListenRemove(gListenHandle);
    llListenRemove(gTextBoxHandle);
    gMenuChannel = (integer)("0x" + llGetSubString(llGetKey(), -8, -2));
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llDialog(user, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

openUserSelectionMenu(key user, string action, list userList) {
    if (llGetListLength(userList) == 0) {
        llInstantMessage(user, "No users in the " + action + " list.");
        openPermissionMenu(user);
        return;
    }
    
    string dialog = "\n[ " + llToUpper(action) + " USER ]\n";
    dialog += "Unit: " + gSyncedUnitName + "\n";
    dialog += "Select user to remove:\n";
    
    list buttons = [];
    integer i;
    for (i = 0; i < llGetListLength(userList) && i < 9; i++) {
        key userKey = (key)llList2String(userList, i);
        string userName = llKey2Name(userKey);
        if (userName == "") {
            userName = "Unknown User";
        }
        
        // Truncate long names for buttons
        if (llStringLength(userName) > 12) {
            userName = llGetSubString(userName, 0, 11);
        }
        buttons += [userName];
    }
    
    buttons += ["-Back-"];
    
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llDialog(user, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

addUser(string input, key requester, integer isAdmin) {
    if (gSyncedUnitKey == NULL_KEY) {
        llInstantMessage(requester, "No unit connected.");
        return;
    }
    
    key targetKey = NULL_KEY;
    
    // Try to parse as UUID first
    if (llStringLength(input) == 36 && llSubStringIndex(input, "-") != -1) {
        targetKey = (key)input;
        if (targetKey == NULL_KEY) {
            llInstantMessage(requester, "Invalid UUID format.");
            return;
        }
    } else {
        // Try to find by name in range
        llSensor(input, NULL_KEY, AGENT, 96.0, PI);
        return; // Will continue in sensor event
    }
    
    // Send add command to unit
    string userType = "TRUSTED";
    if (isAdmin) {
        userType = "ADMINISTRATOR";
    }
    
    string command = "ADD_" + userType + "|" + (string)targetKey + "|" + (string)gSyncedUnitKey + "|" + (string)requester;
    llRegionSay(gUnitLinkChannel, command);
    
    string userName = llKey2Name(targetKey);
    if (userName == "") {
        userName = (string)targetKey;
    }
    
    llInstantMessage(requester, "Adding " + userName + " as " + userType + "...");
    llSay(0, "PERMISSION UPDATE: Adding " + userType + " to " + gSyncedUnitName);
}

removeUser(string userName, key requester, integer isAdmin) {
    if (gSyncedUnitKey == NULL_KEY) {
        llInstantMessage(requester, "No unit connected.");
        return;
    }
    
    list searchList = gUnitTrustedUsers;
    string userType = "TRUSTED";
    if (isAdmin) {
        searchList = gUnitAdministrators;
        userType = "ADMINISTRATOR";
    }
    
    // Find the user by name
    key targetKey = NULL_KEY;
    integer i;
    for (i = 0; i < llGetListLength(searchList); i++) {
        key userKey = (key)llList2String(searchList, i);
        string fullName = llKey2Name(userKey);
        if (llSubStringIndex(fullName, userName) == 0) {
            targetKey = userKey;
            jump found_user;
        }
    }
    @found_user;
    
    if (targetKey == NULL_KEY) {
        llInstantMessage(requester, "User not found: " + userName);
        return;
    }
    
    // Send remove command to unit
    string command = "REMOVE_" + userType + "|" + (string)targetKey + "|" + (string)gSyncedUnitKey + "|" + (string)requester;
    llRegionSay(gUnitLinkChannel, command);
    
    llInstantMessage(requester, "Removing " + userName + " from " + userType + " list...");
    llSay(0, "PERMISSION UPDATE: Removing " + userType + " from " + gSyncedUnitName);
}

showUserLists(key user) {
    string report = "PERMISSION LISTS\n";
    report += "Unit: " + gSyncedUnitName + "\n";
    report += "═══════════════════════\n";
    report += "ADMINISTRATORS (" + (string)llGetListLength(gUnitAdministrators) + "):\n";
    
    integer i;
    for (i = 0; i < llGetListLength(gUnitAdministrators) && i < 10; i++) {
        key userKey = (key)llList2String(gUnitAdministrators, i);
        string userName = llKey2Name(userKey);
        if (userName == "") {
            userName = "Unknown User";
        }
        report += "• " + userName + "\n";
    }
    
    if (llGetListLength(gUnitAdministrators) > 10) {
        report += "... and " + (string)(llGetListLength(gUnitAdministrators) - 10) + " more\n";
    }
    
    report += "\nTRUSTED USERS (" + (string)llGetListLength(gUnitTrustedUsers) + "):\n";
    for (i = 0; i < llGetListLength(gUnitTrustedUsers) && i < 10; i++) {
        key userKey = (key)llList2String(gUnitTrustedUsers, i);
        string userName = llKey2Name(userKey);
        if (userName == "") {
            userName = "Unknown User";
        }
        report += "• " + userName + "\n";
    }
    
    if (llGetListLength(gUnitTrustedUsers) > 10) {
        report += "... and " + (string)(llGetListLength(gUnitTrustedUsers) - 10) + " more\n";
    }
    
    report += "\n═══════════════════════\n";
    report += "Wearer Admin Mode: ";
    if (gWearerAdminMode) {
        report += "ENABLED";
    } else {
        report += "DISABLED";
    }
    
    llInstantMessage(user, report);
}

toggleWearerMode(key user) {
    if (gSyncedUnitKey == NULL_KEY) {
        llInstantMessage(user, "No unit connected.");
        return;
    }
    
    string command = "TOGGLE_WEARER_MODE|" + (string)gSyncedUnitKey + "|" + (string)user;
    llRegionSay(gUnitLinkChannel, command);
    
    string newMode = "DISABLED";
    if (!gWearerAdminMode) {
        newMode = "ENABLED";
    }
    
    llInstantMessage(user, "Setting wearer admin mode to " + newMode + "...");
    llSay(0, "PERMISSION UPDATE: Wearer admin mode " + newMode + " on " + gSyncedUnitName);
}

syncPermissions(key user) {
    if (gSyncedUnitKey == NULL_KEY) {
        llInstantMessage(user, "No unit connected.");
        return;
    }
    
    llInstantMessage(user, "Syncing permission data from " + gSyncedUnitName + "...");
    llRegionSay(gUnitLinkChannel, "REQUEST_PERMISSION_LIST|" + (string)gSyncedUnitKey + "|" + (string)user);
}

resetPermissions(key user) {
    if (gSyncedUnitKey == NULL_KEY) {
        llInstantMessage(user, "No unit connected.");
        return;
    }
    
    llInstantMessage(user, "WARNING: This will reset all permissions to default. Continue?");
    // For now, just notify - could add confirmation dialog later
    llSay(0, "PERMISSION RESET requested for " + gSyncedUnitName);
}

// --- MAIN SCRIPT LOGIC ---
default {
    state_entry() {
        gMenuChannel = (integer)("0x" + llGetSubString(llGetKey(), -8, -2));
        
        // Register with main station
        llMessageLinked(LINK_ROOT, STATION_MODULE_REGISTER, "Permission Manager", NULL_KEY);
        
        // Listen for unit responses
        llListen(gUnitLinkChannel, "", NULL_KEY, "");
        
        llOwnerSay("Station Permission Manager v1.0 initialized.");
    }

    link_message(integer sender, integer num, string msg, key id) {
        if (num == STATION_OPEN_MENU) {
            // Parse: userkey|modulename
            list parts = llParseString2List(msg, ["|"], []);
            key user = (key)llList2String(parts, 0);
            string moduleName = llList2String(parts, 1);
            
            if (moduleName == "Permission Manager" || moduleName == "Permission" || moduleName == "Permissions") {
                gCurrentUser = user;
                openPermissionMenu(user);
            }
        }
        else if (num == STATION_UNIT_SYNC) {
            list parts = llParseString2List(msg, ["|"], []);
            string syncCommand = llList2String(parts, 0);
            
            if (syncCommand == "SYNC_SUCCESS") {
                gSyncedUnitKey = (key)llList2String(parts, 1);
                gSyncedUnitName = llList2String(parts, 2);
                llOwnerSay("Permission Manager synced with: " + gSyncedUnitName);
                
                // Request permission data
                llRegionSay(gUnitLinkChannel, "REQUEST_PERMISSION_LIST|" + (string)gSyncedUnitKey + "|" + (string)gCurrentUser);
            }
            else if (syncCommand == "DISCONNECT") {
                gSyncedUnitKey = NULL_KEY;
                gSyncedUnitName = "";
                gUnitAdministrators = [];
                gUnitTrustedUsers = [];
                gWearerAdminMode = TRUE;
                llOwnerSay("Permission Manager disconnected from unit.");
            }
        }
        else if (num == STATION_UPDATE_DATA) {
            list parts = llParseString2List(msg, ["|"], []);
            string dataType = llList2String(parts, 0);
            
            if (dataType == "PERMISSIONS") {
                string permData = llList2String(parts, 1);
                list dataParts = llParseString2List(permData, ["|"], []);
                if (llGetListLength(dataParts) >= 3) {
                    gUnitAdministrators = llCSV2List(llList2String(dataParts, 0));
                    gUnitTrustedUsers = llCSV2List(llList2String(dataParts, 1));
                    gWearerAdminMode = (integer)llList2String(dataParts, 2);
                }
            }
        }
        else if (num == STATION_UNIT_STATUS) {
            // Parse unit status data
            list parts = llParseString2List(msg, ["|"], []);
            if (llGetListLength(parts) >= 2) {
                gSyncedUnitKey = (key)llList2String(parts, 0);
                gSyncedUnitName = llList2String(parts, 1);
            }
        }
    }

    sensor(integer num_detected) {
        // Handle name-based user lookup
        if (num_detected > 0) {
            key foundKey = llDetectedKey(0);
            string foundName = llDetectedName(0);
            
            if (gMenuState == MENU_ADD_ADMIN) {
                addUser((string)foundKey, gCurrentUser, TRUE);
            } else if (gMenuState == MENU_ADD_TRUSTED) {
                addUser((string)foundKey, gCurrentUser, FALSE);
            }
            
            llInstantMessage(gCurrentUser, "Found user: " + foundName);
            gMenuState = MENU_MAIN;
        } else {
            llInstantMessage(gCurrentUser, "User not found in range.");
            openPermissionMenu(gCurrentUser);
        }
    }
    
    no_sensor() {
        llInstantMessage(gCurrentUser, "User not found in sensor range.");
        openPermissionMenu(gCurrentUser);
    }

    listen(integer chan, string name, key id, string msg) {
        // Handle unit responses
        if (chan == gUnitLinkChannel) {
            list parts = llParseString2List(msg, ["|"], []);
            string command = llList2String(parts, 0);
            
            if (command == "PERMISSION_LIST_RESPONSE") {
                if (llGetListLength(parts) >= 4) {
                    gUnitAdministrators = llCSV2List(llList2String(parts, 1));
                    gUnitTrustedUsers = llCSV2List(llList2String(parts, 2));
                    gWearerAdminMode = (integer)llList2String(parts, 3);
                    llOwnerSay("Permission data updated from unit.");
                }
                return;
            }
            else if (command == "PERMISSION_UPDATE_RESPONSE") {
                if (llGetListLength(parts) >= 4) {
                    string action = llList2String(parts, 1);
                    string userType = llList2String(parts, 2);
                    string result = llList2String(parts, 3);
                    
                    if (result == "SUCCESS") {
                        llInstantMessage(gCurrentUser, "Permission update successful: " + action + " " + userType);
                        // Request updated permission list
                        llRegionSay(gUnitLinkChannel, "REQUEST_PERMISSION_LIST|" + (string)gSyncedUnitKey + "|" + (string)gCurrentUser);
                    } else {
                        llInstantMessage(gCurrentUser, "Permission update failed: " + result);
                    }
                }
                return;
            }
            else if (command == "WEARER_MODE_RESPONSE") {
                if (llGetListLength(parts) >= 2) {
                    string result = llList2String(parts, 1);
                    if (result == "SUCCESS") {
                        gWearerAdminMode = !gWearerAdminMode;
                        string mode = "DISABLED";
                        if (gWearerAdminMode) {
                            mode = "ENABLED";
                        }
                        llInstantMessage(gCurrentUser, "Wearer admin mode " + mode);
                    } else {
                        llInstantMessage(gCurrentUser, "Failed to change wearer mode: " + result);
                    }
                }
                return;
            }
            return;
        }
        
        // Handle menu interactions
        if (chan == gMenuChannel) {
            llListenRemove(gListenHandle);
            llListenRemove(gTextBoxHandle);
            
            if (msg == "-Main-") {
                llInstantMessage(id, "Returning to main station menu.");
                return;
            }
            else if (msg == "-Back-") {
                openPermissionMenu(id);
                return;
            }
            else if (msg == "Add Admin") {
                gMenuState = MENU_ADD_ADMIN;
                gTextBoxHandle = llListen(gMenuChannel, "", id, "");
                llTextBox(id, "Enter administrator name or UUID:\n\nYou can enter:\n• Full avatar name\n• Avatar UUID", gMenuChannel);
                llSetTimerEvent(60.0);
                return;
            }
            else if (msg == "Add Trusted") {
                gMenuState = MENU_ADD_TRUSTED;
                gTextBoxHandle = llListen(gMenuChannel, "", id, "");
                llTextBox(id, "Enter trusted user name or UUID:\n\nYou can enter:\n• Full avatar name\n• Avatar UUID", gMenuChannel);
                llSetTimerEvent(60.0);
                return;
            }
            else if (msg == "Remove Admin") {
                gMenuState = MENU_REMOVE_ADMIN;
                openUserSelectionMenu(id, "Remove Administrator", gUnitAdministrators);
                return;
            }
            else if (msg == "Remove Trusted") {
                gMenuState = MENU_REMOVE_TRUSTED;
                openUserSelectionMenu(id, "Remove Trusted", gUnitTrustedUsers);
                return;
            }
            else if (msg == "Show Lists") {
                showUserLists(id);
                openPermissionMenu(id);
            }
            else if (msg == "Wearer Mode") {
                toggleWearerMode(id);
                openPermissionMenu(id);
            }
            else if (msg == "Sync Perms") {
                syncPermissions(id);
                openPermissionMenu(id);
            }
            else if (msg == "Reset Perms") {
                resetPermissions(id);
                openPermissionMenu(id);
            }
            else {
                // Handle text input or user selection
                if (gMenuState == MENU_ADD_ADMIN) {
                    addUser(msg, id, TRUE);
                    gMenuState = MENU_MAIN;
                    openPermissionMenu(id);
                }
                else if (gMenuState == MENU_ADD_TRUSTED) {
                    addUser(msg, id, FALSE);
                    gMenuState = MENU_MAIN;
                    openPermissionMenu(id);
                }
                else if (gMenuState == MENU_REMOVE_ADMIN) {
                    removeUser(msg, id, TRUE);
                    gMenuState = MENU_MAIN;
                    openPermissionMenu(id);
                }
                else if (gMenuState == MENU_REMOVE_TRUSTED) {
                    removeUser(msg, id, FALSE);
                    gMenuState = MENU_MAIN;
                    openPermissionMenu(id);
                }
                else {
                    llInstantMessage(id, "Unknown command: " + msg);
                    openPermissionMenu(id);
                }
            }
        }
    }
    
    timer() {
        llListenRemove(gListenHandle);
        llListenRemove(gTextBoxHandle);
        gMenuState = MENU_MAIN;
    }
    
    changed(integer change) {
        if (change & CHANGED_OWNER) {
            llResetScript();
        }
    }
}
