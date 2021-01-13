#pragma newdecls required

#include <ccprocessor>
#include <ccprocessor_pkg>

#include <ripext_m>

public Plugin myinfo = 
{
	name = "[CCP] Cloud Config",
	author = "nyoood?",
	description = "...",
	version = "1.0.0",
	url = "discord.gg/ChTyPUG"
};

static const char pkgKey[] = "cloud_cfg";

char g_szURL[NAME_LENGTH];
char g_szEndPoint[MESSAGE_LENGTH];

public void ccp_OnPackageAvailable(int iClient, Handle hPkg) {
    JSONObject pkg = asJSONO(hPkg);

    if(pkg.HasKey(pkgKey)) {
        return;
    }

    if(!iClient) {
        static char config[MESSAGE_LENGTH] = "configs/ccprocessor/cloud/cloud.json";

        if(config[0] == 'c') {
            BuildPath(Path_SM, config, sizeof(config), config);
        }

        if(!FileExists(config)) {
            SetFailState("");
        }

        pkg.Set(pkgKey, JSONObject.FromFile(config, 0));
        pkg = asJSONO(pkg.Get(pkgKey));

        pkg.GetString("url", g_szURL, sizeof(g_szURL));
        pkg.GetString("endpoint", g_szEndPoint, sizeof(g_szEndPoint));

        delete pkg;
    }
}

public void ccp_OnPackageAvailable_Pre(int iClient, Handle hPkg) {
    if(g_szURL[0] && g_szEndPoint[0] && iClient) {
        int accountId;
        if(!(accountId = GetSteamAccountID(iClient))) {
            return;
        }

        // But this is async call
        HTTPClient httpCl = new HTTPClient(g_szURL);

        char szEnd[MESSAGE_LENGTH];
        FormatEx(szEnd, sizeof(szEnd), "%s/%i", g_szEndPoint, accountId);

        httpCl.Get(szEnd, onResponse, GetClientUserId(iClient));

        delete httpCl;
    }
}

public void onResponse(HTTPResponse response, any value, const char[] error) {
    if(response.Status != HTTPStatus_OK || error[0] || !(value = GetClientOfUserId(value)) || !IsClientInGame(value)) {
        return;
    }

    ccp_UpdatePackage(value, response.Data);
}