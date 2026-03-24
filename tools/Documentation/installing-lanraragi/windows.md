# 🪟 LRR for Windows (Win10)

## Download a Release

You can download the latest Windows MSI Installer on the [Release Page](https://github.com/Difegue/LANraragi/releases).

Windows 10 1809 is the minimum supported version. Windows 10 2004 and newer are recommended.

{% hint style="warning" %}
If you're using Windows 10 1809, UTF-8 support needs to be enabled. You can find instructions [here](windows.md#mangled-filenames-when-running-on-windows-10-1809).
{% endhint %}

{% hint style="info" %}
Windows Nightlies are available [here](https://nightly.link/Difegue/LANraragi/workflows/push-continous-delivery/dev).
{% endhint %}

## Installation

Simply execute the installer package.

You might get a SmartScreen prompt from Windows as the installer isn't signed; These are perfectly normal.\
(If you're wondering why I don't sign installers, [this](https://web.archive.org/web/20241204064244/https://gaby.dev/posts/code-signing) article is a good read.)

Once the install completes properly, you'll be able to launch the GUI from the shortcut in your Start Menu:

![](../.gitbook/assets/karen-startmenu.png)

## Configuration

Starting the GUI for the first time will prompt you to setup your content folder and the port you want the server to listen on. The main GUI is always available from your Taskbar.

![Tray GUI and Settings Window](../.gitbook/assets/karen-light.png)

You can also decide whether to start the GUI alongside Windows, or start LRR alongside the GUI.\
Combining the two makes it so that LANraragi starts alongside Windows. 🔥🔥🔥

## Usage

![Tray GUI and Log Console. Check that Dark Theme tho ](../.gitbook/assets/karen-dark.png)

Once the program is running, you can open the Web Client through the shortcut button on the user interface. You can also toggle the Log Console on/off to see what's going on behind the scenes.

## Updating

Updates have to be done manually by downloading and running the latest installer.

## Uninstallation

Simply uninstall the app from Windows Settings.\
Presto! Your database is not deleted in case you ever fancy coming back.

## Troubleshooting

### Installer failures

Make sure you have the Windows App SDK runtime installed to ensure the tray GUI app can run. A copy can be downloaded here: [https://aka.ms/windowsappsdk/1.7/1.7.250606001/windowsappruntimeinstall-x64.exe](https://aka.ms/windowsappsdk/1.7/1.7.250606001/windowsappruntimeinstall-x64.exe)

The tray GUI will show the error message it encountered instead of the LRR Version number if it fails to test the runtime - This might help you troubleshoot further. A detailed error can be found in the log console.

Some users reported that antivirus software can block the runtime install portion of the installer, so you might have some luck temporarily disabling it.

If you're still getting installer failures past that, try generating a full log of the installer:

```
msiexec /i "lanraragi.msi" /l*v "install.log"
```

and open a GitHub issue with it.

### Server isn't available on `localhost:3000` even though it has started properly

Running the application as Administrator might fix this in some instances.\
Otherwise, make sure the Windows Firewall isn't blocking any `perl` process.

### Mangled filenames when running on Windows 10 1809

This specific version of Windows 10 does not support per application UTF-8 so it needs to be enabled globally.

Run `intl.cpl` to open the Region settings, select the "Administrative" tab and click on "Change system locale..."

![](../.gitbook/assets/utf8-region.png)

In the popup select the "Beta: Use Unicode UTF-8" option.

![](../.gitbook/assets/utf8-popup.png)

Restart and use the "Rescan content folder" button to fix existing paths.

![](../.gitbook/assets/utf8-restart.png)
