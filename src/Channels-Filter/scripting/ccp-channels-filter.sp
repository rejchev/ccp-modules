#pragma newdecls required

#define INCLUDE_RIPJSON
#define INCLUDE_MODULE_PACKAGER

#if defined INCLUDE_DEBUG
    #define DEBUG "[Channels-Filter]"
#endif

#include <ccprocessor>

public Plugin myinfo = 
{
    name = "[CCP] Channels Filter",
    author = "nu11ent",
    description = "...",
    version = "1.1.4",
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

        for(int i; i <= MaxClients; i++)
            if(ccp_HasPackage(i))
                ccp_OnPackageAvailable(i);
    }
}

public void ccp_OnPackageAvailable(int iClient) {
    if(!iClient)
        return;

    JSONArray objChannels = new JSONArray();

    if(!ccp_SetArtifact(iClient, pkgKey, objChannels, CALL_DEFAULT)) {
        delete objChannels;
        SetFailState("Something went wrong: ...");
    }

    delete objChannels;
}

Action cmd(int iClient, int args) {
    if(!iClient || !IsClientInGame(iClient)) {
        return Plugin_Handled;
    }

    if(!ccp_HasPackage(iClient) || !ccp_HasArtifact(iClient, pkgKey)) {
        return Plugin_Handled;
    }

    JSONArray objChannels = asJSONA(ccp_GetChannelList());
    if(!objChannels || !objChannels.Length) {
        delete objChannels;
        return Plugin_Handled;
    }

    JSONArray objClientFilter = asJSONA(ccp_GetArtifact(iClient, pkgKey));

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


            JSONArray objChannels = asJSONA(ccp_GetChannelList());
            JSONArray objClientFilter = asJSONA(ccp_GetArtifact(iClient, pkgKey));

            char szValue[MESSAGE_LENGTH];
            objChannels.GetString(item, szValue, sizeof(szValue));
            delete objChannels;

            item = GetIndexOfIndent(objClientFilter, szValue);

            if(item == -1) {
                objClientFilter.PushString(szValue);

            } else {
                objClientFilter.Remove(item);
            }

            ccp_SetArtifact(iClient, pkgKey, objClientFilter, CALL_DEFAULT);
            delete objClientFilter;

            FormatEx(szBuffer, sizeof(szBuffer), "%T", (item != -1) ? "enabled" : "disabled", iClient);
            Format(szValue, sizeof(szValue), "%T", szValue, iClient);

            PrintToChat(iClient, "%T", "chat_setvalue", iClient, szValue, szBuffer);
            cmd(iClient, 0);
        }
    }
}

public Processing cc_proc_OnRebuildString(const int[] props, int part, ArrayList params, int &level, char[] value, int size) {
    if(part != BIND_PROTOTYPE)
        return Proc_Continue;

    static char szIndent[64];
    params.GetString(0, szIndent, sizeof(szIndent));

    JSONArray channelList;
    for(int i; i < 2; i++) {
        if(!((!i) ? SENDER_INDEX(props[i+1]) : props[i+1]))
            continue;
        
        if(!ccp_HasPackage((!i) ? SENDER_INDEX(props[i+1]) : props[i+1]) 
        || !ccp_HasArtifact((!i) ? SENDER_INDEX(props[i+1]) : props[i+1], pkgKey))
            return Proc_Continue;
    
        channelList = asJSONA(ccp_GetArtifact((!i) ? SENDER_INDEX(props[i+1]) : props[i+1], pkgKey));

        if(channelList.Length && GetIndexOfIndent(channelList, szIndent) != -1) {
            delete channelList;
            return Proc_Stop;
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