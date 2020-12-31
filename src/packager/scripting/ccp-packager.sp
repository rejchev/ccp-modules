#include <jansson>

public Plugin myinfo = 
{
	name = "[CCP] Packager",
	author = "nyoood?",
	description = "...",
	version = "1.0.0",
	url = "discord.gg/ChTyPUG"
};

JSONObject jClients[MAXPLAYERS+1];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
    CreateNative("ccp_GetPackage", Native_GetPackage);
    
    RegPluginLibrary("ccprocessor_pkg");
}

public void OnPluginStart() {
    jClients[0] = new JSONObject();
}

public void OnMapStart() {
    pkgRemove(0);

    if(!jClients[0].Clear()) {
        delete jClients[0];
        jClients[0] = new JSONObject();
    }

    packageReady(0);
}

public void OnClientPutInServer(int iClient) {
    delete jClients[iClient];
    if(IsFakeClient(iClient) || IsClientSourceTV(iClient))
        return;

    jClients[iClient] = new JSONObject();
    packageReady(iClient);
}

public void OnClientDisconnect(int iClient) {
    if(jClients[iClient]) {
        pkgRemove(iClient);

        delete jClients[iClient];
    }
}

public any Native_GetPackage(Handle h, int a) {
    int iClient = GetNativeCell(1);

    if(iClient < 0 || iClient >= MAXPLAYERS+1) {
        ThrowNativeError(SP_ERROR_INDEX, "Invalid client '%d' index", iClient);
    }

    return jClients[iClient];
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

void pkgRemove(int iClient) {
    static GlobalForward h;
    if(!h)
        h = new GlobalForward("ccp_OnPackageRemove", ET_Ignore, Param_Cell, Param_Cell);

    Call_StartForward(h);
    Call_PushCell(iClient);
    Call_PushCell(jClients[iClient]);
    Call_Finish();
}