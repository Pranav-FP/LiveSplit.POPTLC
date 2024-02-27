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

    vars.RemoveAmuletComponents = (Action<string>)((id) => {
        vars.RemoveTextComponent(@"BonusModifier\d+:");
        vars.RemoveTextComponent(@"Amulet\d+:");
        vars.RemoveTextComponent(@"AttackType\d+:");
        vars.RemoveTextComponent(@"BonusCondition\d+:");
    });

    vars.RemoveAllComponents = (Action<string>)((id) => {
        vars.RemoveAmuletComponents("");
        vars.RemoveTextComponent("Extra Athra.*");
        vars.RemoveTextComponent("Slots$");
        vars.RemoveTextComponent("----Amulet Viewer Loaded----");
    });

    vars.AmuletMapping = new Dictionary<int, string>
    {
        {1, "White Peacock"},
        {5, "Will of Rostam"},
        {6, "Indomitable Spirit"},
        {9, "Four Royal Stars"},
        {11, "Arash's Arrowhead"},
        {18, "Starving Heart"},
        {24, "Arslân's Glory"},
        {26, "Evil Eye"},
        {28, "Turning Wind"},
    };
    
    vars.ConditionMapping = new Dictionary<int, string>
    {
        {0, "Always"},
        {1, "Full HP"},
        {2, "Low HP"},
    };

    vars.GetAttackList = (Func<int, string>)((attackValue) =>
    {
        string attackList = "";
        if (attackValue >= 64) {
            attackList += "Dodge, ";
            attackValue -= 64;
        }
        if (attackValue >= 32) {
            attackList += "Chakram, ";
            attackValue -= 32;
        }
        if (attackValue >= 16) {
            attackList += "Arrows, ";
            attackValue -= 16;
        }
        if (attackValue >= 8) {
            attackList += "Arthras, ";
            attackValue -= 8;
        }
        if (attackValue >= 4) {
            attackList += "Aerial, ";
            attackValue -= 4;
        }
        if (attackValue >= 2) {
            attackList += "Charge, ";
            attackValue -= 2;
        }
        if (attackValue >= 1) {
            attackList += "Ground, ";
            attackValue -= 1;
        }
        return attackList.TrimEnd(' ').TrimEnd(',');
    });
}

init
{
    vars.RemoveAllComponents("");
    vars.SetTextComponent("Loading Amulet Viewer......", "");
    vars.states = null;
    current.isChangingLevel = false;

    // hardcoding some offsets which we can't get dynamically
    var LINKED_LIST_COUNT_OFFSET = 0x18;
    var LINKED_LIST_HEAD_OFFSET = 0x10;
    var LINKED_LIST_NODE_NEXT_OFFSET = 0x18;
    var LINKED_LIST_NODE_VALUE_OFFSET = 0x28;
    var ARRAY_ELEMENTS_OFFSET = 0x20;

    // not sure if the names are accurate but this is based on what I saw in memory
    var CLASS_OFFSET = 0x0;
    var CLASS_NAME_OFFSET = 0x10;
    
    vars.GetClassNameOfInstance = (Func<IntPtr, bool, string>)((instance, isDereffed) =>
    {
        DeepPointer p;

        if (isDereffed)
        {
            p = new DeepPointer(
                instance + CLASS_OFFSET,
                CLASS_NAME_OFFSET,
                0x0
            );
        } else {
            p = new DeepPointer(
                instance,
                CLASS_OFFSET,
                CLASS_NAME_OFFSET,
                0x0
            );
        }
        
        // this is an ascii string so can't use the asl-help func
        return p.DerefString(game, ReadStringType.ASCII, 128);
    });

    vars.Helper.TryLoad = (Func<dynamic, bool>)(mono =>
    {
        // asl-help has this issue where sometimes offsets resolve to 0x10 less than what they are meant to be
        // this is a fix to that...
        var PAD = 0x10;
        
        var LM = mono["Alkawa.Gameplay", "LootManager", 1];
        var PSOKSI = mono["Alkawa.Gameplay", "PlayerStoneOfKnowledgeStateInfo"];
        var SDBD = mono["Alkawa.Gameplay", "StoneDamageBonusData"];

        vars.Helper["bonusDamage"] = LM.MakeList<IntPtr>(
            "m_instance",
            LM["m_playerStoneOfKnowledgeStateInfo"] + PAD,
            PSOKSI["m_bonusDatas"] + PAD
        );

        vars.Helper["extraArthaDamage"] = LM.Make<int>(
            "m_instance",
            LM["m_playerStoneOfKnowledgeStateInfo"] + PAD,
            PSOKSI["m_focusAttackDamageBonusPercent"] + PAD
        );

        vars.Helper["extraArthaGain"] = LM.Make<float>(
            "m_instance",
            LM["m_playerStoneOfKnowledgeStateInfo"] + PAD,
            PSOKSI["m_focusBonusPercentComboMelee"] + PAD
        );

        vars.Helper["slotsUsed"] = LM.Make<int>(
            "m_instance",
            LM["m_playerStoneOfKnowledgeStateInfo"] + PAD,
            PSOKSI["m_currentStonePoints"] + PAD
        );

        vars.Helper["maxSlots"] = LM.Make<int>(
            "m_instance",
            LM["m_playerStoneOfKnowledgeStateInfo"] + PAD,
            PSOKSI["m_maxStonePoints"] + PAD
        );

        vars.Helper["incomingMeleeReduction"] = LM.Make<int>(
            "m_instance",
            LM["m_playerStoneOfKnowledgeStateInfo"] + PAD,
            PSOKSI["m_meleeDamageReduction"] + PAD
        );

        vars.ReadBonusData = (Func<IntPtr, dynamic>)(bonusData =>
        {
            dynamic ret = new ExpandoObject();
            ret.BonusType = vars.Helper.Read<int>(bonusData + SDBD["m_attackBonusType"] + PAD);
            ret.AttackType = vars.Helper.Read<int>(bonusData + SDBD["m_attackType"] + PAD);
            ret.Bonus = vars.Helper.Read<int>(bonusData + SDBD["m_bonus"] + PAD);
            ret.BonusCondition = vars.Helper.Read<int>(bonusData + SDBD["m_condition"] + PAD);
            ret.Amulet = vars.Helper.Read<int>(bonusData + SDBD["m_stone"] + PAD);
            return ret;
        });

        vars.RemoveTextComponent("Loading Amulet Viewer......");
        return true;
    });
}

update
{
    vars.SetTextComponent("----Amulet Viewer Loaded----", "");
    vars.SetTextComponent("Total Slots", current.maxSlots.ToString());
    vars.SetTextComponent("Used Slots", current.slotsUsed.ToString());
    vars.SetTextComponent("Extra Athra Damage", current.extraArthaDamage.ToString()+"%");
    vars.SetTextComponent("Extra Athra Gain", current.extraArthaGain.ToString()+"%");
    if (current.bonusDamage.Count != vars.oldBonusDamageCount) {
        vars.RemoveAmuletComponents("");
    }
    for (int index = 0; index < current.bonusDamage.Count; index++) {
        string condition = "Unknown";
        var bonusData = vars.ReadBonusData(current.bonusDamage[index]);
        string amuletString = vars.AmuletMapping.TryGetValue(bonusData.Amulet, out condition) ? condition : "Unknown, ID - "+bonusData.Amulet.ToString();
        vars.SetTextComponent("Amulet"+index+":", amuletString);
        string BonusModifier = bonusData.BonusType == 0 ? (bonusData.Bonus > 0 ? "+"+bonusData.Bonus.ToString() : bonusData.Bonus.ToString()) : "x"+((float)bonusData.Bonus/100).ToString();
        vars.SetTextComponent("BonusModifier"+index+":", BonusModifier);
        string conditionString = vars.ConditionMapping.TryGetValue(bonusData.BonusCondition, out condition) ? condition : "Unknown, ID - "+bonusData.BonusCondition.ToString();
        vars.SetTextComponent("BonusCondition"+index+":", conditionString);
        string attackList = vars.GetAttackList(bonusData.AttackType);
        vars.SetTextComponent("AttackType"+index+":", attackList);

        vars.oldBonusDamageCount = current.bonusDamage.Count;
    }
}

onStart
{
	timer.IsGameTimePaused = true;
    
    // refresh all splits when we start the run, none are yet completed
    vars.CompletedSplits.Clear();
    vars.SeenQuests.Clear();
}

start {}

exit
{
    vars.RemoveAllComponents("");
}

split {}
