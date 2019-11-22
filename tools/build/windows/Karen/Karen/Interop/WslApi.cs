using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading.Tasks;

namespace Karen.Interop
{
    [Flags]
    public enum WSL_DISTRIBUTION_FLAGS : uint
    {
        NONE = 0,
        ENABLE_INTEROP = 1,
        APPEND_NT_PATH = 2,
        ENABLE_DRIVE_MOUNTING = 4
    }

    /// <summary>
    /// Imports straight from the WSL API. See https://docs.microsoft.com/en-us/windows/desktop/api/_wsl/ .
    /// </summary>
    public static class WslApi
    {
        [DllImport("wslapi.dll", EntryPoint = "WslConfigureDistribution", ExactSpelling = true, CharSet = CharSet.Unicode)]
        public static extern uint WslConfigureDistribution(
            [In] string distributionName,
            [In] uint defaultUID,
            [In] WSL_DISTRIBUTION_FLAGS wslDistributionFlags
            );

        [DllImport("wslapi.dll", EntryPoint = "WslGetDistributionConfiguration", ExactSpelling = true, CharSet = CharSet.Unicode)]
        public static extern uint WslGetDistributionConfiguration(
            [In] string distributionName,
            [Out] out uint distributionVersion,
            [Out] out uint defaultUID,
            [Out] out WSL_DISTRIBUTION_FLAGS flags,
            [Out] out StringBuilder envvars,
            [Out] out uint envvarCount
            );

        [DllImport("wslapi.dll", EntryPoint = "WslIsDistributionRegistered", ExactSpelling = true, CharSet = CharSet.Unicode)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool WslIsDistributionRegistered(
            [In] string distributionName
            );

        [DllImport("wslapi.dll", EntryPoint = "WslLaunch", ExactSpelling = true, CharSet = CharSet.Unicode)]
        public static extern uint WslLaunch(
            [In] string distributionName,
            [In] string command,
            [In] bool useCurrentWorkingDirectory,
            [In] IntPtr stdIn,
            [In] IntPtr stdOut,
            [In] IntPtr stdErr,
            [Out] out IntPtr processHandle
            );

        [DllImport("wslapi.dll", EntryPoint = "WslLaunchInteractive", ExactSpelling = true, CharSet = CharSet.Unicode)]
        public static extern uint WslLaunchInteractive(
            [In] string distributionName,
            [In] string command,
            [In] bool useCurrentWorkingDirectory,
            [Out] out uint errorCode
            );

        [DllImport("wslapi.dll", EntryPoint = "WslRegisterDistribution", ExactSpelling = true, CharSet = CharSet.Unicode)]
        public static extern uint WslRegisterDistribution(
            [In] string distributionName,
            [In] string tarGzFilename
            );

        [DllImport("wslapi.dll", EntryPoint = "WslUnregisterDistribution", ExactSpelling = true, CharSet = CharSet.Unicode)]
        public static extern uint WslUnregisterDistribution(
            [In] string distributionName
            );
    }
    
}
