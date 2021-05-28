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
	version = "1.0.8",
	url = "https://t.me/nyoood"
};


static const char pkgKey[] = "admin_channel";

JSONObject jConfig;
JSONObject jMessager;

int counter;

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

    counter = 0;

    delete jMessager;
    jMessager = new JSONObject();
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

public Action OnClientSayCommand(int iClient, const char[] cmd, const char[] args) {
    static int rootFlag;
    if(!rootFlag) {
        rootFlag = ReadFlagString(ROOT);
    }

    if(!iClient || !IsClientInGame(iClient) || IsChatTrigger()) {
        return Plugin_Continue;
    }

    static char buffer[MAX_LENGTH];
    FormatEx(buffer, sizeof(buffer), "%s", args);

    TrimString(buffer);

    static char trigger[4];
    jConfig.GetString("channelTrigger", trigger, sizeof(trigger));

    if(buffer[0] == trigger[0]) {
        Format(buffer, sizeof(buffer), "%s", buffer[1]);
            
        TrimString(buffer);
        
        if(!buffer[0]) {
            return Plugin_Continue;
        }

        static int clientFlags;
        clientFlags = GetUserFlagBits(iClient);

        static int accessFlag;
        jConfig.GetString("accessFlag", trigger, sizeof(trigger));
        accessFlag = ReadFlagString(trigger);

        static bool playersCanComplain;
        playersCanComplain = jConfig.GetBool("playersCanComplain");

        if(accessFlag && ((clientFlags & accessFlag) || (clientFlags & rootFlag) || playersCanComplain)) {
            JSONObject message = new JSONObject();

            static char clientName[NAME_LENGTH];
            GetClientName(iClient, clientName, sizeof(clientName));

            message.SetInt("senderId", GetClientUserId(iClient));
            message.SetString("senderName", clientName);
            message.SetBool("isAdmin", ((clientFlags & accessFlag) || (clientFlags & rootFlag)));
            message.SetString("body", buffer);

            static char msgPointer[MESSAGE_LENGTH];
            FormatEx(msgPointer, sizeof(msgPointer), "msgObject@%d", counter++);

            jMessager.Set(msgPointer, message);
            delete message;

            for(int i = 1, a; i <= MaxClients; i++) {
                if(IsClientInGame(i)) {
                    a = GetUserFlagBits(i);
                    if((a & accessFlag) || (a & rootFlag)) {
                        PrintToChat(i, msgPointer);
                    }
                }
            }

            // don't post call
            return Plugin_Stop;
        }
    }

    return Plugin_Continue;
}

char nextMessage[MESSAGE_LENGTH];

public Processing cc_proc_OnNewMessage(const int[] props, int propsCount, ArrayList params) {
    static const char parentChannel[] = "TM";
    
    char szBuffer[MESSAGE_LENGTH];
    params.GetString(0, szBuffer, sizeof(szBuffer));

    nextMessage = NULL_STRING;
    
    if(strcmp(szBuffer, parentChannel) != 0 || !props[0] || IsClientSourceTV(props[1])) {
        return Proc_Continue;
    }

    // message body
    params.GetString(2, szBuffer, sizeof(szBuffer));
    if(!jMessager.HasKey(szBuffer)) {
        return Proc_Continue;
    } 

    FormatEx(nextMessage, sizeof(nextMessage), "%s", szBuffer);

    JSONObject msg = asJSONO(jMessager.Get(szBuffer));
    int sender = GetClientOfUserId(msg.GetInt("senderId"));    

    jConfig.GetString("identificator", szBuffer, sizeof(szBuffer));
    params.SetString(0, szBuffer);

    msg.GetString("body", szBuffer, sizeof(szBuffer));

    if(jConfig.GetBool("useLog")) {
        LogAction(sender, -1, "\"%L\" (%s) used admin channel (text %s)", sender, msg.GetBool("isAdmin") ? "Admin" : "Player", szBuffer);
    }

    delete msg;
    return Proc_Change;
}

public Processing cc_proc_OnRebuildString(const int[] props, int part, ArrayList params, int &level, char[] value, int size) {
    static int rootFlag;
    if(!rootFlag) {
        rootFlag = ReadFlagString(ROOT);
    }

    char szIndent[64];
    params.GetString(0, szIndent, sizeof(szIndent));

    char szBuffer[MESSAGE_LENGTH];
    jConfig.GetString("identificator", szBuffer, sizeof(szBuffer));

    if(strcmp(szIndent, szBuffer) || !nextMessage[0] || !jMessager.HasKey(nextMessage)) {
        return Proc_Continue;
    }

    JSONObject message = asJSONO(jMessager.Get(nextMessage));

    static int senderId;
    senderId = GetClientOfUserId(message.GetInt("senderId"));

    static bool isSenderAdmin;
    isSenderAdmin = message.GetBool("isAdmin");

    static char senderName[NAME_LENGTH];
    message.GetString("senderName", senderName, sizeof(senderName));

    static char msgBody[MESSAGE_LENGTH];
    message.GetString("body", msgBody, sizeof(msgBody));

    delete message;

    static bool isSenderAlive;
    isSenderAlive = senderId && IsClientInGame(senderId) && IsPlayerAlive(senderId);

    JSONArray jValues;

    switch(part) {
        case BIND_PROTOTYPE: {
            if(jConfig.HasKey(szBinds[part]) && jConfig.GetString(szBinds[part], value, size)) {
                Format(value, size, "%c %T", 1, value, senderId);
            }
        }

        case BIND_STATUS, BIND_STATUS_CO: {
            if(jConfig.HasKey(szBinds[part]) && (jValues = asJSONA(jConfig.Get(szBinds[part]))) && jValues.Length) {
                jValues.GetString(view_as<int>(isSenderAlive), value, size);
                Format(value, size, "%T", value, props[2]);
            }
        }

        case BIND_TEAM, BIND_TEAM_CO: {
            if(jConfig.HasKey(szBinds[part]) && (jValues = asJSONA(jConfig.Get(szBinds[part]))) && jValues.Length) {
                jValues.GetString(
                    // view: admin to admin
                    (isSenderAdmin && senderId != props[2]) 
                        ? 0 :
                        // view: sender - user and how he sees this msg
                        (!isSenderAdmin && senderId == props[2]) 
                            ? 2 
                            // view: other options
                            : 1, 
                    value, size
                );

                Format(value, size, "%T", value, props[2]);
            }
        }

        case BIND_NAME: {
            FormatEx(value, size, "%s", senderName);
        }

        case BIND_MSG: {
            FormatEx(value, size, "%s", msgBody);
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