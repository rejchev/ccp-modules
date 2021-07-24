#if defined _ccprocessor_pkg_included
 #endinput
#endif
#define _ccprocessor_pkg_included

#pragma deprecated "v1.0"
forward void ccp_OnPackageAvailable_Pre(int iClient, Handle jsonObj);

#pragma deprecated "v1.0"
forward void ccp_OnPackageAvailable(int iClient, Handle jsonObj);

#pragma deprecated "v1.0"
forward void ccp_OnPackageRemove(int iClient, Handle jsonObj);

#pragma deprecated "v1.0 -> use ccp_pkg_UpdateRequest()"
forward void ccp_OnPackageUpdated(int iClient, Handle jsonObj, Handle hCaller);

#pragma deprecated "v1.0"
native Handle   ccp_UpdatePackage(int iClient, Handle newValue);


forward void ccp_pkg_Available(int iClient);
forward Processing ccp_pkg_UpdateRequest(Handle hPlugin, int iClient, const char[] artifact, Handle value, int &repLevel);

native Handle   ccp_GetPackage(int iClient);
native bool     ccp_SetPackage(int iClient, Handle value, int repLevel);
native bool     ccp_HasPackage(int iClient);
native bool     ccp_IsVerified(int iClient);

native bool     ccp_SetArtifact(int iClient, const char[] artifact, Handle value, int repLevel);
native bool     ccp_RemoveArtifact(int iClient, const char[] artifact, int repLevel);
native Handle   ccp_GetArtifact(int iClient, const char[] artifact);
native bool     ccp_HasArtifact(int iClient, const char[] artifact);

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
public void __pl_ccprocessor_pkg_SetNTVOptional()
{
    MarkNativeAsOptional("ccp_GetPackage");
    MarkNativeAsOptional("ccp_SetPackage");
    MarkNativeAsOptional("ccp_HasPackage");
    MarkNativeAsOptional("ccp_IsVerified");
    MarkNativeAsOptional("ccp_SetArtifact");
    MarkNativeAsOptional("ccp_RemoveArtifact");
    MarkNativeAsOptional("ccp_GetArtifact");
    MarkNativeAsOptional("ccp_HasArtifact");
}
#endif