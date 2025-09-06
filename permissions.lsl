//-- A.R.I.A. Permissions Module (Add-on)
//-- Version 1.4 - WEARER ADMIN MODE CONTROL
//-- Added wearer admin mode toggle functionality

// --- LINKED MESSAGE CODES ---
integer UPDATE_CONFIG = 102;
integer MODULE_REGISTER = 200;
integer OPEN_MY_MENU = 201;
integer UPDATE_USER_LISTS = 105;
integer UPDATE_WEARER_ADMIN_MODE = 106; // NEW: For wearer admin mode updates

// --- STATE VARIABLES ---
integer gMenuChannel;
integer gListenHandle;
key gAdministrator;
list gAdministrators;
list gTrustedUsers;
key gPrimaryAdmin;
key wearer;
integer gPermissionsGranted = FALSE;

// --- NEW: WEARER ADMIN MODE ---
integer gWearerAdminMode = TRUE; // Tracks current wearer admin mode status

// --- MENU & SENSOR VARIABLES ---
integer gPermissionState = 0;
list gScanResults_Keys;
list gScanResults_Names;
integer gScanResults_Page;

// --- HELPER FUNCTIONS ---
open_menu(key id, string str, list btns) {
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", id, "");
    llDialog(id, str, btns, gMenuChannel);
    llSetTimerEvent(30.0);
}

buildScanMenu(key user, integer page) {
    gScanResults_Page = page;
    
    list buttons = [];
    integer start = page * 9;
    integer end = start + 8;
    integer maxResults = llGetListLength(gScanResults_Names);
    integer i = start;
    
    while (i <= end && i < maxResults) {
        buttons += [llList2String(gScanResults_Names, i)];
        i++;
    }
    
    if (start > 0) buttons += ["<-- Back"];
    if (end < maxResults - 1) buttons += ["Next -->"];
    buttons += ["-Cancel-"];
    
    open_menu(user, "\n[ PERMISSIONS: SCAN RESULTS ]\nSelect an avatar to add.", buttons);
}

buildRemoveMenu(key user, integer page) {
    gScanResults_Page = page;
    
    list sourceList = [];
    if (gPermissionState == 2) sourceList = gAdministrators;
    else sourceList = gTrustedUsers;
    
    gScanResults_Keys = sourceList;
    gScanResults_Names = [];
    
    integer maxUsers = llGetListLength(sourceList);
    integer i = 0;
    while (i < maxUsers) {
        key userKey = (key)llList2String(sourceList, i);
        string userName = llKey2Name(userKey);
        if (userName == "") userName = "Unknown User";
        gScanResults_Names += [userName];
        i++;
    }
    
    list buttons = [];
    integer start = page * 9;
    integer end = start + 8;
    i = start;
    while (i <= end && i < maxUsers) {
        buttons += [llList2String(gScanResults_Names, i)];
        i++;
    }
    
    if (start > 0) buttons += ["<-- Back"];
    if (end < maxUsers - 1) buttons += ["Next -->"];
    buttons += ["-Cancel-"];
    
    open_menu(user, "\n[ PERMISSIONS: REMOVE USER ]\nSelect an avatar to remove.", buttons);
}

// NEW: Build main permissions menu with wearer admin mode option
buildMainMenu(key user) {
    string wearerModeStatus = "ENABLED";
    if (!gWearerAdminMode) wearerModeStatus = "DISABLED";
    
    string dialog = "\n[ PERMISSIONS MANAGEMENT ]\nManage user access levels and wearer privileges.\n\n";
    dialog += "Admins: " + (string)llGetListLength(gAdministrators) + "\n";
    dialog += "Trusted: " + (string)llGetListLength(gTrustedUsers) + "\n";
    dialog += "Wearer Admin Mode: " + wearerModeStatus;
    
    list buttons = ["Add Admin", "Rem Admin", "Add Trusted"];
    buttons += ["Rem Trusted", "Wearer Mode", "-Main-"];
    
    open_menu(user, dialog, buttons);
}

default {
    state_entry() {
        wearer = llGetOwner();
        gPrimaryAdmin = llGetOwner();
        gPermissionsGranted = TRUE;
        gMenuChannel = (integer)("0x" + llGetSubString(llGetKey(), -7, -1));
        llMessageLinked(LINK_ROOT, MODULE_REGISTER, "Permissions", NULL_KEY);
        llOwnerSay("Permissions module v1.4 initialized successfully.");
    }
    
    run_time_permissions(integer perm) {
        // Not needed for this module
    }

    link_message(integer sender, integer num, string msg, key id) {
        if (num == OPEN_MY_MENU) {
            key user = (key)msg;
            if (llListFindList(gAdministrators, [user]) != -1) {
                gPermissionState = 0;
                buildMainMenu(user);
            } else {
                llInstantMessage(user, "Access denied. Administrator permissions required.");
            }
        } 
        else if (num == UPDATE_CONFIG) {
            list parts = llParseString2List(msg, ["|"], []);
            if (llGetListLength(parts) >= 2) {
                string admin_csv = llList2String(parts, 0);
                string trusted_csv = llList2String(parts, 1);
                
                if (admin_csv != "") gAdministrators = llCSV2List(admin_csv);
                if (trusted_csv != "") gTrustedUsers = llCSV2List(trusted_csv);
                
                if (llListFindList(gAdministrators, [gPrimaryAdmin]) == -1) {
                    gAdministrators = [gPrimaryAdmin] + gAdministrators;
                }
            }
        }
        // NEW: Handle wearer admin mode updates from main module
        else if (num == UPDATE_WEARER_ADMIN_MODE) {
            gWearerAdminMode = (integer)msg;
        }
    }

    sensor(integer num_detected) {
        gScanResults_Keys = [];
        gScanResults_Names = [];
        
        integer i = 0;
        while (i < num_detected) {
            key detectedKey = llDetectedKey(i);
            if (detectedKey != wearer) {
                gScanResults_Keys += [detectedKey];
                gScanResults_Names += [llDetectedName(i)];
            }
            i++;
        }
        
        if (llGetListLength(gScanResults_Keys) > 0) {
            buildScanMenu(gAdministrator, 0);
        } else {
            llInstantMessage(gAdministrator, "No other avatars found in range.");
            gPermissionState = 0;
        }
    }
    
    no_sensor() {
        llInstantMessage(gAdministrator, "No avatars found in range.");
        gPermissionState = 0;
    }

    listen(integer chan, string name, key id, string msg) {
        if (!gPermissionsGranted) return;
        
        gAdministrator = id;
        llListenRemove(gListenHandle);

        if (msg == "Add Admin") { 
            gPermissionState = 1;
            llSensor("", NULL_KEY, AGENT, 20.0, PI);
        }
        else if (msg == "Rem Admin") { 
            if (llGetListLength(gAdministrators) <= 1) {
                llInstantMessage(id, "Cannot remove administrators. At least one admin must remain.");
                return;
            }
            gPermissionState = 2;
            buildRemoveMenu(id, 0);
        }
        else if (msg == "Add Trusted") { 
            gPermissionState = 3;
            llSensor("", NULL_KEY, AGENT, 20.0, PI);
        }
        else if (msg == "Rem Trusted") { 
            if (llGetListLength(gTrustedUsers) == 0) {
                llInstantMessage(id, "No trusted users to remove.");
                return;
            }
            gPermissionState = 4;
            buildRemoveMenu(id, 0);
        }
        // NEW: Handle wearer admin mode toggle
        else if (msg == "Wearer Mode") {
            gWearerAdminMode = !gWearerAdminMode;
            
            // Send update to main module
            llMessageLinked(LINK_ROOT, UPDATE_WEARER_ADMIN_MODE, (string)gWearerAdminMode, id);
            
            string status = "ENABLED";
            if (!gWearerAdminMode) status = "DISABLED";
            
            llInstantMessage(id, "Wearer Admin Mode " + status + ".");
            if (gWearerAdminMode) {
                llInstantMessage(wearer, "// Administrator privileges have been granted. //");
            } else {
                llInstantMessage(wearer, "// Administrator privileges have been revoked. Access limited to basic functions. //");
            }
            
            // Return to main menu
            buildMainMenu(id);
            return;
        }
        else if (msg == "Next -->") {
            if (gPermissionState == 1 || gPermissionState == 3) {
                buildScanMenu(id, gScanResults_Page + 1);
            } else {
                buildRemoveMenu(id, gScanResults_Page + 1);
            }
        }
        else if (msg == "<-- Back") {
            if (gScanResults_Page > 0) {
                if (gPermissionState == 1 || gPermissionState == 3) {
                    buildScanMenu(id, gScanResults_Page - 1);
                } else {
                    buildRemoveMenu(id, gScanResults_Page - 1);
                }
            }
        }
        else if (msg == "-Cancel-" || msg == "-Main-") {
            gPermissionState = 0;
        }
        else {
            integer index = llListFindList(gScanResults_Names, [msg]);
            if (index != -1) {
                key targetKey = (key)llList2String(gScanResults_Keys, index);
                
                if (gPermissionState == 1) {
                    if (llListFindList(gAdministrators, [targetKey]) == -1) {
                        gAdministrators += [targetKey];
                        llInstantMessage(id, msg + " added as Administrator.");
                    }
                } 
                else if (gPermissionState == 2) {
                    if (targetKey != gPrimaryAdmin) {
                        integer admin_index = llListFindList(gAdministrators, [targetKey]);
                        if (admin_index != -1) {
                            gAdministrators = llDeleteSubList(gAdministrators, admin_index, admin_index);
                            llInstantMessage(id, msg + " removed from Administrators.");
                        }
                    }
                } 
                else if (gPermissionState == 3) {
                    if (llListFindList(gTrustedUsers, [targetKey]) == -1) {
                        gTrustedUsers += [targetKey];
                        llInstantMessage(id, msg + " added as Trusted user.");
                    }
                } 
                else if (gPermissionState == 4) {
                    integer trusted_index = llListFindList(gTrustedUsers, [targetKey]);
                    if (trusted_index != -1) {
                        gTrustedUsers = llDeleteSubList(gTrustedUsers, trusted_index, trusted_index);
                        llInstantMessage(id, msg + " removed from Trusted users.");
                    }
                }
                
                llMessageLinked(LINK_ROOT, UPDATE_USER_LISTS, llList2CSV(gAdministrators) + "|" + llList2CSV(gTrustedUsers), NULL_KEY);
            }
            gPermissionState = 0;
        }
    }
    
    timer() {
        llListenRemove(gListenHandle);
        gPermissionState = 0;
    }
    
    changed(integer c) {
        if (c & CHANGED_OWNER) {
            llResetScript();
        }
    }
}
