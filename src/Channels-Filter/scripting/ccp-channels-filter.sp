#pragma newdecls required

#define INCLUDE_RIPJSON

#if defined INCLUDE_DEBUG
    #define DEBUG "[Channels-Filter]"
#endif

#include <ccprocessor>
#include <ccprocessor_pkg>

public Plugin myinfo = 
{
    name = "[CCP] Channels Filter",
    author = "nu11ent",
    description = "...",
    version = "1.1.3",
    url = "https://t.me/nyoood"
};

static const char pkgKey[] = "channels_filter";

bool g_bLate;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
    g_bLate = late;
    return APLRes_Success;
}

public void OnPluginStart() {
    LoadTranslations("ccp_channels.phrases");
    RegConsoleCmd("sm_channels", cmd);
}

public void OnMapStart() {
    // Handshake
    cc_proc_APIHandShake(cc_get_APIKey());

    // late load
    if(g_bLate) {
        g_bLate = false;

        for(int i; i <= MaxClients; i++) {
            if(!i || (IsClientInGame(i) && !IsFakeClient(i) && IsClientAuthorized(i))) {
                ccp_OnPackageAvailable(i, ccp_GetPackage(i));
            }
        }
    }
}

public void ccp_OnPackageAvailable(int iClient, Handle jsonObj) {
    static const char cloud[]           = "cloud";
    static char config[MESSAGE_LENGTH]  = "configs/ccprocessor/channels-filter/channels.json";

    JSONObject objPackage = asJSONO(jsonObj);

    if(!objPackage || !objPackage.HasKey("auth")) {
        return;
    }

    // Loaded from cloud
    if(objPackage.HasKey(pkgKey) && objPackage.HasKey(cloud) && objPackage.GetBool(cloud)) {
        return;
    }

    JSONArray objChannels;

    if(!iClient) {
        // Load from local
        if(config[0] == 'c') {
            BuildPath(Path_SM, config, sizeof(config), config);
        } 
        
        if(!FileExists(config)) {
            SetFailState("Config file is not exists: %s", config);
        }

        objChannels = JSONArray.FromFile(config, 0);
    }

    if(!objChannels) {
        objChannels = new JSONArray();
    }

    objPackage.Set(pkgKey, objChannels);

    delete objChannels;
}

Action cmd(int iClient, int args) {
    if(!iClient || !IsClientInGame(iClient)) {
        return Plugin_Handled;
    }

    JSONObject objPackage = asJSONO(ccp_GetPackage(0));
    if(!objPackage || !objPackage.HasKey(pkgKey)) {
        return Plugin_Handled;
    }

    JSONObject objClient = asJSONO(ccp_GetPackage(iClient));
    if(!objClient || !objClient.HasKey(pkgKey)) {
        return Plugin_Handled;
    }

    JSONArray objChannels = asJSONA(objPackage.Get(pkgKey));
    if(!objChannels || !objChannels.Length) {
        LogError("objChannels(%x): is empty", objChannels);
        delete objChannels;
        return Plugin_Handled;
    }

    JSONArray objClientFilter = (!objClient.IsNull(pkgKey))
                              ? asJSONA(objClient.Get(pkgKey))
                              : null;
    Menu hMenu;
    hMenu = new Menu(MenuCallBack);
    hMenu.SetTitle("%T \n \n", "title", iClient);
    
    char szBuffer[MESSAGE_LENGTH], szValue[MESSAGE_LENGTH];
    for(int i; i < objChannels.Length; i++) {
        objChannels.GetString(i, szValue, sizeof(szValue));
        FormatEx(
            szBuffer, sizeof(szBuffer), "%T", 
            (!objClientFilter || GetIndexOfIndent(objClientFilter, szValue) == -1)
                ? "enabled"
                : "disabled",
            iClient
        );

        Format(szValue, sizeof(szValue), "%T", szValue, iClient);
        Format(szBuffer, sizeof(szBuffer), "%c%T", i+1, "item_channel", iClient, szValue, szBuffer);

        hMenu.AddItem(szBuffer, szBuffer[1]);
    }
    
    delete objChannels;
    delete objClientFilter;

    hMenu.Display(iClient, MENU_TIME_FOREVER);

    return Plugin_Handled;
}

public int MenuCallBack(Menu hMenu, MenuAction action, int iClient, int option)
{
    switch(action)
    {
        case MenuAction_End: delete hMenu;
        case MenuAction_Select: {
            char szBuffer[MESSAGE_LENGTH];
            hMenu.GetItem(option, szBuffer, sizeof(szBuffer));

            int item = szBuffer[0] - 1;


            JSONObject objPackage = asJSONO(ccp_GetPackage(0));
            JSONObject objClient = asJSONO(ccp_GetPackage(iClient));
            JSONArray objChannels = asJSONA(objPackage.Get(pkgKey));
            JSONArray objClientFilter = (!objClient.IsNull(pkgKey))
                                    ? asJSONA(objClient.Get(pkgKey))
                                    : new JSONArray();

            char szValue[MESSAGE_LENGTH];
            objChannels.GetString(item, szValue, sizeof(szValue));

            item = GetIndexOfIndent(objClientFilter, szValue);

            if(item == -1) {
                objClientFilter.PushString(szValue);

            } else {
                objClientFilter.Remove(item);
            }

            asJSONO(ccp_GetPackage(iClient)).Set(pkgKey, objClientFilter);

            delete objChannels;
            delete objClientFilter;

            FormatEx(szBuffer, sizeof(szBuffer), "%T", (item != -1) ? "enabled" : "disabled", iClient);
            Format(szValue, sizeof(szValue), "%T", szValue, iClient);

            PrintToChat(iClient, "%T", "chat_setvalue", iClient, szValue, szBuffer);
            cmd(iClient, 0);
        }
    }
}

public Processing cc_proc_OnNewMessage(const int[] props, int propsCount, ArrayList params) {
    static char szIndent[64];
    params.GetString(0, szIndent, sizeof(szIndent));

    JSONObject pkg;
    JSONArray channelList;

    for(int i; i < propsCount; i++) {
        if(!props[i]) {
            return Proc_Continue;
        }

        pkg = asJSONO(ccp_GetPackage(props[i]));
        if(!pkg || !pkg.HasKey(pkgKey) || pkg.IsNull(pkgKey)) {
            continue;
        }

        channelList = asJSONA(pkg.Get(pkgKey));
        if(channelList && channelList.Length && GetIndexOfIndent(channelList, szIndent) == -1) {
            delete channelList;
            return Proc_Reject;
        }

        delete channelList;
    } 

    return Proc_Continue;
}

stock int GetIndexOfIndent(JSONArray obj, const char[] indent) {
    static char szBuffer[64];
    for(int i; i < obj.Length; i++) {
        obj.GetString(i, szBuffer, sizeof(szBuffer));

        if(!strcmp(szBuffer, indent)) {
            return i;
        }
    }

    return -1;
}