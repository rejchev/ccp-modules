#pragma newdecls required

#define INCLUDE_RIPJSON

#if defined INCLUDE_DEBUG
    #define DEBUG "[Admin-Channel]"
#endif

#include <ccprocessor>
#include <ccprocessor_pkg>

public Plugin myinfo = 
{
	name = "[CCP] Admin channel",
	author = "nu11ent",
	description = "...",
	version = "1.0.6",
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

bool g_bLate;

bool g_IsMessageInAChannel[MAXPLAYERS+1];
bool g_IsTrue[MAXPLAYERS+1];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
    #if defined DEBUG
        DBUILD()
    #endif

    g_bLate = late;
    return APLRes_Success;
}

public void OnPluginStart() {
    LoadTranslations("admin-channel.phrases");
}

public void OnClientPutInServer(int iClient) {
    g_IsMessageInAChannel[iClient] =
        g_IsTrue[iClient] = false;
}

public void OnMapStart() {
    #if defined DEBUG
        DBUILD()
    #endif

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
    static char config[MESSAGE_LENGTH]  = "configs/ccprocessor/admins-channel/settings.json";

    JSONObject objPackage = asJSONO(jsonObj);

    if(!objPackage || !objPackage.HasKey("auth") || iClient) {
        return;
    }

    if(jConfig) {
        delete jConfig;
    }

    // Loaded from cloud
    if(objPackage.HasKey(pkgKey) && objPackage.HasKey(cloud) && objPackage.GetBool(cloud)) {
        if(!iClient) {
            jConfig = asJSONO(objPackage.Get(pkgKey));    
        }

        return;
    }

    // Load from local
    if(config[0] == 'c') {
        BuildPath(Path_SM, config, sizeof(config), config);
    } 
    
    if(!FileExists(config)) {
        SetFailState("Config file is not exists: %s", config);
    }

    jConfig = JSONObject.FromFile(config, 0);
    objPackage.Set(pkgKey, jConfig);
}

public void ccp_OnPackageRemove(int iClient, Handle jsonObj) {
    if(!iClient) {
        delete (asJSONO(jConfig));
    }
}


public Processing cc_proc_OnNewMessage(const int[] props, int propsCount, ArrayList params) {
    static const char parentChannels[][] = {"STA", "STP"};
    static const char ROOT[] = "z";

    g_IsMessageInAChannel[props[1]] = 
        g_IsTrue[props[0]] = 
            g_IsTrue[props[1]] = false;

    char szBuffer[MESSAGE_LENGTH];
    params.GetString(0, szBuffer, sizeof(szBuffer));
    
    if(!InChannels(szBuffer, parentChannels, sizeof(parentChannels)) || !props[0] || IsClientSourceTV(props[1])) {
        return Proc_Continue;
    } 

    jConfig.GetString("channelTrigger", szBuffer, sizeof(szBuffer));

    char szMessage[MESSAGE_LENGTH];
    params.GetString(2, szMessage, sizeof(szMessage));

    if(szMessage[0] == szBuffer[0]) {
        jConfig.GetString("accessFlag", szBuffer, sizeof(szBuffer));

        // int flags = GetUserFlagBits(sender);
        int access = ReadFlagString(szBuffer);
        int root = ReadFlagString(ROOT);

        // Is sender has premissions
        g_IsTrue[props[0]] = ValidClient(GetUserFlagBits(props[0]), access, root);
        if(!g_IsTrue[props[0]] && !jConfig.GetBool("playersCanComplain")) {
            return Proc_Continue;
        }

        // Is recipient an admin
        if(!(g_IsTrue[props[1]] = ValidClient(GetUserFlagBits(props[1]), access, root)) && props[1] != props[0]) {
            g_IsTrue[props[0]] = false;
            return Proc_Reject;
        }

        // Yeah, this is admin channel....
        g_IsMessageInAChannel[props[1]] = true;

        jConfig.GetString("identificator", szBuffer, sizeof(szBuffer));
        params.SetString(0, szBuffer);

        if(jConfig.GetBool("useLog")) {
            LogAction(props[0], -1, "\"%L\" (%s) used admin channel (text %s)", props[0], g_IsTrue[props[0]] ? "Admin" : "Player", szMessage[1]);
        }

        return Proc_Change;
    }    

    return Proc_Continue;
}

public Processing cc_proc_OnRebuildString(const int[] props, int part, ArrayList params, int &level, char[] value, int size) {
    if(!SENDER_INDEX(props[1]) || (!g_IsTrue[props[2]] && props[SENDER_INDEX(props[1])] != props[2])) {
        return Proc_Continue;
    }

    char szIndent[64];
    params.GetString(0, szIndent, sizeof(szIndent));

    char szBuffer[MESSAGE_LENGTH];
    jConfig.GetString("identificator", szBuffer, sizeof(szBuffer));

    if(strcmp(szIndent, szBuffer)) {
        return Proc_Continue;
    }

    JSONArray jValues;

    switch(part) {
        case BIND_PROTOTYPE: {
            if(jConfig.HasKey(szBinds[part]) && jConfig.GetString(szBinds[part], value, size)) {
                Format(value, size, "%c %T", 1, value, SENDER_INDEX(props[1]));
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
                    (g_IsTrue[SENDER_INDEX(props[1])] && g_IsTrue[props[2]]) ? 0 :
                    (!g_IsTrue[SENDER_INDEX(props[1])] && SENDER_INDEX(props[1]) == props[2]) ? 2 : 1, 
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
    return Proc_Change;
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
    if(!flags) {
        return false;
    }

    return ((access && (flags & access)) || (flags & root));
}
