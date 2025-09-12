//-- A.R.I.A. Permissions Module (Add-on)
//-- Version 2.0 - SIMPLIFIED ACCESS CONTROL
//-- September 11, 2025 - Complete rewrite with simplified permission hierarchy
//-- CHANGES v2.0: Simplified to Primary Admin > Admin > Trusted > Wearer hierarchy,
//                  removed complex wearer admin mode, cleaner access control

// --- LINKED MESSAGE CODES ---
integer UPDATE_CONFIG = 102;
integer MODULE_REGISTER = 200;
integer OPEN_MY_MENU = 201;
integer UPDATE_USER_LISTS = 105;

// --- STATE VARIABLES ---
integer gMenuChannel;
integer gListenHandle;
key gCurrentUser;
key gPrimaryAdmin;
key wearer;

// --- SIMPLIFIED USER MANAGEMENT ---
list gAdministrators;       // Regular Admins
list gTrustedUsers;         // Trusted Users
integer gWearerAccess = TRUE; // TRUE = wearer has access, FALSE = wearer blocked

// --- MENU & SENSOR VARIABLES ---
integer gPermissionState = 0;
list gScanResults_Keys;
list gScanResults_Names;
integer gScanResults_Page;

// --- PERMISSION STATES ---
// 0 = none, 1 = add admin, 2 = remove admin, 3 = add trusted, 4 = remove trusted

// --- ACCESS LEVELS (must match master kernel) ---
integer ACCESS_PRIMARY_ADMIN = 5;
integer ACCESS_ADMIN = 4;
integer ACCESS_TRUSTED = 3;
integer ACCESS_WEARER = 2;
integer ACCESS_DENIED = 1;

// --- SIMPLIFIED ACCESS CONTROL ---
integer getAccessLevel(key id) {
    if (id == gPrimaryAdmin) return ACCESS_PRIMARY_ADMIN;
    if (llListFindList(gAdministrators, [id]) != -1) return ACCESS_ADMIN;
    if (llListFindList(gTrustedUsers, [id]) != -1) return ACCESS_TRUSTED;
    if (id == wearer && gWearerAccess) return ACCESS_WEARER;
    return ACCESS_DENIED;
}

// Check if someone can access this permissions module
integer canAccessPermissions(key id) {
    integer access = getAccessLevel(id);
    // Only Primary Admin, Admins, and Wearer can access permissions
    return (access >= ACCESS_ADMIN || (id == wearer && gWearerAccess));
}

// --- HELPER FUNCTIONS ---
open_menu(key id, string str, list btns) {
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", id, "");
    llDialog(id, str, btns, gMenuChannel);
    llSetTimerEvent(30.0);
}

// Build main permissions menu
buildMainMenu(key user) {
    integer userAccess = getAccessLevel(user);
    string accessTitle = "UNKNOWN";
    
    if (userAccess == ACCESS_PRIMARY_ADMIN) accessTitle = "PRIMARY ADMIN";
    else if (userAccess == ACCESS_ADMIN) accessTitle = "ADMINISTRATOR";
    else if (userAccess == ACCESS_WEARER) accessTitle = "WEARER";
    
    string wearerStatus = "ENABLED";
    if (!gWearerAccess) wearerStatus = "DISABLED";
    
    string dialog = "\n[ PERMISSIONS MANAGEMENT ]\n";
    dialog += "Your Access: " + accessTitle + "\n\n";
    dialog += "Primary Admin: " + llKey2Name(gPrimaryAdmin) + "\n";
    dialog += "Administrators: " + (string)llGetListLength(gAdministrators) + "\n";
    dialog += "Trusted Users: " + (string)llGetListLength(gTrustedUsers) + "\n";
    dialog += "Wearer Access: " + wearerStatus + "\n\n";
    
    list buttons = [];
    
    // Primary Admin gets all options
    if (userAccess == ACCESS_PRIMARY_ADMIN) {
        buttons = ["Add Admin", "Rem Admin", "Add Trusted", "Rem Trusted", "Block Wearer", "List Users"];
        if (!gWearerAccess) {
            buttons = llListReplaceList(buttons, ["Allow Wearer"], 4, 4);
        }
    }
    // Regular Admins can manage trusted users and wearer access
    else if (userAccess == ACCESS_ADMIN) {
        buttons = ["Add Trusted", "Rem Trusted", "Block Wearer", "List Users"];
        if (!gWearerAccess) {
            buttons = llListReplaceList(buttons, ["Allow Wearer"], 2, 2);
        }
    }
    // Wearer can only view their status
    else if (userAccess == ACCESS_WEARER) {
        buttons = ["List Users", "Status"];
    }
    
    buttons += ["-Main-"];
    
    open_menu(user, dialog, buttons);
}

// Build avatar scan menu for adding users
buildScanMenu(key user, integer page) {
    gScanResults_Page = page;
    
    list buttons = [];
    integer start = page * 9;
    integer end = start + 8;
    integer maxResults = llGetListLength(gScanResults_Names);
    integer i = start;
    
    while (i <= end && i < maxResults) {
        string name = llList2String(gScanResults_Names, i);
        // Truncate long names for button display
        if (llStringLength(name) > 12) {
            name = llGetSubString(name, 0, 11);
        }
        buttons += [name];
        i++;
    }
    
    if (start > 0) buttons += ["<-- Back"];
    if (end < maxResults - 1) buttons += ["Next -->"];
    buttons += ["-Cancel-"];
    
    string title = "ADD ADMINISTRATOR";
    if (gPermissionState == 3) title = "ADD TRUSTED USER";
    
    open_menu(user, "\n[ " + title + " ]\nSelect an avatar to add:", buttons);
}

// Build removal menu for existing users
buildRemoveMenu(key user, integer page) {
    gScanResults_Page = page;
    
    list sourceList = [];
    string title = "";
    
    if (gPermissionState == 2) {
        sourceList = gAdministrators;
        title = "REMOVE ADMINISTRATOR";
    } else if (gPermissionState == 4) {
        sourceList = gTrustedUsers;
        title = "REMOVE TRUSTED USER";
    }
    
    gScanResults_Keys = sourceList;
    gScanResults_Names = [];
    
    integer maxUsers = llGetListLength(sourceList);
    integer i = 0;
    while (i < maxUsers) {
        key userKey = (key)llList2String(sourceList, i);
        string userName = llKey2Name(userKey);
        if (userName == "") userName = "Unknown User";
        
        // Truncate long names for button display
        if (llStringLength(userName) > 12) {
            userName = llGetSubString(userName, 0, 11);
        }
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
    
    if (maxUsers == 0) {
        llInstantMessage(user, "No users to remove from this category.");
        gPermissionState = 0;
        buildMainMenu(user);
        return;
    }
    
    open_menu(user, "\n[ " + title + " ]\nSelect a user to remove:", buttons);
}

// Show user lists
showUserLists(key user) {
    string message = "\n[ USER ACCESS LISTS ]\n\n";
    
    message += "PRIMARY ADMIN:\n";
    string primaryName = llKey2Name(gPrimaryAdmin);
    if (primaryName == "") primaryName = "Unknown User";
    message += "• " + primaryName + "\n\n";
    
    message += "ADMINISTRATORS (" + (string)llGetListLength(gAdministrators) + "):\n";
    if (llGetListLength(gAdministrators) == 0) {
        message += "• None\n";
    } else {
        integer i;
        for (i = 0; i < llGetListLength(gAdministrators) && i < 5; i++) {
            key adminKey = (key)llList2String(gAdministrators, i);
            string adminName = llKey2Name(adminKey);
            if (adminName == "") adminName = "Unknown User";
            message += "• " + adminName + "\n";
        }
        if (llGetListLength(gAdministrators) > 5) {
            message += "• ... and " + (string)(llGetListLength(gAdministrators) - 5) + " more\n";
        }
    }
    
    message += "\nTRUSTED USERS (" + (string)llGetListLength(gTrustedUsers) + "):\n";
    if (llGetListLength(gTrustedUsers) == 0) {
        message += "• None\n";
    } else {
        integer i;
        for (i = 0; i < llGetListLength(gTrustedUsers) && i < 5; i++) {
            key trustedKey = (key)llList2String(gTrustedUsers, i);
            string trustedName = llKey2Name(trustedKey);
            if (trustedName == "") trustedName = "Unknown User";
            message += "• " + trustedName + "\n";
        }
        if (llGetListLength(gTrustedUsers) > 5) {
            message += "• ... and " + (string)(llGetListLength(gTrustedUsers) - 5) + " more\n";
        }
    }
    
    message += "\nWEARER ACCESS: ";
    if (gWearerAccess) {
        message += "ENABLED\n";
        string wearerName = llKey2Name(wearer);
        if (wearerName == "") wearerName = "Unknown User";
        message += "• " + wearerName;
    } else {
        message += "DISABLED";
    }
    
    llInstantMessage(user, message);
}

// Update user lists and broadcast to main kernel
updateUserLists() {
    string admin_csv = llList2CSV(gAdministrators);
    string trusted_csv = llList2CSV(gTrustedUsers);
    string update_string = admin_csv + "|" + trusted_csv + "|" + (string)gWearerAccess;
    llMessageLinked(LINK_ROOT, UPDATE_USER_LISTS, update_string, NULL_KEY);
}

// --- MAIN SCRIPT LOGIC ---
default {
    state_entry() {
        wearer = llGetOwner();
        gPrimaryAdmin = llGetOwner();
        
        // Initialize with Primary Admin in admin list
        gAdministrators = [gPrimaryAdmin];
        gWearerAccess = TRUE;
        
        gMenuChannel = (integer)("0x" + llGetSubString(llGetKey(), -7, -1));
        llMessageLinked(LINK_ROOT, MODULE_REGISTER, "Permissions", NULL_KEY);
        
        llOwnerSay("Simplified Permissions Module v2.0 initialized.");
        llOwnerSay("Access Hierarchy: Primary Admin > Admin > Trusted > Wearer");
        
        updateUserLists();
    }

    link_message(integer sender, integer num, string msg, key id) {
        if (num == OPEN_MY_MENU) {
            key user = (key)msg;
            if (canAccessPermissions(user)) {
                gCurrentUser = user;
                gPermissionState = 0;
                buildMainMenu(user);
            } else {
                llInstantMessage(user, "Access denied. Permissions module restricted to Primary Admin, Administrators, and Wearer only.");
            }
        } 
        else if (num == UPDATE_CONFIG) {
            list parts = llParseString2List(msg, ["|"], []);
            if (llGetListLength(parts) >= 3) {
                string admin_csv = llList2String(parts, 0);
                string trusted_csv = llList2String(parts, 1);
                gWearerAccess = (integer)llList2String(parts, 2);
                
                if (admin_csv != "") gAdministrators = llCSV2List(admin_csv);
                if (trusted_csv != "") gTrustedUsers = llCSV2List(trusted_csv);
                
                // Ensure Primary Admin is always in admin list
                if (llListFindList(gAdministrators, [gPrimaryAdmin]) == -1) {
                    gAdministrators = [gPrimaryAdmin] + gAdministrators;
                }
            }
        }
    }

    sensor(integer num_detected) {
        gScanResults_Keys = [];
        gScanResults_Names = [];
        
        integer i = 0;
        while (i < num_detected) {
            key detectedKey = llDetectedKey(i);
            string detectedName = llDetectedName(i);
            
            // Don't add the wearer or primary admin to scan results
            if (detectedKey != wearer && detectedKey != gPrimaryAdmin) {
                // For admin addition, don't show existing admins
                if (gPermissionState == 1 && llListFindList(gAdministrators, [detectedKey]) != -1) {
                    // Skip existing admin
                } 
                // For trusted addition, don't show existing trusted or admins
                else if (gPermissionState == 3 && 
                         (llListFindList(gTrustedUsers, [detectedKey]) != -1 || 
                          llListFindList(gAdministrators, [detectedKey]) != -1)) {
                    // Skip existing trusted or admin
                } 
                else {
                    gScanResults_Keys += [detectedKey];
                    gScanResults_Names += [detectedName];
                }
            }
            i++;
        }
        
        if (llGetListLength(gScanResults_Keys) > 0) {
            buildScanMenu(gCurrentUser, 0);
        } else {
            llInstantMessage(gCurrentUser, "No eligible avatars found in range.");
            gPermissionState = 0;
            buildMainMenu(gCurrentUser);
        }
    }
    
    no_sensor() {
        llInstantMessage(gCurrentUser, "No avatars found in range.");
        gPermissionState = 0;
        buildMainMenu(gCurrentUser);
    }

    listen(integer chan, string name, key id, string msg) {
        if (chan != gMenuChannel) return;
        
        gCurrentUser = id;
        llListenRemove(gListenHandle);
        
        // Check access level for current user
        integer userAccess = getAccessLevel(id);
        
        if (msg == "Add Admin" && userAccess >= ACCESS_PRIMARY_ADMIN) { 
            gPermissionState = 1;
            llSensor("", NULL_KEY, AGENT, 20.0, PI);
        }
        else if (msg == "Rem Admin" && userAccess >= ACCESS_PRIMARY_ADMIN) { 
            if (llGetListLength(gAdministrators) <= 1) {
                llInstantMessage(id, "Cannot remove administrators. Primary Admin must remain, and at least one other admin is recommended.");
                buildMainMenu(id);
                return;
            }
            gPermissionState = 2;
            buildRemoveMenu(id, 0);
        }
        else if (msg == "Add Trusted" && userAccess >= ACCESS_ADMIN) { 
            gPermissionState = 3;
            llSensor("", NULL_KEY, AGENT, 20.0, PI);
        }
        else if (msg == "Rem Trusted" && userAccess >= ACCESS_ADMIN) { 
            gPermissionState = 4;
            buildRemoveMenu(id, 0);
        }
        else if ((msg == "Block Wearer" || msg == "Allow Wearer") && userAccess >= ACCESS_ADMIN) {
            gWearerAccess = !gWearerAccess;
            
            string status = "BLOCKED";
            if (gWearerAccess) status = "ALLOWED";
            
            llInstantMessage(id, "Wearer access is now: " + status);
            if (gWearerAccess) {
                llInstantMessage(wearer, "// Access restored by administrator. //");
            } else {
                llInstantMessage(wearer, "// Access has been restricted by administrator. //");
            }
            
            updateUserLists();
            buildMainMenu(id);
        }
        else if (msg == "List Users") {
            showUserLists(id);
            buildMainMenu(id);
        }
        else if (msg == "Status" && userAccess >= ACCESS_WEARER) {
            string statusMsg = "Your current access level: ";
            if (userAccess == ACCESS_PRIMARY_ADMIN) statusMsg += "PRIMARY ADMIN (Full Control)";
            else if (userAccess == ACCESS_ADMIN) statusMsg += "ADMINISTRATOR (Full Access)";
            else if (userAccess == ACCESS_TRUSTED) statusMsg += "TRUSTED USER (Limited Access)";
            else if (userAccess == ACCESS_WEARER) statusMsg += "WEARER (Basic Access)";
            else statusMsg += "ACCESS DENIED";
            
            llInstantMessage(id, statusMsg);
            buildMainMenu(id);
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
            buildMainMenu(id);
        }
        else {
            // Handle user selection
            integer index = llListFindList(gScanResults_Names, [msg]);
            if (index != -1) {
                key targetKey = (key)llList2String(gScanResults_Keys, index);
                string targetName = llList2String(gScanResults_Names, index);
                
                if (gPermissionState == 1) {
                    // Add Administrator
                    if (llListFindList(gAdministrators, [targetKey]) == -1) {
                        gAdministrators += [targetKey];
                        llInstantMessage(id, targetName + " added as Administrator.");
                        llInstantMessage(targetKey, "You have been granted Administrator access to " + llGetObjectName() + " by " + llKey2Name(id) + ".");
                    }
                } 
                else if (gPermissionState == 2) {
                    // Remove Administrator
                    if (targetKey != gPrimaryAdmin) {
                        integer admin_index = llListFindList(gAdministrators, [targetKey]);
                        if (admin_index != -1) {
                            gAdministrators = llDeleteSubList(gAdministrators, admin_index, admin_index);
                            llInstantMessage(id, targetName + " removed from Administrators.");
                            llInstantMessage(targetKey, "Your Administrator access to " + llGetObjectName() + " has been revoked by " + llKey2Name(id) + ".");
                        }
                    } else {
                        llInstantMessage(id, "Cannot remove Primary Administrator.");
                    }
                } 
                else if (gPermissionState == 3) {
                    // Add Trusted User
                    if (llListFindList(gTrustedUsers, [targetKey]) == -1) {
                        gTrustedUsers += [targetKey];
                        llInstantMessage(id, targetName + " added as Trusted User.");
                        llInstantMessage(targetKey, "You have been granted Trusted User access to " + llGetObjectName() + " by " + llKey2Name(id) + ".");
                    }
                } 
                else if (gPermissionState == 4) {
                    // Remove Trusted User
                    integer trusted_index = llListFindList(gTrustedUsers, [targetKey]);
                    if (trusted_index != -1) {
                        gTrustedUsers = llDeleteSubList(gTrustedUsers, trusted_index, trusted_index);
                        llInstantMessage(id, targetName + " removed from Trusted Users.");
                        llInstantMessage(targetKey, "Your Trusted User access to " + llGetObjectName() + " has been revoked by " + llKey2Name(id) + ".");
                    }
                }
                
                updateUserLists();
                gPermissionState = 0;
                buildMainMenu(id);
            }
        }
    }
    
    timer() {
        llListenRemove(gListenHandle);
        gPermissionState = 0;
        llOwnerSay("Permissions menu timed out.");
    }
    
    changed(integer change) {
        if (change & CHANGED_OWNER) {
            llResetScript();
        }
    }
}
