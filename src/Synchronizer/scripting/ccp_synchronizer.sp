#pragma newdecls required

#define INCLUDE_RIPJSON

#if defined INCLUDE_DEBUG
    #define DEBUG "[Synchronizer]"
#endif

#include <ccprocessor>
#include <ccprocessor_pkg>
#include <ccprocessor_chls>

#include <sdktools>
#include <sdkhooks>

public Plugin myinfo = 
{
	name = "[CCP] Synchronizer",
	author = "rej. chev?",
	description = "...",
	version = "1.0.0",
	url = "https://discord.gg/cFZ97Mzrjy"
};

static const char pkgKey[] = "synchronizer";

bool g_bLate;

int nextSyncTick;

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

        for(int i; i <= MaxClients; i++)
            if(ccp_HasPackage(i))
                ccp_pkg_Available(i);
    }

    nextSyncTick = 0;

    SDKHook(GetPlayerResourceEntity(), SDKHook_ThinkPost, OnThinkPost);
}

public void OnThinkPost(int ent) {
    if(ent == -1) {
        SDKUnhook(ent, SDKHook_ThinkPost, OnThinkPost);
        return;
    }

    static int currentTick;
    currentTick = GetGameTickCount();

    static char szBuffer[4];

    if(currentTick <= nextSyncTick || !nextSyncTick) {
        JSONObject obj;
        if(!ccp_HasArtifact(0, pkgKey))
            return;
        
        obj = asJSONO(ccp_GetArtifact(0, pkgKey));
        
        nextSyncTick = currentTick + obj.GetInt("delay") * RoundFloat(getTickrate());

        delete obj;

        JSONArray channels;
        if(!ccp_HasArtifact(0, "channel_mgr"))
            return;
        
        channels = asJSONA(ccp_GetChannelList());

        ArrayList arr = new ArrayList(MAX_LENGTH, 0);
        static char channel[PREFIX_LENGTH];

        for(int i = 1, a; i <= MaxClients; i++) {
            if(ccp_HasPackage(i)) {
                a = i<<3|GetClientTeam(i)<<1|view_as<int>(IsPlayerAlive(i));
                for(int j; j < channels.Length; j++) {
                    channels.GetString(j, channel, sizeof(channel));
                    stock_RebuildMsg(arr, -1, a, i, channel, NULL_STRING, szBuffer, szBuffer, szBuffer);
                }
            }
        }

        delete channels;
    }
}


public void ccp_pkg_Available(int iClient) {
    static char config[MESSAGE_LENGTH]  
        = "configs/ccprocessor/synchronizer/settings.json";
    
    JSONObject obj;
    if(!iClient) {
        // Load from local
        if(config[0] == 'c') {
            BuildPath(Path_SM, config, sizeof(config), config);
        } 
        
        if(!FileExists(config)) {
            SetFailState("Config file is not exists: %s", config);
        }

        obj = asJSONO(JSONObject.FromFile(config, 0));
    } else {
        obj = new JSONObject();
    }

    if(!ccp_SetArtifact(iClient, pkgKey, obj, 0x01)) {
        SetFailState("Something went wrong: ...");
    }

    delete obj;
}


public Processing cc_proc_OnRebuildString_Post(const int[] props, int part, ArrayList params, int level, const char[] value) {
    char szBuffer[64];
    params.GetString(1, szBuffer, sizeof(szBuffer));
    
    JSONObject obj;

    // this is not the pseudo call ;/
    if(szBuffer[0] || !ccp_HasArtifact(SENDER_INDEX(props[1]), pkgKey))
        return Proc_Continue;
    
    params.GetString(0, szBuffer, sizeof(szBuffer));
    
    obj = asJSONO(ccp_GetArtifact(SENDER_INDEX(props[1]), pkgKey));

    JSONObject ch;

    ch = !obj.HasKey(szBuffer) 
            ? new JSONObject()
            : asJSONO(obj.Get(szBuffer));

    ch.SetString(szBinds[part], value);

    obj.Set(szBuffer, ch);
    delete ch;

    ccp_SetArtifact(SENDER_INDEX(props[1]), pkgKey, obj, 0x01);
    delete obj;

    return Proc_Continue;
}

stock float getTickrate() {
    return (1/GetTickInterval());
}