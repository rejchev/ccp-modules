#pragma newdecls required

#define INCLUDE_RIPJSON

#include <ccprocessor>

#include <clientprefs>

public Plugin myinfo = 
{
	name = "[CCP] Custom Chat",
	author = "nullent?",
	description = "...",
	version = "3.3.6",
	url = "discord.gg/ChTyPUG"
};

int LEVEL[4];
Cookie coHandle;
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
        coHandle = new Cookie("ccm_prefix", NULL_STRING, CookieAccess_Private);
        
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
            if(ccp_HasPackage(i)) {
                ccp_OnPackageAvailable(i);
            }
        }
    }
}

public void ccp_OnPackageAvailable(int iClient) {
    static char szBuffer[MESSAGE_LENGTH] = "configs/ccprocessor/customchat/ccm.json";

    JSON packet;
    if(!iClient) {
        
        if(szBuffer[0] == 'c')
            BuildPath(Path_SM, szBuffer, sizeof(szBuffer), szBuffer);

        else if(!FileExists(szBuffer))
            SetFailState("Where is my config: %s", szBuffer);
    }

    packet = !iClient ? view_as<JSON>(JSONArray.FromFile(szBuffer, 0)) : GetValueFromCookie(iClient);

    ccp_SetArtifact(iClient, pkgKey, packet, (!iClient) ? CALL_IGNORE : CALL_DEFAULT);

    delete packet;
}

public void OnClientPostAdminCheck(int iClient) {
    JSONObject pkg;
    if(!(pkg = asJSONO(ccp_GetPackage(iClient)))) {
        return;
    }

    if(!pkg.HasKey("flags"))
        pkg.SetInt("flags", GetUserFlagBits(iClient));
    
    if(!pkg.HasKey("adminId"))
        pkg.SetInt("adminId", view_as<int>(GetUserAdmin(iClient)));

    ccp_SetPackage(iClient, pkg, CALL_DEFAULT);

    if(!pkg.HasKey(pkgKey)) {
        ccp_OnPackageAvailable(iClient);
    }

    delete pkg;
}

JSON GetValueFromCookie(int iClient) {
    JSONObject client = asJSONO(ccp_GetPackage(iClient));

    char szValue[MESSAGE_LENGTH];
    coHandle.Get(iClient, szValue, sizeof(szValue));
    
    JSONObject jsonModel

    if(szValue[0]) {
        jsonModel = FindInObjects(szValue);

        if(!jsonModel || !HasAccess(client, jsonModel))
            delete jsonModel;
    }

    delete client;
    return jsonModel;
}

JSONObject GetTemplate(int iClient, int index = -1) {    
    if(!ccp_HasArtifact(0, pkgKey))
        SetFailState("Artifact: %s is gone away?", pkgKey);
    
    JSONArray templates;
    if((templates = asJSONA(ccp_GetArtifact(0, pkgKey))) == null || !templates.Length) {
        delete templates;
        return null;
    }

    JSONObject client;
    JSONObject buffer;
    JSONObject template;

    if(index != -1) 
        template = asJSONO(templates.Get(index));
    
    else {
        client = asJSONO(ccp_GetPackage(iClient));

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
    if(iClient && IsClientInGame(iClient) && ccp_HasPackage(iClient)) {
        
        if(!ccp_IsVerified(iClient)) {
            PrintToChat(iClient, "%T", "auth_failed", iClient);
            return Plugin_Handled;
        }

        if(IsMenuDisabled) {
            if(!ccp_HasArtifact(iClient, pkgKey)) {
                JSONObject buffer = GetTemplate(iClient);
                ccp_SetArtifact(iClient, pkgKey, buffer, CALL_DEFAULT);

                char szValue[PREFIX_LENGTH];
                buffer.GetString("name", szValue, sizeof(szValue));
                coHandle.Set(iClient, szValue);

                delete buffer;
            } else {
                if(ccp_RemoveArtifact(iClient, pkgKey, CALL_IGNORE))
                    coHandle.Set(iClient, NULL_STRING);
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

    JSONObject objClient = asJSONO(ccp_GetPackage(iClient));
    JSONArray objArray = asJSONA(ccp_GetArtifact(0, pkgKey));
    JSONObject obj;
    int drawType = ITEMDRAW_DEFAULT;
    char szValue[64];
    if(objClient.HasKey(pkgKey) && !objClient.IsNull(pkgKey)) {
        obj = asJSONO(objClient.Get(pkgKey));
        obj.GetString("name", szValue, sizeof(szValue));
        delete obj;
    } else {
        drawType = ITEMDRAW_DISABLED;
    }

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
                if(ccp_RemoveArtifact(iClient, pkgKey, CALL_DEFAULT))
                    coHandle.Set(iClient, NULL_STRING); 
            } else {
                index -= 1;

                JSONObject artifact = GetTemplate(iClient, index);
                ccp_SetArtifact(iClient, pkgKey, artifact, CALL_DEFAULT);

                char szValue[PREFIX_LENGTH];
                artifact.GetString("name", szValue, sizeof(szValue));
                coHandle.Set(iClient, szValue);

                delete artifact;
            }
            
            menuTemplates(iClient);
        }
    }
}

JSONObject senderModel;

public Processing  cc_proc_OnRebuildString(const int[] props, int part, ArrayList params, int &level, char[] value, int size) {
    static char channels[][] = {"ST1", "STA", "STP"};

    char szIndent[64];
    params.GetString(0, szIndent, sizeof(szIndent));
    
    if(FindChannelInChannels(channels, sizeof(channels), szIndent) == -1 || !SENDER_INDEX(props[1])) {
        return Proc_Continue;
    }

    if(!ccp_HasArtifact(SENDER_INDEX(props[1]), pkgKey))
        return Proc_Continue;

    senderModel = asJSONO(ccp_GetArtifact(SENDER_INDEX(props[1]), pkgKey));
    
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

bool HasAccess(JSONObject objClient, JSONObject jsonModel) {
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

JSONObject FindInObjects(const char[] szName) {
    JSONArray jsonItems;
    if((jsonItems = asJSONA(ccp_GetArtifact(0, pkgKey))) == null)
        return null;

    JSONObject obj;
    if(jsonItems.Length) {
        char szValue[MESSAGE_LENGTH];

        for(int i; i < jsonItems.Length; i++) {
            obj = asJSONO(jsonItems.Get(i));
            obj.GetString("name", szValue, sizeof(szValue));

            if(StrEqual(szValue, szName, false)) {
                break;
            }

            delete obj;
        }
    }
    
    delete jsonItems;
    return obj;
}
