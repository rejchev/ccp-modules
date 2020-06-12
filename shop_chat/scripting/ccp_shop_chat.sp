/*
    NOTE:
        The version has not been tested, so use at your own risk.

*/

#pragma newdecls required

#include ccprocessor
#include shop

#define SZ(%0) %0, sizeof(%0)

public Plugin myinfo = 
{
	name = "[CCP] SHOP Chat",
	author = "nullent?",
	description = "Decorates player messages",
	version = "0.9",
	url = "discord.gg/ChTyPUG"
};

static const char g_szCategory[][] =
{
    "ccp_cprefix", "ccp_lprefix",
    "ccp_cname", "ccp_cmessage"
};

enum
{
    ccp_cprefix = 0,
    ccp_lprefix,
    ccp_cname,
    ccp_cmessage,
    ccp_max
};

enum struct Item
{
    ItemId m_IID;
    ItemType m_TItem;
    CategoryId m_CID;

    char m_szValue[PREFIX_LENGTH];
    char m_szName[PREFIX_LENGTH];

    int m_iPrice;
    int m_iSellPrice;
    int m_iDuration;
    bool m_bEnabled;

    void Reset()
    {
        this.m_IID = INVALID_ITEM;
        this.m_TItem = Item_Togglable;
        this.m_szValue[0] = 0;
        this.m_szName[0] = 0;
        //this.m_szDescription[0] = 0;
        this.m_iPrice = 0;
        this.m_iSellPrice = -1;
        this.m_iDuration = -1;
    }

    void CopyValue(const char[] szValue, bool IsValue)
    {
        strcopy(((IsValue) ? this.m_szValue : this.m_szName), PREFIX_LENGTH, szValue);
    }

    bool IsValidItem()
    {
        return this.m_IID != INVALID_ITEM && this.m_CID != INVALID_CATEGORY && this.m_szValue[0] != 0;
    }

    bool IsItemEnabled()
    {
        return this.m_bEnabled;
    }

    void SetItemStatus(bool newStatus)
    {
        this.m_bEnabled = newStatus;
    }

    void SetValue(int iValue, bool IsSellPrice)
    {
        if(IsSellPrice)
            this.m_iSellPrice = iValue;
        else this.m_iPrice = iValue;
    }

    void SetDuration(int iDuration)
    {
        this.m_iDuration = iDuration;
    }

    char GetItemValue()
    {
        return this.m_szValue;
    }

    char GetItemName()
    {
        return this.m_szName;
    }

    CategoryId GetCatId()
    {
        return this.m_CID;
    }
}

enum struct Category
{
    CategoryId m_CID;

    char m_szName[PREFIX_LENGTH];
    char m_szPath[PLATFORM_MAX_PATH];

    ArrayList m_aItems;

    void Reset()
    {
        this.m_CID = INVALID_CATEGORY;
        this.m_szName[0] = 0;
        this.m_szPath[0] = 0;
        this.m_aItems.Clear();
    }

    bool IsValidCat()
    {
        // LogMessage("CAT: %i, ArrayNULL: %b, Len: %i", this.m_CID, this.IsArrayNULL(), this.m_aItems.Length);
        return this.m_CID != INVALID_CATEGORY && !this.IsArrayNULL() && this.m_aItems.Length;
    }

    void CreatePath(const char[] szPath)
    {
        BuildPath(Path_SM, this.m_szPath, PLATFORM_MAX_PATH, szPath);

        if(!FileExists(this.m_szPath))
            SetFailState("Where is path for the category '%s' : %s ?", this.m_szName, this.m_szPath);
    }

    char GetCatName()
    {
        return this.m_szName;
    }

    char GetCatPath()
    {
        return this.m_szPath;
    }

    int GetItemByName(const char[] ItemBind, Item itemBuffer, int size)
    {
        for(int i; i < this.m_aItems.Length; i++)
        {
            this.m_aItems.GetArray(i, itemBuffer, size);
            if(StrEqual(ItemBind, itemBuffer.m_szName))
                return i;
        }

        itemBuffer.Reset();
        return -1;
    }

    int GetItemById(const ItemId IID, Item itemBuffer, int size)
    {
        for(int i; i < this.m_aItems.Length; i++)
        {
            this.m_aItems.GetArray(i, itemBuffer, size);
            if(itemBuffer.m_IID == IID)
                return i;
        }

        itemBuffer.Reset();
        return -1;
    }

    void WriteCatName(const char[] szName)
    {
        strcopy(this.m_szName, PLATFORM_MAX_PATH, szName);
    }

    void InitArray()
    {
        this.m_aItems = new ArrayList(PLATFORM_MAX_PATH, 0);
    }

    bool IsArrayNULL()
    {
        return this.m_aItems == null;
    }

    void ClearItems()
    {
        this.m_aItems.Clear();
    }

    int GetCategoryType()
    {
        for(int i; i < sizeof(g_szCategory); i++)
            if(StrEqual(this.m_szName, g_szCategory[i]))
                return i;
        
        return -1;
    }
}

ArrayList aClientTemplate[MAXPLAYERS+1];

ArrayList aCategoryList;

public void OnPluginStart()
{
    LoadTranslations("ccp_shop.phrases");

    aCategoryList = new ArrayList(PLATFORM_MAX_PATH, 0);

    CreateConVar("shop_level_cprefix", "1", "Priority for replacing the prefix color", _, true, 0.0).AddChangeHook(CPrefixLevelChanged);
    CreateConVar("shop_level_prefix", "1", "Priority for replacing the prefix", _, true, 0.0).AddChangeHook(PrefixLevelChanged);
    CreateConVar("shop_level_cname", "1", "Priority for replacing the username color", _, true, 0.0).AddChangeHook(CNameLevelChanged);
    CreateConVar("shop_level_cmessage", "1", "Priority for replacing the message color", _, true, 0.0).AddChangeHook(CMessageLevelChanged);

    AutoExecConfig(true, "shop_chat", "ccprocessor");

    if(Shop_IsStarted())
        Shop_Started();
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

CategoryId cId;

public void Shop_Started()
{
    static const char szPath[][] =
    {
        "configs/shop/ccprocessor/cprefix.ini", "configs/shop/ccprocessor/lprefix.ini",
        "configs/shop/ccprocessor/cname.ini", "configs/shop/ccprocessor/cmessage.ini"
    };

    aCategoryList.Clear();

    for(int i; i < ccp_max; i++)
    {
        Category newCategory;
        
        if(newCategory.IsArrayNULL())
            newCategory.InitArray();

        newCategory.Reset();
        newCategory.WriteCatName(g_szCategory[i]);
        newCategory.CreatePath(szPath[i]);
        aCategoryList.Push(1);
        aCategoryList.PushArray(newCategory, sizeof(newCategory));


        Shop_RegisterCategory(
            g_szCategory[i], g_szCategory[i], NULL_STRING, OnCategoryDisplayed
        );        
    }
}


public void Shop_OnCategoryRegistered(CategoryId category_id, const char[] name)
{
    // LogMessage("Category: %s registered with id: %i", name, category_id);
    Category CBuffer;

    for(int i; i < aCategoryList.Length; i+=2)
    {
        aCategoryList.GetArray(i+1, CBuffer, sizeof(CBuffer));

        if(!StrEqual(name, CBuffer.GetCatName()))
            continue;
        
        CBuffer.m_CID = category_id;

        aCategoryList.Set(i, category_id);
        aCategoryList.SetArray(i+1, CBuffer, sizeof(CBuffer));

        cId = category_id;
        ParseItemsPath(CBuffer.m_szPath);
        break;
    }

    // RegisterCategoryItems(category_id, aCategoryList.FindValue(category_id) + 1);
}

public bool OnCategoryDisplayed(int client, CategoryId category_id, const char[] category, const char[] name, char[] buffer, int maxlen)
{
    SetGlobalTransTarget(client);

    FormatEx(buffer, maxlen, "%t", name);

    return true;
}

public void OnMapStart()
{
    CPrefixLevelChanged(FindConVar("shop_level_cprefix"), NULL_STRING, NULL_STRING);
    PrefixLevelChanged(FindConVar("shop_level_prefix"), NULL_STRING, NULL_STRING);
    CNameLevelChanged(FindConVar("shop_level_cname"), NULL_STRING, NULL_STRING);
    CMessageLevelChanged(FindConVar("shop_level_cmessage"), NULL_STRING, NULL_STRING);
}

void ParseItemsPath(const char[] szPath)
{
    SMCParser smParser = new SMCParser();
    smParser.OnKeyValue = OnValueRead;
    smParser.OnEnd = OnReadEnd;

    int iLine;
    if(smParser.ParseFile(szPath, iLine) != SMCError_Okay)
        LogError("Error On parse: %s | Line: %i", szPath, iLine);
}

SMCResult OnValueRead(SMCParser smc, const char[] sKey, const char[] sValue, bool bKey_Quotes, bool bValue_quotes)
{
    if(!sKey[0] || !sValue[0])
        return SMCParse_Continue;

    static Item newItem;
    static int i;

    if(!strcmp(sKey, "value"))
    {
        newItem.CopyValue(sValue, true);
        i++;
    }

    if(!strcmp(sKey, "item_name"))
    {
        newItem.CopyValue(sValue, false);
        i++;
    }
        
    else if(!strcmp(sKey, "price"))
    {   
        newItem.SetValue(StringToInt(sValue), false);
        i++;
    }
    
    else if(!strcmp(sKey, "sellprice"))
    {
        newItem.SetValue(StringToInt(sValue), true);
        i++;
    }
        
    else if(!strcmp(sKey, "duration"))
    {
        newItem.SetDuration(StringToInt(sValue));
        i++;
    }
        
    if(i == 5)
    {
        // LogMessage("Push item: %s for CAT: %i", newItem.GetItemName(), cId);
        newItem.m_CID = cId;
        newItem.m_TItem = Item_Togglable;

        Category category;
        i = aCategoryList.FindValue(cId) + 1;

        aCategoryList.GetArray(i, category, sizeof(category));
        category.m_aItems.PushArray(newItem, sizeof(newItem));

        aCategoryList.SetArray(i, category, sizeof(category));

        newItem.Reset();

        i = 0;
    }

    return SMCParse_Continue;
}

void OnReadEnd(SMCParser smc, bool haled, bool failed)
{
    static int a;
    a++;

    if(a == ccp_max)
    {
        for(int i; i < aCategoryList.Length; i+=2)
            RegisterCategoryItems(i+1);
    }
    
}

void RegisterCategoryItems(int pos)
{
    Category category;
    Item item;

    aCategoryList.GetArray(pos, category, sizeof(category));
    if(!category.IsValidCat())
        return;

    // LogMessage("Category %s:%i is valid", category.GetCatName(), category.m_CID);

    for(int i; i < category.m_aItems.Length; i++)
    {
        category.m_aItems.GetArray(i, item, sizeof(item));

        // LogMessage("Register item: %s for CAT: %i", item.GetItemName(), item.GetCatId());
        if(Shop_StartItem(item.GetCatId(), item.GetItemName()))
        {
            // LogMessage("Start for ITEM: %s is success", item.GetItemName());
            Shop_SetInfo(item.GetItemName(), NULL_STRING, item.m_iPrice, item.m_iSellPrice, item.m_TItem, item.m_iDuration);
            Shop_SetCallbacks(OnItemRegistered, OnItemToogle, _, OnItemDisplay, _, _, _, OnItemSell);
        }
        
        Shop_EndItem();

        item.Reset();
    }
}

public void OnItemRegistered(CategoryId category_id, const char[] category, const char[] item, ItemId item_id)
{
    Category CBuffer;
    Item IBuffer;
    
    int pos = aCategoryList.FindValue(category_id) + 1;

    aCategoryList.GetArray(pos, CBuffer, sizeof(CBuffer));
    int pos2 = CBuffer.GetItemByName(item, IBuffer, sizeof(IBuffer));

    IBuffer.m_IID = item_id;

    CBuffer.m_aItems.SetArray(pos2, IBuffer, sizeof(IBuffer));
    aCategoryList.SetArray(pos, CBuffer, sizeof(CBuffer));
}

public ShopAction OnItemToogle(int iClient, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, bool isOn, bool elapsed)
{
    Category CBuffer;
    Item IBuffer;

    strcopy(CBuffer.m_szName, sizeof(CBuffer.m_szName), category);

    if(!(isOn || elapsed))
    {
        aCategoryList.GetArray(aCategoryList.FindString(category)+1, SZ(CBuffer));
        CBuffer.GetItemById(item_id, SZ(IBuffer));
    }

    aClientTemplate[iClient].SetString(CBuffer.GetCategoryType(), IBuffer.GetItemValue());
    
    return (isOn || elapsed) ? Shop_UseOff : Shop_UseOn;
}

public bool OnItemDisplay(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, ShopMenu menu, bool &disabled, const char[] name, char[] buffer, int maxlen)
{
    SetGlobalTransTarget(client);

    FormatEx(buffer, maxlen, "%t", name);

    return true;
}

public bool OnItemSell(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, ItemType type, int sell_price)
{
    Category catBuffer;
    strcopy(catBuffer.m_szName, sizeof(catBuffer.m_szName), category);

    aClientTemplate[client].SetString(catBuffer.GetCategoryType(), NULL_STRING);

    return true;
}

public void OnClientPutInServer(int iClient)
{
    aClientTemplate[iClient] = new ArrayList(PREFIX_LENGTH, ccp_max);
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
    if(MsgType > eMsg_ALL)
        return;
    
    static int i;
    i = GetItemByBind(szBind);

    if(i == -1)
        return;
    
    if(pLevel > Levels[i])
        return;
    
    static char szItem[PREFIX_LENGTH];
    aClientTemplate[i].GetString(i, SZ(szItem));

    if(!szItem[0])
        return;
    
    pLevel = Levels[i];
    FormatEx(szBuffer, size, szItem);
}

int GetItemByBind(const char[] szBind)
{
    return  (StrEqual(szBind, "{PREFIXCO}"))    ?   ccp_cprefix     : 
            (StrEqual(szBind, "{PREFIX}"))      ?   ccp_lprefix     :
            (StrEqual(szBind, "{NAMECO}"))      ?   ccp_cname       :
            (StrEqual(szBind, "{MSGCO}"))       ?   ccp_cmessage    :
                                                    -1              ;
}