# Peaka ODBC Driver — Setup Guide

## System Requirements

- **Operating system:** Windows 10 or Windows 11, 64-bit
- **Disk space:** ~75 MB
- **Privileges:** Administrator rights required for driver registration and System DSN creation
- **Visual C++ Redistributable:** The Visual C++ Redistributable for Visual Studio 2022 (x64) must be installed before using the driver. If it is not already on your machine, download it from:
  `https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist`

---

## Installation Options

Peaka ODBC Driver can be installed in two ways:

- **Setup installer** (`PeakaODBC_Setup_2.3.9.1001.exe`) — guided wizard, recommended for most users
- **ZIP / manual** (`peaka_odbc.zip`) — extract and run `install.bat`, recommended for advanced users or scripted deployments

Both methods install the same driver and produce the same result.

---

## Option 1 — Setup Installer

### 1. Run the installer

Right-click `PeakaODBC_Setup_2.3.9.1001.exe` → **Run as administrator**.

If Windows SmartScreen shows a warning, click **More info** → **Run anyway**.
This warning appears because the installer is not digitally signed.

### 2. Follow the wizard

The wizard copies all files to `C:\Program Files\Peaka\ODBC\` and registers both the 64-bit and 32-bit drivers automatically. No manual steps required.

### 3. Power BI connector (optional)

On the "Select Additional Tasks" page, check **"Install Power BI Desktop connector"** if you plan to use Peaka with Power BI Desktop. The connector file will be placed in the correct folder automatically.

### 4. Create a DSN (optional, at the end of installation)

On the final page, leave **"Create a DSN (connection) now"** checked and click **Finish**.
A UAC prompt will appear — confirm it. The DSN installer will then open.

If you skip this step, you can create a DSN at any time by running:
```
C:\Program Files\Peaka\ODBC\tools\install-dsn.bat
```
Right-click → **Run as administrator**.

### Uninstalling

Open **Control Panel → Programs → Uninstall a program**, find **Peaka ODBC Driver** and uninstall.
During uninstall, you will be asked whether to also remove existing Peaka DSNs. The Power BI connector file is removed automatically if it exists.

---

## Option 2 — ZIP / Manual Installation

### 1. Extract the ZIP

Extract `peaka_odbc.zip` to any permanent location (e.g. `C:\Peaka\ODBC\`).
Do not run directly from a temporary or Downloads folder.

### 2. Right-click `install.bat` → Run as administrator

```
peaka_odbc\
└── install.bat   ← right-click this
```

### 3. Choose an action from the menu

```
[1] Full setup       (Driver + DSN)      ← recommended for first-time setup
[2] Driver only      (register DLL, once per machine)
[3] DSN only         (add a connection, can be repeated)
[4] Uninstall        (remove a DSN or driver)
[5] List installed   (show all Peaka DSNs and drivers)
[0] Exit
```

Press **Enter** to accept the default (Full setup).

### 4. Driver installation

- Select architecture: **64-bit** (default) or **32-bit**.
  Choose 32-bit only if your application is a 32-bit process.
- If the driver is already registered, you will be asked whether to reinstall.

### 5. DSN creation

- **Scope** — System-wide (all users, recommended) or Current user only.
  System DSNs are visible to all Windows users and services. User DSNs are visible only to the current Windows user account and may not be detected by applications that run as a different user.
- **DSN Name** — The name that appears in ODBC Administrator. Default: `Peaka`.
  Use distinct names (e.g. `Peaka_US`, `Peaka_EU`) to run multiple environments on the same machine.
- **Zone** — US (default) or EU.
- **Host / Port** — Defaults are pre-filled; press Enter to accept.
  - US: `dbc.peaka.studio`, port `4567`
  - EU: `dbc.eu.peaka.studio`, port `4567`

### 6. Done

Close and reopen ODBC Administrator (`odbcad32.exe`) for the new DSN to appear.

---

## Why Administrator Rights Matter

### Running WITH administrator rights (recommended)

- The driver DLL is registered directly in the Windows registry — no extra steps.
- You can create either a **System DSN** (visible to all users and services) or a **User DSN** (visible only to the current Windows user).
- Everything is applied immediately.

### Running WITHOUT administrator rights (manual installation only)

The installer detects the missing rights and adjusts behavior:

**Driver installation:**
The driver cannot be written to `HKEY_LOCAL_MACHINE`, which requires admin.
Instead, the installer generates a file called `peaka-driver.reg` next to `install.bat`.
You must apply it manually:
1. Locate `peaka-driver.reg` in the `peaka_odbc` folder.
2. Right-click it → **Merge**.
3. Confirm the UAC prompt with an administrator account.

Until the `.reg` file is merged, the driver is not registered and no DSN will work.

**DSN creation:**
Without admin rights the installer can only create a **User DSN** (written to `HKEY_CURRENT_USER`).
A User DSN works for interactive applications but is not visible to Windows services or other user accounts.

---

## Running Individual Tools

The helper scripts are in the `tools\` subfolder and can be run directly:

| Script | Purpose |
|---|---|
| `tools\install-driver.bat` | Register the driver DLL |
| `tools\install-dsn.bat` | Create a named DSN (repeatable) |
| `tools\uninstall.bat` | Remove a DSN or driver registration |
| `tools\list-dsn.bat` | List all installed Peaka DSNs and drivers |

Right-click each one and select **Run as administrator** when prompted.

---

## ODBC Administrator — 32-bit vs 64-bit

Windows has two separate ODBC Administrators. Make sure you open the correct one:

| | Path |
|---|---|
| **64-bit** (shows 64-bit drivers and DSNs) | `C:\Windows\System32\odbcad32.exe` |
| **32-bit** (shows 32-bit drivers and DSNs) | `C:\Windows\SysWOW64\odbcad32.exe` |

The shortcut in Control Panel and the Start menu typically opens the 32-bit version.
If you installed a 64-bit driver or DSN and don't see it, open the 64-bit ODBC Administrator directly.

---

## Creating a DSN via ODBC Administrator

In addition to using `tools\install-dsn.bat`, you can create or edit a DSN directly through the ODBC Administrator. This gives you access to all configuration options including SSL, proxy, and advanced settings.

### 1. Open the correct ODBC Administrator

For a 64-bit DSN (recommended for most applications):
```
C:\Windows\System32\odbcad32.exe
```
For a 32-bit DSN (only if your application is a 32-bit process):
```
C:\Windows\SysWOW64\odbcad32.exe
```

### 2. Add a new DSN

1. In ODBC Administrator, click the **System DSN** tab (visible to all users) or **User DSN** tab (current user only). System DSN is recommended.
2. Click **Add**.
3. In the driver list, select **Peaka ODBC Driver** and click **Finish**. The DSN Setup dialog opens.

### 3. Configure the DSN Setup dialog

**Data source name** — Enter a name for this connection, for example `Peaka` or `Peaka_US`. This is the name your applications and Power BI will reference.

**Description** — Optional free-text description, for example `Peaka DSN`.

**Authentication:**

| Field | Value |
|---|---|
| Authentication Type | **JWT Authentication** |
| User | Leave blank |
| Access Token | Your **Peaka Project API Key** (from Project Settings → API Keys in the Peaka console) |

**Data Source:**

| Field | Value |
|---|---|
| Host | `dbc.peaka.studio` (US) or `dbc.eu.peaka.studio` (EU) |
| Port | `4567` |
| Catalog | Optional. Enter a specific catalog to connect to, or leave blank to browse all catalogs. |
| Schema | Optional. Enter a default schema, or leave blank. |
| Time Zone ID | Optional. Leave blank to use the system time zone. Use tz database format if needed (e.g. `Europe/Istanbul`). |

### 4. Enable Remove Type Name Parameters (required for Power BI DirectQuery)

Click **Advanced Options**. In the dialog that opens, check **Remove Type Name Parameters**, then click **OK**.

This setting is recommended for any DSN you intend to use with Power BI in DirectQuery mode. Without it, Power BI may send extra type parameters that Trino cannot handle, which can cause query failures.

### 5. Test and save

Click **Test** to verify the connection. A success message confirms the host, port, and credentials are all correct. Click **OK** to close the Test result, then click **OK** in the DSN Setup dialog to save.

---

## Using the Power BI Desktop Connector

The `peaka.mez` file is a custom Power Query connector that lets Power BI Desktop connect directly to Peaka using the ODBC driver and a DSN you have already configured. It supports **DirectQuery** mode, so Power BI always queries live data.

### Prerequisites

- Peaka ODBC Driver installed (see above).
- At least one DSN created (via the setup wizard or `tools\install-dsn.bat`).
- Power BI Desktop installed.

---

### Step 1 — Place the connector file

**If you used the Setup installer:** check "Install Power BI Desktop connector" during the wizard. The file is placed automatically.

**If you used the ZIP / manual method:** copy `custom\powerbi\peaka.mez` to:
```
%USERPROFILE%\Documents\Power BI Desktop\Custom Connectors\
```
Create the `Custom Connectors` folder if it does not exist.

Power BI Desktop automatically loads any `.mez` files found in that folder at startup.

---

### Step 2 — Enable "Remove Type Name Parameters" on the DSN

This setting is recommended for any DSN you use with Power BI in DirectQuery mode. Without it, Power BI may pass extra type-name parameters that Trino cannot handle, which can cause query failures.

1. Open the ODBC Administrator that matches your DSN bitness:
   - 64-bit DSN: `C:\Windows\System32\odbcad32.exe`
   - 32-bit DSN: `C:\Windows\SysWOW64\odbcad32.exe`
2. On the **System DSN** or **User DSN** tab, select your Peaka DSN and click **Configure**.
3. In the DSN Setup dialog, click **Advanced Options**.
4. Check **Remove Type Name Parameters**.
5. Click **OK** twice to save.

> **If you created the DSN via ODBC Administrator** and already checked this option during setup (Step 4 of the section above), you can skip this step.

---

### Step 3 — Enable custom connectors in Power BI Desktop

Power BI blocks third-party connectors by default. You need to lower this restriction once:

1. Open Power BI Desktop.
2. Go to **File → Options and settings → Options**.
3. In the Options dialog, click **Security**.
4. In the **Data Extensions** area, select **Allow Any Extension To Load Without Validation Or Warning**.
5. Click **OK** and **restart Power BI Desktop**.

> **Note:** Only enable this setting if you trust all the `.mez` files in your Custom Connectors folder. Custom connectors have access to your credentials and network.

---

### Step 4 — Connect to Peaka

1. In Power BI Desktop, click **Home → Get Data → More…**
2. In the **Get Data** dialog, click **Database**.
3. Select **Peaka** from the list and click **Connect**.

---

### Step 5 — Enter connection details

A dialog will appear with the following fields:

| Field | Description |
|---|---|
| **DSN** | The DSN name you created (e.g. `Peaka`). Required. |
| **Catalog** | The catalog / database name to open. Optional — leave blank to browse all catalogs after connecting. |
| **Data Connectivity Mode** | Select **DirectQuery** to always query live data. Select **Import** for a one-time snapshot. |

Click **OK**.

---

### Step 6 — Authenticate

When prompted for credentials, select the **API Key** tab and enter your **Peaka Project API Key**.

You can find your API key in the Peaka console under **Project Settings → API Keys**.

Click **Connect**.

---

### Step 7 — Choose tables and load data

The Navigator panel opens and shows your Peaka catalogs, schemas, and tables. Select the tables or views you want, then click **Load** to import or **Transform Data** to open the Power Query editor first.

---

### Using Power BI with an On-Premises Data Gateway

If you publish reports to the Power BI Service and need scheduled data refresh, you must configure an on-premises data gateway so the service can reach your Peaka DSN.

**Configure the gateway to load the connector:**

1. Open **On-premises Data Gateway**.
2. Go to the **Connectors** tab.
3. In the **Load custom data connectors from folder** field, browse to the folder containing `peaka.mez` (e.g. `Documents\Power BI Desktop\Custom Connectors`), then click **Apply**.
4. Click **Close**.

**Create a data source in the Power BI Service:**

1. In **Power BI Service**, go to **Settings → Manage Gateways**.
2. Select the gateway cluster and open **Gateway Cluster Settings**.
3. Enable **Allow user's custom data connectors to refresh through this gateway cluster**, then click **Apply**.
4. Click **Add data sources to use the gateway** and fill in:
   - **Data Source Name:** any name you choose
   - **Data Source Type:** Peaka
   - **DSN:** the name of your configured DSN (e.g. `Peaka`)
5. Click **Add**.

Your reports can now refresh automatically through the gateway.

---

### Power BI Troubleshooting

**"Peaka" does not appear in the Get Data list**
The connector file is not in the correct folder, or custom connectors are not enabled. Verify the file location (`Documents\Power BI Desktop\Custom Connectors\peaka.mez`) and the Security setting in Options (Step 3), then restart Power BI Desktop.

**Queries fail or return unexpected errors in DirectQuery mode**
The "Remove Type Name Parameters" option is likely not enabled on the DSN. Open ODBC Administrator, select the DSN, click Configure → Advanced Options, check **Remove Type Name Parameters**, and click OK (Step 2 above).

**"Unable to connect" / authentication error**
Check that your Peaka Project API Key is correct and has not expired. Re-enter the API key via **File → Options → Data source settings**.

**"Data source kind does not match" warning**
The DSN name entered in the connection dialog does not match an existing ODBC DSN. Run `tools\list-dsn.bat` to see the exact names of your installed DSNs.

**Published reports fail to refresh in Power BI Service**
The on-premises data gateway must be configured with the Peaka connector and a matching data source. Follow the gateway steps above.

---

## Connecting via Power BI's Built-in ODBC Connector

Power BI Desktop has a native ODBC data source option that connects to any ODBC DSN without requiring the `peaka.mez` connector file. This method works whether or not the custom connector is installed and is useful in environments where custom connectors cannot be deployed.

### Prerequisites

- Peaka ODBC Driver installed and at least one DSN configured (see [Creating a DSN via ODBC Administrator](#creating-a-dsn-via-odbc-administrator)).
- **Remove Type Name Parameters** enabled on the DSN (Advanced Options in the DSN Setup dialog). Required for DirectQuery mode.

### Step 1 — Open the ODBC data source in Power BI

1. In Power BI Desktop, click **Home → Get Data → More…**
2. In the **Get Data** dialog, click **Other**.
3. Select **ODBC** and click **Connect**.

### Step 2 — Select the DSN

In the **From ODBC** dialog, open the **Data source name (DSN)** drop-down and select your Peaka DSN (e.g. `Peaka`).

Leave the **Advanced options** / connection string fields blank unless you need to override a specific setting.

Select the **Data Connectivity Mode**:
- **DirectQuery** — Power BI always queries live data from Peaka. Recommended.
- **Import** — Data is copied into Power BI as a one-time snapshot.

Click **OK**.

### Step 3 — Authenticate

Power BI will ask you to choose an authentication method. Select **Database** and enter:

| Field | Value |
|---|---|
| **User name** | `peaka` |
| **Password** | Your **Peaka Project API Key** |

You can find your API key in the Peaka console under **Project Settings → API Keys**.

> Power BI requires a non-empty user name for Database authentication. Enter `peaka` as a fixed value — the actual authentication is handled by the API key in the Password field.

Click **Connect**.

### Step 4 — Choose tables and load data

The Navigator panel opens and shows your Peaka catalogs, schemas, and tables. Select the tables or views you want, then click **Load** or **Transform Data**.

### Notes

- Because this method uses Power BI's standard ODBC connector rather than the custom Peaka connector, the authentication dialog looks different (Database/username/password instead of API Key tab). The underlying connection is the same.
- The **Remove Type Name Parameters** setting on the DSN is equally important here. If it is not enabled, DirectQuery queries may fail.
- If you need to update the credentials later, go to **File → Options and settings → Data source settings**, select the ODBC data source, and click **Edit Permissions**.

---

## Directory Structure

```
peaka_odbc\
├── install.bat              Main entry point (ZIP installation)
├── driver\
│   ├── SimbatrinoODBC64_2.3.9.1001\   64-bit driver files
│   └── SimbatrinoODBC32_2.3.9.1001\   32-bit driver files
├── tools\
│   ├── install-driver.bat
│   ├── install-dsn.bat
│   ├── uninstall.bat
│   ├── list-dsn.bat
│   └── setup\               Registry templates (used internally)
└── custom\
    └── powerbi\
        └── peaka.mez        Power BI Desktop custom connector
```

`peaka-driver.reg` appears in the root only when the installer runs without administrator rights.

---

## Troubleshooting

**"Setup routines could not be found" / error 126**
The driver DLL path in the registry is wrong or the driver has never been registered.
Run `tools\install-driver.bat` as administrator and choose **yes** when asked to reinstall.

**Visual C++ Runtime error on first use**
The Visual C++ Redistributable for Visual Studio 2022 (x64) is missing. Download and install it from `https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist` and try again.

**DSN appears in ODBC Administrator but connection fails**
Check that the Host and Port values are correct.
Open `tools\list-dsn.bat` to inspect the registered values, then re-run `tools\install-dsn.bat`.

**DSN is not visible to a Windows service**
User DSNs are not visible to services. Re-run `tools\install-dsn.bat` as administrator and choose **System-wide** scope.

**I need separate connections for different environments**
Run `tools\install-dsn.bat` multiple times with different DSN names (e.g. `Peaka_US`, `Peaka_EU`, `Peaka_Test`).
Each DSN can point to a different host while sharing the same driver.

**I don't see the 64-bit driver in ODBC Administrator**
You are likely looking at the 32-bit ODBC Administrator. Open `C:\Windows\System32\odbcad32.exe` directly.

**Enabling diagnostic logging**
Open ODBC Administrator, select the DSN, click **Configure**, then click **Logging Options**. Enable logging only for as long as needed to capture the issue — logging reduces performance and can consume significant disk space. Disable it again once you have captured the logs.
