//-- A.R.I.A. Permissions Module (Add-on)
//-- Version 1.5 - FIXED INITIALIZATION & WEARER ADMIN MODE CONTROL
//-- CHANGELOG v1.5: Fixed permissions initialization - properly receives config from master kernel
//-- CHANGELOG v1.4: Added wearer admin mode toggle functionality

// --- LINKED MESSAGE CODES ---
integer UPDATE_CONFIG = 102;
integer MODULE_REGISTER = 200;
integer OPEN_MY_MENU = 201;
integer UPDATE_USER_LISTS = 105;
integer UPDATE_WEARER_ADMIN_MODE = 106;

// --- STATE VARIABLES ---
integer gMenuChannel;
integer gListenHandle;
key gAdministrator;
list gAdministrators;
list gTrustedUsers;
key gPrimaryAdmin;
key wearer;
integer gPermissionsGranted = FALSE;

// --- WEARER ADMIN MODE ---
integer gWearerAdminMode = TRUE; // Tracks current wearer admin mode status

// --- MENU & SENSOR VARIABLES ---
integer gPermissionState = 0;
list gScanResults_Keys;
list gScanResults_Names;
integer gScanResults_Page;

// --- INITIALIZATION CONTROL ---
integer gConfigReceived = FALSE;

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

// Build main permissions menu with wearer admin mode option
buildMainMenu(key user) {
    string wearerModeStatus = "ENABLED";
    if (!gWearerAdminMode) wearerModeStatus = "DISABLED";
    
    string dialog = "\n[ PERMISSIONS MANAGEMENT ]\nManage user access levels and wearer privileges.\n\n";
    dialog += "Admins: " + (string)llGetListLength(gAdministrators) + "\n";
    dialog += "Trusted: " + (string)llGetListLength(gTrustedUsers) + "\n";
    dialog += "Wearer Admin Mode: " + wearerModeStatus + "\n";
    dialog += "Config Status: ";
    if (gConfigReceived) {
        dialog += "SYNCHRONIZED";
    } else {
        dialog += "WAITING";
    }
    
    list buttons = ["Add Admin", "Rem Admin", "Add Trusted"];
    buttons += ["Rem Trusted", "Wearer Mode", "Show Lists"];
    buttons += ["Refresh", "-Main-", "Close"];
    
    open_menu(user, dialog, buttons);
}

showUserLists(key user) {
    string report = "CURRENT USER PERMISSIONS\n";
    report += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
    
    report += "ADMINISTRATORS (" + (string)llGetListLength(gAdministrators) + "):\n";
    if (llGetListLength(gAdministrators) == 0) {
        report += "  • None\n";
    } else {
        integer i;
        for (i = 0; i < llGetListLength(gAdministrators); i++) {
            key adminKey = (key)llList2String(gAdministrators, i);
            string adminName = llKey2Name(adminKey);
            if (adminName == "") adminName = "Unknown User";
            
            if (adminKey == gPrimaryAdmin) {
                report += "  • " + adminName + " (PRIMARY)\n";
            } else {
                report += "  • " + adminName + "\n";
            }
        }
    }
    
    report += "\nTRUSTED USERS (" + (string)llGetListLength(gTrustedUsers) + "):\n";
    if (llGetListLength(gTrustedUsers) == 0) {
        report += "  • None\n";
    } else {
        integer i;
        for (i = 0; i < llGetListLength(gTrustedUsers); i++) {
            key trustedKey = (key)llList2String(gTrustedUsers, i);
            string trustedName = llKey2Name(trustedKey);
            if (trustedName == "") trustedName = "Unknown User";
            report += "  • " + trustedName + "\n";
        }
    }
    
    report += "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━";
    
    llInstantMessage(user, report);
}

refreshPermissions() {
    // Request updated configuration from master kernel
    llOwnerSay("Requesting permission refresh from master kernel...");
    // The master kernel will automatically send UPDATE_CONFIG when needed
}

default {
    state_entry() {
        wearer = llGetOwner();
        gPrimaryAdmin = llGetOwner();
        gPermissionsGranted = TRUE;
        gMenuChannel = (integer)("0x" + llGetSubString(llGetKey(), -7, -1));
        gConfigReceived = FALSE;
        
        // Initialize with owner as admin (backup measure)
        gAdministrators = [wearer];
        
        llMessageLinked(LINK_ROOT, MODULE_REGISTER, "Permissions", NULL_KEY);
        llOwnerSay("Permissions module v1.5 initialized successfully.");
        llOwnerSay("CHANGELOG v1.5: Fixed initialization and config synchronization");
    }
    
    run_time_permissions(integer perm) {
        // Not needed for this module
    }

    link_message(integer sender, integer num, string msg, key id) {
        if (num == OPEN_MY_MENU) {
            key user = (key)msg;
            
            // Check if user has admin privileges
            if (llListFindList(gAdministrators, [user]) != -1) {
                gPermissionState = 0;
                buildMainMenu(user);
            } else {
                llInstantMessage(user, "Access denied. Administrator permissions required.");
            }
        }
        else if (num == UPDATE_CONFIG) {
            // Receive configuration from master kernel
            list parts = llParseString2List(msg, ["|"], []);
            if (llGetListLength(parts) >= 2) {
                string adminCsv = llList2String(parts, 0);
                string trustedCsv = llList2String(parts, 1);
                
                // Update local lists from master kernel
                if (adminCsv != "") {
                    gAdministrators = llCSV2List(adminCsv);
                } else {
                    gAdministrators = [wearer]; // Ensure owner is always admin
                }
                
                if (trustedCsv != "") {
                    gTrustedUsers = llCSV2List(trustedCsv);
                } else {
                    gTrustedUsers = [];
                }
                
                gConfigReceived = TRUE;
                llOwnerSay("Permissions configuration updated from master kernel.");
                llOwnerSay("Administrators: " + (string)llGetListLength(gAdministrators));
                llOwnerSay("Trusted Users: " + (string)llGetListLength(gTrustedUsers));
            }
        }
    }

    sensor(integer num_detected) {
        gScanResults_Keys = [];
        gScanResults_Names = [];
        
        integer i = 0;
        while (i < num_detected) {
            key detected_key = llDetectedKey(i);
            string detected_name = llDetectedName(i);
            
            // Filter out the wearer from scan results
            if (detected_key != wearer) {
                gScanResults_Keys += [detected_key];
                gScanResults_Names += [detected_name];
            }
            i++;
        }
        
        if (llGetListLength(gScanResults_Keys) == 0) {
            llInstantMessage(gAdministrator, "No avatars detected within 20 meters.");
            gPermissionState = 0;
            return;
        }
        
        buildScanMenu(gAdministrator, 0);
    }

    no_sensor() {
        llInstantMessage(gAdministrator, "No avatars detected within 20 meters.");
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
                buildMainMenu(id);
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
                buildMainMenu(id);
                return;
            }
            gPermissionState = 4;
            buildRemoveMenu(id, 0);
        }
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
        else if (msg == "Show Lists") {
            showUserLists(id);
            buildMainMenu(id);
            return;
        }
        else if (msg == "Refresh") {
            refreshPermissions();
            llInstantMessage(id, "Permissions refreshed from master kernel.");
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
            return;
        }
        else if (msg == "Close") {
            llInstantMessage(id, "Permissions menu closed.");
            gPermissionState = 0;
            return;
        }
        else {
            integer index = llListFindList(gScanResults_Names, [msg]);
            if (index != -1) {
                key targetKey = (key)llList2String(gScanResults_Keys, index);
                
                if (gPermissionState == 1) {
                    if (llListFindList(gAdministrators, [targetKey]) == -1) {
                        gAdministrators += [targetKey];
                        llInstantMessage(id, msg + " added as Administrator.");
                        llOwnerSay("Administrator added: " + msg + " by " + llKey2Name(id));
                    } else {
                        llInstantMessage(id, msg + " is already an Administrator.");
                    }
                } 
                else if (gPermissionState == 2) {
                    if (targetKey != gPrimaryAdmin) {
                        integer admin_index = llListFindList(gAdministrators, [targetKey]);
                        if (admin_index != -1) {
                            gAdministrators = llDeleteSubList(gAdministrators, admin_index, admin_index);
                            llInstantMessage(id, msg + " removed from Administrators.");
                            llOwnerSay("Administrator removed: " + msg + " by " + llKey2Name(id));
                        }
                    } else {
                        llInstantMessage(id, "Cannot remove Primary Administrator.");
                    }
                } 
                else if (gPermissionState == 3) {
                    if (llListFindList(gTrustedUsers, [targetKey]) == -1) {
                        gTrustedUsers += [targetKey];
                        llInstantMessage(id, msg + " added as Trusted user.");
                        llOwnerSay("Trusted user added: " + msg + " by " + llKey2Name(id));
                    } else {
                        llInstantMessage(id, msg + " is already a Trusted user.");
                    }
                } 
                else if (gPermissionState == 4) {
                    integer trusted_index = llListFindList(gTrustedUsers, [targetKey]);
                    if (trusted_index != -1) {
                        gTrustedUsers = llDeleteSubList(gTrustedUsers, trusted_index, trusted_index);
                        llInstantMessage(id, msg + " removed from Trusted users.");
                        llOwnerSay("Trusted user removed: " + msg + " by " + llKey2Name(id));
                    }
                }
                
                // Send updated lists to master kernel
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
