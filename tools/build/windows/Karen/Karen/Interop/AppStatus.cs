using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Karen.Interop
{
    public enum AppStatus
    {
        [Description("⛔ LANraragi is not installed")]
        NotInstalled = 1,
        [Description("❌ LANraragi is stopped")]
        Stopped = 2,
        [Description("🔜 LANraragi is starting...")]
        Starting = 3,
        [Description("✌ LANraragi is running")]
        Started = 4,
    }
}
