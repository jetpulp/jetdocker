#!/usr/bin/env bash

namespace database-backup
${DEBUG} && Log::AddOutput database-backup DEBUG

DatabaseBackup::Fetch()
{
    Log "DatabaseBackup::Fetch"
    Log "You can implement DatabaseBackup::Fetch function in the $JETDOCKER_CUSTOM/pulgins/database-backup.sh file"
}