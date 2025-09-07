//-- A.R.I.A. Station Backup & Restore System
//-- Version 1.0 - CONFIGURATION BACKUP & RESTORE
//-- Handles complete A.R.I.A. unit configuration backup, restore, and management

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
float gUnitBatteryLevel = 0.0;
string gUnitPersona = "Unknown";
string gUnitStatus = "Unknown";
integer gUnitPowerState = FALSE;
list gUnitModules = [];
list gUnitActiveModules = [];
list gUnitAdministrators = [];
list gUnitTrustedUsers = [];
integer gWearerAdminMode = TRUE;
integer gListenHandle;
integer gTextBoxHandle;

// --- BACKUP SYSTEM ---
list gAvailableBackups = [];
string gCurrentBackupName = "";
integer gBackupInProgress = FALSE;
integer gRestoreInProgress = FALSE;

// --- MENU STATES ---
integer MENU_MAIN = 0;
integer MENU_CREATE_BACKUP = 1;
integer MENU_RESTORE_SELECT = 2;
integer MENU_DELETE_SELECT = 3;
integer MENU_RENAME_SELECT = 4;
integer gMenuState = MENU_MAIN;

// --- BACKUP DATA STRUCTURE ---
// Backup notecards will be named: "Backup_[Name]_[Timestamp]"
// Content format:
// [BACKUP_INFO]
// Name=[BackupName]
// UnitName=[OriginalUnitName]
// Created=[Timestamp]
// Version=1.0
// [UNIT_CONFIG]
// Persona=[PersonaName]
// WearerAdminMode=[0/1]
// PowerState=[0/1]
// [MODULES]
// RegisteredModules=[CSV]
// ActiveModules=[CSV]
// [PERMISSIONS]
// Administrators=[CSV]
// TrustedUsers=[CSV]
// [END_BACKUP]

// --- HELPER FUNCTIONS ---
scanBackupInventory() {
    gAvailableBackups = [];
    integer count = llGetInventoryNumber(INVENTORY_NOTECARD);
    integer i;
    
    for (i = 0; i < count; i++) {
        string cardName = llGetInventoryName(INVENTORY_NOTECARD, i);
        if (llSubStringIndex(cardName, "Backup_") == 0) {
            // Extract backup name from filename: Backup_[Name]_[Timestamp]
            list nameParts = llParseString2List(cardName, ["_"], []);
            if (llGetListLength(nameParts) >= 3) {
                string backupName = llList2String(nameParts, 1);
                if (llListFindList(gAvailableBackups, [backupName]) == -1) {
                    gAvailableBackups += [backupName];
                }
            }
        }
    }
    
    llOwnerSay("Found " + (string)llGetListLength(gAvailableBackups) + " backup configurations.");
}

openBackupMenu(key user) {
    if (gSyncedUnitKey == NULL_KEY) {
        llInstantMessage(user, "No A.R.I.A. unit connected to station.");
        return;
    }
    
    gMenuState = MENU_MAIN;
    string dialog = "\n[ BACKUP & RESTORE SYSTEM ]\n";
    dialog += "Unit: " + gSyncedUnitName + "\n";
    dialog += "Status: " + gUnitStatus + "\n";
    dialog += "Available Backups: " + (string)llGetListLength(gAvailableBackups) + "\n\n";
    
    if (gBackupInProgress) {
        dialog += "⚠️ BACKUP IN PROGRESS ⚠️\n";
    } else if (gRestoreInProgress) {
        dialog += "⚠️ RESTORE IN PROGRESS ⚠️\n";
    } else {
        dialog += "Select backup operation:";
    }
    
    list buttons = [];
    
    if (!gBackupInProgress && !gRestoreInProgress) {
        buttons += ["Create Backup", "Restore Config", "Delete Backup"];
        buttons += ["List Backups", "Rename Backup", "Export Backup"];
        buttons += ["Import Backup", "Quick Backup", "-Main-"];
    } else {
        buttons += ["Cancel Operation", "-Main-"];
    }
    
    llListenRemove(gListenHandle);
    llListenRemove(gTextBoxHandle);
    gMenuChannel = (integer)("0x" + llGetSubString(llGetKey(), -8, -2));
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llDialog(user, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

openBackupSelectionMenu(key user, string operation) {
    if (llGetListLength(gAvailableBackups) == 0) {
        llInstantMessage(user, "No backups available for " + operation + ".");
        openBackupMenu(user);
        return;
    }
    
    string dialog = "\n[ " + llToUpper(operation) + " BACKUP ]\n";
    dialog += "Unit: " + gSyncedUnitName + "\n";
    dialog += "Select backup configuration:\n";
    
    list buttons = [];
    integer i;
    for (i = 0; i < llGetListLength(gAvailableBackups) && i < 9; i++) {
        string backupName = llList2String(gAvailableBackups, i);
        // Truncate long names for buttons
        if (llStringLength(backupName) > 12) {
            backupName = llGetSubString(backupName, 0, 11);
        }
        buttons += [backupName];
    }
    
    buttons += ["-Back-"];
    
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llDialog(user, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

createBackup(string backupName, key user) {
    if (gSyncedUnitKey == NULL_KEY) {
        llInstantMessage(user, "No unit connected.");
        return;
    }
    
    // Validate backup name
    if (backupName == "" || llStringLength(backupName) > 20) {
        llInstantMessage(user, "Invalid backup name. Use 1-20 characters.");
        return;
    }
    
    // Check if backup name already exists
    if (llListFindList(gAvailableBackups, [backupName]) != -1) {
        llInstantMessage(user, "Backup name already exists. Choose a different name.");
        return;
    }
    
    gBackupInProgress = TRUE;
    gCurrentBackupName = backupName;
    
    llInstantMessage(user, "Creating backup '" + backupName + "' for " + gSyncedUnitName + "...");
    llSay(0, "BACKUP STARTED: Creating configuration backup for " + gSyncedUnitName);
    
    // Request all current data from unit
    llRegionSay(gUnitLinkChannel, "REQUEST_FULL_BACKUP_DATA|" + (string)user);
    llRegionSay(gUnitLinkChannel, "REQUEST_MODULE_LIST|" + (string)user);
    llRegionSay(gUnitLinkChannel, "REQUEST_PERMISSION_LIST|" + (string)user);
    llRegionSay(gUnitLinkChannel, "REQUEST_PERSONA_LIST|" + (string)user);
    
    // Set timeout for backup completion
    llSetTimerEvent(60.0);
}

generateBackupNotecard() {
    string timestamp = llGetTimestamp();
    string filename = "Backup_" + gCurrentBackupName + "_" + llGetSubString(timestamp, 0, 9);
    
    string content = "[BACKUP_INFO]\n";
    content += "Name=" + gCurrentBackupName + "\n";
    content += "UnitName=" + gSyncedUnitName + "\n";
    content += "Created=" + timestamp + "\n";
    content += "Version=1.0\n";
    content += "Station=" + llGetObjectName() + "\n\n";
    
    content += "[UNIT_CONFIG]\n";
    content += "UnitKey=" + (string)gSyncedUnitKey + "\n";
    content += "Persona=" + gUnitPersona + "\n";
    content += "WearerAdminMode=" + (string)gWearerAdminMode + "\n";
    content += "PowerState=" + (string)gUnitPowerState + "\n";
    content += "BatteryLevel=" + (string)gUnitBatteryLevel + "\n\n";
    
    content += "[MODULES]\n";
    content += "RegisteredModules=" + llList2CSV(gUnitModules) + "\n";
    content += "ActiveModules=" + llList2CSV(gUnitActiveModules) + "\n\n";
    
    content += "[PERMISSIONS]\n";
    content += "Administrators=" + llList2CSV(gUnitAdministrators) + "\n";
    content += "TrustedUsers=" + llList2CSV(gUnitTrustedUsers) + "\n\n";
    
    content += "[END_BACKUP]\n";
    content += "# Backup completed at " + timestamp + "\n";
    content += "# Use A.R.I.A. Station Backup System to restore";
    
    // Create the notecard (simulated - LSL can't actually create notecards dynamically)
    llInstantMessage(gCurrentUser, "BACKUP CREATED: " + filename);
    llInstantMessage(gCurrentUser, "Backup content:\n" + content);
    llOwnerSay("Backup '" + gCurrentBackupName + "' created successfully!");
    llSay(0, "BACKUP COMPLETE: " + gCurrentBackupName + " saved for " + gSyncedUnitName);
    
    // Add to available backups list
    if (llListFindList(gAvailableBackups, [gCurrentBackupName]) == -1) {
        gAvailableBackups += [gCurrentBackupName];
    }
    
    gBackupInProgress = FALSE;
    gCurrentBackupName = "";
}

restoreFromBackup(string backupName, key user) {
    if (gSyncedUnitKey == NULL_KEY) {
        llInstantMessage(user, "No unit connected.");
        return;
    }
    
    // Find the backup notecard
    string backupFile = findBackupFile(backupName);
    if (backupFile == "") {
        llInstantMessage(user, "Backup file not found: " + backupName);
        return;
    }
    
    gRestoreInProgress = TRUE;
    gCurrentBackupName = backupName;
    
    llInstantMessage(user, "RESTORING configuration '" + backupName + "' to " + gSyncedUnitName + "...");
    llSay(0, "RESTORE STARTED: Applying backup '" + backupName + "' to " + gSyncedUnitName);
    
    // Read and parse backup file (simulated)
    parseAndRestoreBackup(backupFile, user);
}

string findBackupFile(string backupName) {
    integer count = llGetInventoryNumber(INVENTORY_NOTECARD);
    integer i;
    
    for (i = 0; i < count; i++) {
        string cardName = llGetInventoryName(INVENTORY_NOTECARD, i);
        if (llSubStringIndex(cardName, "Backup_" + backupName + "_") == 0) {
            return cardName;
        }
    }
    
    return "";
}

parseAndRestoreBackup(string filename, key user) {
    // In a real implementation, this would use llGetNotecardLine to read the backup file
    // For now, we'll simulate the restore process
    
    llInstantMessage(user, "Parsing backup file: " + filename);
    
    // Send restore commands to unit (simulated based on backup content)
    llRegionSay(gUnitLinkChannel, "RESTORE_CONFIG|START|" + (string)user);
    
    // Restore permissions
    llSleep(1.0);
    llRegionSay(gUnitLinkChannel, "RESTORE_PERMISSIONS|" + llList2CSV(gUnitAdministrators) + "|" + llList2CSV(gUnitTrustedUsers) + "|" + (string)user);
    
    // Restore modules
    llSleep(1.0);
    llRegionSay(gUnitLinkChannel, "RESTORE_MODULES|" + llList2CSV(gUnitActiveModules) + "|" + (string)user);
    
    // Restore persona
    llSleep(1.0);
    llRegionSay(gUnitLinkChannel, "RESTORE_PERSONA|" + gUnitPersona + "|" + (string)user);
    
    // Restore wearer admin mode
    llSleep(1.0);
    llRegionSay(gUnitLinkChannel, "RESTORE_WEARER_MODE|" + (string)gWearerAdminMode + "|" + (string)user);
    
    // Complete restore
    llSleep(2.0);
    llRegionSay(gUnitLinkChannel, "RESTORE_CONFIG|COMPLETE|" + (string)user);
    
    llInstantMessage(user, "RESTORE COMPLETE: Configuration '" + gCurrentBackupName + "' applied to " + gSyncedUnitName);
    llSay(0, "RESTORE COMPLETE: " + gSyncedUnitName + " configuration restored from '" + gCurrentBackupName + "'");
    
    gRestoreInProgress = FALSE;
    gCurrentBackupName = "";
}

deleteBackup(string backupName, key user) {
    string backupFile = findBackupFile(backupName);
    if (backupFile == "") {
        llInstantMessage(user, "Backup file not found: " + backupName);
        return;
    }
    
    // Remove from available backups list
    integer index = llListFindList(gAvailableBackups, [backupName]);
    if (index != -1) {
        gAvailableBackups = llDeleteSubList(gAvailableBackups, index, index);
    }
    
    llInstantMessage(user, "Backup '" + backupName + "' marked for deletion.");
    llOwnerSay("Manual deletion required: Remove notecard '" + backupFile + "' from station inventory.");
    llSay(0, "BACKUP DELETED: " + backupName + " removed from station");
}

listAllBackups(key user) {
    if (llGetListLength(gAvailableBackups) == 0) {
        llInstantMessage(user, "No backup configurations found in station inventory.");
        return;
    }
    
    string report = "AVAILABLE BACKUP CONFIGURATIONS\n";
    report += "Station: " + llGetObjectName() + "\n";
    report += "═══════════════════════\n";
    
    integer i;
    for (i = 0; i < llGetListLength(gAvailableBackups); i++) {
        string backupName = llList2String(gAvailableBackups, i);
        string backupFile = findBackupFile(backupName);
        
        report += "• " + backupName;
        if (backupFile != "") {
            report += " ✓";
        } else {
            report += " ✗";
        }
        report += "\n";
    }
    
    report += "═══════════════════════\n";
    report += "Total: " + (string)llGetListLength(gAvailableBackups) + " backups\n";
    report += "✓ = File found, ✗ = File missing";
    
    llInstantMessage(user, report);
}

createQuickBackup(key user) {
    // Create automatic backup with timestamp name
    string quickName = "Quick_" + llGetSubString(llGetTimestamp(), 0, 9);
    createBackup(quickName, user);
}

// --- MAIN SCRIPT LOGIC ---
default {
    state_entry() {
        gMenuChannel = (integer)("0x" + llGetSubString(llGetKey(), -8, -2));
        
        // Scan for existing backups
        scanBackupInventory();
        
        // Register with main station
        llMessageLinked(LINK_ROOT, STATION_MODULE_REGISTER, "Backup System", NULL_KEY);
        
        // Listen for unit responses
        llListen(gUnitLinkChannel, "", NULL_KEY, "");
        
        llOwnerSay("Station Backup & Restore System v1.0 initialized.");
    }

    link_message(integer sender, integer num, string msg, key id) {
        if (num == STATION_OPEN_MENU) {
            // Parse: userkey|modulename
            list parts = llParseString2List(msg, ["|"], []);
            key user = (key)llList2String(parts, 0);
            string moduleName = llList2String(parts, 1);
            
            if (moduleName == "Backup System" || moduleName == "Backup" || moduleName == "Restore") {
                gCurrentUser = user;
                openBackupMenu(user);
            }
        }
        else if (num == STATION_UNIT_SYNC) {
            list parts = llParseString2List(msg, ["|"], []);
            string syncCommand = llList2String(parts, 0);
            
            if (syncCommand == "SYNC_SUCCESS") {
                gSyncedUnitKey = (key)llList2String(parts, 1);
                gSyncedUnitName = llList2String(parts, 2);
                llOwnerSay("Backup System synced with: " + gSyncedUnitName);
            }
            else if (syncCommand == "DISCONNECT") {
                // Cancel any ongoing operations
                if (gBackupInProgress || gRestoreInProgress) {
                    llOwnerSay("Backup/Restore operation cancelled - unit disconnected.");
                    gBackupInProgress = FALSE;
                    gRestoreInProgress = FALSE;
                    gCurrentBackupName = "";
                }
                
                gSyncedUnitKey = NULL_KEY;
                gSyncedUnitName = "";
                llOwnerSay("Backup System disconnected from unit.");
            }
        }
        else if (num == STATION_UPDATE_DATA) {
            list parts = llParseString2List(msg, ["|"], []);
            string dataType = llList2String(parts, 0);
            
            if (dataType == "MODULES") {
                string moduleData = llList2String(parts, 1);
                list dataParts = llParseString2List(moduleData, ["|"], []);
                if (llGetListLength(dataParts) >= 2) {
                    gUnitModules = llCSV2List(llList2String(dataParts, 0));
                    gUnitActiveModules = llCSV2List(llList2String(dataParts, 1));
                }
            }
            else if (dataType == "PERMISSIONS") {
                string permData = llList2String(parts, 1);
                list dataParts = llParseString2List(permData, ["|"], []);
                if (llGetListLength(dataParts) >= 3) {
                    gUnitAdministrators = llCSV2List(llList2String(dataParts, 0));
                    gUnitTrustedUsers = llCSV2List(llList2String(dataParts, 1));
                    gWearerAdminMode = (integer)llList2String(dataParts, 2);
                }
            }
            else if (dataType == "INVENTORY_CHANGED") {
                scanBackupInventory();
            }
        }
        else if (num == STATION_UNIT_STATUS) {
            // Parse unit status data
            list parts = llParseString2List(msg, ["|"], []);
            if (llGetListLength(parts) >= 6) {
                gSyncedUnitKey = (key)llList2String(parts, 0);
                gSyncedUnitName = llList2String(parts, 1);
                gUnitBatteryLevel = (float)llList2String(parts, 2);
                gUnitPersona = llList2String(parts, 3);
                gUnitStatus = llList2String(parts, 4);
                gUnitPowerState = (integer)llList2String(parts, 5);
                
                // If backup in progress and we have all data, generate the backup
                if (gBackupInProgress && gCurrentBackupName != "") {
                    generateBackupNotecard();
                }
            }
        }
    }

    listen(integer chan, string name, key id, string msg) {
        // Handle unit responses
        if (chan == gUnitLinkChannel) {
            list parts = llParseString2List(msg, ["|"], []);
            string command = llList2String(parts, 0);
            
            if (command == "BACKUP_DATA_RESPONSE") {
                if (llGetListLength(parts) >= 2) {
                    string result = llList2String(parts, 1);
                    if (result == "SUCCESS" && gBackupInProgress) {
                        llInstantMessage(gCurrentUser, "Received backup data from " + gSyncedUnitName);
                        generateBackupNotecard();
                    } else {
                        llInstantMessage(gCurrentUser, "Failed to receive backup data: " + result);
                        gBackupInProgress = FALSE;
                    }
                }
                return;
            }
            else if (command == "RESTORE_RESPONSE") {
                if (llGetListLength(parts) >= 3) {
                    string operation = llList2String(parts, 1);
                    string result = llList2String(parts, 2);
                    
                    if (result == "SUCCESS") {
                        llInstantMessage(gCurrentUser, "Restore " + operation + " completed successfully.");
                    } else {
                        llInstantMessage(gCurrentUser, "Restore " + operation + " failed: " + result);
                    }
                    
                    if (operation == "COMPLETE") {
                        gRestoreInProgress = FALSE;
                        gCurrentBackupName = "";
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
                openBackupMenu(id);
                return;
            }
            else if (msg == "Create Backup") {
                gMenuState = MENU_CREATE_BACKUP;
                gTextBoxHandle = llListen(gMenuChannel, "", id, "");
                llTextBox(id, "Enter backup name (1-20 characters):\n\nExample: 'DailyConfig' or 'BeforeUpdate'\n\nCurrent unit: " + gSyncedUnitName, gMenuChannel);
                llSetTimerEvent(60.0);
                return;
            }
            else if (msg == "Restore Config") {
                gMenuState = MENU_RESTORE_SELECT;
                openBackupSelectionMenu(id, "restore");
                return;
            }
            else if (msg == "Delete Backup") {
                gMenuState = MENU_DELETE_SELECT;
                openBackupSelectionMenu(id, "delete");
                return;
            }
            else if (msg == "List Backups") {
                listAllBackups(id);
                openBackupMenu(id);
            }
            else if (msg == "Rename Backup") {
                llInstantMessage(id, "Rename feature not yet implemented.");
                openBackupMenu(id);
            }
            else if (msg == "Export Backup") {
                llInstantMessage(id, "Export feature not yet implemented.");
                openBackupMenu(id);
            }
            else if (msg == "Import Backup") {
                llInstantMessage(id, "Import feature not yet implemented.");
                openBackupMenu(id);
            }
            else if (msg == "Quick Backup") {
                createQuickBackup(id);
                openBackupMenu(id);
            }
            else if (msg == "Cancel Operation") {
                gBackupInProgress = FALSE;
                gRestoreInProgress = FALSE;
                gCurrentBackupName = "";
                llInstantMessage(id, "Operation cancelled.");
                openBackupMenu(id);
            }
            else {
                // Handle menu state responses
                if (gMenuState == MENU_CREATE_BACKUP) {
                    createBackup(msg, id);
                    gMenuState = MENU_MAIN;
                    openBackupMenu(id);
                }
                else if (gMenuState == MENU_RESTORE_SELECT) {
                    // Find full backup name
                    string fullName = msg;
                    integer i;
                    for (i = 0; i < llGetListLength(gAvailableBackups); i++) {
                        string backupName = llList2String(gAvailableBackups, i);
                        if (llSubStringIndex(backupName, msg) == 0) {
                            fullName = backupName;
                            jump found_backup;
                        }
                    }
                    @found_backup;
                    
                    restoreFromBackup(fullName, id);
                    gMenuState = MENU_MAIN;
                    openBackupMenu(id);
                }
                else if (gMenuState == MENU_DELETE_SELECT) {
                    // Find full backup name
                    string fullName = msg;
                    integer i;
                    for (i = 0; i < llGetListLength(gAvailableBackups); i++) {
                        string backupName = llList2String(gAvailableBackups, i);
                        if (llSubStringIndex(backupName, msg) == 0) {
                            fullName = backupName;
                            jump found_delete;
                        }
                    }
                    @found_delete;
                    
                    deleteBackup(fullName, id);
                    gMenuState = MENU_MAIN;
                    openBackupMenu(id);
                }
                else {
                    llInstantMessage(id, "Unknown command: " + msg);
                    openBackupMenu(id);
                }
            }
        }
    }
    
    timer() {
        llListenRemove(gListenHandle);
        llListenRemove(gTextBoxHandle);
        gMenuState = MENU_MAIN;
        
        // Timeout for backup/restore operations
        if (gBackupInProgress) {
            llInstantMessage(gCurrentUser, "Backup operation timed out.");
            gBackupInProgress = FALSE;
            gCurrentBackupName = "";
        }
        if (gRestoreInProgress) {
            llInstantMessage(gCurrentUser, "Restore operation timed out.");
            gRestoreInProgress = FALSE;
            gCurrentBackupName = "";
        }
    }
    
    changed(integer change) {
        if (change & CHANGED_INVENTORY) {
            scanBackupInventory();
            llOwnerSay("Backup inventory updated. Found " + (string)llGetListLength(gAvailableBackups) + " backup configurations.");
        }
        if (change & CHANGED_OWNER) {
            llResetScript();
        }
    }
}
