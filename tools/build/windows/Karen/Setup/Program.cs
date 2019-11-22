using System;
using System.Diagnostics;
using Microsoft.Deployment.WindowsInstaller;
using WixSharp;
using WixSharp.CommonTasks;
using WixSharp.Controls;
using System.Linq;

namespace Setup
{
    public class Program
    {
        static void Main()
        {
            // This project type has been superseded with the EmbeddedUI based "WixSharp Managed Setup - Custom Dialog"
            // project type. Which provides by far better final result and user experience.
            // However due to the Burn limitations (see this discussion: https://wixsharp.codeplex.com/discussions/645838)
            // currently "Custom CLR Dialog" is the only working option for having bootstrapper silent UI displaying
            // individual MSI packages UI implemented in managed code.

            var uninstallerShortcut = new ExeFileShortcut("Uninstall LANraragi", "[System64Folder]msiexec.exe", "/x [ProductCode]");

            var project = new Project("LANraragi",
                             new Dir(@"%AppData%\LANraragi", 
                                 new Files(@"..\Karen\bin\x64\Release\*.*"),
                                            new File(@"..\External\package.tar"),
                                             new Dir("LxRunOffline",
                                                 new Files(@"..\External\LxRunOffline\*.*")),
                                            uninstallerShortcut
                                    ),
                             new ElevatedManagedAction(RegisterWslDistro,
                                 Return.check,
                                 When.After,
                                 Step.InstallFiles,
                                 Condition.NOT_BeingRemoved),
                             new ElevatedManagedAction(UnRegisterWslDistro,
                                 Return.check,
                                 When.Before,
                                 Step.RemoveFiles,
                                 Condition.BeingUninstalled)
                            );

            project.ResolveWildCards()
                .FindFile((f) => f.Name.EndsWith("Karen.exe"))
                .First()
                .Shortcuts = new[] {
                new FileShortcut("LANraragi for Windows", "INSTALLDIR"),
                new FileShortcut("LANraragi for Windows", "%Desktop%")
            };

            project.GUID = new Guid("6fe30b47-2577-43ad-1337-1861ba25889b");
            project.Platform = Platform.x64;
            project.MajorUpgradeStrategy = MajorUpgradeStrategy.Default;
            project.Version = Version.Parse("1.0.0.1");

            // TODO: remove reg key on uninstall
            // Remove-ItemProperty -Name 'Karen' -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'

            // Check for x64 Windows 10
            project.LaunchConditions.Add(new LaunchCondition("VersionNT64","LANraragi for Windows can only be installed on a 64-bit Windows."));
            project.LaunchConditions.Add(new LaunchCondition("VersionNT>=\"603\"", "LANraragi for Windows can only be installed on Windows 10 and up."));

            //Schedule custom dialog between WelcomeDlg and InstallDirDlg standard MSI dialogs.
            project.InjectClrDialog(nameof(ShowDialogIfWslDisabled), NativeDialogs.WelcomeDlg, NativeDialogs.InstallDirDlg);

            //remove LicenceDlg
            project.RemoveDialogsBetween(NativeDialogs.InstallDirDlg, NativeDialogs.VerifyReadyDlg);

            //project.SourceBaseDir = "<input dir path>";
            project.OutDir = "bin";
            project.BuildMsi();
        }

        [CustomAction]
        public static ActionResult RegisterWslDistro(Session session)
        {
            UnRegisterWslDistro(session);

            if (session.IsUninstalling())
                return ActionResult.Success;

            var packageLocation = session.Property("INSTALLDIR") + @"\package.tar";
            var lxRunLocation = session.Property("INSTALLDIR") + @"LxRunOffline";
            var distroLocation = session.Property("INSTALLDIR") + @"Distro";

            return session.HandleErrors(() =>
            {
                // Use LxRunOffline to either install or uninstall the WSL distro.
                session.Log("Installing WSL Distro from package.tar");
                Process.Start(lxRunLocation + @"\LxRunOffline.exe",  "i -n lanraragi -d " + distroLocation + " -f " + packageLocation);
                
                session.Log("Removing package.tar");
                System.IO.File.Delete(packageLocation);
            });
        }

        [CustomAction]
        public static ActionResult UnRegisterWslDistro(Session session)
        {
            return session.HandleErrors(() =>
            {
                session.Log("Removing previous WSL Distro");
                Process.Start("wslconfig.exe", "/unregister lanraragi");
            });
        }

        [CustomAction]
        public static ActionResult ShowDialogIfWslDisabled(Session session)
        {
            return WixCLRDialog.ShowAsMsiDialog(new CustomDialog(session));
        }

    }
}