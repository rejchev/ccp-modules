#pragma newdecls required

#define INCLUDE_RIPJSON

#include <vip_core>
#include <ccprocessor>
#include <clientprefs>

public Plugin myinfo = 
{
	name = "[CCP] Custom Chat <VIP>",
	author = "nyood",
	description = "...",
	version = "2.0.7",
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
    LoadTranslations("ccp_core.phrases");
    LoadTranslations("vip_ccpchat.phrases");
    LoadTranslations("vip_modules.phrases");

    manageConVars();

    if(VIP_IsVIPLoaded())
        VIP_OnVIPLoaded();

    if(g_bLate) {
        ccp_OnPackageAvailable(0);
        cc_config_parsed();

        for(int i = 1; i <= MaxClients; i++) {
            OnClientPutInServer(i);
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
}

public void ccp_OnPackageAvailable(int iClient) {
    if(iClient)
        return;
    
    static char szConfig[PLATFORM_MAX_PATH] = "data/vip/modules/chat.json";

    if(szConfig[0] == 'd')
        BuildPath(Path_SM, szConfig, sizeof(szConfig), szConfig);
    
    if(!FileExists(szConfig))
        SetFailState("Where is my config??: %s", szConfig);
    
    JSONObject objFile = JSONObject.FromFile(szConfig, 0);

    ccp_SetArtifact(iClient, pkgKey, objFile, CALL_IGNORE);

    delete objFile;
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

        VIP_RegisterFeature(szFeature, INT, SELECTABLE, OnSelected_Feature, OnDisplay_Feature, OnDraw_Feature);
    }
}

public void OnPluginEnd()
{
    if(!CanTestFeatures() 
    || GetFeatureStatus(FeatureType_Native, "VIP_UnregisterFeature") != FeatureStatus_Available)
        return;

    VIP_UnregisterMe();
}

public bool OnSelected_Feature(int iClient, const char[] szFeature)
{
    g_iBindNow[iClient] = BIND_MAX;

    FeatureMenu(iClient, szFeature).Display(iClient, MENU_TIME_FOREVER);
    return false;
}

public bool OnDisplay_Feature(int iClient, const char[] szFeature, char[] szDisplay, int iMaxLength)
{
    int iBind = BindFromString(szFeature);
    FormatEx(szDisplay, iMaxLength, "%T [%T]", szFeature, iClient, "empty_value", iClient);

    if(!ccp_HasArtifact(iClient, pkgKey))
        return true;

    JSONObject artifact = asJSONO(ccp_GetArtifact(iClient, pkgKey));

    if(IsPartValid(artifact, iBind) && artifact.GetString(szBinds[iBind], szDisplay, iMaxLength))
    {
        if(TranslationPhraseExists(szDisplay)) {
            Format(szDisplay, iMaxLength, "%T", szDisplay, iClient);
        }

        ccp_replaceColors(szDisplay, true);

        Format(szDisplay, iMaxLength, "%T [%s]", szFeature, iClient, szDisplay);
    }

    delete artifact;

    return true;
}

public int OnDraw_Feature(int iClient, const char[] szFeature, int iStyle) {
    char szBuffer[MESSAGE_LENGTH];
    VIP_GetClientVIPGroup(iClient, szBuffer, sizeof(szBuffer));

    JSONObject artifact = asJSONO(ccp_GetArtifact(0, pkgKey));

    int iDrawType = ITEMDRAW_DEFAULT;

    if(artifact.HasKey(szBuffer) && !artifact.IsNull(szBuffer)) {
        JSONObject group = asJSONO(artifact.Get(szBuffer));
        delete artifact;

        if(group.HasKey(szFeature) && !group.IsNull(szFeature)) {
            JSONArray list = asJSONA(group.Get(szFeature));
            delete group;

            if(list.Length) {
                delete list;
                return iDrawType;
            }

            delete list;
        }        

        delete group;
    }

    delete artifact;

    iDrawType = ITEMDRAW_DISABLED;
    
    return iDrawType;
}

public void VIP_OnVIPClientLoaded(int iClient)
{
    char szGroup[64];
    char szFeature[64];
    VIP_GetClientVIPGroup(iClient, szGroup, sizeof(szGroup));

    JSONObject model = new JSONObject();

    for(int i, idx; i < BIND_MAX; i++)
    {
        if((idx = IsValidPart(i)) == -1)
            continue;
        
        FormatBind("vip_chat_", i, 'l', szFeature, sizeof(szFeature));

        if(!VIP_IsClientFeatureUse(iClient, szFeature)){
            model.SetNull(szBinds[i]);
            continue;
        }
        
        GetValueFromCookie(iClient, model, coFeatures[idx], i);
    }

    ccp_SetArtifact(iClient, pkgKey, model, CALL_DEFAULT);
    delete model;
}

void GetValueFromCookie(int iClient, JSONObject model, Cookie coHandle, const int part) {
    char szValue[MESSAGE_LENGTH];

    if(coHandle)
    {
        GetClientCookie(iClient, coHandle, szValue, sizeof(szValue));
        
        if(part != BIND_PREFIX && g_mPalette.FindString(szValue) == -1) {
            szValue = NULL_STRING;
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

    g_iBindNow[iClient] = BIND_MAX;

    int iBind = BindFromString(szFeature);
    if(iBind == BIND_MAX) {
        return hMenu;
    }

    char szBuffer[MESSAGE_LENGTH], szOption[NAME_LENGTH];
    VIP_GetClientVIPGroup(iClient, szBuffer, sizeof(szBuffer));
    
    JSONObject model;
    if((model = asJSONO(ccp_GetArtifact(iClient, pkgKey))) == null) {
        FormatEx(szBuffer, sizeof(szBuffer), "%T", "wrong_artifact", iClient);
        PrintToChat(iClient, "%T", "something_wrong", iClient, szBuffer);

        return hMenu;
    }

    JSONObject pkg;
    if((pkg = asJSONO(ccp_GetArtifact(0, pkgKey))) == null) {
        FormatEx(szBuffer, sizeof(szBuffer), "%T", "wrong_internal", iClient);
        PrintToChat(iClient, "%T", "something_wrong", iClient, szBuffer);
        
        delete model;
        return hMenu;
    }

    JSONObject group;
    if(!pkg.HasKey(szBuffer) || (group = asJSONO(pkg.Get(szBuffer))) == null) {
        Format(szBuffer, sizeof(szBuffer), "%T", "wrong_group", iClient, szBuffer);
        PrintToChat(iClient, "%T", "something_wrong", iClient, szBuffer);

        delete model;
        delete pkg;
        return hMenu;
    }

    JSONArray items;
    if(!group.HasKey(szBuffer) || (items = asJSONA(group.Get(szBinds[iBind]))) == null) {
        FormatEx(szBuffer, sizeof(szBuffer), "%T", szBinds[iBind], iClient);
        Format(szBuffer, sizeof(szBuffer), "%T", "wrong_items", iClient, szBuffer);
        PrintToChat(iClient, "%T", "something_wrong", iClient, szBuffer);

        delete model;
        delete group;
        delete pkg;

        return hMenu;
    }

    delete group;

    hMenu = new Menu(FeatureMenu_CallBack);
    hMenu.SetTitle("%T%T \n \n", "feature_title", iClient, szFeature, iClient);

    char szValue[MESSAGE_LENGTH];
    if(!IsPartValid(model, iBind) || !model.GetString(szBinds[iBind], szValue, sizeof(szValue))) {
        szValue = NULL_STRING;
    }

    for(int i, a, iDrawType; i < items.Length; i++)
    {
        szOption = NULL_STRING;
        szBuffer = NULL_STRING;
        a = -1;

        items.GetString(i, szBuffer, sizeof(szBuffer));
        
        if(StrContains(szBuffer, "disable", false) != -1) {
            iDrawType = (szValue[0]) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED;
            a = 0;
        } else if(StrContains(szBuffer, "custom", false) != -1) {
            iDrawType = ITEMDRAW_DEFAULT;
            a = 1;
        } else {
            iDrawType = (!strcmp(szBuffer, szValue)) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT;
        }

        Format(szBuffer, sizeof(szBuffer), "%c%c%T", iBind, i+1, szBuffer, iClient);

        ccp_replaceColors(szBuffer[2], true);

        if(a != -1)
            Format(szBuffer, sizeof(szBuffer), "%s \n \n", szBuffer);
        
        hMenu.AddItem(szBuffer, szBuffer[2], iDrawType);
    } 

    hMenu.ExitButton = true;
    hMenu.ExitBackButton = true;

    if(!hMenu.ItemCount) {
        delete hMenu;
    }

    delete model;
    delete pkg;
    delete items;

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

            if(!ccp_HasArtifact(iClient, pkgKey))
                return;

            // pkg -> pkgKey -> vipGroup -> bindArray
            JSONObject group = asJSONOEx(szOption, asJSONO(ccp_GetArtifact(0, pkgKey)));

            JSONArray items = asJSONA(group.Get(szBinds[part]));
            delete group;

            items.GetString(idx, szOption, sizeof(szOption));
            delete items;
            
            if(!strcmp(szOption, "custom")) {
                g_iBindNow[iClient] = part;

                PrintToChat(iClient, "%T", "wait_custom_value", iClient);
                return;
            } 

            JSONObject artifact = asJSONO(ccp_GetArtifact(iClient, pkgKey));

            if(!strcmp(szOption, "disable")) {
                artifact.SetNull(szBinds[part]);
                szOption = NULL_STRING;
            }
            else artifact.SetString(szBinds[part], szOption);

            ccp_SetArtifact(iClient, pkgKey, artifact, CALL_DEFAULT);
            delete artifact;
            
            UpdateCookie(iClient, part, szOption);

            FormatBind("vip_chat_", part, 'l', szOption, sizeof(szOption));

            FeatureMenu(iClient, szOption).Display(iClient, MENU_TIME_FOREVER);
        }
    }
}

public void OnClientPutInServer(int iClient) {
    g_iBindNow[iClient] = BIND_MAX;
}

public Action OnClientSayCommand(int iClient, const char[] command, const char[] args)
{
    if(!iClient || !IsClientInGame(iClient) || IsFakeClient(iClient) || IsChatTrigger())
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

        if(!ccp_HasArtifact(iClient, pkgKey)) {
            g_iBindNow[iClient] = BIND_MAX;
            return Plugin_Handled;
        }

        JSONObject model = asJSONO(ccp_GetArtifact(iClient, pkgKey));
        
        UpdateCookie(iClient, g_iBindNow[iClient], szBuffer);

        model.SetString(szBinds[g_iBindNow[iClient]], szBuffer);
        ccp_SetArtifact(iClient, pkgKey, model, CALL_DEFAULT);
        delete model;

        PrintToChat(iClient, "%T", "ccp_custom_success", iClient);

        FormatBind("vip_chat_", g_iBindNow[iClient], 'l', szBuffer, sizeof(szBuffer));

        FeatureMenu(iClient, szBuffer).Display(iClient, MENU_TIME_FOREVER);

        g_iBindNow[iClient] = BIND_MAX; /// ???

        return Plugin_Handled;
    }

    return Plugin_Continue;
}

JSONObject objModel;

public Processing  cc_proc_OnRebuildString(const int[] props, int part, ArrayList params, int &pLevel, char[] value, int size) {
    int idx = IsValidPart(part);
    if(idx == -1 || !SENDER_INDEX(props[1]) || pLevel > level[idx]) {
        return Proc_Continue;
    }

    objModel = asJSONO(ccp_GetArtifact(0, pkgKey));
    if(!objModel.HasKey("channels")) {
        delete objModel;
        return Proc_Continue;
    }

    JSONArray channels = asJSONA(objModel.Get("channels"));
    delete objModel;

    char szIndent[64];
    params.GetString(0, szIndent, sizeof(szIndent));
    if(FindChannelInChannels_json(channels, szIndent) == -1) {
        return Proc_Continue;
    }

    objModel = asJSONO(ccp_GetArtifact(SENDER_INDEX(props[1]), pkgKey));
    if(!objModel || !IsPartValid(objModel, part)) {
        delete objModel;
        return Proc_Continue;
    }

    static char szValue[MESSAGE_LENGTH];
    if(!objModel.GetString(szBinds[part], szValue, sizeof(szValue)) || !szValue[0]) {
        delete objModel;
        return Proc_Continue;
    }

    if(part == BIND_PREFIX && TranslationPhraseExists(szValue)) {
        Format(szValue, sizeof(szValue), "%T", szValue, props[2]);
    }

    pLevel = level[idx];
    FormatEx(value, size, szValue);

    delete objModel;
    return Proc_Change;
}

stock int IsValidPart(const int part)
{
    static const int ValidParts[] = {BIND_PREFIX_CO, BIND_PREFIX, BIND_NAME_CO, BIND_MSG_CO};

    for(int i; i < sizeof(ValidParts); i++)
        if(ValidParts[i] == part)
            return i;

    return -1;
}

stock JSONObject getClientModel(int iClient) {
    JSONObject obj;
    obj = asJSONO(ccp_GetPackage(iClient));

    if(!obj || !obj.HasKey(pkgKey) || !obj.HasKey("auth"))
        return null;
    
    obj = asJSONO(obj.Get(pkgKey));
    return obj;
}

stock bool IsPartValid(JSONObject model, int part) {
    return model.HasKey(szBinds[part]) && !model.IsNull(szBinds[part]);
}

stock JSONObject asJSONOEx(const char[] key, JSONObject obj, bool dlt = true) {
    JSONObject out;
    
    out = asJSONO(obj.Get(key));

    if(dlt) delete obj;

    return out;
}
