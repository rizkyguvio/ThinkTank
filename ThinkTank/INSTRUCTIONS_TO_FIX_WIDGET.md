# How to Fix the Widget (App Group Setup)

The widget is currently failing to load data because it cannot access the shared database. This happens because the **App Group entitlement** is missing from the Xcode project configuration.

### Steps to Fix:

1.  Open the project in Xcode.
2.  Select the **ThinkTank** project in the Project Navigator (blue icon at the top left).
3.  Select the **ThinkTank** target (under "Targets").
4.  Go to the **Signing & Capabilities** tab.
5.  Click **+ Capability** (top left of the tab).
6.  Search for **App Groups** and double-click to add it.
7.  In the *App Groups* section, click the **+** button.
8.  Enter exactly: `group.personal.ThinkTank.Gio`
9.  Check the box next to `group.personal.ThinkTank.Gio`.

### IMPORTANT: Repeat for the Widget Extension

1.  Select the **ThinkTankWidgets** target (under "Targets").
2.  Go to the **Signing & Capabilities** tab.
3.  Click **+ Capability**.
4.  Search for **App Groups** and add it.
5.  Check the box next to `group.personal.ThinkTank.Gio` (it should already appear in the list).

Once both targets have the App Group enabled and checked, build and run the app again. The widget will now work!
