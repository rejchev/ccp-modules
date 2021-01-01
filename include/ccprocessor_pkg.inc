#if defined _ccprocessor_pkg_included
 #endinput
#endif
#define _ccprocessor_pkg_included

forward void ccp_OnPackageAvailable(int iClient, Handle jsonObj);
forward void ccp_OnPackageRemove(int iClient, Handle jsonObj);

native Handle ccp_GetPackage(int iClient);

public SharedPlugin __pl_ccprocessor_pkg= 
{
    name = "ccprocessor_pkg",
    file = "ccp-packager.smx",
#if defined REQUIRE_PLUGIN
    required = 1
#else
    required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_ccprocessor_SetNTVOptional()
{
    MarkNativeAsOptional("ccp_GetPackage");
}
#endif