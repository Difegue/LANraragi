using System;
using System.Diagnostics;
using System.Management.Automation;
using System.Windows.Forms;
using Microsoft.Deployment.WindowsInstaller;
using WixSharp;

public partial class CustomDialog : WixCLRDialog
{
    private string obj;

    public CustomDialog()
    {
        InitializeComponent();
    }

    public CustomDialog(Session session)
        : base(session)
    {
        InitializeComponent();

        using (var powerShellInstance = PowerShell.Create())
        {
            powerShellInstance.AddScript(@"Get-Command wsl"); // This command fails if wsl.exe doesn't exist
            var psOutput = powerShellInstance.Invoke();

            if (powerShellInstance.Streams.Error.Count > 0)
            {
                foreach (var err in powerShellInstance.Streams.Error)
                    obj += err.ToString();
            }
        }
    }

    void backBtn_Click(object sender, EventArgs e)
    {
        MSIBack();

    }

    void nextBtn_Click(object sender, EventArgs e)
    {
        MSICancel();
    }

    void cancelBtn_Click(object sender, EventArgs e)
    {
        MSICancel();
    }

    private void linkLabel1_LinkClicked(object sender, LinkLabelLinkClickedEventArgs e)
    {
        Process.Start("https://docs.microsoft.com/en-us/windows/wsl/install-win10");
    }

    private void linkLabel2_LinkClicked(object sender, LinkLabelLinkClickedEventArgs e)
    {
        MessageBox.Show(obj, "Error thrown while looking for WSL");
    }

    private void CustomDialog_Load(object sender, EventArgs e)
    {
        // Do nothing if WSL is enabled
        // This prevents going back to the very first page of the setup but whatever tbh
        if (obj == null)
            MSINext();
    }
}
