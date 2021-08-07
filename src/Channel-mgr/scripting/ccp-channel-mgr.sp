#pragma newdecls required

#define INCLUDE_RIPJSON

#if defined INCLUDE_DEBUG
    #define DEBUG "[Channel-mgr]"
#endif

#include <ccprocessor>
#include <ccprocessor_pkg>
#include <ccprocessor_chls>

public Plugin myinfo = 
{
	name = "[CCP] Channel manager",
	author = "rej. chev?",
	description = "...",
	version = "1.0.0",
	url = "https://discord.gg/cFZ97Mzrjy"
};

static const char pkgKey[] = "channel_mgr";

bool g_bLate;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
    #if defined DEBUG
        DBUILD()
    #endif

    CreateNative("ccp_FindChannel",     Native_FindChannel);
    CreateNative("ccp_GetChannelTag",   Native_GetChannelTag);
    CreateNative("ccp_GetChannelList",  Native_GetChannelList);
    CreateNative("ccp_RemoveChannel",   Native_RemoveChannel);
    CreateNative("ccp_AddChannel",      Native_AddChannel);

    RegPluginLibrary("ccprocessor_chls");

    g_bLate = late;
    return APLRes_Success;
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

        if(ccp_HasPackage(0))
            ccp_OnPackageAvailable(0);
    }

}

public void ccp_OnPackageAvailable(int iClient) {
    if(iClient)
        return;
    
    static const char handlers[4][] = {
        "ccp-saytext2", "ccp-radiomsg", "ccp-textmsg", "ccp-saytext"
    };

    static const char nativeChannels[4][PREFIX_LENGTH] = {
        "", "RT", "TM", "ST"
    };

    JSONArray channels = new JSONArray();
    for(int i; i < sizeof(handlers); i++) {
        if(FindPluginByFile(handlers[i])) {
            if(!i) {
                channels.PushString("STA");
                channels.PushString("STP");
                channels.PushString("CN");
            }

            else channels.PushString(nativeChannels[i]);
        }
    }

    ccp_SetArtifact(iClient, pkgKey, channels, CALL_DEFAULT);

    delete channels;
}

public any Native_FindChannel(Handle h, int a) {
    char tag[PREFIX_LENGTH];
    GetNativeString(1, tag, sizeof(tag));

    JSONArray channels;
    if((channels = asJSONA(ccp_GetChannelList())) != null) {

        char szBuffer[64];
        for(int i; i < channels.Length; i++) {
            channels.GetString(i, szBuffer, sizeof(szBuffer));
            if(!strcmp(tag, szBuffer, true)) {
                delete channels;
                return i;
            }

        }

        delete channels;
    }

    return -1;
}

public any Native_GetChannelTag(Handle h, int a) {
    char szBuffer[PREFIX_LENGTH];

    int index = GetNativeCell(1);

    JSONArray channels;
    if((channels = asJSONA(ccp_GetChannelList())) != null) {

        if(index < 0 || channels.Length <= index) {
            delete channels;
            return false;
        }
        
        channels.GetString(index, szBuffer, sizeof(szBuffer));
        delete channels;

        SetNativeString(2, szBuffer, sizeof(szBuffer));
        return true;
    }

    return false;
}

public any Native_GetChannelList(Handle h, int a) {
    if(ccp_HasArtifact(0, pkgKey))
        return ccp_GetArtifact(0, pkgKey);

    return 0;
}

public any Native_RemoveChannel(Handle h, int a) {
    int index = GetNativeCell(1);

    JSONArray channels;
    if((channels = asJSONA(ccp_GetChannelList())) != null) {

        if(index < 0 || channels.Length <= index) {
            delete channels;
            return false;
        }
        
        channels.Remove(index);
        
        // TODO: replacement level from native params
        bool bSet = ccp_SetArtifact(0, pkgKey, channels, CALL_DEFAULT);
        delete channels;

        return bSet;
    }

    return false;
}

public any Native_AddChannel(Handle h, int a) {
    char szBuffer[PREFIX_LENGTH];
    GetNativeString(1, szBuffer, sizeof(szBuffer));

    if(ccp_FindChannel(szBuffer) != -1)
        return false;

    JSONArray channels;
    if((channels = asJSONA(ccp_GetChannelList())) != null) {
        channels.PushString(szBuffer);
        
        // TODO: replacement level from native params
        // Dumb idea...
        bool bSet = ccp_SetArtifact(0, pkgKey, channels, CALL_DEFAULT);
        delete channels;

        return bSet;
    }

    return false;
}