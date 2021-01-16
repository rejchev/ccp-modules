#pragma newdecls required

#include <ccprocessor>

public Plugin myinfo = 
{
	name = "[CCP] Admin channel",
	author = "nu11ent",
	description = "...",
	version = "1.0.2",
	url = "https://t.me/nyoood"
};

static const char trigger[] = "#";

StringMap g_smSettings;

bool IsLogAction;
bool IsPlayer;
bool IsAdminChannel;

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

public void cc_proc_MsgUniqueId(int mType, int sender, int msgId, const char[] message, const int[] clients, int count) {
    IsAdminChannel = false;

    if(mType > eMsg_ALL || !sender) {
        return;
    }

    IsAdminChannel = message[0] == trigger[0];

    if(IsAdminChannel) {
        IsPlayer = GetUserAdmin(sender) == INVALID_ADMIN_ID;

        if(IsLogAction && !IsClientSourceTV(clients[0])) {
            LogAction(sender, -1, "\"%L\" (%s) used admin channel (text %s)", sender, !IsPlayer ? "Admin" : "Player", message[1]);
        }
    }
}

public void cc_proc_RebuildClients(const int mType, int iClient, int[] clients, int &numClients) {
    if(!IsAdminChannel || !numClients || IsClientSourceTV(clients[0])) {
        return;
    }

    numClients = 0;
    for(int i = 1; i <= MaxClients; i++) {
        if(IsClientInGame(i) && !IsFakeClient(i) && (iClient == i || GetUserAdmin(i) != INVALID_ADMIN_ID)) {
            clients[numClients++] = i;
        }
    }

}

public Action cc_proc_RebuildString(const int mType, int sender, int recipient, int part, int &pLevel, char[] buffer, int size) {
    if(IsAdminChannel) {
        
        if(part == BIND_MSG) {
            ReplaceStringEx(buffer, size, trigger, "", -1, -1, false);
        } else if(part == BIND_TEAM && IsPlayer) {
            // Message from player
            FormatEx(buffer, size, "%T", (sender == recipient) ? "to_admins" : "from_player", recipient);
        } else {
            char szValue[64];
            if(!g_smSettings.GetString(szBinds[part], szValue, sizeof(szValue)) || !szValue[0]) {
                return Plugin_Continue;
            }

            FormatEx(buffer, size, "%T", szValue, recipient);
        }
    }

    return Plugin_Continue;
}