#pragma newdecls required

#if defined INCLUDE_DEBUG
    #define DEBUG "[Cloud-Config]"
#endif

#include <ccprocessor>
#include <ccprocessor_pkg>

#undef REQUIRE_EXTENSIONS
#include <ripext_m>
#define REQUIRE_EXTENSIONS

public Plugin myinfo = 
{
	name = "[CCP] Cloud Config",
	author = "nyood?",
	description = "...",
	version = "1.0.2",
	url = "discord.gg/ChTyPUG"
};

static const char pkgKey[] = "cloud_cfg";

char g_szUrl[MESSAGE_LENGTH];

public void OnMapStart() {
    #if defined DEBUG
    DBUILD()
    #endif
}

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

        JSONObject objFile = JSONObject.FromFile(config, 0);
        objFile.GetString("url", g_szUrl, sizeof(g_szUrl));

        pkg.Set(pkgKey, objFile);
        delete objFile;
    }
}

public void ccp_OnPackageAvailable_Pre(int iClient, Handle hPkg) {
    if(g_szUrl[0] && iClient) {
        LoadRequest(iClient, createClient(), GetClientAuthIdEx(iClient));
    }
}

public void ccp_OnPackageRemove(int iClient, Handle jsonObj) {
    if(g_szUrl[0] && iClient && jsonObj) {
        UpdateRequest(iClient, createClient(), GetClientAuthIdEx(iClient), asJSONO(jsonObj));
    }
}

void LoadRequest(int iClient, HTTPClient http, const char[] steam) {
    #if defined DEBUG
    DWRITE("%s: LoadRequest(%N): http(%x), steam('%s')", DEBUG, iClient, http, steam);
    #endif

    if(http && steam[0]) {
        JSONObject route = GetRoutePkg("loadUser");

        if(route) {
            char szRoute[MAX_LENGTH];
            route.GetString("route", szRoute, sizeof(szRoute));
            
            ReplaceString(szRoute, sizeof(szRoute), "{SID}", steam);

            SetRequestHeaders(http, route);
            SetRequestProps(http, route);

            http.Get(szRoute, getClient_CallBack, GetClientUserId(iClient));
        }

        delete route;
    }

    delete http;
}

public void getClient_CallBack(HTTPResponse response, any value, const char[] error) {
    if(error[0]) {
        LogError("getClient_CallBack(%d): %s", response.Status, error);
        return;
    }

    if(!(value = GetClientOfUserId(value)) || !IsClientInGame(value)) {
        #if defined DEBUG
        DWRITE("%s: CallBack(getClient_CallBack): Invalid Client '%d'", DEBUG, value);
        #endif
    }

    JSONObject route = GetRoutePkg("loadUser");
    if(route && route.GetInt("responseCode") == view_as<int>(response.Status)) {
        char szKey[64];
        route.GetString("responseData", szKey, sizeof(szKey));

        JSONObject objClient = asJSONO(response.Data);
        if(szKey[0]) {
            objClient = asJSONO(objClient.Get(szKey));
        }

        ccp_UpdatePackage(value, objClient);
        delete objClient;
    } else {
        #if defined DEBUG
        DWRITE("%s: CallBack(getClient_CallBack) response code ('%d')", DEBUG, response.Status);
        #endif
    }

    delete route;
}

void UpdateRequest(int iClient, HTTPClient http, const char[] steam, JSONObject client) {
    #if defined DEBUG
    DWRITE("%s: UpdateRequest(%N): http(%x), steam('%s')", DEBUG, iClient, http, steam);
    #endif

    if(http && steam[0]) {
        JSONObject route = GetRoutePkg("updateUser");

        if(route) {
            char szRoute[MAX_LENGTH];
            route.GetString("route", szRoute, sizeof(szRoute));
            
            ReplaceString(szRoute, sizeof(szRoute), "{SID}", steam);

            SetRequestHeaders(http, route);
            SetRequestProps(http, route);

            char szMethod[8];
            route.GetString("method", szMethod, sizeof(szMethod));

            if(szMethod[1] == 'U') {
                http.Put(szRoute, client, updateClient_CallBack);
            } else if(szMethod[1] == 'A') {
                http.Patch(szRoute, client, updateClient_CallBack);
            } else if(szMethod[1] == 'O') {
                http.Post(szRoute, client, updateClient_CallBack);
            }
        }

        delete route;
    }   

    delete http;  
}

public void updateClient_CallBack(HTTPResponse response, any value, const char[] error) {
    if(error[0]) {
        LogError("updateClient_CallBack(%d): %s", response.Status, error);
        return;
    }

    #if defined DEBUG
    DWRITE("%s: CallBack(updateClient_CallBack) response code ('%d')", DEBUG, response.Status);
    #endif
}


void SetRequestHeaders(HTTPClient http, JSONObject route) {
    char szKey[64], szValue[MESSAGE_LENGTH];
    
    JSONObject headers = asJSONO(route.Get("headers"));
    JSONObjectKeys objKeys = asJSONK(headers.Keys());

    if(objKeys) {
        while(objKeys.ReadKey(szKey, sizeof(szKey))) {
            if(headers.GetString(szKey, szValue, sizeof(szValue))) {
                #if defined DEBUG
                DWRITE("%s: SetHeaders(%x): %s = %s", DEBUG, http, szKey, szValue);
                #endif
                
                http.SetHeader(szKey, szValue);
            }
        }
    }

    delete objKeys;
    delete headers;
}

void SetRequestProps(HTTPClient http, JSONObject route) {
    if(route.HasKey("ConnectTimeout")) {
        http.ConnectTimeout = route.GetInt("ConnectTimeout");
    }

    if(route.HasKey("Timeout")) {
        http.Timeout = route.GetInt("Timeout");
    }

    if(route.HasKey("FollowLocation")) {
        http.FollowLocation = route.GetBool("FollowLocation");
    }
}

JSONObject GetRoutePkg(const char[] key) {
    JSONObject pkg = asJSONO(asJSONO(ccp_GetPackage(0)).Get(pkgKey));
    if(!pkg || !pkg.HasKey(key)) {
        delete pkg;
        return null;
    }

    JSONObject routePkg = asJSONO(pkg.Get(key));

    delete pkg;
    return routePkg;
}

HTTPClient createClient() {
    return new HTTPClient(g_szUrl);
}

stock char[] GetClientAuthIdEx(int iClient) {
    char szAuth[66];
    if(!GetClientAuthId(iClient, AuthId_Steam2, szAuth, sizeof(szAuth))) {
        szAuth = NULL_STRING;
    }

    return szAuth;
}