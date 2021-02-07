#pragma newdecls required

#include <ccprocessor>

public Plugin myinfo = 
{
	name = "[CCP] Admin channel",
	author = "nu11ent",
	description = "...",
	version = "1.0.4",
	url = "https://t.me/nyoood"
};

static const char trigger[] = "#";
static const char indent[] = "ST1";

StringMap g_smSettings;

bool IsLogAction;
bool IsPlayer;

public void OnPluginStart() {
    LoadTranslations("admin-channel.phrases");

    g_smSettings = new StringMap();
}

public void OnMapStart() {
    static char config[MESSAGE_LENGTH] = "configs/ccprocessor/admins-channel/settings.ini";

    if(config[0] == 'c') {
        BuildPath(Path_SM, config, sizeof(config), config);
    } 

    if(!FileExists(config)) {
        SetFailState("Config file is not exists: %s", config);
    }

    g_smSettings.Clear();

    KeyValues kv = new KeyValues("settings");
    if(kv.ImportFromFile(config)) {
        kv.Rewind();

        char szBuffer[MESSAGE_LENGTH];
        IsLogAction = view_as<bool>(kv.GetNum("use_log", 1));

        for(int i; i < BIND_MAX; i++) {
            FormatBind("channel_", i, 'l', szBuffer, sizeof(szBuffer));

            kv.GetString(szBuffer, szBuffer, sizeof(szBuffer), NULL_STRING);

            g_smSettings.SetString(szBinds[i], szBuffer, true);
        }
    }

    delete kv;
}

public bool cc_proc_OnNewMessage(int sender, ArrayList params) {
    char szIndent[64];
    params.GetString(0, szIndent, sizeof(szIndent));
    
    if((szIndent[0] != 'S' && szIndent[1] != 'T' && strlen(szIndent) < 3) || !sender) {
        return true;
    } 

    char szMessage[MESSAGE_LENGTH];
    params.GetString(2, szMessage, sizeof(szMessage));
    LogMessage("Message: %s", szMessage);

    bool IsAdminChannel = szMessage[0] == trigger[0];

    if(IsAdminChannel) {
        params.SetString(0, indent); // virtual channel: ST1

        IsPlayer = GetUserAdmin(sender) == INVALID_ADMIN_ID;

        int players[MAXPLAYERS+1];
        params.GetArray(3, players, sizeof(players));

        if(IsLogAction && !IsClientSourceTV(players[0])) {
            LogAction(sender, -1, "\"%L\" (%s) used admin channel (text %s)", sender, !IsPlayer ? "Admin" : "Player", szMessage[1]);
        }
    }    

    return true;
}

public Action cc_proc_OnRebuildClients(const int[] props, int propsCount, ArrayList params) {
    char szIndent[64];
    params.GetString(0, szIndent, sizeof(szIndent));

    if(strcmp(szIndent, indent)) {
        return Plugin_Continue;
    }

    int playersNum = params.Get(3);
    int players[MAXPLAYERS+1];
    params.GetArray(2, players, playersNum);

    if(!playersNum || IsClientSourceTV(players[0])) {
        return Plugin_Continue;
    }

    playersNum = 0;
    for(int i = 1; i <= MaxClients; i++) {
        if(IsClientInGame(i) && !IsFakeClient(i) && (props[1] == i || GetUserAdmin(i) != INVALID_ADMIN_ID)) {
            players[playersNum++] = i;
        }
    }

    params.SetArray(2, players, playersNum);
    params.Set(3, playersNum);

    return Plugin_Continue;
}

public Action  cc_proc_OnRebuildString(const int[] props, int part, ArrayList params, int &level, char[] value, int size) {
    char szIndent[64];
    params.GetString(0, szIndent, sizeof(szIndent));

    if(strcmp(szIndent, indent)) {
        return Plugin_Continue;
    }

    if(part == BIND_MSG) {
        ReplaceStringEx(value, size, trigger, "", -1, -1, false);
    } else if(part == BIND_TEAM && IsPlayer) {
        // Message from player
        FormatEx(value, size, "%T", ((props[1] >> 3) == props[2]) ? "to_admins" : "from_player", props[2]);
    } else {
        char szValue[64];
        if(!g_smSettings.GetString(szBinds[part], szValue, sizeof(szValue)) || !szValue[0]) {
            return Plugin_Continue;
        }

        FormatEx(value, size, "%T", szValue, props[2]);
    }

    return Plugin_Continue;
}