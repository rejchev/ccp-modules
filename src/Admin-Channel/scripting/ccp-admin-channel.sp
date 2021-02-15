#pragma newdecls required

#if defined INCLUDE_DEBUG
    #define DEBUG "[Admin-Channel]"
#endif

#include <ccprocessor>
#include <ccprocessor_pkg>

#undef REQUIRE_EXTENSIONS
#include <ripext_m>
#define REQUIRE_EXTENSIONS

public Plugin myinfo = 
{
	name = "[CCP] Admin channel",
	author = "nu11ent",
	description = "...",
	version = "1.0.5",
	url = "https://t.me/nyoood"
};


static const char pkgKey[] = "admin_channel";

enum 
{
    ADMIN_TO_ADMINS = 0,
    PLAYER_TO_ADMINS,
    PLAYER_FROM_HIMSELF
};

JSONObject jConfig;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
    if(late) {
        Handle obj;
        for(int i; i <= MaxClients; i++) {
            if((obj = ccp_GetPackage(i)) != null) {
                ccp_OnPackageAvailable(i, obj);
            }
        }
    }

    return APLRes_Success;
}

public void OnPluginStart() {
    LoadTranslations("admin-channel.phrases");
}

public void ccp_OnPackageAvailable(int iClient, Handle jsonObj) {
    JSONObject pkg = asJSONO(jsonObj);
    if(!pkg || iClient) {
        return;
    }

    static char config[MESSAGE_LENGTH] = "configs/ccprocessor/admins-channel/settings.json";

    if(config[0] == 'c') {
        BuildPath(Path_SM, config, sizeof(config), config);
    } 

    if(!FileExists(config)) {
        SetFailState("Config file is not exists: %s", config);
    }

    delete jConfig;
    jConfig = JSONObject.FromFile(config, 0);

    pkg.Set(pkgKey, jConfig);
}

bool HasAccess;

public bool cc_proc_OnNewMessage(int sender, ArrayList params) {
    static const char parentChannels[][] = {"STA", "STP"};
    static const char ROOT[] = "z";

    char szBuffer[MESSAGE_LENGTH];
    params.GetString(0, szBuffer, sizeof(szBuffer));
    
    if(!InChannels(szBuffer, parentChannels, sizeof(parentChannels)) || !sender) {
        return true;
    } 

    jConfig.GetString("channelTrigger", szBuffer, sizeof(szBuffer));

    char szMessage[MESSAGE_LENGTH];
    params.GetString(2, szMessage, sizeof(szMessage));

    if(szMessage[0] == szBuffer[0]) {
        jConfig.GetString("accessFlag", szBuffer, sizeof(szBuffer));

        int flags = GetUserFlagBits(sender);
        int access = ReadFlagString(szBuffer);
        int root = ReadFlagString(ROOT);

        HasAccess = ValidClient(flags, access, root);
        if(!HasAccess && !jConfig.GetBool("playersCanComplain")) {
            return true;
        }

        jConfig.GetString("identificator", szBuffer, sizeof(szBuffer));
        params.SetString(0, szBuffer);

        int players[MAXPLAYERS+1];
        params.GetArray(3, players, sizeof(players));

        if(jConfig.GetBool("useLog") && !IsClientSourceTV(players[0])) {
            LogAction(sender, -1, "\"%L\" (%s) used admin channel (text %s)", sender, HasAccess ? "Admin" : "Player", szMessage[1]);
        }
    }    

    return true;
}

public Action cc_proc_OnRebuildClients(const int[] props, int propsCount, ArrayList params) {
    char szIndent[64];
    params.GetString(0, szIndent, sizeof(szIndent));

    char szBuffer[64];
    jConfig.GetString("identificator", szBuffer, sizeof(szBuffer));

    if(strcmp(szIndent, szBuffer)) {
        return Plugin_Continue;
    }

    int playersNum = params.Get(3);
    int players[MAXPLAYERS+1];
    params.GetArray(2, players, playersNum);

    if(!playersNum || IsClientSourceTV(players[0])) {
        return Plugin_Continue;
    }

    jConfig.GetString("accessFlag", szBuffer, sizeof(szBuffer));
    playersNum = 0;

    for(int i = 1, a = ReadFlagString(szBuffer), b = ReadFlagString("z"); i <= MaxClients; i++) {
        if(IsClientInGame(i) && !IsFakeClient(i) && (props[1] == i || ValidClient(GetUserFlagBits(i), a, b))) {
            players[playersNum++] = i;
        }
    }

    params.SetArray(2, players, playersNum);
    params.Set(3, playersNum);

    return Plugin_Continue;
}

public Action cc_proc_OnRebuildString(const int[] props, int part, ArrayList params, int &level, char[] value, int size) {
    char szIndent[64];
    params.GetString(0, szIndent, sizeof(szIndent));

    char szBuffer[MESSAGE_LENGTH];
    jConfig.GetString("identificator", szBuffer, sizeof(szBuffer));

    if(strcmp(szIndent, szBuffer)) {
        return Plugin_Continue;
    }

    JSONArray jValues;

    switch(part) {
        case BIND_PROTOTYPE: {
            if(jConfig.HasKey(szBinds[part]) && jConfig.GetString(szBinds[part], value, size)) {
                FormatEx(value, size, "%c %T", 1, value, SENDER_INDEX(props[1]));
            }
        }

        case BIND_STATUS, BIND_STATUS_CO: {
            if(jConfig.HasKey(szBinds[part]) && (jValues = asJSONA(jConfig.Get(szBinds[part]))) && jValues.Length) {
                jValues.GetString(view_as<int>(SENDER_ALIVE(props[1])), value, size);
                Format(value, size, "%T", value, props[2]);
            }
        }

        case BIND_TEAM, BIND_TEAM_CO: {
            if(jConfig.HasKey(szBinds[part]) && (jValues = asJSONA(jConfig.Get(szBinds[part]))) && jValues.Length) {
                jValues.GetString(
                    (HasAccess) ? 0 :
                    (!HasAccess && SENDER_INDEX(props[1]) == props[2]) ? 2 : 3, 
                    value, size
                );

                Format(value, size, "%T", value, props[2]);
            }
        }

        case BIND_MSG: {
            jConfig.GetString("channelTrigger", szBuffer, sizeof(szBuffer));
            if(ReplaceStringEx(value, size, szBuffer, "", -1, -1, false) != -1) {
                TrimString(value);
            }
        }

        default: {
            if(jConfig.HasKey(szBinds[part]) && jConfig.GetString(szBinds[part], value, size)) {
                FormatEx(value, size, "%T", value, props[2]);
            }
        }
    }

    delete jValues;
    return Plugin_Continue;
}

stock bool InChannels(const char[] channel, const char[][] channels, int count) {
    for(int i; i < count; i++) {
        if(!strcmp(channel, channels[i], true)) {
            return true;
        }
    }

    return false;
}

stock bool ValidClient(int flags, int access, int root) {
    return (flags && ((access && (flags & access)) || (flags & root)));
}