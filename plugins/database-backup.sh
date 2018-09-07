#!/usr/bin/env bash


DatabaseBackup::Fetch()
{
    namespace database-backup
    ${DEBUG} && Log::AddOutput database-backup DEBUG
    Log "DatabaseBackup::Fetch"
    Log "You can implement DatabaseBackup::Fetch function in the $JETDOCKER_CUSTOM/pulgins/database-backup.sh file"
}