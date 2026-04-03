For User Manual see [src/README.md](src/README.md)

---

## Building from Source

### Step 1 — Run the build script

Run the script that matches your environment:

**Windows**
```
build.bat
```
Requires [7-Zip](https://7-zip.org) (`7z.exe` on PATH or installed at the default location).

**macOS / Linux**
```bash
./build.sh
```
Requires `zip` (pre-installed on most systems).

Both scripts produce two files inside the `dist\` folder:

| File | Description |
|---|---|
| `dist\peaka.mez` | Power BI Desktop custom connector |
| `dist\peaka_odbc.zip` | Full distribution package (driver + scripts + connector) |

### Step 2 — Build the Setup installer (optional)

If [Inno Setup 6](https://jrsoftware.org/isinfo.php) is installed on your machine, compile `peaka-odbc-setup.iss` to produce the Windows Setup installer:

```
ISCC.exe peaka-odbc-setup.iss
```

The compiled installer is written to:

```
dist\PeakaODBC_Setup_<version>.exe
```

`ISCC.exe` is located in the Inno Setup installation folder (typically `C:\Program Files (x86)\Inno Setup 6\`). You can also open `peaka-odbc-setup.iss` in the Inno Setup IDE and press **Ctrl+F9** to compile.

