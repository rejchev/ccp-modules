#if defined _ccprocessor_chls_included
 #endinput
#endif
#define _ccprocessor_chls_included

native Handle   ccp_GetChannelList();
native bool     ccp_GetChannelTag(int index, char[] buffer, int size);
native bool     ccp_RemoveChannel(int index);
native bool     ccp_AddChannel(const char[] tag);
native int      ccp_FindChannel(const char[] tag);


public SharedPlugin __pl_ccprocessor_chls= 
{
    name = "ccprocessor_chls",
    file = "ccp-channel-mgr.smx",
#if defined REQUIRE_PLUGIN
    required = 1
#else
    required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_ccprocessor_chls_SetNTVOptional()
{
    MarkNativeAsOptional("ccp_GetChannelList");
    MarkNativeAsOptional("ccp_GetChannelTag");
    MarkNativeAsOptional("ccp_FindChannel");
    MarkNativeAsOptional("ccp_RemoveChannel");
    MarkNativeAsOptional("ccp_AddChannel");

}
#endif