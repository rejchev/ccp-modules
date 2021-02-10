#pragma newdecls required

#if defined INCLUDE_DEBUG
    #define DEBUG "[Packager]"
#endif

#include <ccprocessor>

#undef REQUIRE_EXTENSIONS
#include <ripext_m>
#define REQUIRE_EXTENSIONS

public Plugin myinfo = 
{
	name = "[CCP] JSON Packager",
	author = "nyoood?",
	description = "...",
	version = "1.0.2",
	url = "discord.gg/ChTyPUG"
};

JSONObject jClients[MAXPLAYERS+1];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
    #if defined DEBUG
    DBUILD()
    #endif

    CreateNative("ccp_GetPackage", Native_GetPackage);
    CreateNative("ccp_UpdatePackage", Native_UpdatePackage);
    
    RegPluginLibrary("ccprocessor_pkg");

    if(late) {
        for(int i =1; i <= MaxClients; i++) {
            if(IsClientInGame(i)) {
                OnClientDisconnect(i);
                OnClientPutInServer(i);
            }
        }
    }
}

public void OnMapStart() {
    #if defined DEBUG
    DBUILD()
    #endif

    Call_pkgReady(0);
}

public void OnMapEnd() {
    Call_pkgClear(0);
}

public void OnClientPutInServer(int iClient) {
    if(IsFakeClient(iClient) || IsClientSourceTV(iClient))
        return;

    Call_pkgReady(iClient);
}

public void OnClientDisconnect(int iClient) {
    if(IsFakeClient(iClient) || IsClientSourceTV(iClient))
        return;

    Call_pkgClear(iClient);
}

public any Native_GetPackage(Handle h, int a) {
    int iClient = GetNativeCell(1);

    if(iClient < 0 || iClient >= MAXPLAYERS+1) {
        ThrowNativeError(SP_ERROR_INDEX, "Invalid client '%d' index", iClient);
    }

    return jClients[iClient];
}

public any Native_UpdatePackage(Handle h, int a) {
    int iClient = GetNativeCell(1);
    if(iClient < 0 || iClient >= MAXPLAYERS+1) {
        ThrowNativeError(SP_ERROR_INDEX, "Invalid client '%d' index", iClient);
    }

    if(jClients[iClient]) {
        delete jClients[iClient];
    }

    char szBuffer[2048];
    view_as<JSON>(GetNativeCell(2)).ToString(szBuffer, sizeof(szBuffer), 0);
    
    #if defined DEBUG
    DWRITE("%s: Native(update): => \n%s", DEBUG, szBuffer);
    #endif

    jClients[iClient] = JSONObject.FromString(szBuffer);

    GetPluginFilename(h, szBuffer, sizeof(szBuffer));
    jClients[iClient].SetBool("cloud", StrContains(szBuffer, "ccp-cloud") != -1);

    pkgUpdated(iClient, h); 

    return jClients[iClient];
}

void packageReady_Pre(int iClient) {
    static GlobalForward h;
    if(!h)
        h = new GlobalForward("ccp_OnPackageAvailable_Pre", ET_Ignore, Param_Cell, Param_Cell);

    Call_StartForward(h);
    Call_PushCell(iClient);
    Call_PushCell(jClients[iClient]);
    Call_Finish();
}

void packageReady(int iClient) {
    static GlobalForward h;
    if(!h)
        h = new GlobalForward("ccp_OnPackageAvailable", ET_Ignore, Param_Cell, Param_Cell);

    Call_StartForward(h);
    Call_PushCell(iClient);
    Call_PushCell(jClients[iClient]);
    Call_Finish();
}

void Call_pkgReady(int iClient) {
    pkgInit(iClient);

    packageReady_Pre(iClient);
    packageReady(iClient);
}

void Call_pkgClear(int iClient) {
    static GlobalForward h;
    if(!h)
        h = new GlobalForward("ccp_OnPackageRemove", ET_Ignore, Param_Cell, Param_Cell);

    Call_StartForward(h);
    Call_PushCell(iClient);
    Call_PushCell(jClients[iClient]);
    Call_Finish();

    pkgClear(iClient);
}

void pkgInit(int iClient) {
    if(!jClients[iClient]) {
        jClients[iClient] = new JSONObject();
    }
}

void pkgClear(int iClient) {
    delete jClients[iClient];
}

void pkgUpdated(int iClient, Handle hInitiator) {
    static GlobalForward h;
    if(!h)
        h = new GlobalForward("ccp_OnPackageUpdated", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);

    Call_StartForward(h);
    Call_PushCell(iClient);
    Call_PushCell(jClients[iClient]);
    Call_PushCell(hInitiator);
    Call_Finish();
}