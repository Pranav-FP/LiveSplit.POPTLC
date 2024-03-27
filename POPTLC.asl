state("TheLostCrown") { }
state("TheLostCrown_plus") { }

startup
{
    Assembly.Load(File.ReadAllBytes("Components/asl-help")).CreateInstance("Unity");
    vars.Helper.GameName = "POPTLC";
    
    // The ubisoft+ version of this game is weird and requires overriding some config in asl-help
    vars.Helper.Il2CppModules.Add("GameAssembly_plus.dll");
    vars.Helper.DataDirectory = "TheLostCrown_Data";

    vars.SetTextComponent = (Action<string, string>)((id, text) =>
	{
		var textSettings = timer.Layout.Components.Where(x => x.GetType().Name == "TextComponent").Select(x => x.GetType().GetProperty("Settings").GetValue(x, null));
		var textSetting = textSettings.FirstOrDefault(x => (x.GetType().GetProperty("Text1").GetValue(x, null) as string) == id);
		if (textSetting == null)
		{
		var textComponentAssembly = Assembly.LoadFrom("Components\\LiveSplit.Text.dll");
		var textComponent = Activator.CreateInstance(textComponentAssembly.GetType("LiveSplit.UI.Components.TextComponent"), timer);
		timer.Layout.LayoutComponents.Add(new LiveSplit.UI.Components.LayoutComponent("LiveSplit.Text.dll", textComponent as LiveSplit.UI.Components.IComponent));

		textSetting = textComponent.GetType().GetProperty("Settings", BindingFlags.Instance | BindingFlags.Public).GetValue(textComponent, null);
		textSetting.GetType().GetProperty("Text1").SetValue(textSetting, id);
		}

		if (textSetting != null)
		textSetting.GetType().GetProperty("Text2").SetValue(textSetting, text);
	});

    vars.RemoveTextComponent = (Action<string>)((id) => {
        int indexToRemove = -1;
        do {
            indexToRemove = -1;
            foreach (dynamic component in timer.Layout.Components) {
                if (component.GetType().Name == "TextComponent" && System.Text.RegularExpressions.Regex.IsMatch(component.Settings.Text1, id)) {
                    indexToRemove = timer.Layout.Components.ToList().IndexOf(component);
                }
            }
            if (indexToRemove != -1) {
                timer.Layout.LayoutComponents.RemoveAt(indexToRemove);
            }
        } while (indexToRemove != -1);
    });

    vars.oldBonusDamageCount = null;

    vars.RemoveAllComponents = (Action<string>)((id) => {
        vars.RemoveTextComponent(@"Slot \d+");
        vars.RemoveTextComponent("----Completion Viewer Loaded----");
    });
}

init
{
    vars.RemoveAllComponents("");
    vars.SetTextComponent("Loading Completion Viewer......", "");
    vars.states = null;
    current.isChangingLevel = false;

    // hardcoding some offsets which we can't get dynamically
    var DICT_ENTRIES_OFFSET = 0x18;
    var DICT_LENGTH_OFFSET = 0x18;
    var DICT_ITEMS_OFFSET = 0x20;
    var DICT_KEY_SIZE = 0x8;
    var DICT_VAL_SIZE = 0x8;
    var DICT_ITEM_SIZE = 0x8 + DICT_KEY_SIZE + DICT_VAL_SIZE;
    var DICT_KEY_OFFSET = 0x8;
    var DICT_VAL_OFFSET = 0x8 + DICT_KEY_SIZE;

    vars.Helper.TryLoad = (Func<dynamic, bool>)(mono =>
    {
        // asl-help has this issue where sometimes offsets resolve to 0x10 less than what they are meant to be
        // this is a fix to that...
        var PAD = 0x10;

        var LSM = mono["Alkawa.Gameplay", "LoadSaveManager", 1];
        var SPI = mono["Alkawa.Gameplay", "SaveProgressionInfos"];

        vars.Helper["progressionsList0"] = LSM.MakeList<IntPtr>(
            "m_instance",
            LSM["m_progressions"] + PAD,
            DICT_ENTRIES_OFFSET,
            DICT_ITEMS_OFFSET + (0*DICT_ITEM_SIZE) + DICT_VAL_OFFSET
        );
        vars.Helper["progressionsList1"] = LSM.MakeList<IntPtr>(
            "m_instance",
            LSM["m_progressions"] + PAD,
            DICT_ENTRIES_OFFSET,
            DICT_ITEMS_OFFSET + (1*DICT_ITEM_SIZE) + DICT_VAL_OFFSET
        );
        vars.Helper["progressionsList2"] = LSM.MakeList<IntPtr>(
            "m_instance",
            LSM["m_progressions"] + PAD,
            DICT_ENTRIES_OFFSET,
            DICT_ITEMS_OFFSET + (2*DICT_ITEM_SIZE) + DICT_VAL_OFFSET
        );

        vars.ReadProgression = (Func<IntPtr, float>)(progression =>
        {
            float completion = vars.Helper.Read<float>(progression + SPI["m_completion"] + PAD);
            return completion;
        });

        vars.RemoveTextComponent("Loading Completion Viewer......");
        return true;
    });
}

update
{
    vars.SetTextComponent("----Completion Viewer Loaded----", "");
    float completionSlot1 = vars.ReadProgression(current.progressionsList0[0])*100;
    vars.SetTextComponent("Slot 1", completionSlot1.ToString()+"%");
    float completionSlot2 = vars.ReadProgression(current.progressionsList1[0])*100;
    vars.SetTextComponent("Slot 2", completionSlot2.ToString()+"%");
    float completionSlot3 = vars.ReadProgression(current.progressionsList2[0])*100;
    vars.SetTextComponent("Slot 3", completionSlot3.ToString()+"%");
}

onStart
{
	timer.IsGameTimePaused = true;
}

start {}

exit
{
    vars.RemoveAllComponents("");
}

split {}
