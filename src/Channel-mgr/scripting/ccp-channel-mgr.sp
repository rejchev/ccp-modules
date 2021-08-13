#pragma newdecls required

#define INCLUDE_RIPJSON

#if defined INCLUDE_DEBUG
    #define DEBUG "[Channel-mgr]"
#endif

#include <ccprocessor>

public Plugin myinfo = 
{
	name = "[CCP] Channel manager",
	author = "rej. chev?",
	description = "...",
	version = "1.0.1",
	url = "https://discord.gg/cFZ97Mzrjy"
};

static const char pkgKey[] = "channel_mgr";

bool g_bLate;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
    #if defined DEBUG
        DBUILD()
    #endif

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
        "ccp-saytext2.smx", "ccp-radiomsg.smx", "ccp-textmsg.smx", "ccp-saytext.smx"
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