#pragma newdecls required

// <jansson>
#define INCLUDE_JSON

// <packager>
#define INCLUDE_PACKAGER

// <storage>
#define INCLUDE_STORAGE

#include <ccprocessor>

public Plugin myinfo = 
{
	name = "[CCP] Custom Chat",
	author = "rej.chev?",
	description = "...",
	version = "3.4.0",
	url = "discord.gg/ChTyPUG"
};

int LEVEL[4];
bool IsMenuDisabled;

static const char pkgKey[] = "ccm";

bool g_bLate;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
    g_bLate = late;
    return APLRes_Success;
}

public void OnPluginStart()
{
    LoadTranslations("ccp_customchat.phrases");

    manageConVars();

    RegConsoleCmd("sm_prefix", Cmd_Prefix);
}

void manageConVars(bool bCreate = true) {
    char szBuffer[128];

    for(int i; i < BIND_MAX; i++) {
        if(indexPart(i) == -1)
            continue;

        FormatBind("ccm_", i, 'l', szBuffer, sizeof(szBuffer)/2);
        if(bCreate){
            Format(szBuffer[strlen(szBuffer)+1], sizeof(szBuffer), "Priority level for %s", szBinds[i]);
            CreateConVar(szBuffer, "1", szBuffer[strlen(szBuffer)+1], _, true, 1.0).AddChangeHook(onChange);
        } else {
            onChange(FindConVar(szBuffer), NULL_STRING, NULL_STRING);
        }
    }
    
    if(bCreate) {
        
        CreateConVar("ccm_disable_menu", "0", "Disable menu", _, true, 0.0, true, 1.0).AddChangeHook(disableMenu);
        AutoExecConfig(true, "ccp_ccmessage", "ccprocessor");
    } else {
        disableMenu(FindConVar("ccm_disable_menu"), NULL_STRING, NULL_STRING);
    }
}

public void onChange(ConVar convar, const char[] oldVal, const char[] newVal)
{
    char szBuffer[64];
    convar.GetName(szBuffer, sizeof(szBuffer));

    int part = BindFromString(szBuffer);
    if(part == BIND_MAX || (part = indexPart(part)) == -1)
        return;
    
    LEVEL[part] = convar.IntValue;
}

public void disableMenu(ConVar convar, const char[] oldVal, const char[] newVal)
{
    IsMenuDisabled = convar.BoolValue;
}

public void OnMapStart() {
    cc_proc_APIHandShake(cc_get_APIKey());
    manageConVars(false);

    if(g_bLate) {
        g_bLate = false;

        for(int i; i <= MaxClients; i++) {
            if(pckg_HasPackage(i)) {
                pckg_OnPackageAvailable(i);
            }
        }
    }
}

public void pckg_OnPackageAvailable(int iClient) {
    static char szBuffer[MESSAGE_LENGTH] = "configs/ccprocessor/customchat/ccm.json";

    JsonObject packet;
    if(!iClient) {
        
        if(szBuffer[0] == 'c')
            BuildPath(Path_SM, szBuffer, sizeof(szBuffer), szBuffer);

        else if(!FileExists(szBuffer))
            SetFailState("Where is my config: %s", szBuffer);
    }

    packet = !iClient 
                ? asJSONO(Json.JsonF(szBuffer, 0)) 
                : asJSONO(storage_ReadValue(iClient, pkgKey));

    if(iClient && !packet)
        packet = GetTemplate(iClient);

    if(packet)
        pckg_SetArtifact(iClient, pkgKey, packet);

    delete packet;
}

public void OnClientPostAdminCheck(int iClient) {
    JsonObject pkg;
    if(!(pkg = asJSONO(pckg_GetPackage(iClient)))) {
        return;
    }

    if(!pkg.HasKey("flags"))
        pkg.SetInt("flags", GetUserFlagBits(iClient));
    
    if(!pkg.HasKey("adminId"))
        pkg.SetInt("adminId", view_as<int>(GetUserAdmin(iClient)));

    if(pckg_SetPackage(iClient, pkg))
        pckg_OnPackageAvailable(iClient);

    delete pkg;
}

JsonObject GetTemplate(int iClient, int index = -1) {    
    JsonObject artifact;
    artifact = asJSONO(pckg_GetArtifact(0, pkgKey));

    JsonArray templates;
    if(!artifact.HasKey("items")) {
        delete artifact;
        return artifact;
    }

    templates = asJSONA(artifact.Get("items"));
    delete artifact;

    JsonObject client;
    JsonObject buffer;
    JsonObject template;

    if(index != -1) 
        template = asJSONO(templates.Get(index));
    
    else {
        client = asJSONO(pckg_GetPackage(iClient));

        for(int i, b, c; i < templates.Length; i++) {
            buffer = asJSONO(templates.Get(i));

            c = buffer.GetInt("priority");
            if(c > b && HasAccess(client, buffer)) {
                delete template;
                template = asJSONO(templates.Get(i));
            }

            delete buffer;
        }
    }

    delete client;
    delete templates;

    return template;
}

public Action Cmd_Prefix(int iClient, int args) {
    if(iClient && IsClientInGame(iClient) && pckg_HasPackage(iClient)) {
        
        if(!pckg_IsVerified(iClient)) {
            PrintToChat(iClient, "%T", "auth_failed", iClient);
            return Plugin_Handled;
        }

        if(IsMenuDisabled) {
            if(!pckg_HasArtifact(iClient, pkgKey)) {
                JsonObject buffer = GetTemplate(iClient);
                if(pckg_SetArtifact(iClient, pkgKey, buffer)) {
                    delete buffer;

                    buffer = asJSONO(pckg_GetArtifact(iClient, pkgKey));
                    storage_WriteValue(iClient, pkgKey, buffer);
                }

                delete buffer;
            } else {
                if(pckg_RemoveArtifact(iClient, pkgKey))
                    storage_RemoveValue(iClient, pkgKey);
            }
        } else {
            menuTemplates(iClient);
        }
    }
    
    return Plugin_Handled;
}

void menuTemplates(int iClient) {
    Menu hMenu = new Menu(menuCallBack);

    hMenu.SetTitle("%T \n \n", "choose_template", iClient);

    char szBuffer[256];

    JsonObject obj = asJSONO(pckg_GetArtifact(0, pkgKey));

    if(!obj.HasKey("items")) {
        delete obj;
        return;
    }

    JsonArray objArray = asJSONA(obj.Get("items"));
    delete obj;

    char szValue[64];
    int drawType = ITEMDRAW_DEFAULT;

    if(pckg_HasArtifact(iClient, pkgKey)) {
        obj = asJSONO(pckg_GetArtifact(iClient, pkgKey));
        obj.GetString("name", szValue, sizeof(szValue));
        delete obj;
    } else {
        drawType = ITEMDRAW_DISABLED;
    }

    JsonObject objClient = asJSONO(pckg_GetPackage(iClient));

    FormatEx(szBuffer, sizeof(szBuffer), "d%T \n \n", "remove", iClient);
    hMenu.AddItem(szBuffer, szBuffer[1], drawType);

    for(int i; i < objArray.Length; i++) {
        obj = asJSONO(objArray.Get(i));
        obj.GetString("name", szBuffer, sizeof(szBuffer));

        drawType = (!strcmp(szValue, szBuffer)) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT;
        
        Format(szBuffer, sizeof(szBuffer), "%c%T", i+1, szBuffer, iClient);

        if(HasAccess(objClient, obj)) {
            hMenu.AddItem(szBuffer, szBuffer[1], drawType);
        }

        delete obj;
    }

    delete objArray;
    delete objClient;
    delete obj;

    hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int menuCallBack(Menu hMenu, MenuAction action, int iClient, int param) {
    switch(action) {
        case MenuAction_End: delete hMenu;
        case MenuAction_Select: {
            char item[64];
            hMenu.GetItem(param, item, sizeof(item));

            int index = item[0];
            if(index == 'd') {
                if(pckg_RemoveArtifact(iClient, pkgKey))
                    storage_RemoveValue(iClient, pkgKey);
            } else {
                index -= 1;

                JsonObject artifact = GetTemplate(iClient, index);
                if(pckg_SetArtifact(iClient, pkgKey, artifact)) {
                    delete artifact;

                    artifact = asJSONO(pckg_GetArtifact(iClient, pkgKey));
                    storage_WriteValue(iClient, pkgKey, artifact);
                }

                delete artifact;
            }
            
            menuTemplates(iClient);
        }
    }
}

JsonObject senderModel;

public Processing  cc_proc_OnRebuildString(const int[] props, int part, ArrayList params, int &level, char[] value, int size) {
    JsonArray channels;

    senderModel = asJSONO(pckg_GetArtifact(0, pkgKey));
    channels = asJSONA(senderModel.Get("channels"));

    delete senderModel;

    char szIndent[64];
    params.GetString(0, szIndent, sizeof(szIndent));
    
    if(FindChannelInChannels_json(channels, szIndent) == -1 || !SENDER_INDEX(props[1])) {
        delete channels;
        return Proc_Continue;
    }

    delete channels;

    if(!pckg_HasArtifact(SENDER_INDEX(props[1]), pkgKey))
        return Proc_Continue;

    senderModel = asJSONO(pckg_GetArtifact(SENDER_INDEX(props[1]), pkgKey));
    
    int index = indexPart(part);
    if(index == -1 || LEVEL[index] < level || !senderModel.HasKey(szBinds[part])) {
        delete senderModel;
        return Proc_Continue;
    }
    
    static char szValue[MESSAGE_LENGTH];
    senderModel.GetString(szBinds[part], szValue, sizeof(szValue));

    if(!szValue[0]) {
        delete senderModel;
        return Proc_Continue;
    }
    
    if(part == BIND_PREFIX)
        Format(szValue, sizeof(szValue), "%T", szValue, props[2]);
    
    level = LEVEL[index];
    FormatEx(value, size, szValue);

    delete senderModel;
    return Proc_Change;  
}

bool HasAccess(JsonObject objClient, JsonObject jsonModel) {
    char szBuffer[64], szValue[64];

    int type = jsonModel.GetInt("type");
    jsonModel.GetString("value", szValue, sizeof(szValue));

    switch(type) {
        // auth
        case 1: {
            objClient.GetString("auth", szBuffer, sizeof(szBuffer));

            if(strcmp(szValue, szBuffer)) {
                return false;
            } 
        }
        // flag 
        case 2: {
            if(!objClient.HasKey("flags") || !(objClient.GetInt("flags") & ReadFlagString(szValue))) {
                return false;
            }
        }
        // group
        case 3: {
            int d;
            if(!objClient.HasKey("adminId") || view_as<AdminId>((d = objClient.GetInt("adminId"))) == INVALID_ADMIN_ID) {
                return false;
            }

            for(int j; j < view_as<AdminId>(d).GroupCount; j++) {
                view_as<AdminId>(d).GetGroup(j, szBuffer, sizeof(szBuffer));

                if(!strcmp(szBuffer, szValue)) {
                    break;
                }

                szBuffer = NULL_STRING;
            }

            if(!szBuffer[0]) {
                return false;
            }
        }

        default: return false;
    }

    return true;
}

int indexPart(int part) {
    static const int parts[] = { BIND_PREFIX_CO, BIND_PREFIX, BIND_NAME_CO, BIND_MSG_CO };

    int i;
    while(i < sizeof(parts))
        if(part == parts[i++])
            return i-1;
    
    return -1;
}