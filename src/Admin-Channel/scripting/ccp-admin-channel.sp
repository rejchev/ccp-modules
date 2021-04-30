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
	author = "nyood",
	description = "...",
	version = "1.0.7",
	url = "https://t.me/nyoood"
};


static const char pkgKey[] = "admin_channel";

JSONObject jConfig;

bool g_bLate;

static const char ROOT[] = "z";

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
    
    int iROOT = ReadFlagString(ROOT);

    char szBuffer[MESSAGE_LENGTH];
    params.GetString(0, szBuffer, sizeof(szBuffer));
    
    if(!InChannels(szBuffer, parentChannels, sizeof(parentChannels)) || !props[0] || IsClientSourceTV(props[1])) {
        return Proc_Continue;
    } 

    jConfig.GetString("channelTrigger", szBuffer, sizeof(szBuffer));

    char szMessage[MESSAGE_LENGTH];
    params.GetString(2, szMessage, sizeof(szMessage));
    TrimString(szMessage);

    if(szMessage[0] == szBuffer[0]) {
        jConfig.GetString("accessFlag", szBuffer, sizeof(szBuffer));
        
#if defined DEBUG
        DWRITE("%s: cc_proc_OnNewMessage(trigger): \
                    \n\t\t\t\tSender: %N \
                    \n\t\t\t\tRecipient: %N \
                    \n\t\t\t\tTrigger: used \
                    \n\t\t\t\tMessage: %s", \
        DEBUG, props[0], props[1], szMessage);
#endif

        if(!szBuffer[0]) {
            return Proc_Continue;
        }

        int flag = ReadFlagString(szBuffer);
        bool isSenderAdmin = ValidClient(GetUserFlagBits(props[0]), flag, iROOT);

        if(!jConfig.GetBool("playersCanComplain") && !isSenderAdmin) {
#if defined DEBUG
            DWRITE("%s: cc_proc_OnNewMessage(msg continue): \
                        \n\t\t\t\tSender: %N \
                        \n\t\t\t\tComplain: false \
                        \n\t\t\t\tAdmin: false", \
            DEBUG, props[0]);
#endif
            return Proc_Continue;
        }

        if(!ValidClient(GetUserFlagBits(props[1]), flag, iROOT)) {
#if defined DEBUG
            DWRITE("%s: cc_proc_OnNewMessage(msg rejected): \
                        \n\t\t\t\tRecipient: %N \
                        \n\t\t\t\tAdmin: false", \
            DEBUG, props[1]);
#endif
            return Proc_Reject;
        }

        // now all rights...
        jConfig.GetString("identificator", szBuffer, sizeof(szBuffer));
        params.SetString(0, szBuffer);

        if(jConfig.GetBool("useLog")) {
            LogAction(props[0], -1, "\"%L\" (%s) used admin channel (text %s)", props[0], isSenderAdmin ? "Admin" : "Player", szMessage[1]);
        }

        return Proc_Change;
    }    

    return Proc_Continue;
}

public Processing cc_proc_OnRebuildString(const int[] props, int part, ArrayList params, int &level, char[] value, int size) {
    int iROOT = ReadFlagString(ROOT);

    if(!SENDER_INDEX(props[1])) {
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
            jConfig.GetString("accessFlag", szBuffer, sizeof(szBuffer));

            int flag = ReadFlagString(szBuffer);
            bool isSenderAdmin = ValidClient(GetUserFlagBits(SENDER_INDEX(props[1])), flag, iROOT);
            bool isRecipientAdmin = ValidClient(GetUserFlagBits(props[2]), flag, iROOT);

            if(jConfig.HasKey(szBinds[part]) && (jValues = asJSONA(jConfig.Get(szBinds[part]))) && jValues.Length) {
                jValues.GetString(
                    // view: admin to admin
                    (isSenderAdmin && isRecipientAdmin) 
                        ? 0 :
                        // view: sender - user and how he sees this msg
                        (!isSenderAdmin && SENDER_INDEX(props[1]) == props[2]) 
                            ? 2 
                            // view: other options
                            : 1, 
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
#if defined DEBUG
    DWRITE("%s: ValidClient(): \
                \n\t\t\t\tFlags: %d \
                \n\t\t\t\tAccess: %d \
                \n\t\t\t\tRoot: %d \
                \n\t\t\t\tExpected Result: %d \
                \n\t\t\t\tResult: %d", \
    DEBUG, flags, access, root, flags && ((access && (flags & access)) || (flags & root)), !flags ? false : ((access && (flags & access)) || (flags & root)));
#endif

    if(!flags) {
        return false;
    }

    return ((access && (flags & access)) || (flags & root));
}
