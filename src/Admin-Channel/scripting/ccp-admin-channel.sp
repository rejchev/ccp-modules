#pragma newdecls required

#include <ccprocessor>

public Plugin myinfo = 
{
	name = "[CCP] Admin channel",
	author = "nu11ent",
	description = "...",
	version = "1.0.3",
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

public bool cc_proc_OnNewMessage(
const char[] indent, 
int sender, 
const char[] msg_key, 
const char[] msg,
const int[] players, 
int playersNum) {
    IsAdminChannel = false;

    if((indent[0] != 'S' && indent[1] != 'T' && strlen(indent) < 3) || !sender) {
        return true;
    } 

    IsAdminChannel = msg[0] == trigger[0];

    if(IsAdminChannel) {
        IsPlayer = GetUserAdmin(sender) == INVALID_ADMIN_ID;

        if(IsLogAction && !IsClientSourceTV(players[0])) {
            LogAction(sender, -1, "\"%L\" (%s) used admin channel (text %s)", sender, !IsPlayer ? "Admin" : "Player", msg[1]);
        }
    }    

    return true;
}

public void cc_proc_OnRebuildClients(
int mid,
const char[] indent,
int sender, 
const char[] msg_key, 
int[] players, 
int &playersNum 
) {
    if(!IsAdminChannel || !playersNum || IsClientSourceTV(players[0])) {
        return;
    }

    playersNum = 0;
    for(int i = 1; i <= MaxClients; i++) {
        if(IsClientInGame(i) && !IsFakeClient(i) && (sender == i || GetUserAdmin(i) != INVALID_ADMIN_ID)) {
            players[playersNum++] = i;
        }
    }
}

public Action cc_proc_OnRebuildString(
int mid,
const char[] indent,
int sender,
int recipient,
int part,
int &level, 
char[] buffer,
int size
) {
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