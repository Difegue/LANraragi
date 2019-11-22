using HideConsoleOnCloseManaged;
using Microsoft.Win32.SafeHandles;
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.IO.Pipes;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading.Tasks;

namespace Karen.Interop
{
    /// <summary>
    /// Abstracts a WSL distro, allowing to start and stop a process within it.
    /// Also features a togglable console with the process' STDOUT.
    /// </summary>
    public class WslDistro
    {

        public AppStatus Status { get; private set; }
        public String Version { get; private set; }

        private IntPtr _lrrHandle;
        private Process _lrrProc;

        public WslDistro()
        {
            Status = CheckDistro() ? AppStatus.Stopped : AppStatus.NotInstalled;

            // Compute version only if the distro exists
            if (Status == AppStatus.Stopped)
                Version = GetVersion();
        }

        private bool CheckDistro()
        {
            //return WslApi.WslIsDistributionRegistered(DISTRO_NAME);
            // ^ This WSL API call is currently broken from WPF applications.
            // See https://stackoverflow.com/questions/55681500/why-did-wslapi-suddenly-stop-working-in-wpf-applications.
            // Stuck doing a manual wsl.exe call for now...

            var proc = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = Environment.SystemDirectory + "\\wslconfig.exe",
                    Arguments = "/l",
                    UseShellExecute = false,
                    RedirectStandardInput = true,
                    RedirectStandardError = true,
                    RedirectStandardOutput = true,
                    CreateNoWindow = true,
                }
            };
            try
            {
                proc.Start();
                while (!proc.StandardOutput.EndOfStream)
                {
                    string line = proc.StandardOutput.ReadLine();
                    if (line.Replace("\0","").Contains(Properties.Resources.DISTRO_NAME))
                    {
                        return true;
                    }
                }
            }
            catch (Exception e)
            {
                //WSL might not be enabled ?
                Version = e.Message;
                return false;
            }

            return false;
        }

        private string GetVersion()
        {
            // Perl one-liner to execute on the distro to get the version number+name
            string oneLiner = "perl -Mojo -E \"my $conf = j(f(qw(/home/koyomi/lanraragi/package.json))->slurp); say %$conf{version}.q/ - '/.%$conf{version_name}.q/'/\"";

            var proc = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = Environment.SystemDirectory + "\\wsl.exe",
                    Arguments = "-d "+ Properties.Resources.DISTRO_NAME + " --exec " + oneLiner,
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    CreateNoWindow = true,
                }
            };
            try
            {
                proc.Start();
                while (!proc.StandardOutput.EndOfStream)
                {
                    string line = proc.StandardOutput.ReadLine();
                    return "Version " + line;
                }
            }
            catch (Exception e)
            {
                // Distro exists but the one-liner fails ?
                Status = AppStatus.NotInstalled;
                return e.Message;
            }

            // Distro exists but the one-liner returns nothing
            Status = AppStatus.NotInstalled;
            return "WSL Distro doesn't function properly. Consider updating Windows 10.";

        }

        public void ShowConsole()
        {
            ShowWindow(GetConsoleWindow(), SW_SHOW);
            ShowWindow(GetConsoleWindow(), SW_RESTORE);
        }

        public void HideConsole()
        {
            ShowWindow(GetConsoleWindow(), SW_HIDE);
        }

        public bool? StartApp()
        {
            if (!Directory.Exists(Properties.Settings.Default.ContentFolder))
            {
                Version = "Content Folder doesn't exist!";
                return false;
            }

            Status = AppStatus.Starting;

            // Spawn a new console 
            AllocConsole();

            // Hide it 
            HideConsole();
            HideConsoleOnClose.Enable();

            // Get its handles
            var stdIn = GetStdHandle(STD_INPUT_HANDLE);
            var stdOut = GetStdHandle(STD_OUTPUT_HANDLE);
            var stdError = GetStdHandle(STD_ERROR_HANDLE);

            // Map the user's content folder to its WSL equivalent
            // This means lowercasing the drive letter, removing the : and replacing every \ by a /.
            string winPath = Properties.Settings.Default.ContentFolder;
            string contentFolder = "/mnt/" + Char.ToLowerInvariant(winPath[0]) + winPath.Substring(1).Replace(":", "").Replace("\\", "/");

            // The big bazooper. Export port and content folder and start supervisord.
            string command = "export LRR_NETWORK=http://*:"+ Properties.Settings.Default.NetworkPort + " " +
                             "&& export LRR_DATA_DIRECTORY='"+contentFolder+"' " +
                             (Properties.Settings.Default.ForceDebugMode ? "&& export LRR_FORCE_DEBUG=1 " : "") +
                             "&& cd /home/koyomi/lanraragi && rm -f script/hypnotoad.pid " +
                             "&& sysctl vm.overcommit_memory=1 " +
                             "&& supervisord --nodaemon --configuration ./tools/DockerSetup/supervisord.conf";

            // Start process in WSL and hook up handles 
            // This will direct WSL output to the new console window, or to Visual Studio if running with the debugger attached.
            // See https://stackoverflow.com/questions/15604014/no-console-output-when-using-allocconsole-and-target-architecture-x86
            WslApi.WslLaunch(Properties.Resources.DISTRO_NAME, command, false, stdIn,stdOut,stdError, out _lrrHandle);

            // Get Process ID of the returned procHandle
            int lrrId = GetProcessId(_lrrHandle);
            _lrrProc = Process.GetProcessById(lrrId);

            // Check that the returned process is still alive
            if (_lrrProc != null && !_lrrProc.HasExited)
                Status = AppStatus.Started;

            return !_lrrProc?.HasExited;
        }

        public bool? StopApp()
        {  
            // Kill WSL Process
            if (_lrrProc != null && !_lrrProc.HasExited)
            {
                _lrrProc.Kill();

                // Ensure child unix processes are killed as well by killing the distro. This is only possible on 1809 and up.
                new Process
                {
                    StartInfo = new ProcessStartInfo
                    {
                        FileName = "wslconfig.exe",
                        Arguments = "/terminate " + Properties.Resources.DISTRO_NAME,
                        UseShellExecute = false,
                        RedirectStandardOutput = true,
                        CreateNoWindow = true,
                    }
                }.Start();
            }

            // No need to remove the attached console here in case the app is restarted later down
            Status = AppStatus.Stopped;
            return _lrrProc?.HasExited;
        }

        #region Your friendly neighborhood P/Invokes for console host wizardry

        [DllImport("kernel32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        static extern bool AllocConsole();

        [DllImport("kernel32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool FreeConsole();

        [DllImport("kernel32.dll")]
        static extern int GetProcessId(IntPtr handle);

        [DllImport("kernel32.dll")]
        static extern IntPtr GetConsoleWindow();

        [DllImport("User32")]
        static extern bool ShowWindow(IntPtr hwnd, int nCmdShow);

        [DllImport("kernel32.dll", EntryPoint = "GetStdHandle", SetLastError = true, CharSet = CharSet.Auto, CallingConvention = CallingConvention.StdCall)]
        private static extern IntPtr GetStdHandle(int nStdHandle);

        private const int STD_INPUT_HANDLE = -10;
        private const int STD_OUTPUT_HANDLE = -11;
        private const int STD_ERROR_HANDLE = -12;

        private const int SW_HIDE = 0;
        private const int SW_SHOW = 5;
        private const int SW_RESTORE = 9;

        #endregion
    }
}
