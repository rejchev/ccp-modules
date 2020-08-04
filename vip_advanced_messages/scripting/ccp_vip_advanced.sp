#pragma newdecls required

#include ccprocessor
#include vip_core

public Plugin myinfo = 
{
	name = "[CCP] Advanced VIP message",
	author = "nullent?",
	description = "Advanced vip message",
	version = "1.2.0",
	url = "discord.gg/ChTyPUG"
};

bool bEnabled[MAXPLAYERS+1];

static const char g_szFeature[] = "advanced_message";

public void OnPluginStart()
{    
    if(VIP_IsVIPLoaded())
        VIP_OnVIPLoaded(); 
}

public void VIP_OnVIPLoaded()
{
    VIP_RegisterFeature(g_szFeature, BOOL, TOGGLABLE, OnToogleFeature);
}

public void OnMapStart()
{
    cc_proc_APIHandShake(cc_get_APIKey());
}

public void OnPluginEnd()
{
    if(!CanTestFeatures() || GetFeatureStatus(FeatureType_Native, "VIP_UnregisterFeature") != FeatureStatus_Available)
        return;

    VIP_UnregisterFeature(g_szFeature);
}

public void OnClientPutInServer(int iClient)
{
    bEnabled[iClient] = false;
}

public void VIP_OnVIPClientLoaded(int iClient)
{
    bEnabled[iClient] = VIP_IsClientFeatureUse(iClient, g_szFeature) && VIP_GetClientFeatureStatus(iClient, g_szFeature) == ENABLED;
}

public Action OnToogleFeature(int iClient, const char[] szFeature, VIP_ToggleState eOldStatus, VIP_ToggleState &eNewStatus)
{
    bEnabled[iClient] = eNewStatus == ENABLED;
}

public bool cc_proc_SkipColorsInMsg(int iClient)
{
    return bEnabled[iClient];
}