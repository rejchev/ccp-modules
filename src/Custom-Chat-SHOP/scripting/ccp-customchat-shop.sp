#pragma newdecls required

#include <ccprocessor>
#include <shop>
#include <ccprocessor_pkg>

#undef REQUIRE_EXTENSIONS
#include <ripext_m>
#define REQUIRE_EXTENSIONS

#define SZ(%0) %0, sizeof(%0)

public Plugin myinfo = 
{
	name = "[CCP] Custom Chat <SHOP>",
	author = "nullent?",
	description = "...",
	version = "1.5.2",
	url = "discord.gg/ChTyPUG"
};

const ItemType g_IType = Item_Togglable;

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
    JSONObject obj;

    if(!iClient) {
        static char config[MESSAGE_LENGTH] = "configs/shop/ccprocessor/shop_chat.json";

        if(config[0] == 'c') {
            BuildPath(Path_SM, config, sizeof(config), config);
        }

        if(!FileExists(config)) {
            SetFailState("Config file is not exists: %s", config);
        }
        
        obj = JSONObject.FromFile(config, 0);
        pkg.Set(pkgKey, obj);
    
        if(Shop_IsStarted())
            RegisterCategorys();
    } else {
        obj = new JSONObject();
        for(int i; i < BIND_MAX; i++)
            obj.SetNull(szBinds[i]);
        
        pkg.Set(pkgKey, obj);
    }

    delete obj;
}

public void OnMapStart()
{
    cc_proc_APIHandShake(cc_get_APIKey());
    manageConVars(false);
}

public void Shop_Started()
{
    OnMapEnd();
    RegisterCategorys();
}

public void OnMapEnd()
{
    Shop_UnregisterMe();
}

public void OnPluginEnd()
{
    OnMapEnd();
}

void RegisterCategorys() {
    JSONObject obj = asJSONO(asJSONO(ccp_GetPackage(0)).Get(pkgKey));
    if(!obj) {
        return;
    }

    JSONArray jsonPart;
    JSONObject item;

    CategoryId id;

    char szBuffer[MESSAGE_LENGTH];
    for(int i; i < BIND_MAX; i++ ) {
        if(!obj.HasKey(szBinds[i])) {
            continue;
        }

        jsonPart = asJSONA(obj.Get(szBinds[i]));
        if(!jsonPart || !jsonPart.Length) {
            delete jsonPart;
            continue;
        }

        id = Shop_RegisterCategory(
            szBinds[i], szBinds[i], NULL_STRING, OnCategoryDisplayed
        );

        if(id == INVALID_CATEGORY) {
            delete jsonPart;
            continue;
        }

        for(int j, p, s, d; j < jsonPart.Length; j++) {
            item = asJSONO(jsonPart.Get(j));
            if(!item) {
                continue;
            }

            item.GetString("value", szBuffer, sizeof(szBuffer));
            p = item.GetInt("price");
            s = item.GetInt("sellprice");
            d = item.GetInt("duration");

            RegisterItem(id, szBuffer, szBuffer, szBuffer, p, s, d);

            delete item;
        }

        delete jsonPart;
    }
    
    delete obj;
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

    asJSONO(ccp_GetPackage(iClient)).Set(pkgKey, obj);
    delete obj;

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

    asJSONO(ccp_GetPackage(client)).Set(pkgKey, obj);
    delete obj;

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

public void cc_proc_MsgUniqueId(int mType, int sender, int msgId, const char[] message, const int[] clients, int count) {
    delete senderModel;

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
