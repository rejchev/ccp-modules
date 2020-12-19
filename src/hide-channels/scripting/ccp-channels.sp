#pragma newdecls required

#include <ccprocessor>

public Plugin myinfo = 
{
	name = "[CCP] Channels",
	author = "nu11ent",
	description = "...",
	version = "1.1.0",
	url = "https://t.me/nyoood"
};

bool g_chIgnore[MAXPLAYERS+1][eMsg_MAX];

int levels[2];

public void OnPluginStart()
{
	LoadTranslations("ccp_channels.phrases");
	RegConsoleCmd("sm_channels", cmd);

	CreateConVar("channels_prototype", "1000", "Template replacement priority", _, true, 1.0).AddChangeHook(OnProto);
	CreateConVar("channels_msg", "1000", "Message replacement priority", _, true, 1.0).AddChangeHook(OnMessage);

	AutoExecConfig(true, "channels", "ccprocessor");
}

public void OnMapStart()
{
	OnProto(FindConVar("channels_prototype"), NULL_STRING, NULL_STRING);
	OnMessage(FindConVar("channels_msg"), NULL_STRING, NULL_STRING);
}

public void OnProto(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	levels[0] = cvar.IntValue;
}

public void OnMessage(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	levels[1] = cvar.IntValue;
}

public void OnClientPutInServer(int iClient)
{
	for(int i; i < eMsg_MAX; i++)
		g_chIgnore[iClient][i] = false;
}

Action cmd(int iClient, int args)
{
	static const char keys[][] = {"team", "public", "changename", "radio", "server"};

	if(iClient && IsClientInGame(iClient))
	{
		Menu hMenu = new Menu(MenuCallBack);

		hMenu.SetTitle("%T \n \n", "title", iClient);

		char szBuffer[MESSAGE_LENGTH];
		for(int i; i < eMsg_MAX; i++)
		{
			FormatEx(szBuffer, sizeof(szBuffer), "%T", (g_chIgnore[iClient][i]) ? "disabled" : "enabled", iClient);
			Format(szBuffer, sizeof(szBuffer), "%c%T", i+1, keys[i], iClient, szBuffer);

			// [cell]Any words [Enabled/Disabled]
			hMenu.AddItem(szBuffer, szBuffer[1]);
		}

		hMenu.Display(iClient, MENU_TIME_FOREVER);
	}

	return Plugin_Handled;
}

public int MenuCallBack(Menu hMenu, MenuAction action, int iClient, int option)
{
	switch(action)
	{
		case MenuAction_End: delete hMenu;
		case MenuAction_Select: 
		{
			char szBuffer[4];
			hMenu.GetItem(option, szBuffer, sizeof(szBuffer));

			int mType = szBuffer[0] - 1;

			g_chIgnore[iClient][mType] = !g_chIgnore[iClient][mType];
			cmd(iClient, 0);
		}
	}
}

public Action cc_proc_RebuildString(const int mType, int sender, int recipient, int part, int &pLevel, char[] buffer, int size)
{
	if(g_chIgnore[sender][mType])
		return Plugin_Stop;

	return Plugin_Continue;
}

public void cc_proc_RebuildClients(const int mType, int iClient, int[] clients, int &numClients)
{
	RemoveFromRecepients(mType, clients, numClients);
}

void RemoveFromRecepients(const int mType, int[] clients, int &numClients)
{
	// int players[MAXPLAYERS+1];

	int size = numClients;
	numClients = 0;

	for(int i; i < size; i++)
	{
		if(!g_chIgnore[clients[i]][mType])
			clients[numClients++] = clients[i];
	}
}