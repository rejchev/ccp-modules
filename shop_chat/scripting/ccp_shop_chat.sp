
#pragma newdecls required

#include ccprocessor
#include shop

#define SZ(%0) %0, sizeof(%0)

public Plugin myinfo = 
{
	name = "[CCP] SHOP Chat",
	author = "nullent?",
	description = "Decorates player messages",
	version = "1.2.0",
	url = "discord.gg/ChTyPUG"
};

enum
{
    ccp_cprefix = 0,
    ccp_lprefix,
    ccp_cname,
    ccp_cmessage,

    ccp_max
};

static const char g_szCategory[ccp_max][] =
{
    "ccp_cprefix", "ccp_lprefix",
    "ccp_cname", "ccp_cmessage"
};

const ItemType g_IType = Item_Togglable;

static CategoryId g_CatS[ccp_max];

ArrayList aClientTemplate[MAXPLAYERS+1];


public void OnPluginStart()
{    
    LoadTranslations("ccp_shop.phrases");
    LoadTranslations("ccproc.phrases");

    CreateConVar("shop_level_cprefix", "1", "Priority for replacing the prefix color", _, true, 0.0).AddChangeHook(CPrefixLevelChanged);
    CreateConVar("shop_level_prefix", "1", "Priority for replacing the prefix", _, true, 0.0).AddChangeHook(PrefixLevelChanged);
    CreateConVar("shop_level_cname", "1", "Priority for replacing the username color", _, true, 0.0).AddChangeHook(CNameLevelChanged);
    CreateConVar("shop_level_cmessage", "1", "Priority for replacing the message color", _, true, 0.0).AddChangeHook(CMessageLevelChanged);

    AutoExecConfig(true, "shop_chat", "ccprocessor");
}

int Levels[ccp_max];

public void CPrefixLevelChanged(ConVar cvar, const char[] oldVal, const char[] newVal)
{
    Levels[ccp_cprefix] = cvar.IntValue;
}

public void PrefixLevelChanged(ConVar cvar, const char[] oldVal, const char[] newVal)
{
    Levels[ccp_lprefix] = cvar.IntValue;
}

public void CNameLevelChanged(ConVar cvar, const char[] oldVal, const char[] newVal)
{
    Levels[ccp_cname] = cvar.IntValue;
}

public void CMessageLevelChanged(ConVar cvar, const char[] oldVal, const char[] newVal)
{
    Levels[ccp_cmessage] = cvar.IntValue;
}

public void OnMapStart()
{
    static char szPath[ccp_max][MESSAGE_LENGTH] =
    {
        "configs/shop/ccprocessor/cprefix.ini", "configs/shop/ccprocessor/lprefix.ini",
        "configs/shop/ccprocessor/cname.ini", "configs/shop/ccprocessor/cmessage.ini"
    };

    cc_proc_APIHandShake(cc_get_APIKey());

    CPrefixLevelChanged(FindConVar("shop_level_cprefix"), NULL_STRING, NULL_STRING);
    PrefixLevelChanged(FindConVar("shop_level_prefix"), NULL_STRING, NULL_STRING);
    CNameLevelChanged(FindConVar("shop_level_cname"), NULL_STRING, NULL_STRING);
    CMessageLevelChanged(FindConVar("shop_level_cmessage"), NULL_STRING, NULL_STRING);

    if(!Shop_IsStarted())
        return;

    RegisterCategory();

    ReadCatItems(szPath);
}

public void Shop_Started()
{
    OnMapEnd();
    OnMapStart();
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
    for(int i; i < ccp_max; i++)
    {
        g_CatS[i] = 
            Shop_RegisterCategory(
                g_szCategory[i], g_szCategory[i], NULL_STRING, OnCategoryDisplayed
            )
    }
}

SMCParser smParser[ccp_max];

ArrayList aItems;

public void ReadCatItems(char[][] szConfigs)
{
    if(!aItems)
        aItems = new ArrayList(PREFIX_LENGTH, 0);
    
    aItems.Clear();

    for(int i; i < ccp_max; i++)
    {
        if(szConfigs[i][6] == 's')
            BuildPath(Path_SM, szConfigs[i], PREFIX_LENGTH, szConfigs[i]);
        
        if(!FileExists(szConfigs[i]))
        {
            LogError("Where is my file: %s", szConfigs[i]);
            continue;
        }

        smParser[i] = new SMCParser();
        smParser[i].OnKeyValue = OnValueRead;
        smParser[i].OnEnd = OnReadEnd;

        int iLine;
        if(smParser[i].ParseFile(szConfigs[i], iLine) != SMCError_Okay)
            LogError("Fail on line %i: %s", iLine, szConfigs[i]);
    }
}

public bool OnCategoryDisplayed(int client, CategoryId category_id, const char[] category, const char[] name, char[] buffer, int maxlen)
{
    FormatEx(buffer, maxlen, "%T", name, client);

    return true;
}

SMCResult OnValueRead(SMCParser smc, const char[] sKey, const char[] sValue, bool bKey_Quotes, bool bValue_quotes)
{
    if(!sKey[0])
        return SMCParse_Continue;

    static int iPrice, iSell, iDuration, i = 0;
    static char item_name[PREFIX_LENGTH], item_value[PREFIX_LENGTH];

    if(StrEqual(sKey, "item_value"))
    {
        i++;
        strcopy(item_value, sizeof(item_value), sValue);
    }
        
    
    else if(StrEqual(sKey, "item_name"))
    {
        i++;
        strcopy(item_name, sizeof(item_name), sValue);
    }
        
    
    else if(StrEqual(sKey, "item_price"))
    {
        i++;
        iPrice = StringToInt(sValue);
    }
        
    
    else if(StrEqual(sKey, "item_sellprice"))
    {
        i++;
        iSell = StringToInt(sValue);
    }
        
    
    else if(StrEqual(sKey, "item_duration"))
    {
        i++;
        iDuration = StringToInt(sValue);
    }
        

#define ITEM_OPTIONS 5

    if(i == ITEM_OPTIONS)
    {
        for(i = 0; i < ccp_max; i++)
            if(smParser[i] == smc)
                break;

        char item_key[PREFIX_LENGTH];
        FormatEx(item_key, sizeof(item_key), "%s_%i", item_name, i);

        RegisterItem(g_CatS[i], item_key, item_name, item_value, iPrice, iSell, iDuration);

        i = 0;
    }

    return SMCParse_Continue;
}

void RegisterItem(CategoryId cid, const char[] item_key, const char[] item_name, const char[] item_value, int p, int s, int d)
{
    if(Shop_StartItem(cid, item_key))
    {
        aItems.PushString(item_key);
        aItems.PushString(item_value);

        Shop_SetInfo(item_name, NULL_STRING, p, s, g_IType, d);
        Shop_SetCallbacks(OnItemRegistered, OnItemToogle, _, OnItemDisplay, _, _, _, OnItemSell);
            
        Shop_EndItem();
    }
}

void OnReadEnd(SMCParser smc, bool haled, bool failed)
{
    for(int i; i < ccp_max; i++)
        if(smParser[i] == smc)
            delete smParser[i];   
}

public void OnItemRegistered(CategoryId category_id, const char[] category, const char[] item, ItemId item_id)
{
    // ...
}

public ShopAction OnItemToogle(int iClient, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, bool isOn, bool elapsed)
{
    char szValue[PREFIX_LENGTH];
    aClientTemplate[iClient].GetString(GetCatIdx(category), szValue, sizeof(szValue));

    if(szValue[0])
    {
        aItems.GetString(aItems.FindString(szValue)-1, szValue, sizeof(szValue));

        if(!StrEqual(item, szValue))
            Shop_ToggleClientItem(iClient, Shop_GetItemId(category_id, szValue), Toggle_Off);

        szValue = NULL_STRING;
    }

    if(!(isOn || elapsed))
        aItems.GetString(aItems.FindString(item)+1, szValue, sizeof(szValue));
    
    aClientTemplate[iClient].SetString(GetCatIdx(category), szValue);

    return (isOn || elapsed) ? Shop_UseOff : Shop_UseOn;
}

public bool OnItemDisplay(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, ShopMenu menu, bool &disabled, const char[] name, char[] buffer, int maxlen)
{
    FormatEx(buffer, maxlen, "%T", name, client);

    return true;
}

public bool OnItemSell(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, ItemType type, int sell_price)
{
    aClientTemplate[client].SetString(GetCatIdx(category), NULL_STRING);

    return true;
}

public void OnClientPutInServer(int iClient)
{
    aClientTemplate[iClient] = new ArrayList(PREFIX_LENGTH, ccp_max);

    ClearArrayEx(aClientTemplate[iClient]);
}

public void OnClientDisconnect(int iClient)
{
    delete aClientTemplate[iClient];
}

int MsgType;

public void cc_proc_MsgBroadType(const int type)
{
    MsgType = type;
}

public void cc_proc_RebuildString(int iClient, int &pLevel, const char[] szBind, char[] szBuffer, int size)
{
    if(MsgType < eMsg_SERVER)
    {
        static int i;
        i = GetItemByBind(szBind);

        if(i == -1)
            return;
        
        if(pLevel > Levels[i])
            return;
        
        char szItem[PREFIX_LENGTH];
        aClientTemplate[iClient].GetString(i, SZ(szItem));

        if(!szItem[0])
            return;
        
        pLevel = Levels[i];
        FormatEx(szBuffer, size, szItem);
    }
}

int GetItemByBind(const char[] szBind)
{
    return  (StrEqual(szBind, "{PREFIXCO}"))    ?   ccp_cprefix     : 
            (StrEqual(szBind, "{PREFIX}"))      ?   ccp_lprefix     :
            (StrEqual(szBind, "{NAMECO}"))      ?   ccp_cname       :
            (StrEqual(szBind, "{MSGCO}"))       ?   ccp_cmessage    :
                                                    -1              ;
}

int GetCatIdx(const char[] category)
{
    for(int i; i < sizeof(g_szCategory); i++)
        if(StrEqual(category, g_szCategory[i]))
            return i;

    return -1;
}

void ClearArrayEx(ArrayList &arr)
{
    for(int i; i < ccp_max; i++)
        arr.SetString(i, "");
}