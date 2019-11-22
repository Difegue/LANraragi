using Microsoft.Win32;
using System.ComponentModel;
using System.Windows;
using System.Windows.Forms;
using System.Windows.Navigation;
using System.Diagnostics;
using System.Text.RegularExpressions;

namespace Karen
{
    /// <summary>
    /// Interaction logic for MainWindow.xaml
    /// </summary>
    public partial class MainWindow : Window
    {

        public MainWindow()
        {
            InitializeComponent();
            DataContext = this;
        }

        private void PickFolder(object sender, RoutedEventArgs e)
        {
            FolderBrowserDialog dlg = new FolderBrowserDialog();
            dlg.Description = "Select your LANraragi Content Folder.";

            if (dlg.ShowDialog() == System.Windows.Forms.DialogResult.OK)
            {
                Properties.Settings.Default.ContentFolder = dlg.SelectedPath;
            }
        }

        private void OnClosing(object sender, CancelEventArgs e)
        {
            // Set first launch to false
            Properties.Settings.Default.FirstLaunch = false;

            Properties.Settings.Default.Save();

            //Update registry according to the StartWithWindows pref
            if (Properties.Settings.Default.StartWithWindows)
                AddApplicationToStartup();
            else
                RemoveApplicationFromStartup();

        }

        public static void AddApplicationToStartup()
        {
            using (RegistryKey key = Registry.CurrentUser.OpenSubKey("SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run", true))
            {
                key.SetValue("Karen", "\"" + System.Reflection.Assembly.GetExecutingAssembly().Location + "\"");
            }
        }

        public static void RemoveApplicationFromStartup()
        {
            using (RegistryKey key = Registry.CurrentUser.OpenSubKey("SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run", true))
            {
                key.DeleteValue("Karen", false);
            }
        }

        private void Hyperlink_RequestNavigate(object sender, RequestNavigateEventArgs e)
        {
            Process.Start(new ProcessStartInfo(e.Uri.AbsoluteUri));
            e.Handled = true;
        }

        private void NumberValidationTextBox(object sender, System.Windows.Input.TextCompositionEventArgs e)
        {
            Regex regex = new Regex("[^0-9]+");
            e.Handled = regex.IsMatch(e.Text);
        }

    }
}
