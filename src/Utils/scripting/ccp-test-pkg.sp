#pragma newdecls required

#define INCLUDE_RIPJSON

#define DEBUG "[Packager-Test]"

#include <ccprocessor>
#include <ccprocessor_pkg>

public Plugin myinfo = 
{
	name = "[CCP] Packager Test",
	author = "rej.chev",
	description = "...",
	version = "1.0.0",
	url = "discord.gg/ChTyPUG"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
    OnMapStart();
}

public void OnMapStart() {
    DBUILD()
}

public void ccp_OnPackageAvailable(int iClient) {
    static char szBuffer[MAX_LENGTH];
    JSONObject pkg = asJSONO(ccp_GetPackage(iClient));

    view_as<JSON>(pkg).ToString(szBuffer, sizeof(szBuffer), JSON_COMPACT);

    DWRITE("%s: ccp_OnPackageAvailable(): \
            \n\t\t\t\tClient: %N \
            \n\t\t\t\tBuffer: %s", DEBUG, iClient, szBuffer);

    delete pkg;

    pkg = asJSONO(ccp_GetPackage(iClient));
    pkg.SetInt("test", 1);
    ccp_SetPackage(iClient, pkg, 0x01);
    delete pkg;

    pkg = new JSONObject();
    pkg.SetString("test", "test");
    ccp_SetArtifact(iClient, "myself", pkg, 0x01);

    DWRITE("%s: ccp_OnPackageAvailable(): \
            \n\t\t\t\tClient: %N \
            \n\t\t\t\tHasArtifact(myself): %b", DEBUG, iClient, ccp_HasArtifact(iClient, "myself"));

    delete pkg;

    pkg = asJSONO(ccp_GetPackage(iClient));

    view_as<JSON>(pkg).ToString(szBuffer, sizeof(szBuffer), 0);

    DWRITE("%s: ccp_OnPackageAvailable(): \
            \n\t\t\t\tClient: %N \
            \n\t\t\t\tBuffer: %s", DEBUG, iClient, szBuffer);

    delete pkg;

    pkg = asJSONO(ccp_GetArtifact(iClient, "myself"));
    view_as<JSON>(pkg).ToString(szBuffer, sizeof(szBuffer), JSON_COMPACT);

    DWRITE("%s: ccp_OnPackageAvailable(artifact): \
            \n\t\t\t\tClient: %N \
            \n\t\t\t\tBuffer: %s", DEBUG, iClient, szBuffer);

    delete pkg;

}

public Processing ccp_OnPackageUpdate(Handle ctx, any &level) {
    JSONObject obj = asJSONO(ctx);
    
    static char field[PREFIX_LENGTH];
    obj.GetString("field", field, sizeof(field));

    JSON value;
    if(!obj.IsNull(field)) {
        value = obj.Get(field);
    }

    static char szBuffer[MAX_LENGTH];
    if(value) 
        value.ToString(szBuffer, sizeof(szBuffer), JSON_COMPACT);

    DWRITE("%s: ccp_OnPackageUpdate():\
            \n\t\t\t\tClient: %N \
            \n\t\t\t\tField: %s \
            \n\t\t\t\tisArtifact: %b \
            \n\t\t\t\tValue: %s \
            \n\t\t\t\tLevel: %d", DEBUG, GetClientOfUserId(obj.GetInt("client")), field, obj.GetBool("isArtifact"), szBuffer, level);
    
    delete value;
}

public void ccp_OnPackageUpdate_Post(Handle ctx, any level) {

}