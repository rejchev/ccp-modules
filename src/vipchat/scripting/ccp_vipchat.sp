#include <UTF-8-string>

#pragma newdecls required

#include <vip_core>
#include <ccprocessor>
#include <clientprefs>
#include <ccprocessor_pkg>
#include <jansson>

public Plugin myinfo = 
{
	name = "[CCP] VIP Chat",
	author = "nullent?",
	description = "Chat features for VIP by user R1KO",
	version = "2.0.0",
	url = "discord.gg/ChTyPUG"
};

ArrayList g_mPalette;

int level[4];
Cookie coFeatures[4];

int g_iBindNow[MAXPLAYERS+1];

bool g_bLate;

static const char pkgKey[] = "vip_chat";

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

    manageConVars();

    if(VIP_IsVIPLoaded())
        VIP_OnVIPLoaded();

    if(g_bLate) {
        ccp_OnPackageAvailable(0, ccp_GetPackage(0));
        cc_config_parsed();

        for(int i = 1; i <= MaxClients; i++) {
            if(IsClientInGame(i) && !IsFakeClient(i) && VIP_IsClientVIP(i)) {
                VIP_OnVIPClientLoaded(i);
            }
        }

        g_bLate = false;
    }
}

void manageConVars(bool bCreate = true) {
    char szBuffer[128];

    for(int i; i < BIND_MAX; i++) {
        if(IsValidPart(i) == -1)
            continue;

        FormatBind("ccp_vip_", i, 'l', szBuffer, sizeof(szBuffer)/2);
        if(bCreate){
            Format(szBuffer[strlen(szBuffer)+1], sizeof(szBuffer), "Priority level for %s", szBinds[i]);
            CreateConVar(szBuffer, "1", szBuffer[strlen(szBuffer)+1], _, true, 1.0).AddChangeHook(onChange);
        } else {
            onChange(FindConVar(szBuffer), NULL_STRING, NULL_STRING);
        }
    }
    
    if(bCreate) {
        AutoExecConfig(true, "ccp_vipchat", "ccprocessor");
    }
}

public void onChange(ConVar convar, const char[] oldVal, const char[] newVal)
{
    char szBuffer[64];
    convar.GetName(szBuffer, sizeof(szBuffer));

    int part = BindFromString(szBuffer);
    if(part == BIND_MAX || (part = IsValidPart(part)) == -1)
        return;
    
    level[part] = convar.IntValue;
}

public void OnMapStart()
{
    cc_proc_APIHandShake(cc_get_APIKey());

    manageConVars(false);

    g_mPalette = null;    
}

public void ccp_OnPackageAvailable(int iClient, Handle objClient) {
    JSONObject pkg = view_as<JSONObject>(objClient);

    if(!iClient) {
        static char szConfig[PLATFORM_MAX_PATH] = "data/vip/modules/chat.json";

        if(szConfig[0] == 'd')
            BuildPath(Path_SM, szConfig, sizeof(szConfig), szConfig);
        
        if(!FileExists(szConfig))
            SetFailState("Where is my config??: %s", szConfig);
        
        pkg.Set(pkgKey, JSONObject.FromFile(szConfig, 0));
    }
}

public void ccp_OnPackageRemove(int iClient, Handle objClient) {
    JSONObject pkg = view_as<JSONObject>(objClient);

    if(!pkg.HasKey(pkgKey)) {
        return;
    }

    JSONObject obj;

    if(!iClient) {
        obj = view_as<JSONObject>(pkg.Get(pkgKey));
        JSONObject sub;
        JSONObjectKeys objKeys = view_as<JSONObjectKeys>(obj);
        char szKey[64];
        while(objKeys.ReadKey(szKey, sizeof(szKey))) {
            sub = view_as<JSONObject>(obj.Get(szKey));
            if(sub)
                delete sub;
        }

        delete objKeys;
        delete obj;

    } else {
        obj = view_as<JSONObject>(pkg.Get(pkgKey));
        if(obj)
            delete obj;
    }

    pkg.Remove(pkgKey);
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

    JSONObject obj = view_as<JSONObject>(ccp_GetPackage(iClient));
    obj = view_as<JSONObject>(obj.Get(pkgKey));

    if(obj && !obj.IsNull(szBinds[iBind]) && obj.GetString(szBinds[iBind], szDisplay, iMaxLength))
    {
        if(TranslationPhraseExists(szDisplay)) {
            Format(szDisplay, iMaxLength, "%T", szDisplay, iClient);
        }

        ccp_replaceColors(szDisplay, true);

        Format(szDisplay, iMaxLength, "%T [%s]", szFeature, iClient, szDisplay);
    }

    return true;
}

public void VIP_OnVIPClientLoaded(int iClient)
{
    char szFeature[64];
    char szGroup[64];
    VIP_GetClientVIPGroup(iClient, szGroup, sizeof(szGroup));

    // int idx;

    JSONObject server = view_as<JSONObject>(ccp_GetPackage(0));
    JSONObject client = view_as<JSONObject>(ccp_GetPackage(iClient));

    for(int i, idx; i < BIND_MAX; i++)
    {
        if((idx = IsValidPart(i)) == -1)
            continue;
        
        FormatBind("vip_chat_", i, 'l', szFeature, sizeof(szFeature));

        if(!VIP_IsClientFeatureUse(iClient, szFeature))
            continue;
        
        client.Set(pkgKey, view_as<JSONObject>(view_as<JSONObject>(server.Get(pkgKey)).Get("model")));
        
        GetValueFromCookie(iClient, view_as<JSONObject>(client.Get(pkgKey)), coFeatures[idx], i);
    }
}

void GetValueFromCookie(int iClient, JSONObject model, Cookie coHandle, const int part) {
    char szValue[PREFIX_LENGTH];

    if(coHandle)
    {
        GetClientCookie(iClient, coHandle, szValue, sizeof(szValue));
        
        if(part != BIND_PREFIX) {
            szValue = NULL_STRING;

            int a = g_mPalette.FindString(szValue);
            if(a != -1)
                g_mPalette.GetString(a+1, szValue, sizeof(szValue));
        }
    }

    if(szValue[0])
        model.SetString(szBinds[part], szValue);    
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

    char szBuffer[MESSAGE_LENGTH], szOption[NAME_LENGTH];
    VIP_GetClientVIPGroup(iClient, szBuffer, sizeof(szBuffer));
    
    JSONObject model = view_as<JSONObject>(view_as<JSONObject>(ccp_GetPackage(iClient)).Get(pkgKey));
    JSONObject pkg = view_as<JSONObject>(view_as<JSONObject>(ccp_GetPackage(0)).Get(pkgKey));
    JSONArray items = view_as<JSONArray>(view_as<JSONObject>(pkg.Get(szBuffer)).Get(szBinds[iBind]));

    if(!items || !items.Length) {
        return hMenu;
    }

    hMenu = new Menu(FeatureMenu_CallBack);

    // SetGlobalTransTarget(iClient);
    hMenu.SetTitle("%T%T \n \n", "feature_title", iClient, szFeature, iClient);

    // FormatEx(szBuffer, sizeof(szBuffer), "%c%c%T \n \n", 'r', iBind, "ccp_disable", iClient);

    // int iDrawType = (g_mClients[iClient].GetString(szBinds[iBind], szOption, sizeof(szOption)) && szOption[0]) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED;

    // hMenu.AddItem(szBuffer, szBuffer[2], iDrawType);

    // if(partValues.FindString("custom") != -1)
    // {
    //     FormatEx(szBuffer, sizeof(szBuffer), "%c%T \n \n", 'c', "custom", iClient);
    //     hMenu.AddItem(szBuffer, szBuffer[1]);
    // }

    char szValue[MESSAGE_LENGTH];
    if(!model.IsNull(szBinds[iBind]) || !model.GetString(szBinds[iBind], szValue, sizeof(szValue))) {
        szValue = NULL_STRING;
    }

    for(int i, a, iDrawType; i < items.Length; i++)
    {
        szOption = NULL_STRING;
        szBuffer = NULL_STRING;
        a = -1;

        items.GetString(i, szBuffer, sizeof(szBuffer));
        
        if(!strcmp(szBuffer, "disable")) {
            iDrawType = (szValue[0]) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED;
            a = 0;
        } else if(!strcmp(szBuffer, "custom")) {
            iDrawType = ITEMDRAW_DEFAULT;
            a = 1;
        } else {
            iDrawType = (!strcmp(szBuffer, szValue)) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT;
        }

        Format(szBuffer, sizeof(szBuffer), "%c%c%T %c%c", iBind, i+1, szBuffer, iClient, (a != -1) ? 10 : 0, (a != -1) ? 10 : 0);

        ccp_replaceColors(szBuffer[1], true);
        
        if(a == -1)
            hMenu.AddItem(szBuffer, szBuffer[2], iDrawType);
        else {
            hMenu.InsertItem(a, NULL_STRING, szBuffer[2], iDrawType);
        }
    } 

    if(hMenu.ItemCount == 1)
    {
        delete hMenu;
        return hMenu;
    }

    hMenu.ExitButton = true;
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

            int part = szOption[0];
            int idx = szOption[1] - 1;

            VIP_GetClientVIPGroup(iClient, szOption, sizeof(szOption));

            JSONObject model = 
                view_as<JSONObject>(
                    view_as<JSONObject>(
                        ccp_GetPackage(iClient)
                    ).Get(pkgKey)
                );

            JSONArray items =
                view_as<JSONArray>(
                    view_as<JSONObject>(
                        view_as<JSONObject>(
                            ccp_GetPackage(0)
                        ).Get(pkgKey)
                    ).Get(szOption)
                );

            items.GetString(idx, szOption, sizeof(szOption));

            if(!strcmp(szOption, "disable")) {
                model.SetNull(szBinds[part]);
                UpdateCookie(iClient, part, NULL_STRING);
                return;
            } else if(!strcmp(szOption, "custom")) {
                g_iBindNow[iClient] = part;

                PrintToChat(iClient, "%T", "wait_custom_value", iClient);
                return;
            }

            model.SetString(szBinds[part], szOption);
            UpdateCookie(iClient, part, szOption);

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

        if(g_iBindNow[iClient] != BIND_PREFIX && g_mPalette.FindString(szBuffer) == -1)
        {
            BreakPoint(g_iBindNow[iClient], szBuffer);
            PrintToChat(iClient, "%T", "invalid_color_value", iClient, szBuffer);

            return Plugin_Handled;
        }

        JSONObject model = 
            view_as<JSONObject>(
                view_as<JSONObject>(
                    ccp_GetPackage(iClient)
                ).Get(pkgKey)
            );
        
        model.SetString(szBinds[g_iBindNow[iClient]], szBuffer);

        UpdateCookie(iClient, g_iBindNow[iClient], szBuffer);

        g_iBindNow[iClient] = BIND_MAX;

        PrintToChat(iClient, "%T", "ccp_custom_success", iClient);

        VIP_SendClientVIPMenu(iClient, false);

        return Plugin_Handled;
    }

    return Plugin_Continue;
}

JSONObject senderModel;

public void cc_proc_MsgUniqueId(int mType, int sender, int msgId, const int[] clients, int count) {
    if(mType > eMsg_ALL || !sender)
        return;
    
    senderModel = 
        view_as<JSONObject>(
            view_as<JSONObject>(
                ccp_GetPackage(sender)
            ).Get(pkgKey)
        );
}

public Action cc_proc_RebuildString(const int mType, int sender, int recipient, int part, int &pLevel, char[] buffer, int size)
{
    if(mType > eMsg_ALL || !sender || !VIP_IsClientVIP(sender)) {
        return Plugin_Continue;
    }

    int idx = IsValidPart(part);
    if(idx == -1) {
        return Plugin_Continue;
    }

    if(level[idx] < pLevel) {
        return Plugin_Continue;
    }
    
    if(!senderModel || senderModel.IsNull(szBinds[part])) {
        return Plugin_Continue;
    }

    static char szValue[MESSAGE_LENGTH];
    senderModel.GetString(szBinds[part], szValue, sizeof(szValue));

    if(!szValue[0]) {
        return Plugin_Continue;
    }

    if(part == BIND_PREFIX) {
        Format(szValue, sizeof(szValue), "%T", szValue, recipient);
    }

    pLevel = level[idx];
    FormatEx(buffer, size, szValue);

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