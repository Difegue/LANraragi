using System.Linq;
using System.Windows;
using Hardcodet.Wpf.TaskbarNotification;
using Karen.Interop;

namespace Karen
{
    /// <summary>
    /// Simple application. Check the XAML for comments.
    /// </summary>
    public partial class App : Application
    {
        private TaskbarIcon notifyIcon;
        public WslDistro Distro { get; set; }

        public void ToastNotification(string text)
        {
            notifyIcon.ShowBalloonTip("LANraragi", text, notifyIcon.Icon);
        }

        public void ShowConfigWindow()
        {
            if (Application.Current.MainWindow == null)
                Application.Current.MainWindow = new MainWindow();

            Application.Current.MainWindow.Show();

            if (Application.Current.MainWindow.WindowState == WindowState.Minimized)
                Application.Current.MainWindow.WindowState = WindowState.Normal;
        }

        protected override void OnStartup(StartupEventArgs e)
        {
            base.OnStartup(e);

            // Only one instance of the bootloader allowed at a time
            var exists = System.Diagnostics.Process.GetProcessesByName(System.IO.Path.GetFileNameWithoutExtension(System.Reflection.Assembly.GetEntryAssembly().Location)).Count() > 1;
            if (exists)
            {
                MessageBox.Show("Another instance of the application is already running.");
                Application.Current.Shutdown();
            }

            Distro = new WslDistro();

            // First time ?
            if (Karen.Properties.Settings.Default.FirstLaunch)
            {
                MessageBox.Show("Looks like this is your first time running the app! Please setup your Content Folder in the Settings.");
                ShowConfigWindow();
            }

            // Create the Taskbar Icon now so it appears in the tray
            notifyIcon = (TaskbarIcon)FindResource("NotifyIcon");

            // Check if server starts with app 
            if (Karen.Properties.Settings.Default.StartServerAutomatically && Distro.Status == AppStatus.Stopped)
            {
                ToastNotification("LANraragi is starting automagically...");
                Distro.StartApp();
            }
            else
                ToastNotification("The Launcher is now running! Please click the icon in your Taskbar.");
        }

        protected override void OnExit(ExitEventArgs e)
        {
            notifyIcon.Dispose(); //the icon would clean up automatically, but this is cleaner
            Distro.StopApp();
            WslDistro.FreeConsole(); //clean up the console to ensure it's closed alongside the app
            base.OnExit(e);
        }
    }
}
