using Karen.Interop;
using Microsoft.Win32;
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;

namespace Karen
{

    #region Some more Win32 to ask the DWM for acrylic
    internal enum AccentState
    {
        ACCENT_DISABLED = 0,
        ACCENT_ENABLE_GRADIENT = 1,
        ACCENT_ENABLE_TRANSPARENTGRADIENT = 2,
        ACCENT_ENABLE_BLURBEHIND = 3,
        ACCENT_ENABLE_ACRYLIC = 4,
        ACCENT_INVALID_STATE = 5
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct AccentPolicy
    {
        public AccentState AccentState;
        public uint AccentFlags;
        public uint GradientColor;
        public uint AnimationId;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct WindowCompositionAttributeData
    {
        public WindowCompositionAttribute Attribute;
        public IntPtr Data;
        public int SizeOfData;
    }

    internal enum WindowCompositionAttribute
    {
        // ...
        WCA_ACCENT_POLICY = 19
        // ...
    }
    #endregion

    public partial class KarenPopup : UserControl, INotifyPropertyChanged
    {
        [DllImport("user32.dll")]
        internal static extern int SetWindowCompositionAttribute(IntPtr hwnd, ref WindowCompositionAttributeData data);
        private uint _blurBackgroundColor = 0x99FFFFFF;

        public event PropertyChangedEventHandler PropertyChanged;

        public string Version => ((App)Application.Current).Distro.Version;
        public AppStatus DistroStatus => ((App)Application.Current).Distro.Status;
        public bool IsStarted => DistroStatus == AppStatus.Started;
        public bool IsStopped => DistroStatus == AppStatus.Stopped;
        public bool IsNotInstalled => DistroStatus == AppStatus.NotInstalled;

        public KarenPopup()
        {
            InitializeComponent();
            BorderBrush = SystemParameters.WindowGlassBrush;
            DataContext = this;
        }

        // Wait for Control to Load
        void KarenPopup_Loaded(object sender, RoutedEventArgs e)
        {
            // Get PresentationSource
            PresentationSource presentationSource = PresentationSource.FromVisual((Visual)sender);

            // Subscribe to PresentationSource's ContentRendered event
            presentationSource.ContentRendered += KarenPopup_ContentRendered;
        }

        void KarenPopup_ContentRendered(object sender, EventArgs e)
        {
            this.Resources.MergedDictionaries.Clear();

            try
            {
                //Get Light/Dark theme from registry
                RegistryKey registryKey = Registry.CurrentUser.OpenSubKey("Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize");
                RegistryValueKind kind = registryKey.GetValueKind("AppsUseLightTheme");
                string lightThemeOn = registryKey.GetValue("AppsUseLightTheme").ToString();

                if (lightThemeOn != "0")
                {
                    _blurBackgroundColor = 0x99FFFFFF;
                    this.Resources.MergedDictionaries.Add(new ResourceDictionary() { Source = new Uri("/Themes/Light.xaml", UriKind.Relative) });
                }
                else
                {
                    _blurBackgroundColor = 0xAA000000;
                    this.Resources.MergedDictionaries.Add(new ResourceDictionary() { Source = new Uri("/Themes/Dark.xaml", UriKind.Relative) });
                }
                this.Dispatcher.Invoke(() => { }, System.Windows.Threading.DispatcherPriority.Render);
            } catch (Exception)
            {
                //eh 
                this.Resources.MergedDictionaries.Add(new ResourceDictionary() { Source = new Uri("/Themes/Light.xaml", UriKind.Relative) });
            }

            //Display the popup...with cool acrylic!
            EnableBlur((HwndSource)sender);
        }

        //Enable Acrylic on the Popup's HWND.
        internal void EnableBlur(HwndSource source)
        {
            var accent = new AccentPolicy();
            accent.AccentState = AccentState.ACCENT_ENABLE_ACRYLIC;
            accent.GradientColor = _blurBackgroundColor;

            var accentStructSize = Marshal.SizeOf(accent);

            var accentPtr = Marshal.AllocHGlobal(accentStructSize);
            Marshal.StructureToPtr(accent, accentPtr, false);

            var data = new WindowCompositionAttributeData();
            data.Attribute = WindowCompositionAttribute.WCA_ACCENT_POLICY;
            data.SizeOfData = accentStructSize;
            data.Data = accentPtr;

            SetWindowCompositionAttribute(source.Handle, ref data);

            Marshal.FreeHGlobal(accentPtr);
        }

        private void Show_Config(object sender, RoutedEventArgs e)
        {
            ((App)Application.Current).ShowConfigWindow();

            ((Popup)this.Parent).IsOpen = false;
        }

        private void UpdateProperties()
        {
            PropertyChanged(this, new PropertyChangedEventArgs("DistroStatus"));
            PropertyChanged(this, new PropertyChangedEventArgs("IsStarted"));
            PropertyChanged(this, new PropertyChangedEventArgs("IsStopped"));
            PropertyChanged(this, new PropertyChangedEventArgs("Version"));
        }

        private void Show_Console(object sender, RoutedEventArgs e)
        {
            ((App)Application.Current).Distro.ShowConsole();
        }

        private void Shutdown_App(object sender, RoutedEventArgs e)
        {
            Application.Current.Shutdown();
        }

        private void Start_Distro(object sender, RoutedEventArgs e)
        {
            ((App)Application.Current).Distro.StartApp();
            UpdateProperties();
        }

        private void Stop_Distro(object sender, RoutedEventArgs e)
        {
            ((App)Application.Current).Distro.StopApp();
            UpdateProperties();
        }

        private void Open_Webclient(object sender, RoutedEventArgs e)
        {
            System.Diagnostics.Process.Start("http://localhost:"+ Properties.Settings.Default.NetworkPort);
        }

        private void Open_Distro(object sender, RoutedEventArgs e)
        {
            System.Diagnostics.Process.Start(@"\\wsl$\lanraragi\home\koyomi\lanraragi");
        }
    }
}
