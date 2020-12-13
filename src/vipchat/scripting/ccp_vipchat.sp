#include UTF-8-string

#pragma newdecls required

#include <vip_core>
#include <ccprocessor>
#include <clientprefs>

public Plugin myinfo = 
{
	name = "[CCP] VIP Chat",
	author = "nullent?",
	description = "Chat features for VIP by user R1KO",
	version = "1.8.5",
	url = "discord.gg/ChTyPUG"
};

StringMap g_mPalette;

int level[BIND_PREFIX];
Cookie coFeatures[BIND_PREFIX];

int g_iBindNow[MAXPLAYERS+1];

StringMap g_mClients[MAXPLAYERS+1];
StringMap g_mItems;

bool g_bLate;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{ 
    g_bLate = late;
    return APLRes_Success
}

public void OnPluginStart()
{    
    LoadTranslations("ccproc.phrases");
    LoadTranslations("vip_ccpchat.phrases");
    LoadTranslations("vip_modules.phrases");

    char szBuffer[NAME_LENGTH];
    ConVar convar;

    for(int i, a; i < BIND_MAX; i++)
    {
        if(IsValidPart(i) != -1)
        {
            FormatBind("ccp_level_", i, 'l', szBuffer, sizeof(szBuffer));

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

    int bind = BindFromString(szName);
    bind = IsValidPart(bind);

    if(bind == -1)
        return;

    level[bind] = convar.IntValue;
}

enum
{
    OFFSET_GroupName = 0, // -> 64
    OFFSET_FeatureName = 65, // -> 128
    OFFSET_Values = 129
};

public void OnMapStart()
{
    cc_proc_APIHandShake(cc_get_APIKey());
    
    delete g_mItems;
    
    static char szConfig[PLATFORM_MAX_PATH] = "data/vip/modules/chat.ini";

    if(szConfig[0] == 'd')
        BuildPath(Path_SM, szConfig, sizeof(szConfig), szConfig);
    
    if(!FileExists(szConfig))
        SetFailState("Where is my config??: %s", szConfig);
    
    KeyValues kv = new KeyValues("vip_chat");
    if(!kv.ImportFromFile(szConfig))
        SetFailState("Failed when import a config: %s", szConfig);
    
    g_mItems = new StringMap();

    if(kv.GotoFirstSubKey())
    {
        char szBuffer[1024];
        int expc;
        int part;
    
        do
        {
            kv.GetSectionName(szBuffer, sizeof(szBuffer));
            szBuffer[OFFSET_FeatureName-1] = 0;

            if(kv.GotoFirstSubKey(false))
            {
                StringMap mParts = new StringMap();
            
                do
                {
                    ArrayList aPartsValues = new ArrayList(PREFIX_LENGTH, 0);

                    kv.GetSectionName(szBuffer[OFFSET_FeatureName], OFFSET_Values - 1);
                    szBuffer[OFFSET_Values - 1] = 0;

                    part = BindFromString(szBuffer[OFFSET_FeatureName]);

                    if(part == BIND_MAX)
                        continue;

                    kv.GetString("", szBuffer[OFFSET_Values], sizeof(szBuffer));
                    expc = ReplaceString(szBuffer[OFFSET_Values], sizeof(szBuffer), ";", ";") + 1;

                    char[][] explode = new char[expc][PREFIX_LENGTH];
                    ExplodeString(szBuffer[OFFSET_Values], ";", explode, expc, PREFIX_LENGTH);

                    for(int i; i < expc; i++)
                        aPartsValues.PushString(explode[i]);
                    
                    mParts.SetValue(szBinds[part], aPartsValues);

                }
                while(kv.GotoNextKey(false));
                
                g_mItems.SetValue(szBuffer[OFFSET_GroupName], mParts);

                kv.GoBack();
            }
        }
        while(kv.GotoNextKey());
    }

    delete kv;

    if(g_bLate) {
        cc_config_parsed();
        for(int i = 1; i <= MaxClients; i++) {
            if(IsClientConnected(i) && !IsClientSourceTV(i)) {
                OnClientPutInServer(i);
                OnClientDisconnect(i);

                if(VIP_IsClientVIP(i)) {
                    VIP_OnVIPClientLoaded(i);
                }
            }
        }

        g_bLate = false;
    }
}

public void cc_config_parsed()
{
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
        
        FormatBind("vip_chat_", i, 'l', szFeature, sizeof(szFeature));

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
        
        FormatBind("vip_chat_", i, 'l', szFeature, sizeof(szFeature));
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
    int iBind = BindFromString(szFeature);

    FormatEx(szDisplay, iMaxLength, "%T [%T]", szFeature, iClient, "empty_value", iClient);

    if(g_mClients[iClient].GetString(szBinds[iBind], szDisplay, iMaxLength))
    {
        if(TranslationPhraseExists(szDisplay)) {
            Format(szDisplay, iMaxLength, "%T", szDisplay, iClient);
        }

        ccp_replaceColors(szDisplay, true);

        Format(szDisplay, iMaxLength, "%T [%s]", szFeature, iClient, szDisplay);
    }

    return true;
}

public void OnClientDisconnect(int iClient)
{
    if(g_mClients[iClient])
        g_mClients[iClient].Clear();
}

public void OnClientPutInServer(int iClient)
{
    g_iBindNow[iClient] = BIND_MAX;

    if(!g_mClients[iClient])
        g_mClients[iClient] = new StringMap();
}

public void VIP_OnVIPClientLoaded(int iClient)
{
    char szFeature[64];

    int idx;

    for(int i; i < BIND_MAX; i++)
    {
        if((idx = IsValidPart(i)) == -1)
            continue;
        
        FormatBind("vip_chat_", i, 'l', szFeature, sizeof(szFeature));

        if(!VIP_IsClientFeatureUse(iClient, szFeature))
            continue;
        
        GetValueFromCookie(iClient, coFeatures[idx], szFeature);
    }
}

void GetValueFromCookie(int iClient, Cookie coHandle, const char[] szFeature)
{
    char szValue[PREFIX_LENGTH], szBuffer[4];
    int iBind = BindFromString(szFeature);

    if(coHandle)
    {
        GetClientCookie(iClient, coHandle, szValue, sizeof(szValue));
        
        if(iBind != BIND_PREFIX && !g_mPalette.GetString(szValue, szBuffer, sizeof(szBuffer)))
            szValue = NULL_STRING;
    }

    if(szValue[0])
        g_mClients[iClient].SetString(szBinds[iBind], szValue);    
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

    int iBind = BindFromString(szFeature);
    if(iBind == BIND_MAX) {
        return hMenu;
    }
        
    ArrayList partValues;
    StringMap map;

    char szBuffer[MESSAGE_LENGTH], szOption[NAME_LENGTH];
    VIP_GetClientVIPGroup(iClient, szBuffer, sizeof(szBuffer));

    if(!g_mItems.GetValue(szBuffer, map))
        return hMenu;
    
    if(!map.GetValue(szBinds[iBind], partValues) || !partValues.Length)
        return hMenu;

    hMenu = new Menu(FeatureMenu_CallBack);

    // SetGlobalTransTarget(iClient);
    hMenu.SetTitle("%T%T \n \n", "feature_title", iClient, szFeature, iClient);

    FormatEx(szBuffer, sizeof(szBuffer), "%c%c%T \n \n", 'r', iBind, "ccp_disable", iClient);

    int iDrawType = (g_mClients[iClient].GetString(szBinds[iBind], szOption, sizeof(szOption)) && szOption[0]) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED;

    hMenu.AddItem(szBuffer, szBuffer[2], iDrawType);

    if(partValues.FindString("custom") != -1)
    {
        FormatEx(szBuffer, sizeof(szBuffer), "%c%T \n \n", 'c', "custom", iClient);
        hMenu.AddItem(szBuffer, szBuffer[1]);
    }

    for(int i; i < partValues.Length; i++)
    {
        szOption = NULL_STRING;

        partValues.GetString(i, szBuffer, sizeof(szBuffer));

        if(!strcmp(szBuffer, "custom"))
            continue;
        
        g_mClients[iClient].GetString(szBinds[iBind], szOption, sizeof(szOption));

        iDrawType = (UTF8StrEqual(szOption, szBuffer)) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT;

        Format(szBuffer, sizeof(szBuffer), "%c%T", i, szBuffer, iClient);

        ccp_replaceColors(szBuffer[1], true);
        
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

            if(idx == 'c')
            {
                // g_bWaitingCustom[iClient] = true;
                g_iBindNow[iClient] = iBind;

                PrintToChat(iClient, "%T", "wait_custom_value", iClient);
                return;
            }

            char szValue[128];

            if(idx != 'r') {

                VIP_GetClientVIPGroup(iClient, szValue, sizeof(szValue));
                
                StringMap map;
                g_mItems.GetValue(szValue, map);

                ArrayList partValues;
                map.GetValue(szBinds[iBind], partValues);

                partValues.GetString(idx, szValue, sizeof(szValue));
                g_mClients[iClient].SetString(szBinds[iBind], szValue);
            } else {
                g_mClients[iClient].Remove(szBinds[iBind]);
            }

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

        g_mClients[iClient].SetString(szBinds[g_iBindNow[iClient]], szBuffer, true);
        
        UpdateCookie(iClient, g_iBindNow[iClient], szBuffer);

        g_iBindNow[iClient] = BIND_MAX;

        PrintToChat(iClient, "%T", "ccp_custom_success", iClient);

        VIP_SendClientVIPMenu(iClient, false);

        return Plugin_Handled;
    }

    return Plugin_Continue;
}

public Action cc_proc_RebuildString(const int mType, int iClient, int &pLevel, const char[] szBind, char[] szBuffer, int iSize)
{
    int a, part = BindFromString(szBind);
    if((a = IsValidPart(part)) == -1)
        return Plugin_Continue;

    else if(mType > eMsg_ALL)
        return Plugin_Continue;
    
    else if(!VIP_IsClientVIP(iClient))
        return Plugin_Continue;
    
    else if(pLevel > level[a])
        return Plugin_Continue;
    
    char szValue[NAME_LENGTH];
    if(!g_mClients[iClient].GetString(szBind, szValue, sizeof(szValue)) || !szValue[0])
        return Plugin_Continue;

    if(part == BIND_PREFIX && TranslationPhraseExists(szValue)) {
        Format(szValue, sizeof(szValue), "%T", szValue, iClient);
    }
    
    pLevel = level[a];
    FormatEx(szBuffer, iSize, szValue);

    return Plugin_Continue;
}

stock int IsValidPart(const int part)
{
    static const int ValidParts[] = {BIND_PREFIX_CO, BIND_PREFIX, BIND_NAME_CO, BIND_MSG_CO};

    for(int i; i < sizeof(ValidParts); i++)
        if(ValidParts[i] == part)
            return i;

    return -1;
}