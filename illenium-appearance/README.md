ILLENIUM APPEARANCE — QBOX REWRITE
v5.7.0-qbx-clean | March 2026

OVERVIEW
This release is a full logic rewrite of illenium-appearance for Qbox (qbx_core).
The UI is unchanged, but nearly all game logic has been rewritten using modern
Qbox patterns and Community Ox best practices.

Framework: Qbox (qbx_core)
Base Version: illenium-appearance v5.7.0
UI: Unchanged
Database: Fully backward compatible

----------------------------------

MAJOR BUG FIXES

Save / Load
• appearance_save now reads the actual ped appearance instead of NUI state
• Replaced delete+insert save with atomic upsert
• Fixed stale saves loading on relog
• Charge + save now handled in one atomic server event
• Eye color -1 bug clamped to valid range

Clothing Application
• Fixed collection="" crash with collection natives
• Fixed props reverting after model change
• Prevented component 2 (hair) double-application
• Corrected tattoo / hair apply order

Framework & Events
• Fixed incorrect playerLoaded event
• Replaced QBCore.Functions calls with qbx_core exports
• Added outfit ownership verification
• Fixed cache leaks on player disconnect
• Fixed multiple event name typos
• Fixed qb-multicharacter switching issues

----------------------------------

IMPROVEMENTS

DLC Clothing Stability
Clothing now saves:
• collection name
• collection-local index
• global index fallback

Result:
Adding DLC packs will NOT break saved outfits.

Old saves automatically migrate when players visit the clothing shop.

----------------------------------

PERFORMANCE

• Removed unnecessary NUI Wait(250)
• Shop interaction no longer waits on server money check
• Client outfit cache added
• Polling thread replaced with event-driven keybinds

----------------------------------

COMMUNITY OX INTEGRATION

The resource now uses Community Ox wherever possible:

• lib.zones
• lib.addKeybind
• lib.showTextUI / hideTextUI
• lib.notify
• lib.inputDialog
• lib.registerContext / showContext
• lib.callback.register
• lib.addCommand
• oxmysql
• ox_target (optional)
• ox_lib radial (optional)

----------------------------------

SERVER SECURITY

• All server events validate source
• citizenID derived server-side only
• Outfit ownership validated
• chargeAndSave prevents free clothing exploit
• Appearance model validated before DB write

----------------------------------

UNCHANGED FROM UPSTREAM

The following remain identical to upstream v5.7.0:

• web UI
• game constants
• customization cameras
• shared configs
• locales
• SQL tables
• database query functions
• ESX / Ox adapters

----------------------------------

INSTALLATION

1. Drop the resource into your resources folder
2. Rename to "illenium-appearance" if needed
3. Restart the resource
4. No SQL required

----------------------------------

TEST CHECKLIST

• Relog loads correct clothes
• /reloadskin restores appearance
• Clothing shop saves and loads correctly
• Outfit save / update / delete works
• Props save correctly (hats etc)
• Death / respawn keeps clothes
• Players see correct clothes on each other
• DLC clothing additions do not break saves

----------------------------------

illenium-appearance-qbx-clean
Qbox Production Release
March 2026
