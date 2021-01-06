#pragma newdecls required

#include <ccprocessor>
#include <ccprocessor_pkg>

#include <clientprefs>
#include <jansson>

public Plugin myinfo = 
{
	name = "[CCP] Custom Chat",
	author = "nullent?",
	description = "...",
	version = "3.3.1",
	url = "discord.gg/ChTyPUG"
};

int LEVEL[4];
Cookie coHandle;
bool IsMenuDisabled;

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
    JSONObject pkg = view_as<JSONObject>(objClient);

    if(!iClient) {
        static char szBuffer[256] = "configs/ccprocessor/customchat/ccm.json";

        if(szBuffer[0] == 'c') {
            BuildPath(Path_SM, szBuffer, sizeof(szBuffer), szBuffer);
        } else if(!FileExists(szBuffer)) {
            SetFailState("Where is my config: %s", szBuffer);
        }

        pkg.Set("ccm", JSONArray.FromFile(szBuffer, 0));
    } else {

        if(!pkg.HasKey("auth")) {
            char szBuffer[64];
            GetClientAuthId(iClient, AuthId_Engine, szBuffer, sizeof(szBuffer));
            pkg.SetString("auth", szBuffer);
        }

        GetValueFromCookie(iClient, pkg);
        // setTemplate(iClient, pkg);
    }
}

public void OnClientPostAdminCheck(int iClient) {
    JSONObject pkg = view_as<JSONObject>(ccp_GetPackage(iClient));
    if(!pkg)
        return;
    
    if(!pkg.HasKey("flags"))
        pkg.SetInt("flags", GetUserFlagBits(iClient));
    
    if(!pkg.HasKey("adminId"))
        pkg.SetInt("adminId", view_as<int>(GetUserAdmin(iClient)));

    // setTemplate(iClient, pkg);

    if(!pkg.HasKey("ccm")) {
        GetValueFromCookie(iClient, pkg);
    }
}

void GetValueFromCookie(int iClient, JSONObject pkg) {
    char szValue[MESSAGE_LENGTH];
    coHandle.Get(iClient, szValue, sizeof(szValue));
    
    if(szValue[0]) {
        JSONObject jsonModel = FindInObjects(szValue);

        if(HasAccess(pkg, jsonModel)) {
            pkg.Set("ccm", jsonModel);
        }
    }
}

public void ccp_OnPackageRemove(int iClient, Handle objClient) {
    JSONObject pkg = view_as<JSONObject>(objClient);

    if(!pkg.HasKey("ccm")) {
        return;
    }

    JSONObject obj;

    if(!iClient) {
        JSONArray objArray = view_as<JSONArray>(pkg.Get("ccm"));
        
        for(int i; i < objArray.Length; i++) {
            obj = view_as<JSONObject>(objArray.Get(i));
            if(obj) {
                delete obj;
            }
        }

        delete objArray;

    } {
        obj = view_as<JSONObject>(pkg.Get("ccm"));
        if(obj)
            delete obj;
    }

    pkg.Remove("ccm");
}

void setTemplate(int iClient, JSONObject pkg, int index = -1) {
    JSONObject server = view_as<JSONObject>(ccp_GetPackage(0));

    if(!server.HasKey("ccm")) {
        // LogMessage("!Server Has: ccm");
        return;
    }
    
    JSONArray jsonArray = view_as<JSONArray>(server.Get("ccm"));
    if(!jsonArray) {
        // LogMessage("Invalid array");
        return;
    }

    if(index != -1) {
        if(pkg.HasKey("ccm")) {
            pkg.Remove("ccm");
        }        

        // LogMessage("Set val");
        pkg.Set("ccm", jsonArray.Get(index));

        char szValue[MESSAGE_LENGTH];
        server = view_as<JSONObject>(pkg.Get("ccm"));

        server.GetString("name", szValue, sizeof(szValue));
        coHandle.Set(iClient, szValue);
        return;
    }

    JSONObject obj;

    char szBuffer[64];
    if(!GetClientAuthId(iClient, AuthId_Engine, szBuffer, sizeof(szBuffer))){
        return;
    }

    for(int i, b, c; i < jsonArray.Length; i++) {
        obj = view_as<JSONObject>(jsonArray.Get(i));

        if(obj) {
            c = obj.GetInt("priority");

            if(c > b && HasAccess(pkg, obj)) {
                b = c;

                if(pkg.HasKey("ccm")) {
                    pkg.Remove("ccm");
                }

                // LogMessage("Set obj: %i", i);

                if(pkg.Set("ccm", view_as<JSON>(obj))){
                    // char szValue[MESSAGE_LENGTH];
                    server = view_as<JSONObject>(pkg.Get("ccm"));

                    server.GetString("name", szBuffer, sizeof(szBuffer));
                    coHandle.Set(iClient, szBuffer);
                }
            }
        }   

        obj = null;
    }

}

public Action Cmd_Prefix(int iClient, int args)
{
    if(iClient && IsClientInGame(iClient) && !IsFakeClient(iClient))
    {
        JSONObject objClient = view_as<JSONObject>(ccp_GetPackage(iClient));
        if(objClient) {
            if(IsMenuDisabled) {
                if(!objClient.HasKey("ccm")) {
                    setTemplate(iClient, objClient);
                } else {
                    objClient.Remove("ccm");
                    coHandle.Set(iClient, NULL_STRING);
                }
            } else {
                menuTemplates(iClient);
            }

        }
    }
    
    return Plugin_Handled;
}

void menuTemplates(int iClient)
{
    Menu hMenu = new Menu(menuCallBack);

    hMenu.SetTitle("%T \n \n", "choose_template", iClient);

    char szBuffer[256];

    JSONObject objClient = view_as<JSONObject>(ccp_GetPackage(iClient));
    JSONArray objArray = view_as<JSONArray>(view_as<JSONObject>(ccp_GetPackage(0)).Get("ccm"));
    int drawType = ITEMDRAW_DEFAULT;
    JSONObject obj;
    char szValue[64];
    if(objClient.HasKey("ccm")) {
        obj = view_as<JSONObject>(objClient.Get("ccm"));
        obj.GetString("name", szValue, sizeof(szValue));
        obj = null;
    } else {
        drawType = ITEMDRAW_DISABLED;
    }

    FormatEx(szBuffer, sizeof(szBuffer), "d%T \n \n", "remove", iClient);
    hMenu.AddItem(szBuffer, szBuffer[1], drawType);

    for(int i; i < objArray.Length; i++) {
        obj = view_as<JSONObject>(objArray.Get(i));
        if(!obj) {
            continue;
        }

        obj.GetString("name", szBuffer, sizeof(szBuffer));
        drawType = (!strcmp(szValue, szBuffer)) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT;
        
        Format(szBuffer, sizeof(szBuffer), "%c%T", i+1, szBuffer, iClient);

        if(!HasAccess(objClient, obj)) {
            continue;
        }

        hMenu.AddItem(szBuffer, szBuffer[1], drawType);
    }

    hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int menuCallBack(Menu hMenu, MenuAction action, int iClient, int param) {
    switch(action) {
        case MenuAction_End: delete hMenu;
        case MenuAction_Select: {
            char item[64];
            hMenu.GetItem(param, item, sizeof(item));

            JSONObject objClient = view_as<JSONObject>(ccp_GetPackage(iClient));

            int index = item[0];
            if(index == 'd') {
                objClient.Remove("ccm");
            } else {
                index -= 1;
                setTemplate(iClient, objClient, index);
            }
            
            menuTemplates(iClient);
        }
    }
}

JSONObject objSender;

public void cc_proc_MsgUniqueId(int mType, int sender, int msgId, const int[] clients, int count) {
    if(mType > eMsg_ALL || !sender)
        return;

    objSender = view_as<JSONObject>(ccp_GetPackage(sender));
}

public Action cc_proc_RebuildString(const int mType, int sender, int recipient, int part, int &pLevel, char[] buffer, int size)
{
    if(mType > eMsg_ALL || !sender)
        return Plugin_Continue;
    
    int index = indexPart(part);
    if(index == -1)
        return Plugin_Continue;
    
    if(LEVEL[index] < pLevel)
        return Plugin_Continue;
    
    // LogMessage("levle: %d:%i", part, sender);

    JSONObject obj;
    // LogMessage("Has ccm: %b", objSender.HasKey("ccm"));
    if(!objSender || !objSender.HasKey("ccm"))
        return Plugin_Continue;

    // LogMessage("Client obj");
    
    obj = view_as<JSONObject>(objSender.Get("ccm"));
    if(!obj || !obj.HasKey(szBinds[part]))
        return Plugin_Continue;
    
    // LogMessage("obj");

    static char szValue[MESSAGE_LENGTH];
    obj.GetString(szBinds[part], szValue, sizeof(szValue));

    // LogMessage(szValue);

    if(!szValue[0])
        return Plugin_Continue;
    
    if(part == BIND_PREFIX)
        Format(szValue, sizeof(szValue), "%T", szValue, recipient);
    
    pLevel = LEVEL[index];
    FormatEx(buffer, size, szValue);

    return Plugin_Continue;  
}

bool HasAccess(JSONObject objClient, JSONObject obj) {
    char szBuffer[64], szValue[64];

    int type = obj.GetInt("type");
    obj.GetString("value", szValue, sizeof(szValue));

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

            if(szBuffer[0] == 0) {
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
    JSONObject obj;
    JSONArray jsonItems = view_as<JSONArray>(
        view_as<JSONObject>(view_as<JSONObject>(ccp_GetPackage(0))).Get("ccm")
    );

    if(!jsonItems || !jsonItems.Length) {
        return null;
    }

    char szValue[MESSAGE_LENGTH];
    for(int i; i < jsonItems.Length; i++) {
        obj = view_as<JSONObject>(jsonItems.Get(i));

        if(!obj.HasKey("name")) {
            LogError("FindInObjects(%i): Invalid object", i);
            continue;
        }

        obj.GetString("name", szValue, sizeof(szValue));

        if(StrEqual(szValue, szName, false)) {
            return obj;
        }
    }

    return null;
}