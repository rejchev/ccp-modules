#pragma newdecls required

#include <ccprocessor>
#include <shop>
#include <jansson>
#include <ccprocessor_pkg>

#define SZ(%0) %0, sizeof(%0)
#define asJSONO(%0) view_as<JSONObject>(%0)
#define asJSONA(%0) view_as<JSONArray>(%0)
#define asJSONK(%0) view_as<JSONObjectKeys>(%0)

public Plugin myinfo = 
{
	name = "[CCP] Custom Chat <SHOP>",
	author = "nullent?",
	description = "...",
	version = "1.5.0",
	url = "discord.gg/ChTyPUG"
};

const ItemType g_IType = Item_Togglable;

static CategoryId g_CatS[BIND_MAX];
static const char pkgKey[] = "shop_chat";

int levels[BIND_MAX];

public void OnPluginStart()
{    
    LoadTranslations("ccproc.phrases");
    LoadTranslations("ccp_shop.phrases");

    manageConVars();
}

void manageConVars(bool bCreate = true) {
    char szBuffer[128];

    for(int i; i < BIND_MAX; i++) {
        FormatBind("ccp_shop_", i, 'l', szBuffer, sizeof(szBuffer)/2);
        if(bCreate){
            Format(szBuffer[strlen(szBuffer)+1], sizeof(szBuffer), "Priority level for %s", szBinds[i]);
            CreateConVar(szBuffer, "1", szBuffer[strlen(szBuffer)+1], _, true, 1.0).AddChangeHook(onChange);
        } else {
            onChange(FindConVar(szBuffer), NULL_STRING, NULL_STRING);
        }
    }
    
    if(bCreate) {
        AutoExecConfig(true, "ccp_shopchat", "ccprocessor");
    }
}

public void onChange(ConVar convar, const char[] oldVal, const char[] newVal)
{
    char szBuffer[64];
    convar.GetName(szBuffer, sizeof(szBuffer));

    int part = BindFromString(szBuffer);
    if(part == BIND_MAX)
        return;
    
    levels[part] = convar.IntValue;
}

public void ccp_OnPackageAvailable(int iClient, Handle hPkg) {
    JSONObject pkg = asJSONO(hPkg);

    if(!pkg || !pkg.HasKey(pkgKey)) {
        return;
    }

    if(!iClient) {
        static char config[MESSAGE_LENGTH] = "configs/shop/ccprocessor/chop_chat.json";

        if(config[0] == 'c') {
            BuildPath(Path_SM, config, sizeof(config), config);
        }

        if(!FileExists(config)) {
            SetFailState("Config file is not exists: %s", config);
        }

        pkg.Set(pkgKey, JSONObject.FromFile(config, 0));

        if(!Shop_IsStarted())
            return;

        RegisterCategory();
    } else {
        JSONObject model = new JSONObject();
        for(int i; i < BIND_MAX; i++)
            model.SetNull(szBinds[i]);
        
        pkg.Set(pkgKey, model);
    }
}

public void ccp_OnPackageRemove(int iClient, Handle hPkg) {
    JSONObject pkg = asJSONO(hPkg);
    if(!pkg.HasKey(pkgKey)) {
        return;
    }

    JSONObject obj = asJSONO(pkg.Get(pkgKey));

    if(!iClient) {
        JSONObject sub;
        JSONObjectKeys keys = asJSONK(obj.Keys());

        char szKey[64];
        while(keys.ReadKey(szKey, sizeof(szKey))) {
            sub = asJSONO(obj.Get(szKey));
            if(sub) {
                delete sub;
            }
        }

        delete keys;
    }

    if(obj) {
        delete obj;
    }

    pkg.Remove(pkgKey);
}

public void OnMapStart()
{
    cc_proc_APIHandShake(cc_get_APIKey());
    manageConVars(false);
}

public void Shop_Started()
{
    OnMapEnd();
    RegisterCategory();
}

public void OnMapEnd()
{
    Shop_UnregisterMe();
}

public void OnPluginEnd()
{
    OnMapEnd();
}

public void RegisterCategory()
{
    for(int i; i < BIND_MAX; i++) {
        g_CatS[i] = Shop_RegisterCategory(
            szBinds[i], szBinds[i], NULL_STRING, OnCategoryDisplayed
        );

        FillItems(g_CatS[i], i);
    }
}

void FillItems(CategoryId id, const int part) {
    JSONObject obj = asJSONO(asJSONO(ccp_GetPackage(0)).Get(pkgKey));
    if(!obj || !obj.HasKey(szBinds[part])) {
        return;
    }

    JSONArray jsonPart = asJSONA(obj.Get(szBinds[part]));
    if(!jsonPart || !jsonPart.Length) {
        return;
    }

    char szBuffer[MESSAGE_LENGTH];
    for(int i, p, s, d; i < jsonPart.Length; i++) {
        obj = asJSONO(jsonPart.Get(i));
        if(!obj) {
            continue;
        }

        obj.GetString("value", szBuffer, sizeof(szBuffer));
        p = obj.GetInt("price");
        s = obj.GetInt("sellprice");
        d = obj.GetInt("duration");

        RegisterItem(id, szBuffer, szBuffer, szBuffer, p, s, d);
    }
}

void RegisterItem(CategoryId cid, const char[] item_key, const char[] item_name, const char[] item_value, int p, int s, int d)
{
    if(Shop_StartItem(cid, item_key))
    {
        Shop_SetInfo(item_name, NULL_STRING, p, s, g_IType, d);
        Shop_SetCallbacks(OnItemRegistered, OnItemToogle, _, OnItemDisplay, _, _, _, OnItemSell);
            
        Shop_EndItem();
    }
}

public void OnItemRegistered(CategoryId category_id, const char[] category, const char[] item, ItemId item_id)
{
    // ...
}

public ShopAction OnItemToogle(int iClient, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, bool isOn, bool elapsed)
{
    int part = BindFromString(category);

    char szValue[MESSAGE_LENGTH];

    // value of client model
    JSONObject obj = getClientModel(iClient);
    if(obj && IsPartValid(obj, part)) {
        obj.GetString(szBinds[part], szValue, sizeof(szValue));
    }

    if(szValue[0])
    {
        if(!StrEqual(item, szValue))
            Shop_ToggleClientItem(iClient, Shop_GetItemId(category_id, szValue), Toggle_Off);

        szValue = NULL_STRING;
    }

    if(!(isOn || elapsed))
        strcopy(szValue, sizeof(szValue), item);
    
    if(szValue[0]) {
        obj.SetString(szBinds[part], szValue);
    } else obj.SetNull(szBinds[part]);

    return (isOn || elapsed) ? Shop_UseOff : Shop_UseOn;
}

public bool OnItemDisplay(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, ShopMenu menu, bool &disabled, const char[] name, char[] buffer, int maxlen)
{
    int part = BindFromString(category);

    FormatEx(buffer, maxlen, "%T", name, client);

    ccp_replaceColors(buffer, true);

    if(part == BIND_PREFIX)
        Format(buffer, maxlen, "%T", "tag_display", client, buffer);

    return true;
}

public bool OnCategoryDisplayed(int client, CategoryId category_id, const char[] category, const char[] name, char[] buffer, int maxlen, ShopMenu menu)
{
    FormatEx(buffer, maxlen, "%T", name, client);
    return true;
}

public bool OnItemSell(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, ItemType type, int sell_price)
{
    int part = BindFromString(category);

    char szValue[MESSAGE_LENGTH];
    JSONObject obj = getClientModel(client);
    if(obj && IsPartValid(obj, part)) {
        obj.GetString(szBinds[part], szValue, sizeof(szValue));
    }

    if(szValue[0] && StrEqual(szValue, item, false)) {
        obj.SetNull(szBinds[part]);
    }

    // aClientTemplate[client].SetString(GetCatIdx(category), NULL_STRING);

    return true;
}

public void OnClientPutInServer(int iClient)
{
    // ,,,,
}

public void OnClientDisconnect(int iClient)
{
    // .....
}

JSONObject senderModel;

public void cc_proc_MsgUniqueId(int mType, int sender, int msgId, const int[] clients, int count) {
    senderModel = null;

    if(mType > eMsg_ALL || !sender) {
        return;
    }

    senderModel = getClientModel(sender);
}

public Action cc_proc_RebuildString(const int mType, int sender, int recipient, int part, int &pLevel, char[] buffer, int size)
{
    if(!senderModel) {
        return Plugin_Continue;
    }

    if(levels[part] < pLevel || !IsPartValid(senderModel, part)) {
        return Plugin_Continue;
    }

    static char szValue[MESSAGE_LENGTH];
    if(!senderModel.GetString(szBinds[part], szValue, sizeof(szValue)) || !szValue[0]) {
        return Plugin_Continue;
    }

    if(part == BIND_PREFIX && TranslationPhraseExists(szValue)) {
        Format(szValue, sizeof(szValue), "%T", szValue, recipient);
    }

    pLevel = levels[part];
    FormatEx(buffer, size, szValue);

    return Plugin_Continue;
}

stock JSONObject getClientModel(int iClient) {
    JSONObject obj;
    obj = asJSONO(ccp_GetPackage(iClient));

    if(!obj || !obj.HasKey(pkgKey))
        return null;
    
    obj = asJSONO(obj.Get(pkgKey));
    return obj;
}

stock bool IsPartValid(JSONObject model, int part) {
    return model.HasKey(szBinds[part]) && !model.IsNull(szBinds[part]);
}