#pragma newdecls required

#include <ccprocessor>
#include <ccprocessor_pkg>

#include <clientprefs>

#undef REQUIRE_EXTENSIONS
#include <ripext_m>
#define REQUIRE_EXTENSIONS

public Plugin myinfo = 
{
	name = "[CCP] Custom Chat",
	author = "nullent?",
	description = "...",
	version = "3.3.3",
	url = "discord.gg/ChTyPUG"
};

int LEVEL[4];
Cookie coHandle;
bool IsMenuDisabled;

static const char objKey[] = "ccm";

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
}

public void ccp_OnPackageAvailable(int iClient, Handle objClient) {
    JSONObject pkg = asJSONO(objClient);

    if(!iClient) {
        static char szBuffer[MESSAGE_LENGTH] = "configs/ccprocessor/customchat/ccm.json";
        if(szBuffer[0] == 'c') {
            BuildPath(Path_SM, szBuffer, sizeof(szBuffer), szBuffer);
        } else if(!FileExists(szBuffer)) {
            SetFailState("Where is my config: %s", szBuffer);
        }

        JSONArray jsonInput = JSONArray.FromFile(szBuffer, 0);
        pkg.Set(objKey, jsonInput);
        delete jsonInput;
    } else {
        if(!pkg.HasKey("auth")) {
            char szBuffer[64];
            GetClientAuthId(iClient, AuthId_Engine, szBuffer, sizeof(szBuffer));
            pkg.SetString("auth", szBuffer);
        }

        GetValueFromCookie(iClient, pkg);
    }
}

public void OnClientPostAdminCheck(int iClient) {
    JSONObject pkg = asJSONO(ccp_GetPackage(iClient));
    if(!pkg) {
        return;
    }

    if(!pkg.HasKey("flags"))
        pkg.SetInt("flags", GetUserFlagBits(iClient));
    
    if(!pkg.HasKey("adminId"))
        pkg.SetInt("adminId", view_as<int>(GetUserAdmin(iClient)));

    if(!pkg.HasKey(objKey)) {
        GetValueFromCookie(iClient, pkg);
    }
}

void GetValueFromCookie(int iClient, JSONObject pkg) {
    char szValue[MESSAGE_LENGTH];
    coHandle.Get(iClient, szValue, sizeof(szValue));
    
    if(szValue[0]) {
        JSONObject jsonModel = FindInObjects(szValue);

        if(jsonModel && HasAccess(pkg, jsonModel)) {
            pkg.Set(objKey, jsonModel);
        }

        delete jsonModel;
    }
}

void setTemplate(int iClient, JSONObject pkg, int index = -1) {    
    JSONArray jsonArray = asJSONA(asJSONO(ccp_GetPackage(0)).Get(objKey));
    
    if(!jsonArray) {
        return;
    } 

    if(jsonArray.Length) {
        char szValue[MESSAGE_LENGTH];
        JSONObject obj;
        if(index != -1) {
            obj = asJSONO(jsonArray.Get(index));
            obj.GetString("name", szValue, sizeof(szValue));

            if(pkg.Set(objKey, obj)){
                coHandle.Set(iClient, szValue);
            }
        } else {
            for(int i, b, c; i < jsonArray.Length; i++) {
                obj = asJSONO(jsonArray.Get(i));
                obj.GetString("name", szValue, sizeof(szValue));

                c = obj.GetInt("priority");
                if(c > b && HasAccess(pkg, obj)) {
                    b = c;
                    if(pkg.Set(objKey, obj)) {
                        coHandle.Set(iClient, szValue);
                    }
                }

                delete obj;
            }
        }
        
        delete obj;
    }

    delete jsonArray;
}

public Action Cmd_Prefix(int iClient, int args) {
    if(iClient && IsClientInGame(iClient) && !IsFakeClient(iClient))
    {
        JSONObject objClient = asJSONO(ccp_GetPackage(iClient));
        if(objClient) {
            if(IsMenuDisabled) {
                if(!objClient.HasKey(objKey)) {
                    setTemplate(iClient, objClient);
                } else {
                    objClient.Remove(objKey);
                    coHandle.Set(iClient, NULL_STRING);
                }
            } else {
                menuTemplates(iClient);
            }
        }
    }
    
    return Plugin_Handled;
}

void menuTemplates(int iClient) {
    Menu hMenu = new Menu(menuCallBack);

    hMenu.SetTitle("%T \n \n", "choose_template", iClient);

    char szBuffer[256];

    JSONObject objClient = asJSONO(ccp_GetPackage(iClient));
    JSONArray objArray = asJSONA(asJSONO(ccp_GetPackage(0)).Get(objKey));
    JSONObject obj;
    int drawType = ITEMDRAW_DEFAULT;
    char szValue[64];
    if(objClient.HasKey(objKey) && !objClient.IsNull(objKey)) {
        obj = asJSONO(objClient.Get(objKey));
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

    hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int menuCallBack(Menu hMenu, MenuAction action, int iClient, int param) {
    switch(action) {
        case MenuAction_End: delete hMenu;
        case MenuAction_Select: {
            char item[64];
            hMenu.GetItem(param, item, sizeof(item));

            JSONObject objClient = asJSONO(ccp_GetPackage(iClient));

            int index = item[0];
            if(index == 'd') {
                objClient.Remove(objKey);
            } else {
                index -= 1;
                setTemplate(iClient, objClient, index);
            }
            
            menuTemplates(iClient);
        }
    }
}

JSONObject senderModel;

public bool cc_proc_OnNewMessage(
    const char[] indent, int sender, const char[] temp_key, const char[] msg, const int[] players, int playersNum
) {
    delete senderModel;

    if((indent[0] != 'S' && indent[1] != 'T' && strlen(indent) < 3) || !sender)
        return true;

    senderModel = asJSONO(ccp_GetPackage(sender));
    if(!senderModel.HasKey(objKey) || senderModel.IsNull(objKey)) {
        senderModel = null;
        return true;
    }

    senderModel = asJSONO(senderModel.Get(objKey));
    return true;
}

public Action cc_proc_OnRebuildString(
    int mid, const char[] indent, int sender,
    int recipient, int part, int &level, 
    char[] buffer, int size
) {
    if(!senderModel)
        return Plugin_Continue;
    
    int index = indexPart(part);
    if(index == -1 || LEVEL[index] < level)
        return Plugin_Continue;

    if(!senderModel.HasKey(szBinds[part]))
        return Plugin_Continue;
    
    static char szValue[MESSAGE_LENGTH];
    senderModel.GetString(szBinds[part], szValue, sizeof(szValue));

    if(!szValue[0])
        return Plugin_Continue;
    
    if(part == BIND_PREFIX)
        Format(szValue, sizeof(szValue), "%T", szValue, recipient);
    
    level = LEVEL[index];
    FormatEx(buffer, size, szValue);

    return Plugin_Continue;  
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
    JSONArray jsonItems = asJSONA(asJSONO(ccp_GetPackage(0)).Get(objKey));
    if(!jsonItems) {
        return null;
    }

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