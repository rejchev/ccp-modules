#include UTF-8-string

#pragma newdecls required

#include vip_core
#include ccprocessor
#include clientprefs

public Plugin myinfo = 
{
	name = "[CCP] VIP Chat",
	author = "nullent?",
	description = "Chat features for VIP by user R1KO",
	version = "1.8.3",
	url = "discord.gg/ChTyPUG"
};

StringMap g_mPalette;

int level[BIND_PREFIX];
Cookie coFeatures[BIND_PREFIX];

int g_iBindNow[MAXPLAYERS+1];

enum struct Items
{
    StringMap m_mFeatures;

    any GetChildMap(const char[] szFeature = NULL_STRING, const char[] szGroup = NULL_STRING)
    {
        any value;

        // null
        if(!szFeature[0])
            return value;
        
        // null
        if(!this.m_mFeatures.GetValue(szFeature, value))
            return value;
        
        // StringMap or null
        if(!szGroup[0])
            return value;
        
        // null
        if(!view_as<StringMap>(value).GetValue(szGroup, value))
            return 0;
        
        // ArrayList or null
        return value;        
    }

    bool WriteItem(const char[] szFeature, const char[] szGroup = NULL_STRING, any value)
    {
        bool success;

        if(!szGroup[0]) success = this.m_mFeatures.SetValue(szFeature, value, true);
        else
        {
            StringMap map = this.GetChildMap(szFeature);

            if(map) success = map.SetValue(szGroup, value, true);
        }

        return success;
    }

    void Reset()
    {
        this.m_mFeatures.Clear();
    }

    void Init()
    {
        this.m_mFeatures = new StringMap();
    }
}

Items g_IFeatures;

enum struct ClientTemplate
{
    StringMap m_mTemplate;

    char m_szVIPGroup[PREFIX_LENGTH];

    bool IsValidTemplate()
    {
        return this.m_mTemplate != null;
    }

    void InitTemplate()
    {
        if(!this.IsValidTemplate())
            this.m_mTemplate = new StringMap();
        
        else this.m_mTemplate.Clear();
    }

    void Reset()
    {
        this.m_szVIPGroup[0] = 0;
        delete this.m_mTemplate;
    }

    bool GetValue(const char[] szBind, char[] szValue, int size)
    {
        return this.IsValidTemplate() && this.m_mTemplate.GetString(szBind, szValue, size);
    }

    bool SetValue(const char[] szBind, const char[] newValue)
    {
        return this.IsValidTemplate() && this.m_mTemplate.SetString(szBind, newValue, true);
    }

    bool GetValueEx(int iClient, const char[] szBind, char[] szValue, int size)
    {
        bool bFound = this.GetValue(szBind, szValue, size);

        if(bFound && !strcmp(szBind, szBinds[BIND_PREFIX]) && TranslationPhraseExists(szValue))
            Format(szValue, size, "%T", szValue, iClient);

        return bFound; 
    }

    bool GetTranslation(int iClient, const char[] szBind, char[] szValue, int size)
    {
        bool bFound = this.GetValue(szBind, szValue, size);

        if(!bFound)
            return false;

        if((bFound = TranslationPhraseExists(szValue)))        
            Format(szValue, size, "%T", szValue, iClient);

        return bFound;
    }

    // Comparison of two keys
    bool IsPartEqual(const char[] szBind, const char[] szValue)
    {
        char szBuffer[NAME_LENGTH];

        if(!this.IsValidTemplate())
            return false;
        
        else if(!this.GetValue(szBind, szBuffer, sizeof(szBuffer)))
            return false;
        
        return StrEqual(szBuffer, szValue);
    }

    void Remove(const char[] key)
    {
        this.m_mTemplate.Remove(key);
    }
}

ClientTemplate tempClient[MAXPLAYERS+1];

public void OnPluginStart()
{    
    LoadTranslations("ccproc.phrases");
    LoadTranslations("vip_ccpchat.phrases");
    LoadTranslations("vip_modules.phrases");

    g_IFeatures.Init();

    char szBuffer[NAME_LENGTH];
    ConVar convar;

    for(int i, a; i < BIND_MAX; i++)
    {
        if(IsValidPart(i) != -1)
        {
            strcopy(szBuffer, sizeof(szBuffer), szBinds[i]);

            ReplaceString(szBuffer, sizeof(szBuffer), "{", "");
            ReplaceString(szBuffer, sizeof(szBuffer), "}", "");

            Format(szBuffer, sizeof(szBuffer), "ccp_level_%s", szBuffer);

            (convar = CreateConVar(szBuffer, "1", "Priority level", _, true, 0.0)).AddChangeHook(OnLevelsChanged);
            level[a++] = convar.IntValue;
        }
    }

    AutoExecConfig(true, "ccp_vipchat", "ccprocessor");

    if(VIP_IsVIPLoaded())
        VIP_OnVIPLoaded();
}

public void OnLevelsChanged(ConVar convar, const char[] oldVal, const char[] newVal)
{
    char szName[NAME_LENGTH];
    convar.GetName(szName, sizeof(szName));
    Format(szName, sizeof(szName), "{%s}", szName[FindCharInString(szName, '_', true)]);

    int bind = BindAsNum(szName);
    bind = IsValidPart(bind);

    if(bind == -1)
        return;

    level[bind] = convar.IntValue;
}

enum
{
    OFFSET_FeatureName = 0,
    OFFSET_GroupName = 65,
    OFFSET_Values = 129
};

public void OnMapStart()
{
    cc_proc_APIHandShake(cc_get_APIKey());

    static char szConfig[PLATFORM_MAX_PATH] = "data/vip/modules/chat.ini";

    g_IFeatures.Reset();

    if(szConfig[0] == 'd')
        BuildPath(Path_SM, szConfig, sizeof(szConfig), szConfig);
    
    if(!FileExists(szConfig))
        SetFailState("Where is my config??: %s", szConfig);
    
    KeyValues kv = new KeyValues("vip_chat");
    if(!kv.ImportFromFile(szConfig))
        SetFailState("Failed when import a config: %s", szConfig);
    
    if(kv.GotoFirstSubKey())
    {
        int expc;
        char szBuffer[1024];
        ArrayList aBuffer;

        do
        {
            kv.GetSectionName(szBuffer, OFFSET_GroupName - 1);
            szBuffer[OFFSET_GroupName-1] = 0;

            g_IFeatures.WriteItem(szBuffer[OFFSET_FeatureName], NULL_STRING, new StringMap());

            if(kv.GotoFirstSubKey(false))
            {
                do
                {
                    aBuffer = new ArrayList(PREFIX_LENGTH, 0);

                    kv.GetSectionName(szBuffer[OFFSET_GroupName], OFFSET_GroupName - 1);
                    szBuffer[OFFSET_Values - 1] = 0;

                    kv.GetString("", szBuffer[OFFSET_Values], sizeof(szBuffer));
                    expc = ReplaceString(szBuffer[OFFSET_Values], sizeof(szBuffer), ";", ";") + 1;

                    char[][] explode = new char[expc][PREFIX_LENGTH];
                    ExplodeString(szBuffer[OFFSET_Values], ";", explode, expc, PREFIX_LENGTH);

                    for(int i; i < expc; i++)
                        aBuffer.PushString(explode[i]);
                    
                    g_IFeatures.WriteItem(szBuffer, szBuffer[OFFSET_GroupName], aBuffer);

                }
                while(kv.GotoNextKey(false));

                kv.GoBack();
            }
        }
        while(kv.GotoNextKey());
    }

    delete kv;

    if(!g_mPalette)
        g_mPalette = cc_drop_palette();
}

public void VIP_OnVIPLoaded()
{
    char szFeature[64];
    int part;

    for(int i; i < BIND_MAX; i++)
    {
        if((part = IsValidPart(i)) == -1)
            continue;
        
        BindAsFeature(szBinds[i], szFeature, sizeof(szFeature));

        coFeatures[part] = new Cookie(szFeature, NULL_STRING, CookieAccess_Private);

        VIP_RegisterFeature(szFeature, INT, SELECTABLE, OnSelected_Feature, OnDisplay_Feature);
    }
}

public void OnPluginEnd()
{
    if(!CanTestFeatures() || GetFeatureStatus(FeatureType_Native, "VIP_UnregisterFeature") != FeatureStatus_Available)
        return;
    
    char szFeature[64];

    for(int i; i < BIND_MAX; i++)
    {
        if(IsValidPart(i) == -1)
            continue;
        
        BindAsFeature(szBinds[i], szFeature, sizeof(szFeature));
        VIP_UnregisterFeature(szFeature);
    }
}

public bool OnSelected_Feature(int iClient, const char[] szFeature)
{
    // g_bWaitingCustom[iClient] = false;
    g_iBindNow[iClient] = BIND_MAX;

    Menu hMenu = FeatureMenu(iClient, szFeature);
    if(hMenu)   hMenu.Display(iClient, MENU_TIME_FOREVER);

    return false;
}

public bool OnDisplay_Feature(int iClient, const char[] szFeature, char[] szDisplay, int iMaxLength)
{
    int iBind = FeatureAsNum(szFeature);

    FormatEx(szDisplay, iMaxLength, "%T [%T]", szFeature, iClient, "empty_value", iClient);

    if(tempClient[iClient].GetValue(szBinds[iBind], szDisplay, iMaxLength))
    {
        if(!tempClient[iClient].GetTranslation(iClient, szBinds[iBind], szDisplay, iMaxLength) && iBind != BIND_PREFIX)
            SetFailState("Unknown color value: %s", szDisplay);

        cc_clear_allcolors(szDisplay, iMaxLength);

        Format(szDisplay, iMaxLength, "%T [%s]", szFeature, iClient, szDisplay);
    }

    return true;
}

public void OnClientDisconnect(int iClient)
{
    tempClient[iClient].Reset();
}

public void OnClientPutInServer(int iClient)
{
    g_iBindNow[iClient] = BIND_MAX;
}

public void VIP_OnVIPClientLoaded(int iClient)
{
    VIP_GetClientVIPGroup(iClient, tempClient[iClient].m_szVIPGroup, sizeof(tempClient[].m_szVIPGroup));

    char szFeature[64];

    int idx;

    tempClient[iClient].InitTemplate();

    for(int i; i < BIND_MAX; i++)
    {
        if((idx = IsValidPart(i)) == -1)
            continue;
        
        BindAsFeature(szBinds[i], szFeature, sizeof(szFeature));

        if(!VIP_IsClientFeatureUse(iClient, szFeature))
            continue;
        
        GetValueFromCookie(iClient, coFeatures[idx], szFeature);
    }
}

void GetValueFromCookie(int iClient, Cookie coHandle, const char[] szFeature)
{
    char szValue[PREFIX_LENGTH], szBuffer[4];
    int iBind = FeatureAsNum(szFeature);

    if(coHandle)
    {
        GetClientCookie(iClient, coHandle, szValue, sizeof(szValue));
        
        if(iBind != BIND_PREFIX && !g_mPalette.GetString(szValue, szBuffer, sizeof(szBuffer)))
            szValue = NULL_STRING;
    }

    if(szValue[0])
        tempClient[iClient].SetValue(szBinds[iBind], szValue);    
}

void UpdateCookie(int iClient, int iIdx, const char[] newValue)
{
    iIdx = IsValidPart(iIdx);
    if(iIdx == -1)
        return;
    
    SetClientCookie(iClient, coFeatures[iIdx], newValue);
}

Menu FeatureMenu(int iClient, const char[] szFeature)
{
    Menu hMenu;
    int iBind = FeatureAsNum(szFeature);
    ArrayList aValues = g_IFeatures.GetChildMap(szFeature, tempClient[iClient].m_szVIPGroup);
    
    if(!aValues)
        return hMenu;

    hMenu = new Menu(FeatureMenu_CallBack);

    // SetGlobalTransTarget(iClient);
    hMenu.SetTitle("%T%T \n \n", "feature_title", iClient, szFeature, iClient);

    char szBuffer[MESSAGE_LENGTH], szOption[NAME_LENGTH];
    FormatEx(szBuffer, sizeof(szBuffer), "%c%c%T \n \n", 'r', iBind, "ccp_disable", iClient);

    int iDrawType = (tempClient[iClient].GetValue(szBinds[iBind], szOption, sizeof(szOption))) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED;

    hMenu.AddItem(szBuffer, szBuffer[2], iDrawType);

    if(aValues.FindString("custom") != -1)
    {
        FormatEx(szBuffer, sizeof(szBuffer), "%c%T \n \n", 'c', "custom", iClient);
        hMenu.AddItem(szBuffer, szBuffer[1]);
    }

    for(int i; i < aValues.Length; i++)
    {
        aValues.GetString(i, szBuffer, sizeof(szBuffer));

        if(!strcmp(szBuffer, "custom"))
            continue;
        
        iDrawType = (tempClient[iClient].IsPartEqual(szFeature, szBuffer)) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT;

        Format(szBuffer, sizeof(szBuffer), "%c%T", i, szBuffer, iClient);

        cc_clear_allcolors(szBuffer[1], sizeof(szBuffer));
        
        hMenu.AddItem(szBuffer, szBuffer[1], iDrawType);
    } 

    if(hMenu.ItemCount == 1)
    {
        delete hMenu;
        return hMenu;
    }

    hMenu.ExitButton = false;
    hMenu.ExitBackButton = true;

    return hMenu; 
}

public int FeatureMenu_CallBack(Menu hMenu, MenuAction action, int iClient, int iOpt2)
{
    switch(action)
    {
        case MenuAction_End: delete hMenu;
        case MenuAction_Cancel:
        {
            if(iOpt2 == MenuCancel_ExitBack)
            {
                VIP_SendClientVIPMenu(iClient, false);
            }
        }
        case MenuAction_Select:
        {
            char szOption[NAME_LENGTH];
            
            hMenu.GetItem(iOpt2, szOption, sizeof(szOption));

            char idx = szOption[0];

            hMenu.GetItem(0, szOption, sizeof(szOption));

            int iBind = szOption[1];

            BindAsFeature(szBinds[iBind], szOption, sizeof(szOption));

            if(idx == 'c')
            {
                // g_bWaitingCustom[iClient] = true;
                g_iBindNow[iClient] = iBind;

                PrintToChat(iClient, "%T", "wait_custom_value", iClient);
                return;
            }

            char szValue[64];

            if(idx != 'r')
                view_as<ArrayList>(g_IFeatures.GetChildMap(szOption, tempClient[iClient].m_szVIPGroup)).GetString(idx, szValue, sizeof(szValue));

            if(idx != 'r')
                tempClient[iClient].SetValue(szBinds[iBind], szValue);
            else tempClient[iClient].Remove(szBinds[iBind]);

            UpdateCookie(iClient, iBind, szValue);

            VIP_SendClientVIPMenu(iClient, false);
        }
    }
}

public Action OnClientSayCommand(int iClient, const char[] command, const char[] args)
{
    if(!IsClientInGame(iClient) || IsFakeClient(iClient) || IsChatTrigger())
        return Plugin_Continue;

    if(g_iBindNow[iClient] != BIND_MAX)
    {
        char szBuffer[MESSAGE_LENGTH];
        strcopy(szBuffer, sizeof(szBuffer), args);

        TrimString(szBuffer);

        if(g_iBindNow[iClient] != BIND_PREFIX && !g_mPalette.GetString(szBuffer, szBuffer[STATUS_LENGTH+1], STATUS_LENGTH))
        {
            BreakPoint(g_iBindNow[iClient], szBuffer);
            PrintToChat(iClient, "%T", "invalid_color_value", iClient, szBuffer);

            return Plugin_Handled;
        }

        tempClient[iClient].SetValue(szBinds[g_iBindNow[iClient]], szBuffer);
        
        UpdateCookie(iClient, g_iBindNow[iClient], szBuffer);

        g_iBindNow[iClient] = BIND_MAX;

        PrintToChat(iClient, "%T", "ccp_custom_success", iClient);

        VIP_SendClientVIPMenu(iClient, false);

        return Plugin_Handled;
    }

    return Plugin_Continue;
}

public void cc_proc_RebuildString(const int mType, int iClient, int &pLevel, const char[] szBind, char[] szBuffer, int iSize)
{
    int part = BindAsNum(szBind);
    if((part = IsValidPart(part)) == -1)
        return;

    else if(mType > eMsg_ALL)
        return;
    
    else if(!VIP_IsClientVIP(iClient))
        return;
    
    else if(pLevel > level[part])
        return;
    
    char szValue[NAME_LENGTH];
    if(!tempClient[iClient].GetValueEx(iClient, szBind, szValue, sizeof(szValue)))
        return;
    
    pLevel = level[part];
    FormatEx(szBuffer, iSize, szValue);
}

stock void BindAsFeature(const char[] szBind, char[] szFeature, int size)
{
    strcopy(szFeature, size, szBind);

    ReplaceString(szFeature, size, "{", "", true);
    ReplaceString(szFeature, size, "}", "", true);

    for(int i; i < strlen(szFeature); i++)
        szFeature[i] = CharToLower(szFeature[i]);

    Format(szFeature, size, "vip_chat_%s", szFeature);    
}

stock int FeatureAsBind(const char[] szFeature, char[] szBind, int size)
{
    strcopy(szBind, size, szFeature[9]);

    for(int i; i < strlen(szBind); i++)
        szBind[i] = CharToUpper(szBind[i]);
    
    Format(szBind, size, "{%s}", szBind);

    return BindAsNum(szBind);
}

stock int FeatureAsNum(const char[] szFeature)
{
    char szBind[16];

    return FeatureAsBind(szFeature, szBind, sizeof(szBind));
}

stock int BindAsNum(const char[] szBind)
{
    for(int i; i < BIND_MAX; i++)
        if(StrEqual(szBind, szBinds[i]))
            return i;
    
    return BIND_MAX;
}

stock int IsValidPart(const int part)
{
    static const int ValidParts[] = {BIND_PREFIX_CO, BIND_PREFIX, BIND_NAME_CO, BIND_MSG_CO};

    for(int i; i < sizeof(ValidParts); i++)
        if(ValidParts[i] == part)
            return i;

    return -1;
}