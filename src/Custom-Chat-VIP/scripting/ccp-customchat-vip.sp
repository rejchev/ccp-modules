#pragma newdecls required

#define INCLUDE_RIPJSON
#define INCLUDE_MODULE_STORAGE
#define INCLUDE_MODULE_PACKAGER

#include <vip_core>
#include <ccprocessor>

public Plugin myinfo = 
{
	name = "[CCP] Custom Chat <VIP>",
	author = "nyood",
	description = "...",
	version = "2.1.0",
	url = "discord.gg/ChTyPUG"
};

ArrayList g_mPalette;

int level[BIND_MAX];

int g_iBindNow[MAXPLAYERS+1];

bool g_bLate;

static const char pkgKey[] = "vip_chat";
static const char FEATURE[] = "ccp_chat";

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
        FormatBind(FEATURE, i, 'l', szBuffer, sizeof(szBuffer)/2);
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
    if(part == BIND_MAX)
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
    if(!VIP_IsValidFeature(FEATURE))
        VIP_RegisterFeature(FEATURE, VIP_NULL, SELECTABLE, OnSelected_Feature);
}

public void OnPluginEnd()
{
    if(!CanTestFeatures() 
    || GetFeatureStatus(FeatureType_Native, "VIP_UnregisterMe") != FeatureStatus_Available)
        return;

    VIP_UnregisterMe();
}

public bool OnSelected_Feature(int iClient, const char[] szFeature) {
    partsOfMsgsMenu(iClient).Display(iClient, MENU_TIME_FOREVER);
    return false;
}

public void VIP_OnVIPClientLoaded(int iClient)
{
    JSONObject storage;

    if((storage = asJSONO(ccp_storage_ReadValue(iClient, pkgKey))) == null)
        storage = new JSONObject();

    ccp_SetArtifact(iClient, pkgKey, storage, CALL_DEFAULT);
    delete storage;            
}

Menu partsOfMsgsMenu(int iClient) {
    g_iBindNow[iClient] = BIND_MAX;

    Menu menu;

    char szBuffer[MESSAGE_LENGTH];
    VIP_GetClientVIPGroup(iClient, szBuffer, sizeof(szBuffer));

    JSONObject artifact = asJSONO(ccp_GetArtifact(0, pkgKey));
    JSONObject group = asJSONO(artifact.Get(szBuffer));

    delete artifact;

    JSONObjectKeys keys = group.Keys();
    delete group;

    menu = new Menu(partsOfMsgsMenu_CallBack);
    menu.SetTitle("%T %T \n \n", "parts_ofMsg_title_tag", iClient, "parts_ofMsg_title", iClient);

    group = asJSONO(ccp_GetArtifact(iClient, pkgKey));
    
    char szValue[MESSAGE_LENGTH], out[MESSAGE_LENGTH];
    while(keys.ReadKey(szBuffer, sizeof(szBuffer))) {
        szValue = NULL_STRING;

        if(group.HasKey(szBuffer))
            group.GetString(szBuffer, szValue, sizeof(szValue));

        if(!szValue[0])
            FormatEx(szValue, sizeof(szValue), "%T", "empty_value", iClient);
        
        if(TranslationPhraseExists(szValue))
            Format(szValue, sizeof(szValue), "%T", szValue, iClient);

        FormatEx(out, sizeof(out), "%c%T [%s]", BindFromString(szBuffer) + 1, szBuffer, iClient, szValue);

        menu.AddItem(out, out[1]);
    }

    menu.ExitButton = true;
    menu.ExitBackButton = true;

    if(!menu.ItemCount)
        delete menu;

    delete keys;
    delete group;

    return menu;
}

public int partsOfMsgsMenu_CallBack(Menu hMenu, MenuAction action, int iClient, int iOpt2)
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
            char szOption[MESSAGE_LENGTH];
            hMenu.GetItem(iOpt2, szOption, sizeof(szOption));

            int part = szOption[0] - 1;
            if(part == BIND_MAX)
                return;
            
            FeatureMenu(iClient, part).Display(iClient, MENU_TIME_FOREVER);
        }
    }
}

Menu FeatureMenu(int iClient, const int msgPart)
{
    g_iBindNow[iClient] = BIND_MAX;

    Menu hMenu;

    char szBuffer[MESSAGE_LENGTH];
    VIP_GetClientVIPGroup(iClient, szBuffer, sizeof(szBuffer));

    JSON items = getItemsList(szBuffer, szBinds[msgPart]);

    if(!items)
        return null;
    
    char szOption[MESSAGE_LENGTH], szValue[MESSAGE_LENGTH];
    JSONObject client = asJSONO(ccp_GetArtifact(iClient, pkgKey));

    if(client.HasKey(szBinds[msgPart]))
        client.GetString(szBinds[msgPart], szValue, sizeof(szValue));

    delete client;

    hMenu = new Menu(FeatureMenu_CallBack);
    hMenu.SetTitle("%T %T \n \n", "feature_title", iClient, szBinds[msgPart], iClient);

    for(int i, a, iDrawType; i < asJSONA(items).Length; i++)
    {
        szOption = NULL_STRING;
        szBuffer = NULL_STRING;
        a = -1;

        asJSONA(items).GetString(i, szBuffer, sizeof(szBuffer));
        
        if(StrContains(szBuffer, "disable", false) != -1) {
            iDrawType = (szValue[0]) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED;
            a = 0;
        } else if(StrContains(szBuffer, "custom", false) != -1) {
            iDrawType = ITEMDRAW_DEFAULT;
            a = 1;
        } else {
            iDrawType = (!strcmp(szBuffer, szValue)) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT;
        }

        Format(szBuffer, sizeof(szBuffer), "%c%c%T", msgPart+1, i+1, szBuffer, iClient);

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
                partsOfMsgsMenu(iClient).Display(iClient, MENU_TIME_FOREVER);
            }
        }
        case MenuAction_Select:
        {
            char szOption[NAME_LENGTH];
            hMenu.GetItem(iOpt2, szOption, sizeof(szOption));

            int part = szOption[0] - 1;
            int idx = szOption[1] - 1;

            VIP_GetClientVIPGroup(iClient, szOption, sizeof(szOption));

            JSONArray items = asJSONA(getItemsList(szOption, szBinds[part]));

            items.GetString(idx, szOption, sizeof(szOption));
            delete items;
            
            if(!strcmp(szOption, "custom")) {
                g_iBindNow[iClient] = part;

                PrintToChat(iClient, "%T", "wait_custom_value", iClient);
                return;
            } 

            JSONObject artifact = asJSONO(ccp_GetArtifact(iClient, pkgKey));

            if(!strcmp(szOption, "disable")) {
                artifact.Remove(szBinds[part]);
                szOption = NULL_STRING;
            }
            else artifact.SetString(szBinds[part], szOption);

            if(ccp_SetArtifact(iClient, pkgKey, artifact, CALL_DEFAULT)) {
                delete artifact;

                artifact = asJSONO(ccp_GetArtifact(iClient, pkgKey));
                ccp_storage_WriteValue(iClient, pkgKey, artifact);
            }
            
            delete artifact;

            FeatureMenu(iClient, part).Display(iClient, MENU_TIME_FOREVER);
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
        
        model.SetString(szBinds[g_iBindNow[iClient]], szBuffer);
        if(ccp_SetArtifact(iClient, pkgKey, model, CALL_DEFAULT)) {
            delete model;

            model = asJSONO(ccp_GetArtifact(iClient, pkgKey));
            ccp_storage_WriteValue(iClient, pkgKey, model);
        }

        delete model;

        PrintToChat(iClient, "%T", "ccp_custom_success", iClient);

        FeatureMenu(iClient, g_iBindNow[iClient]).Display(iClient, MENU_TIME_FOREVER);

        return Plugin_Handled;
    }

    return Plugin_Continue;
}

public Processing  cc_proc_OnRebuildString(const int[] props, int part, ArrayList params, int &pLevel, char[] value, int size) {
    if(!SENDER_INDEX(props[1]) || pLevel > level[part]) {
        return Proc_Continue;
    }

    JSONObject objModel;

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

    delete channels;

    objModel = asJSONO(ccp_GetArtifact(SENDER_INDEX(props[1]), pkgKey));
    if(!objModel || !objModel.HasKey(szBinds[part])) {
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

    pLevel = level[part];
    FormatEx(value, size, szValue);

    delete objModel;
    return Proc_Change;
}

stock JSON getItemsList(const char[] group, const char[] msgPart) {
    JSON first;
    JSON second;

    first = asJSON(ccp_GetArtifact(0, pkgKey));

    if(!asJSONO(first).HasKey(group)) {
        delete first;
        return first;
    }

    second = asJSON(asJSONO(first).Get(group));
    delete first;

    if(!asJSONO(second).HasKey(msgPart)) {
        delete second;
        return second;
    }

    first = asJSON(asJSONO(second).Get(msgPart));
    delete second;

    return first;
}