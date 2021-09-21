#pragma newdecls required

#define INCLUDE_RIPJSON
#define INCLUDE_MODULE_PACKAGER

#if defined INCLUDE_DEBUG
    #define DEBUG "[Join-Server]"
#endif

#include <ccprocessor>

public Plugin myinfo = 
{
	name = "[CCP] Join Server",
	author = "rej.chev?",
	description = "Processing player connect&disconnect events",
	version = "1.0.1",
	url = "https://discord.gg/cFZ97Mzrjy"
};

static const char pkgKey[] = "join_server";

static const char objectPattern[] = "js@%x";

JSONObject jConfig;
JSONObject jMessanger;

bool g_bLate;

char currentObject[64];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
    #if defined DEBUG
        DBUILD()
    #endif

    g_bLate = late;
    return APLRes_Success;
}

public void OnPluginStart() {
    // Temporary solution
    LoadTranslations("ccp-joinserver.phrases");

    HookEvent("player_connect", Events, EventHookMode_Pre);
    HookEvent("player_disconnect", Events, EventHookMode_Pre);
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

        for(int i; i <= MaxClients; i++)
            if(ccp_HasPackage(i))
                ccp_OnPackageAvailable(i);
    }

    delete jMessanger;
    jMessanger = new JSONObject();
}

public void ccp_OnPackageAvailable(int iClient) {
    static char config[MESSAGE_LENGTH]  = "configs/ccprocessor/join-server/settings.json";

    if(iClient)
        return;
    

    if(jConfig) {
        delete jConfig;
    }

    // Load from local
    if(config[0] == 'c') {
        BuildPath(Path_SM, config, sizeof(config), config);
    } 
    
    if(!FileExists(config)) {
        SetFailState("Config file is not exists: %s", config);
    }

    jConfig = JSONObject.FromFile(config, 0);

    ccp_SetArtifact(iClient, pkgKey, jConfig, CALL_IGNORE);
}

public void ccp_OnPackageUpdate_Post(Handle ctx, any level) {
    JSONObject obj = asJSONO(ctx);
    
    if(!obj.GetBool("isArtifact") || GetClientOfUserId(obj.GetInt("client")))
        return;
    
    char szBuffer[PREFIX_LENGTH];
    obj.GetString("field", szBuffer, sizeof(szBuffer));

    if(strcmp(szBuffer, "channel_mgr") || level != CALL_DEFAULT)
        return;
    
    if(jConfig) {
        jConfig.GetString("identificator", szBuffer, sizeof(szBuffer));

        if(ccp_FindChannel(szBuffer) == -1)
            ccp_AddChannel(szBuffer);
    }
}

Action Events(Event event, const char[] name, bool dbc) {
    if(!jConfig.GetBool("processing"))
        return Plugin_Continue;

    event.SetBool("silent", true);

    if(jConfig.GetBool("hideMessages"))
        return Plugin_Changed;

    // params
    char szName[NAME_LENGTH];
    event.GetString("name", szName, sizeof(szName));

    int userId = event.GetInt("userid");

    char network[NAME_LENGTH];
    event.GetString("networkid", network, sizeof(network));

    int bot = event.GetInt("bot");

    int index = -1;
    char buffer[NAME_LENGTH];
    if(name[7] == 'd')
        event.GetString("reason", buffer, sizeof(buffer));

    else {
        event.GetString("address", buffer, sizeof(buffer));
        index = event.GetInt("index");
    } 

    JSONObject message = new JSONObject();
    message.SetString("event", name);
    message.SetInt("userid", userId);
    message.SetInt("index", index);
    message.SetInt("bot", bot);
    message.SetString("name", szName);
    message.SetString("network", network);
    message.SetString(name[7] == 'd' ? "reason" : "address", buffer);

    // event address
    FormatEx(szName, sizeof(szName), objectPattern, event);
    
    jMessanger.Set(szName, message);
    delete message;

    for(int i = 1; i <= MaxClients; i++)
        if(IsClientInGame(i))
            PrintToChat(i, szName);    
    
    return Plugin_Changed;
}

public Processing cc_proc_OnNewMessage(const int[] props, int propsCount, ArrayList params) {
    static const char parentChannel[] = "TM";
    
    char szBuffer[MESSAGE_LENGTH];
    params.GetString(0, szBuffer, sizeof(szBuffer));

    currentObject = NULL_STRING;
    
    if(strcmp(szBuffer, parentChannel) != 0 || IsClientSourceTV(props[1]))
        return Proc_Continue;

    // message object
    params.GetString(2, szBuffer, sizeof(szBuffer));
    if(!jMessanger.HasKey(szBuffer))
        return Proc_Continue;

    FormatEx(currentObject, sizeof(currentObject), "%s", szBuffer);

    JSONObject msg = asJSONO(jMessanger.Get(szBuffer));
    int sender = GetClientOfUserId(msg.GetInt("userid"));    

    jConfig.GetString("identificator", szBuffer, sizeof(szBuffer));
    params.SetString(0, szBuffer);

    msg.GetString("event", szBuffer, sizeof(szBuffer));

    char reason[NAME_LENGTH] = "no reason";
    if(szBuffer[7] == 'd')
        msg.GetString("reason", reason, sizeof(reason));

    char network[NAME_LENGTH];
    msg.GetString("network", network, sizeof(network));

    if(sender && IsClientConnected(sender) && jConfig.GetBool("useLog"))
        LogAction(
            sender, -1, "\"%L\" %s the game (%s). Network ID: %s", 
            sender, szBuffer[7] == 'd' ? "disconnected from" : "connected to", reason, network
        );

    delete msg;
    return Proc_Change;
}

public Processing cc_proc_OnRebuildString(const int[] props, int part, ArrayList params, int &level, char[] value, int size) {
    static char szIdent[64];
    params.GetString(0, szIdent, sizeof(szIdent));

    static char szBuffer[MESSAGE_LENGTH];
    jConfig.GetString("identificator", szBuffer, sizeof(szBuffer));

    // LogMessage("Ident(now): %s, Ident(expected): %s, MessagerHas: %b", szIdent, szBuffer, jMessanger.HasKey(currentObject));

    if(strcmp(szIdent, szBuffer) != 0 || !currentObject[0] || !jMessanger.HasKey(currentObject)) {
        return Proc_Continue;
    }

    int priority = jConfig.GetInt("priority");
    if(level > priority)
        return Proc_Continue;

    level = priority;
    // LogMessage("Level now: %d", level);

    JSONObject message = asJSONO(jMessanger.Get(currentObject));

    static char event[NAME_LENGTH];
    message.GetString("event", event, sizeof(event));

    static char szBot[NAME_LENGTH];
    FormatEx(szBot, sizeof(szBot), "%T", message.GetInt("bot") ? "js_bot" : "js_player", props[2]);

    static char name[NAME_LENGTH];
    message.GetString("name", name, sizeof(name));

    static char network[NAME_LENGTH];
    message.GetString("network", network, sizeof(network));

    static char buffer[MESSAGE_LENGTH];
    message.GetString(event[7] == 'd' ? "reason" : "address", buffer, sizeof(buffer));

    delete message;

    JSONArray jValues;

    switch(part) {
        case BIND_PROTOTYPE: {
            if(jConfig.HasKey(szBinds[part]) && jConfig.GetString(szBinds[part], value, size)) {
                Format(value, size, "%c %T", 1, value, props[2]); // because the template contains the body of the message, not the tag
            }
        }

        case BIND_STATUS, BIND_STATUS_CO, BIND_NAME_CO, BIND_MSG_CO, BIND_PREFIX_CO: {
            if(jConfig.HasKey(szBinds[part])) {
                jConfig.GetString(szBinds[part], value, size);

                if(part != BIND_STATUS) 
                    Format(value, size, "%T", value, props[2]);
                
                else Format(value, size, "%T", value, props[2], szBot, network);
            }
        }
            
        case BIND_PREFIX:{
            if(jConfig.HasKey(szBinds[part])) {
                jConfig.GetString(szBinds[part], value, size);
                Format(value, size, "%T", value, props[2]);
            }
        }

        case BIND_NAME:
            FormatEx(value, size, "%s", name);

        case BIND_MSG: {
            if(jConfig.HasKey(szBinds[part]) && (jValues = asJSONA(jConfig.Get(szBinds[part]))) && jValues.Length) {
                jValues.GetString(event[7] == 'd', value, size);
                Format(value, size, "%T", value, props[2], buffer);
            }
        }
    }

    delete jValues;
    return Proc_Change;
}
