/**
*	Description:
*		Plugin that will dynamically set the HP of bots and quota based on players joined and
*		difference between bots and humans scores.
*
*		This plugin was based off of the not publicly released metamod plugin Adaptive Bots by Old and Slow (https://forums.alliedmods.net/member.php?u=15225)
*		I did not have access to the sourcecode and this was designed off of my experience playing on a server that had this plugin.
*
*		It's a fun plugin and I wanted others to enjoy this type of gameplay.
*
*********************************************************************
*	Changelog:
*
*	2015.02.03 06:22
*		Umgestellt zur Team Unreality-Edition
*
*	2015.02.03 18:15
*		Platzierung des Advertisement abgeändert
*		color.inc entfernt
*		morecolor.inc hinzugefügt
*		Andere Farben für Chat-Befehle
*
*	2015.02.03 22:48
*		Meldung für Bot_Quota hinzugefügt
*		Teils in ibots.phrases.txt ausgelagert
*
*	2015.02.03 23:49
*		Teleportierung bei Bot-Übernahme korregiert
*
*	2015.02.04 01:15
*		Rücksetzung des Beacons falls Spieler überlebt
*		nonVIP-Player können, entsprechend der CFG Bots übernehmen
* 
*	2015.02.04 18:35
*		Beacon rücksetzung korregiert
*		Hinweis wenn kein Bot mehr übernommen werden kann
*		Alle Texte in ibots.phrases.txt
*		Standart Prefix für Chat-Nachrichten
*
*	2015.02.06 00:02
*		Benachritigungen bearbeitet
*		Updater entfernt
*		unnötigen Code entfernt
		kein Sound mehr bei Hinweis auf Botübernahme

	2015.02
		Korrektur wenn Spieler durch "World" stirbt
		Extrapunkte für Messerkill per Config
		Korrektur beim Team des übernommenen Bots
		Gewinnerausgabe korregieren
		Hinweise für Botübernahme korregiert
		Selbstmörder, durch "World" oder Console gestorbene, können in der Runde kein Bot übernehmen
		Punkte für Bombe per Config
		WinLimit per Config
		MaxRounds per Config
		mp_autoteambalance automatisch auf 0 mit rückmeldung
		mp_limitteams automatisch auf 0 mit Rückmeldung
		mp_forcecamera passend zu iBots_use_BotControl
		mp_friendlyfire passend zu iBots_FFMode
		Handhabung von FriendlyFire überarbeitet
		Gewinner werden in der Console ausgegeben für HLstatsX:CE
			(Nicht aufgeführte Felder leer/unberührt lassen.)
			In den HLstatsX:CE folgendes eintragen:
			  Game Settings > [Game] > Actions
				Action Code: iBots_win
				Player Action: X
				Player Points Reward: 50
				Team Points Reward: 0
				Action Description: Won Round on iBots
			  Game Settings > [Game] > Plyr Action Awards
				Action: Win Round on iBots
				Award Name: Top Botkiller
				Verb Plural: times won in iBots
			  Ribbons (triggered by Awards)
			   gilt für jedes Ribbon:
				Image file: (Bild muss vorher erstellt unf hochgeladen werden)
				Trigger Award: Top Botkiller
			   Ribbon 1 
				Ribbon Name: Award of iBots
				No. awards needed: 1
			   Ribbon 2 
				Ribbon Name: Bronze iBots Killer
				No. awards needed: 5
			   Ribbon 3 
				Ribbon Name: Silver iBots Killer
				No. awards needed: 12
			   Ribbon 4 
				Ribbon Name: Gold iBots Killer
				No. awards needed: 20
			   Ribbon 5 
				Ribbon Name: Platinum iBots Killer
				No. awards needed: 30
			   Ribbon 6 
				Ribbon Name: Supreme iBots Killer
				No. awards needed: 50
			Außerdem folgende Änderungen vornehmen:
			  General Settings > HLstatsX:CE Settings > Point calculation settings
				*Minimum number of skill points a player will gain from each frag. Default 2: 0
		zufälliges Team für Bots integriert (iBots_bot_team 1)
		es kann bot_prefix gesetzt werden
		neue CVar iBots_Kick um permanentes austauschen der Bots zu de-/aktivieren
		wenn kein Spieler über die Dauer von mp_roundtime auf dem Server war, wird alles auf Starteinstellungen zurückgesetzt

TODO: ~~~~~~   TOP   ~~~~~~

TODO: wenn kein Spieler da, iBot aus stellen
		bot_quoat
		bot_quota_mode
		bot_join_after_player
		bot_join_team - iBots_TEAM_BOT
		iBot_JoinMode
		iBots_ManageBots
		iBots_FFMode
		iBots_use_beacon "1"
	
NOTE: Vorerst deaktiviert: NoEndRoundHandle
		(B:H|CT:T|1:1) Bombe gelegt > H übernimmt B > H stirbt > Bombe explodiert -> geht nicht weiter!!!
		
TODO: OnTakeDamage event umstellen
		
TODO: mp_maxrounds / iBots_MaxRounds Prüfen
		nach Mapchange wird der Wert aus server.cfg genommen anstelle iBots.cfg

TODO:
TODO: ~~~~~~   CODE   ~~~~~~		
**/

#include <_myFunctions>
#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <morecolors>
#include <sdkhooks>
#include <autoexecconfig>

#undef REQUIRE_PLUGIN
//#include <updater>

#define PLUGIN_VERSION "1.6.4"
#define PLUGIN_ANNOUNCE "Team Unreality Edition by electronic_m\nwww.Team-Unreality.de"

//#define UPDATE_URL "http://raiko-schmidt.de/ibots.txt"

#define SOUND_BLIP		"buttons/blip1.wav"
#define SOUND_BEEP		"buttons/button17.wav"
#define BLOCKED_WEAPONS	"buttons/weapon_cant_buy.wav"

#define MAX_WEAPON_STRING	80

#define	MAX_WEAPON_SLOTS	6

#define HEGrenadeOffset		11	// (11 * 4)
#define FlashbangOffset 	12	// (12 * 4)
#define SmokegrenadeOffset	13	// (13 * 4)

#define _DEBUG  0 // Set to 1 for debug spew
#if !defined _DEBUG2
	#define _DEBUG2 0
#endif

#if _DEBUG || _DEBUG2
	new DebugUser = 0;
#endif

new bool:b_MapIsOver = false,

	Float:f_iBotsQuota = 0.0,

	Handle:h_ClientAdvertise[MAXPLAYERS+1] = {INVALID_HANDLE, ...},
	Handle:KickTimer[MAXPLAYERS+1] = {INVALID_HANDLE, ...},
	Handle:BeaconTimer[MAXPLAYERS+1] = {INVALID_HANDLE, ...},

	MinQuota, MinHP, iBotsHPIncrease, iBotsHPDecrease, MaxFrags, MaxRounds, MaxWins, MaxBots, HumanWinningStreak, HumansStreakMoney,
	BotWinningStreak, BotsStreakMoney, StreakMoney, WinningDifference, BotDifficulty = -1, FinalDiff_Bots, FinalDiff_Humans,
	AdvertiseInterval, TEAM_BOT = 1, TEAM_HUMAN, KickAnytime,

	iBotsHealth = 100,
	score_bot = 0, score_human = 0,
	BotsWinStreak = 0, HumansWinStreak = 0,
	Advertisetime = 0,
	FragCount[MAXPLAYERS+1] = {0, ...},
	bool:MapIsDone = false,
	bool:RoundRunning = false,
	//bool:UseUpdater = false,

	Handle:botteam = INVALID_HANDLE, Handle:humanteam = INVALID_HANDLE,

	Handle:ibot_bot_team = INVALID_HANDLE,
	Handle:ibot_quota = INVALID_HANDLE,
	Handle:ibot_quota_mode = INVALID_HANDLE,
	Handle:mp_fraglimit = INVALID_HANDLE,
	Handle:mp_maxrounds = INVALID_HANDLE,
	Handle:mp_winlimit = INVALID_HANDLE,
	Handle:mp_limitteams = INVALID_HANDLE,
	Handle:mp_autoteambalance = INVALID_HANDLE,
	Handle:mp_friendlyfire = INVALID_HANDLE,
	Handle:mp_forcecamera = INVALID_HANDLE,
	Handle:ibot_difficulty = INVALID_HANDLE,
	Handle:mp_restartgame = INVALID_HANDLE,
	Handle:mp_roundtime = INVALID_HANDLE,
	Handle:mp_round_restart_delay = INVALID_HANDLE,
	Handle:reservedslots = INVALID_HANDLE,

	Handle:botsprefix = INVALID_HANDLE,
	String:OrgPrefix[MAX_NAME_LENGTH], String:NewPrefix[MAX_NAME_LENGTH],
	String:Orgbotteam[5], String:Orghumanteam[5],

	g_BeamSprite = -1, g_HaloSprite = -1,

	EasyBonus, FairBonus, NormalBonus, ToughBonus, HardBonus, VeryHardBonus, ExpertBonus, EliteBonus,
	BombFrag = 3,
	Float:KnifeBonusMultiplier = 1.0, KnifeBonusFrag = 0, KnifeBonusControl = 0,

	bool:ModifyHP = true,
	bool:HPBonus = true,
	JoinPartMode = 1,
	ireservedslots,
	ClientHP[MAXPLAYERS+1],

	bool:UseSuperNades = false,
	Float:NadeMultiplyer = 1.0,
	Float:NadeMultiplyerIncrease = 0.20,
	Float:NadeMultiplyerDecrease = 0.15,
	bool:ManageBots = true,
	bool:UseMaxFrags = false,
	bool:UseMaxRounds = false,
	bool:UseMaxWins = false,
	bool:UseIgnitedNades = false,
	bool:IsVIP[MAXPLAYERS+1] = {false, ...},
	FFMode = 0,
	
	bool:AllowReset = true,

	Handle:BotQuotaTimer = INVALID_HANDLE,
	Handle:ResetEverythingTimer = INVALID_HANDLE,

	BotDifficultyChangeableBot = 0, BotDifficultyChangeableHuman = 0,
	AdjustBotDiff = 1,
	StartingBotDiff,
	Orgbotdifficulty, Orgbotquota, String:Orgbotquotamode[7], Orgfraglimit, Orgmaxrounds, Orgwinlimit, Orglimitteams, Orgautoteambalance, Orgfriendlyfire, Orgforcecamera,
	bool:IsCSGO,
	bool:AllowBotControl = true,
	HumansStreakDiff, BotsStreakDiff,

	Handle:NoEndRoundHandle = INVALID_HANDLE,
	bool:HideDeath[MAXPLAYERS+1],
	bool:IsControllingBot[MAXPLAYERS+1],
	Float:RestartRoundTime,
	Float: RoundTime,
	String:PlayerOldSkin[MAXPLAYERS+1][PLATFORM_MAX_PATH],
	bool:AllowedToControlBot[MAXPLAYERS+1],
	BotControlTimes[MAXPLAYERS+1],

	String:ChatPrefix[45] = "{tudark}[{whitesmoke}iBots{tudark}]{default}",
	String:CleanPrefix[5] = "[iBots]",

	BotControlTimesVIP, BotControlTimesREG, BotMaxHP, HumanMaxHP, BotControlMsg, bool:UseBeacon, bool:IsClientAdmin[MAXPLAYERS+1];

public Plugin:myinfo =
{
	name = "iBots Team Unreality Edition",
	author = "electronic m",
	description = "Interative CSS gameplay for Bots vs Humans with reactive quota, health and difficulty.",
	version = PLUGIN_VERSION,
	url = "http://www.team-unreality.de"
}



/***************************************************************************************************************************************\
* ======================================================================================================================================*
* 														Event Functions																	*
* ======================================================================================================================================*
\***************************************************************************************************************************************/

/**
 * Called when the plugin is fully initialized and all known external references
 * are resolved. This is only called once in the lifetime of the plugin, and is
 * paired with OnPluginEnd().
 *
 * If any run-time error is thrown during this callback, the plugin will be marked
 * as failed.
 *
 * It is not necessary to close any handles or remove hooks in this function.
 * SourceMod guarantees that plugin shutdown automatically and correctly releases
 * all resources.
 *
 * @noreturn
 */

public OnPluginStart()
{	
	// Create CVars
	CreateMyCVars();

	// Hook Needed Events
	HookEvent("cs_win_panel_match", 	OnCSWinPanelMatch);
	HookEvent("round_end", 				OnRoundEnd);
	HookEvent("round_start", 			OnRoundStart);
	HookEvent("player_team", 			OnTeamJoin, 		EventHookMode_Pre);
	HookEvent("player_death", 			OnPlayerDeath,		EventHookMode_Pre);
	HookEvent("bomb_defused", 			OnBombEvent, 		EventHookMode_Pre);
	HookEvent("bomb_exploded",			OnBombEvent,		EventHookMode_Pre);
	HookEvent("player_spawn",			OnPlayerSpawn);
	HookEvent("player_connect", 		OnPlayerConnect, 	EventHookMode_Pre);
	HookEvent("player_activate", 		OnPlayerActivate);
	HookEvent("player_disconnect",		OnPlayerDisconnect,	EventHookMode_Pre);
	HookEvent("cs_win_panel_round",		OnCSWinPanelRound,	EventHookMode_Pre);
	// Thanks to KyleS for showing me this method of suppressing some CVar message to clients
	HookEvent("server_cvar", 			OnCvarChanged, 	EventHookMode_Pre);

	RegConsoleCmd("sm_ibots", Cmd_ibots);
	RegConsoleCmd("sm_itest", Cmd_itest);
	RegAdminCmd("sm_ibots_switch", Cmd_SwitchTeams, ADMFLAG_SLAY, "Allows you to switch the teams");
	RegAdminCmd("sm_ibots_hp", Cmd_iBotsHP, ADMFLAG_GENERIC, "Set the HP of the iBots");
	RegAdminCmd("sm_ibots_diff", Cmd_iBotsDiff, ADMFLAG_GENERIC, "Set the Difficulty of the Bots");

	LoadTranslations("ibots.phrases");

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && IsClientInGame(i))
		{
			OnClientPutInServer(i);
			OnClientPostAdminCheck(i);
		}
	}
}

/**
 * Called when the plugin is about to be unloaded.
 *
 * @noreturn
 **/
public OnPluginEnd()
{
	#if _DEBUG2
		DebugMessage("Setting server variables back to original...");
	#endif

	SetConVarString(botsprefix, OrgPrefix);
	SetConVarString(botteam, Orgbotteam);
	SetConVarString(humanteam, Orghumanteam);

	SetConVarInt(ibot_difficulty, Orgbotdifficulty);
	SetConVarInt(ibot_quota, Orgbotquota);
	SetConVarString(ibot_quota_mode, Orgbotquotamode);
	SetConVarInt(mp_fraglimit, Orgfraglimit);
	SetConVarInt(mp_maxrounds, Orgmaxrounds);
	SetConVarInt(mp_winlimit, Orgwinlimit);
	SetConVarInt(mp_limitteams, Orglimitteams);
	SetConVarInt(mp_autoteambalance, Orgautoteambalance);
	SetConVarInt(mp_friendlyfire, Orgfriendlyfire);
	SetConVarInt(mp_forcecamera, Orgforcecamera);
}

/**
 * Called when the map has loaded, servercfgfile (server.cfg) has been
 * executed, and all plugin configs are done executing.This is the best
 * place to initialize plugin functions which are based on cvar data.
 *
 * @note This will always be called once and only once per map.It will be
 * called after OnMapStart().
 *
 * @noreturn
 */
 public OnConfigsExecuted()
{
	if ((reservedslots = FindConVar("sm_reserved_slots")) != INVALID_HANDLE)
	{
		HookConVarChange(reservedslots, z_CvarReservedSlotsChanged);
		ireservedslots = GetConVarInt(reservedslots);
	}
	else
		ireservedslots = 1;

	if (UseMaxFrags)
		SetConVarInt(mp_fraglimit, MaxFrags);
	else
		SetConVarInt(mp_fraglimit, 0);

	if (UseMaxRounds)
		SetConVarInt(mp_maxrounds, MaxRounds);
	else
		SetConVarInt(mp_maxrounds, 0);

	if (UseMaxWins)
		SetConVarInt(mp_winlimit, MaxWins);
	else
		SetConVarInt(mp_winlimit, 0);

	// Disable limit teams to get more bots than Humans
	SetConVarInt(mp_limitteams, 0);

	// Disable autoteambalance
	SetConVarInt(mp_autoteambalance, 0);
	
	SetConVarString(ibot_quota_mode, "normal");
	
	// Set ForceCamera to take over Bots
	if (AllowBotControl)
		SetConVarInt(mp_forcecamera, 0);

	ChangeBotDifficulty((BotDifficulty == -1) ? StartingBotDiff : BotDifficulty, true);
	
	if(ManageBots)
		SetConVarInt(ibot_quota, 0);
		
	iBotsQuota();
	
	SetTeams();


	//if (!IsCSGO)
	//	SetConVarString(botsprefix, NewPrefix);
}

/**
 * Called when the map is loaded.
 *
 * @note This used to be OnServerLoad(), which is now deprecated.
 * Plugins still using the old forward will work.
 */
public OnMapStart()
{
	#if _DEBUG
		DebugMessage("Running OnMapStart");
	#endif
	
	g_BeamSprite = PrecacheModel("materials/sprites/bomb_planted_ring.vmt");
	g_HaloSprite = PrecacheModel("materials/sprites/halo.vtf");

	ResetEverything();

	PrecacheSound(SOUND_BEEP, true);
 	PrecacheSound(SOUND_BLIP, true);
 	PrecacheSound(BLOCKED_WEAPONS, true);
	
	AllowReset = true;
}

/**
 * Called right before a map ends.
 */
public OnMapEnd()
{
	#if _DEBUG
		DebugMessage("Running OnMapEnd");
	#endif

	switch (AdjustBotDiff)
	{
		case 1:
		{
			#if _DEBUG
				DebugMessage("Setting bot_difficulty back to default [%i]", StartingBotDiff);
			#endif

			ChangeBotDifficulty(StartingBotDiff);
		}

		case 2:
		{
			#if _DEBUG
				DebugMessage("Setting bot_difficulty for next map...");
			#endif

			new difference = score_human - score_bot;
			new bdiff = BotDifficulty;

				// If Humans beat bots
			if (difference > 0) 
			{
				if (difference >= FinalDiff_Humans)
				{
					if (bdiff < 3)
					{
						bdiff++;
						CPrintToChatAll("%s %t", ChatPrefix, "Bots Too Easy", bdiff);
					}
					else
					{
						CPrintToChatAll("%s %t", ChatPrefix, "Bot Hardest", bdiff);
						return;
					}
				}
			}	// If bots beat humans
			else if (difference < 0) 
			{
				difference *= -1;
				if (difference >= FinalDiff_Bots)
				{
					if (bdiff > 0)
					{
						bdiff--;
						CPrintToChatAll("%s %t", ChatPrefix, "Bots Too Hard", bdiff);
					}
					else
					{
						CPrintToChatAll("%s %t", ChatPrefix, "Bots Easiest", bdiff);
						return;
					}
				}
			}
			
			if (bdiff == BotDifficulty)
				CPrintToChatAll("%s %t", ChatPrefix, "Bots Good");
			else
				ChangeBotDifficulty(bdiff);
		}
	}
}

/**
 * Called when a client is entering the game.
 *
 * Whether a client has a steamid is undefined until OnClientAuthorized
 * is called, which may occur either before or after OnClientPutInServer.
 * Similarly, use OnClientPostAdminCheck() if you need to verify whether
 * connecting players are admins.
 *
 * GetClientCount() will include clients as they are passed through this
 * function, as clients are already in game at this point.
 *
 * @param client		Client index.
 * @noreturn
 */
public OnClientPutInServer(client)
{
	if (UseSuperNades)
	{
		#if _DEBUG
			DebugMessage("SDKHooking OnTakeDamage on %L", client);
		#endif

		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	}

	if (AdvertiseInterval > 0 && !IsFakeClient(client))
	{
		ClearTimer(h_ClientAdvertise[client]);

		h_ClientAdvertise[client] = CreateTimer(20.0, Timer_JoinAdvertise, client);
	}

	ClientHP[client] = 0;
}

/**
 * Called once a client is authorized and fully in-game, and
 * after all post-connection authorizations have been performed.
 *
 * This callback is gauranteed to occur on all clients, and always
 * after each OnClientPutInServer() call.
 *
 * @param client		Client index.
 * @noreturn
 */
public OnClientPostAdminCheck(client)
{
	#if _DEBUG
		DebugMessage("Running OnClientPostAdminCheck for %L", client);
	#endif

	if (IsValidClient(client) && !IsFakeClient(client))
	{
		if (CheckCommandAccess(client, "ibots_vip", ADMFLAG_RESERVATION))
		{
			IsVIP[client] = true;
			
			#if _DEBUG || _DEBUG2
				DebugUser = client;
			#endif
		}
			
		else
			IsVIP[client] = false;

		#if _DEBUG2
			DebugMessage("%L %s a VIP", client, (IsVIP[client])? "is" : "is NOT");
		#endif

		// BotControl prüft das Custom-AdminFlag nicht.
		//if (CheckCommandAccess(client, "allow_control_bots", ADMFLAG_CUSTOM1))
		//{

		if (AllowBotControl)
		{
			AllowedToControlBot[client] = true;

			if (IsVIP[client])
				BotControlTimes[client] = BotControlTimesVIP;
			else
				BotControlTimes[client] = BotControlTimesREG;
		}
		//}
		//else
		//{
		//	AllowedToControlBot[client] = false;
		//}

		if (CheckCommandAccess(client, "ibots_admin", ADMFLAG_GENERIC))
			IsClientAdmin[client] = true;
	}
}

/**
 *	"player_disconnect"			// a client was disconnected
 *	{
 *		"userid"	"short"		// user ID on server
 *		"reason"	"string"	// "self", "kick", "ban", "cheat", "error"
 *		"name"		"string"	// player name
 *		"networkid"	"string"	// player network (i.e steam) id
 *		"bot"		"short"		// is a bot
 *	}
 */
public Action:OnPlayerDisconnect(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new IsBot = GetEventInt(event, "bot");
	new Humans = (IsBot) ? -1 : GetAlivePlayers(0,"human",false);

	if (IsBot)
	{
		#if _DEBUG
			DebugMessage("Bot disconnected, silencing the event");
		#endif

		SetEventBroadcast(event, true);
	}

	#if _DEBUG2
		DebugMessage("OnPlayerDisconnect Humans:%i",GetAlivePlayers(0,"human",false));
	#endif
	#if _DEBUG || _DEBUG2
		if (client == DebugUser)
			DebugUser = 0;
	#endif	
	// ===================================================================================================================================
	// Clean up client specific variables and open timers (if they exist)
	// ===================================================================================================================================
	if (IsValidClient(client))
	{
		ClearTimer(h_ClientAdvertise[client]);
		ClearTimer(KickTimer[client]);
		ClearTimer(BeaconTimer[client]);
		FragCount[client] = 0;
		ClientHP[client] = 0;
		IsVIP[client] = false;
		IsClientAdmin[client] = false;

		SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);

		if (Humans == 1)
			AllowReset = true;
		
		#if _DEBUG2
			DebugMessage("%L disconnected, all client variables reset", client);
		#endif
	} else if (Humans == 0)
		AllowReset = true;

	if (JoinPartMode == 3)
	{
		#if _DEBUG
			DebugMessage("OnClientDisconnect, JoinPartMode is 3, about to adjust bot_quota...");
		#endif

		CreateTimer(0.5, Timer_UpdateQuotaDisconnect);
	}	
	
	return Plugin_Continue;
}

/**
 * @brief When an entity is created
 *
 * @param		entity		Entity index
 * @param		classname	Class name
 * @noreturn
 */
public OnEntityCreated(entity, const String:classname[])
{
	if (UseIgnitedNades && StrContains(classname, "_projectile") != -1)
	{
		#if _DEBUG
			DebugMessage("About to ignite hegrenade [%i]", entity);
		#endif

		SDKHook(entity, SDKHook_Spawn, OnEntitySpawned);
	}
}

/**
 * @brief When an entity is spawned
 *
 * @param		entity		Entity index
 * @noreturn
 */
public OnEntitySpawned(entity)
{
	new client = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");

	if (IsValidClient(client) && IsVIP[client])
	{
		#if _DEBUG
			DebugMessage("Igniting hegrenade thrown by VIP %L", client);
		#endif

		IgniteEntity(entity, 5.0);
	}
	else
	{
		#if _DEBUG
			DebugMessage("Did not ignite hegrenade [%i].Either player is not valid or not VIP, player [%i]", entity, client);
		#endif
	}
}

/**
 * @brief When a player takes damage
 *
 * @param		victim		Victim entity index
 * @param		attacker	Attacker entity index (not always another player)
 * @param		inflictor	Entity index of source of damage
 * @param		damage		Damage amount (in float), return plugin_changed if altered
 * @param		damagetype	Enum for damagetype
 * @param		weapon		Weapon entity
 * @param		damageForce	Vector[3] damage force
 * @param		damagePosition	Vector[3] position where damage occurred
 * @param		classname	Class name
 * @noreturn
 */
public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3])
{
	if (!(0 < attacker < MaxClients))
		return Plugin_Continue;

	if (!RoundRunning)	
		return Plugin_Handled;
		
	if (0 < FFMode <= 6)
	{
		#if _DEBUG
			DebugMessage("OnTakeDamage FFMode is %i", FFMode);
		#endif

		new ateam = GetClientTeam(attacker);
		new vteam = GetClientTeam(victim);

		if (ateam == vteam && ( (FFMode & 4 && IsVIP[victim]) || (FFMode & 2 && IsFakeClient(victim)) || (FFMode & 1 && !IsFakeClient(victim)) ) )
		{
			#if _DEBUG
				DebugMessage("OnTakeDamage, setting damage to 0.0 and damageForces to 0.0");
			#endif

			//damage = 0.0;
			//damagetype = DMG_PREVENT_PHYSICS_FORCE;

			//damageForce[0] = 0.0;
			//damageForce[1] = 0.0;
			//damageForce[2] = 0.0;
			return Plugin_Handled;
			//return Plugin_Changed;
		}
	}

	if (UseSuperNades)
	{
		decl String:sWeapon[MAX_WEAPON_STRING];
		sWeapon[0] = '\0';

		if (IsValidEntity(inflictor))
			GetEntityClassname(inflictor, sWeapon, sizeof(sWeapon));
		else
			return Plugin_Continue;

		if (StrEqual(sWeapon, "hegrenade_projectile", false))
		{
			#if _DEBUG
				DebugMessage("UseSuperNades, adjusting damage by %f", NadeMultiplyer);
			#endif

			damage *= NadeMultiplyer;

			return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}

/**
 *	"player_connect"			// a new client connected
 *	{
 *		"name"		"string"	// player name
 *		"index"		"byte"		// player slot (entity index-1)
 *		"userid"	"short"		// user ID on server (unique on server)
 *		"networkid" "string" // player network (i.e steam) id
 *		"address"	"string"	// ip:port
 *		"bot"		"short"		// is a bot
 *	}
 */
public Action:OnPlayerConnect(Handle:event, const String:name[], bool:dontBroadcast)
{
	SetEventBroadcast(event, true);
	return Plugin_Continue;
}

/**
 *	"player_activate"
 *	{
 *		"userid"	"short"		// user ID on server
 *	}
 */
public Action:OnPlayerActivate(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	#if _DEBUG
		DebugMessage("Player %N joined", client);
	#endif
		
	if (!IsFakeClient(client) )
	{
		CPrintToChatAll("%t","Player joined", client);
	
		if (ResetEverythingTimer != INVALID_HANDLE)
		{
			#if _DEBUG2
				DebugMessage("Reset ResetEverythingTimer OnPlayerActivate %L", client);
			#endif
			
			ClearTimer(ResetEverythingTimer);
		}
	}
}

/**
 *	"player_spawn"				// player spawned in game
 *	{
 *		"userid"	"short"		// user ID on server
 *	}
 */
public Action:OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	// Retrieve client's current Frag Count
	FragCount[client] = GetClientFrags(client);
	
	// Reset HideDeath if true
	if (HideDeath[client])
		HideDeath[client] = false;
	
	if (IsFakeClient(client))
	{
		#if _DEBUG
			DebugMessage("OnPlayerSpawn, bot spawned, adjusting HP...");
		#endif
		HideDeath[client] = false;
		SetEntProp(client, Prop_Send, "m_iHealth", iBotsHealth, 1);
	}
	else
	{
		if (ClientHP[client] > 100)
		{
			#if _DEBUG
				DebugMessage("OnPlayerSpawn, human spawned who had +100 HP, setting HP to higher amount...");
			#endif

			SetEntProp(client, Prop_Send, "m_iHealth", ClientHP[client], 1);
			ClientHP[client] = 0;
		}
	}
}

/**
 *	"round_start"
 *	{
 *		"timelimit"	"long"		// round time limit in seconds
 *		"fraglimit"	"long"		// frag limit in seconds
 *		"objective"	"string"	// round objective
 *	}
 */
public Action:OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	#if _DEBUG
		DebugMessage("Running OnRoundStart");
	#endif

	if (JoinPartMode == 1)
	{
		#if _DEBUG
			DebugMessage("JoinPartMode is 1, running iBots Quota...");
		#endif

		iBotsQuota();
	}

	// Exec Money
	iBotsMoney();

	if (AdvertiseInterval > 0)
	{
		// If Advertise every X rounds enabled, advertise to clients connected.See Timer_Advertise
		Advertisetime++;

		if (Advertisetime > AdvertiseInterval)
		{
			#if _DEBUG
				DebugMessage("Starting Advertisement timer...");
			#endif

			CreateTimer(2.0, Timer_Advertise);
			Advertisetime = 0;
		}
	}

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			PlayerOldSkin[i][0] = '\0';
			GetClientModel(i, PlayerOldSkin[i], sizeof(PlayerOldSkin[]));
		
			if (AllowBotControl && BotControlTimes[i] > 0)
				AllowedToControlBot[i] = true;
		}
	}
	
	// zur Fehlerbehebung der Botübernahme
	RoundRunning = true;
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (!IsValidClient(client))
		return Plugin_Continue;
	
	new clientTeam = GetClientTeam(client);
	
	// Check if the player is using (USE KEY) while dead (CSS code)
	if (!(buttons & IN_USE && AllowBotControl && !IsCSGO && !IsPlayerAlive(client) && (clientTeam == CS_TEAM_CT || clientTeam == CS_TEAM_T)))
		return Plugin_Continue;
	
	// Check how many times can take the player still in control of a bot
	if (BotControlTimes[client] <= 0)
	{
		PrintHintText(client, "%t", "No Bot Takeover Map hint");
		return Plugin_Continue;
	}

	// Find out who the player is spectating.
	new target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
	if(!IsValidClient(target))
		return Plugin_Continue;
	
	// Check whether the player is spectate a bot
	if (!IsFakeClient(target))
	{
		PrintHintText(client, "%t", "No Human Takeover hint");
		return Plugin_Continue;
	}
	
	new clientTeamAlive = GetAlivePlayers(clientTeam);
	new targetTeam = GetClientTeam(target);
	new opposideTeamAlive = GetAlivePlayers((clientTeam == CS_TEAM_T) ? CS_TEAM_CT : CS_TEAM_T);
	
	// Check whether the player is allowed or one team without alive players
	if (!RoundRunning || !AllowedToControlBot[client] || clientTeamAlive < 1 || opposideTeamAlive < 1)
	{
		PrintHintText(client, "%t", "No Bot Takeover Round hint");
		return Plugin_Continue;
	}

	/** Wegen Fehler deaktiviert
	*if (GetAliveBots() == 1)
	*	//Fight until death
	*	SetConVarInt(NoEndRoundHandle, 1);
	**/
	
	// Switch player to BOT team, save list of weapons bot currently has, get bot's location, slay/kill/kick bot, spawn player where bot was, give player weapons bot had.
	new hp, armor, helmet, defuser, nvgs, prim, sec, c4, gHE, gFB, gSG;
	decl String:PrimarySlot[MAX_WEAPON_STRING]; PrimarySlot[0] = '\0';
	decl String:SecondarySlot[MAX_WEAPON_STRING]; SecondarySlot[0] = '\0';

	if ((prim = GetPlayerWeaponSlot(target, CS_SLOT_PRIMARY)) > MaxClients)
	{
		GetEntityClassname(prim, PrimarySlot, sizeof(PrimarySlot));
		RemoveItem(target, prim);
		#if _DEBUG2
			DebugMessage("PrimarySlot: %s",PrimarySlot);
		#endif
	}
	else
		Format(PrimarySlot, sizeof(PrimarySlot), "NONE");

	if ((sec = GetPlayerWeaponSlot(target, CS_SLOT_SECONDARY)) > MaxClients)
	{
		GetEntityClassname(sec, SecondarySlot, sizeof(SecondarySlot));
		RemoveItem(target, sec);
		#if _DEBUG2
			DebugMessage("SecondarySlot: %s",SecondarySlot);
		#endif
	}
	else
		Format(SecondarySlot, sizeof(SecondarySlot), "NONE");
		
	if ((c4 = GetPlayerWeaponSlot(target, CS_SLOT_C4)) > MaxClients && IsValidEntity(c4))
	{
			#if _DEBUG2
				DebugMessage("C4: %i", c4);
			#endif
			
			RemoveItem(target, c4);
			c4 = 1;
	}			

	gHE = GetClientGrenades(target, HEGrenadeOffset);
	gFB = GetClientGrenades(target, FlashbangOffset);
	gSG = GetClientGrenades(target, SmokegrenadeOffset);
	
	hp = GetEntProp(target, Prop_Send, "m_iHealth");
	helmet = GetEntProp(target, Prop_Send, "m_bHasHelmet");
	armor = GetEntProp(target, Prop_Send, "m_ArmorValue");
	defuser = GetEntProp(target, Prop_Send, "m_bHasDefuser"); 
	nvgs = GetEntProp(target, Prop_Send, "m_bHasNightVision");
	
	if (defuser) SetEntProp(target, Prop_Send, "m_bHasDefuser", 0, 1);
	if (nvgs) SetEntProp(target, Prop_Send, "m_bHasNightVision", 0, 1);
	
	if (targetTeam != clientTeam)
		CS_SwitchTeam(client, targetTeam);
	
	new Float:vecPos[3], Float:vecAng[3];
	GetClientAbsOrigin(target, vecPos);
	GetClientAbsAngles(target, vecAng);
	
	CS_RespawnPlayer(client);
	
	HideDeath[target] = true;
	ForcePlayerSuicide(target);
	
	SetEntProp(client, Prop_Send, "m_iHealth", hp);
	if (helmet) SetEntProp(client, Prop_Send, "m_bHasHelmet", helmet);
	if (armor) SetEntProp(client, Prop_Send, "m_ArmorValue", armor);
	if (defuser) SetEntProp(client, Prop_Send, "m_bHasDefuser", defuser); //GivePlayerItem(client, "item_defuser");
	if (nvgs) SetEntProp(target, Prop_Send, "m_bHasNightVision", nvgs); //GivePlayerItem(client, "item_nvgs");
	if (c4 == 1) GivePlayerItem(client, "weapon_c4");
	GiveClientGrenades(client, HEGrenadeOffset, gHE);
	GiveClientGrenades(client, FlashbangOffset, gFB);
	GiveClientGrenades(client, SmokegrenadeOffset, gSG);
	
	if (!StrEqual(SecondarySlot, "NONE", false))
		GivePlayerItem(client, SecondarySlot);

	if (!StrEqual(PrimarySlot, "NONE", false))
		GivePlayerItem(client, PrimarySlot);
	
	TeleportEntity(client, vecPos, vecAng, NULL_VECTOR);

	IsControllingBot[client] = true;
	BotControlTimes[client]--;

	if (BotControlMsg > 0)
		AdviseBotControl(client);

	if (BotControlTimes[client] <= 0)
	{
		CPrintToChat(client, "%s %t", ChatPrefix, "Last Bot Takeover");
		AllowedToControlBot[client] = false;
	}
	else
		CPrintToChat(client, "%s %t", ChatPrefix, "Bot Takeover", BotControlTimes[client]);

	// We must return Plugin_Continue to let the changes be processed.
	// Otherwise, we can return Plugin_Handled to block the commands
	return Plugin_Continue;
}

/**
 *	"player_death"				// a game event, name may be 32 charaters long
 *	{
 *		"userid"	"short"		// user ID who died
 *		"attacker"	"short"		// user ID who killed
 *	}
 */
public Action:OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new victimSerial = GetClientSerial(victim);
	new bool:victimIsBot = IsFakeClient(victim);
	new killer = GetClientOfUserId(GetEventInt(event, "attacker"));
	new bool:killerIsValide = IsValidClient(killer);

	#if _DEBUG
		DebugMessage("OnPlayerDeath - victim is [%N] - killer is [%N]", victim, killer);
	#endif

	new victimTeam = GetClientTeam(victim);
	new killerTeam;
	
	if (killer != 0 && !GetClientTeam(killer))
		killerTeam = GetClientTeam(killer);
	else
		killerTeam = 0;

	if (!victimIsBot && IsControllingBot[victim])
	{	// Wechselt Spieler direkt wieder ins Player-Team falls er einen Bot übernommen hatte
		#if _DEBUG2
			DebugMessage("Reset Victim direkt");
		#endif
		
		CreateTimer(0.2, Timer_ResetPlayer, victimSerial);
	}

	CheckForBeacon();
	
	if (!killerIsValide || killer == victim)
	{		
		if (HideDeath[victim])
		{
			CreateTimer(0.2, Timer_DestroyRagdoll, victimSerial);
			return Plugin_Handled;
		}
		else
		{
			#if !_DEBUG2
				// Verhindere, dass Selbstmörder einen Bot übernehmen
				AllowedToControlBot[victim] = false;
				return Plugin_Continue;
			#endif
		}
	}

	if (killerTeam == victimTeam)
	{
		FragCount[killer]--;
		return Plugin_Continue;
	}

	FragCount[killer]++;

	new hp_bonus = 0;
	if (victimIsBot && HPBonus)
		hp_bonus = BotLevel(victim, true);

	if (killerIsValide && !IsFakeClient(killer))
	{
		decl String:wname[80];
		wname[0] = '\0';

		GetEventString(event, "weapon", wname, sizeof(wname));
		if (StrEqual(wname, "knife", false))
		{
			#if _DEBUG
				DebugMessage("Weapon used was a knife...");
			#endif
			
			new BonusControl = false;
			new BonusFrag = false;
			
			if (KnifeBonusControl > 0)
			{
				BotControlTimes[killer] += KnifeBonusControl;
				AllowedToControlBot[killer] = true;
				BonusControl= true;
			}
			
			if (KnifeBonusFrag > 0)
			{
				new score = GetClientFrags(killer);
				score += KnifeBonusFrag;
				SetEntProp(killer, Prop_Data, "m_iFrags", score++);
				FragCount[killer] += KnifeBonusFrag;
				BonusFrag = true;
			}
			
			
			if (BonusControl)
			{
				CPrintToChat(killer, "%s %t", ChatPrefix, "Knife Control Bonus", KnifeBonusControl);
				PrintHintText(killer, "%t", "Knife Control Bonus", KnifeBonusControl);
			}
			
			if (BonusFrag)
			{
				CPrintToChat(killer, "%s %t", ChatPrefix, "Knife Frag Bonus", KnifeBonusFrag);
				PrintHintText(killer, "%t", "Knife Frag Bonus", KnifeBonusFrag);
			}
			
			if (BonusControl && BonusFrag)
				PrintHintText(killer, "%t", "Knife Frag+Control Bonus", KnifeBonusFrag, KnifeBonusControl);

			if (hp_bonus > 0 && KnifeBonusMultiplier > 0)
				hp_bonus = RoundToNearest(hp_bonus * KnifeBonusMultiplier);
		}

		if (hp_bonus > 0)
		{
			new health = GetEntProp(killer, Prop_Send, "m_iHealth");
			if (health != HumanMaxHP)
			{
				if ((health += hp_bonus) > HumanMaxHP)
					health = HumanMaxHP;
				
				SetEntProp(killer, Prop_Send, "m_iHealth", health , 1);
				CPrintToChat(killer, "%s %t", ChatPrefix, "HP Bonus", hp_bonus);
			}
		}
	}

	// If this kill equals the mp_fraglimit set MapIsDone and create timer to announce winner of map
	if (killerIsValide && UseMaxFrags && FragCount[killer] >= MaxFrags)
	{
		if (!MapIsDone)
		{
			// Set this so the "who won" message won't repeat on multi kill over MaxFrags kills
			// (example: hegrenade kills 4 people where only 1 was needed to reach maxfrags)
			MapIsDone = true;
			b_MapIsOver = false;
			CreateTimer(0.5, Timer_MapHasEnded, killer);
			return Plugin_Continue;
		}
	}

	if (AllowBotControl && !victimIsBot	&& AllowedToControlBot[victim])
	{
		if (IsCSGO)
			CS_SwitchTeam(victim, TEAM_BOT);

		// Implement a timer instead
		CreateTimer(2.0, Timer_AdvertiseBotControl, victimSerial, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}

	return Plugin_Continue;
}

public Action:OnBombEvent(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Retrieve ID of player who defused/plant the bomb
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!IsValidClient(client))
		return Plugin_Handled;
	
	
	if (IsClientInGame(client))
	{
		new score = GetClientFrags(client);
		score += BombFrag-3;
		SetEntProp(client, Prop_Data, "m_iFrags", score);
		FragCount[client] += BombFrag;

		if (!IsFakeClient(client) && BombFrag != 3)
		{
			if (BombFrag>0)
			{
				CPrintToChat(client, "%s %t", ChatPrefix, "Bomb Frag", BombFrag);
				PrintHintText(client, "%t", "Bomb Frag", BombFrag);
			}
			else
				PrintHintText(client, "%t", "Bomb No Frag hint");
		}
	}
	return Plugin_Continue;
}

/**
 *	"round_end"
 *	{
 *		"winner"	"byte"		// winner team/user i
 *		"reason"	"byte"		// reson why team won
 *		"message"	"string"	// end round message
 *	}
 */
public Action:OnRoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	#if _DEBUG
		DebugMessage("Running OnRoundEnd");
	#endif
	
	// zur Fehlerbehebung der Botübernahme
	RoundRunning = false;
	
	//NOTE: OnGameStart
	//if(GetEventInt(event, "reason") == 15)
	
	new winner = GetEventInt(event, "winner");
	// NOTE: aus um Hängen des TeamScores zu vermeiden
	//if (winner <= 1)
	//	return Plugin_Continue;
	
	// As long as no one has reached the mp_fraglimit
	if (!MapIsDone)
	{
		#if _DEBUG
			DebugMessage("OnRoundEnd Winner:%i",winner);
		#endif
		
		iBotsHP(winner);
	}
	
	
	if (JoinPartMode == 2)
		iBotsQuota();

	CreateTimer(0.1, Timer_SetScore);

	new HP;

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && !IsFakeClient(i) && IsPlayerAlive(i))
		{
			if (IsControllingBot[i])
			{
				CreateTimer(((RestartRoundTime > 0)? RestartRoundTime-0.2 : 0.0), Timer_ResetPlayer, GetClientSerial(i));
				continue;
			}
			
			HP = GetClientHealth(i);

			if (HP > HumanMaxHP )
				ClientHP[i] = HumanMaxHP;
			else if (HP > 100)
				ClientHP[i] = HP;
		}
	}
	
	return Plugin_Continue;
}

/**
 *	"cs_win_panel_match"
 *	{
 *		"t_score"						"short"
 *		"ct_score"						"short"
 *		"t_kd"							"float"
 *		"ct_kd"							"float"
 *		"t_objectives_done"				"short"
 *		"ct_objectives_done"			"short"
 *		"t_money_earned"				"long"
 *		"ct_money_earned"				"long"
 *	}
 */
public Action:OnCSWinPanelMatch(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!MapIsDone)
	{
		b_MapIsOver = true;
		CreateTimer(0.0, Timer_MapHasEnded, 0);
	}
	OnMapEnd();	
}

public Action:OnCSWinPanelRound(Handle:event, const String:name[], bool:dontBroadcast)
{
	return Plugin_Handled;
}

/**
 *	"player_team"				// player change his team
 *	{
 *		"userid"	"short"		// user ID on server
 *		"team"		"byte"		// team id
 *		"oldteam" "byte"		// old team id
 *		"disconnect" "bool"		// team change because player disconnects
 *		"autoteam" "bool"		// true if the player was auto assigned to the team
 *		"silent" "bool"			// if true wont print the team join messages
 *		"name"	"string"		// player's name
 *	}
 */
public Action:OnTeamJoin(Handle:event, const String:name[], bool:dontBroadcast)
{	
	// Set the event notification off for team joins
	SetEventBroadcast(event, true);
	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsValidClient(client) && !IsFakeClient(client) && GetEventInt(event, "team") == TEAM_HUMAN)
		AllowReset = false;
	
	return Plugin_Continue;
}

public Action:OnCvarChanged(Handle:event, const String:name[], bool:dontBroadcast)
{
	#if _DEBUG
		return Plugin_Continue;
	#endif

	decl String:sConVarName[64];
	sConVarName[0] = '\0';

	GetEventString(event, "cvarname", sConVarName, sizeof(sConVarName));

	if (StrContains(sConVarName, "bot_difficulty", false) >= 0	||
		StrContains(sConVarName, "bot_quota", false) >= 0		||
		StrContains(sConVarName, "bot_team_join", false) >= 0	||
		StrContains(sConVarName, "mp_humanteam", false) >= 0	||
		StrContains(sConVarName, "ibots_bot_team", false) >= 0	)
		SetEventBroadcast(event, true);

	return Plugin_Continue;
}



/***************************************************************************************************************************************\
* ======================================================================================================================================*
* 														Personal Functions																*
* ======================================================================================================================================*
\***************************************************************************************************************************************/

stock LogEventToGame(const String:event[], client) {
    decl String:Auth[64];

    if (!GetClientAuthId(client, AuthId_Engine, Auth, sizeof(Auth)))
        strcopy(Auth, sizeof(Auth), "UNKNOWN");

    new team = GetClientTeam(client), UserId = GetClientUserId(client);
    LogToGame("\"%N<%d><%s><%s>\" triggered \"%s\"", client, UserId, Auth, (team == CS_TEAM_T) ? "TERRORIST" : "CT", event);
}

stock SetTeams(newTeam = -1)
{
	if (newTeam == -1)
		newTeam = TEAM_BOT;
	
	if(newTeam == 1)
		newTeam = GetRandomInt(CS_TEAM_T, CS_TEAM_CT);
	
	if (newTeam == CS_TEAM_CT)
	{
		TEAM_BOT = CS_TEAM_CT;
		SetConVarString(botteam, "CT");
		TEAM_HUMAN = CS_TEAM_T;
		SetConVarString(humanteam, "T");
	}
	else if (newTeam == CS_TEAM_T)
	{
		TEAM_BOT = CS_TEAM_T;
		SetConVarString(botteam, "T");
		TEAM_HUMAN = CS_TEAM_CT;
		SetConVarString(humanteam, "CT");
	}
	else
		return;
	
	SetConVarInt(ibot_bot_team, newTeam);

	new team, bool:IsBot, bool:TeamsChanged = false;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i))
			continue;

		team = GetClientTeam(i);
		
		if (team != CS_TEAM_CT && team != CS_TEAM_T)
			continue;
		
		IsBot = IsFakeClient(i);
		
		if(IsBot && team != TEAM_BOT)
		{
			CS_SwitchTeam(i, TEAM_BOT);
			TeamsChanged = true;
		}
		else if (!IsBot && team != TEAM_HUMAN)
		{
			CS_SwitchTeam(i, TEAM_HUMAN);
			TeamsChanged = true;
		}
	}
	if (TeamsChanged)
		SetConVarInt(mp_restartgame, 2);
}

stock AdviseBotControl(client)
{
	if (BotControlMsg == 2)
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && i != client && !IsFakeClient(i))
			{
				if (IsClientAdmin[i])
					CPrintToChat(i, "%s %t", ChatPrefix, "Player Took Over Bot Admin", client, BotControlTimes[client]);
				else
					CPrintToChat(i, "%s %t", ChatPrefix, "Player Took Over Bot", client);

				PrintHintText(i, "%t", "Player Took Over Bot hint", client);
			}
		}
	}
	else
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && IsClientAdmin[i])
				CPrintToChat(i, "%s %t", ChatPrefix, "Player Took Over Bot Admin", client, BotControlTimes[client]);
		}
	}
}

/**
* Gets the number of specific players.
*
* @param		searchTeam		Team in which to search. (0, TEAM_BOT, TEAM_HUMAN)
* @param		searchTyp		Player type for which to search. (bot, human, any)
* @param		searchAlive		Is it important that the player is alive? (true, false)
*
* @return						The number of players in which the parameters match.
*/
stock GetAlivePlayers(searchTeam = 1, const String:searchTyp[]="any", bool:searchAlive=true)
{
	new typ =	(StrEqual(searchTyp, 	"any", 		false))?  1: // Kind any
				(StrEqual(searchTyp, 	"bot",		false))?  2: // Kind Bot
				(StrEqual(searchTyp, 	"human",	false))?  3: // Kind Human
															  0; // KindError
	if (!typ)
		SetFailState("Wrong typ of Player '%s'", searchTyp);

	new alive = 0;
	for (new i = 1; i <= MaxClients; i++)
	{
		//Im Spiel, Lebt falls nötig und im gesuchtem Team
		if (!IsClientInGame(i) || (searchAlive && !IsPlayerAlive(i)) || (searchTeam > 1 && GetClientTeam(i) != searchTeam))
			continue;
		
		if (typ == 1)
			alive++;
		else
		{
			new bool:IsClientBot = IsFakeClient(i);								
			if ((typ == 2 && IsClientBot) || (typ == 3 && !IsClientBot))
				alive++;
		}
	}

	return alive;
}

stock GiveClientGrenades(client, Offset, count)
{
	if(count < 1)
		return;
	
	decl String:item[MAX_WEAPON_STRING]; item[0] = '\0';
	
	switch (Offset)
	{
		case HEGrenadeOffset: Format(item, sizeof(item), "weapon_hegrenade");
		case FlashbangOffset: Format(item, sizeof(item), "weapon_flashbang");
		case SmokegrenadeOffset: Format(item, sizeof(item), "weapon_smokegrenade");
		default: return;
	}
	
	for (new i = 0; i < count; i++)
		GivePlayerItem(client, item);
}

stock GetClientGrenades(client, Offset)
{
	new count = GetEntProp(client, Prop_Data, "m_iAmmo", _, Offset);
	SetEntProp(client, Prop_Data, "m_iAmmo", 0, _, Offset);
	
	#if _DEBUG2
		if (count != 0) DebugMessage("Grenades#%i: %i", Offset, count);
	#endif

	return count;
}

stock BotLevel(client, bool:bonus=false)
{
	if (!IsClientInGame(client) || !IsFakeClient(client))
		return -1;

	decl String:name[MAX_NAME_LENGTH];
	name[0] = '\0';

	GetClientName(client, name, sizeof(name));

	if (StrContains(name, "elite", false) != -1)
	{
		if(bonus)
			return EliteBonus;
		else
			return 3;
	}
	else if (StrContains(name, "expert", false) != -1)
	{
		if(bonus)
			return ExpertBonus;
		else
			return 3;
	}
	else if (StrContains(name, "veryhard", false) != -1)
	{
		if(bonus)
			return VeryHardBonus;
		else
			return 2;
	}
	else if (StrContains(name, "hard", false) != -1)
	{
		if(bonus)
			return HardBonus;
		else
			return 2;
	}
	else if (StrContains(name, "tough", false) != -1)
	{
		if(bonus)
			return ToughBonus;
		else
			return 1;
	}
	else if (StrContains(name, "normal", false) != -1)
	{
		if(bonus)
			return NormalBonus;
		else
			return 1;
	}
	else if (StrContains(name, "fair", false) != -1)
	{
		if(bonus)
			return FairBonus;
		else
			return 0;
	}	
	else if (StrContains(name, "easy", false) != -1)
	{
		if(bonus)
			return EasyBonus;
		else
			return 0;
	}
	
	return 0;
}

stock StopAllBeacon()
{
	for (new i = 1; i <= MaxClients; ++i)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i)) ClearTimer(BeaconTimer[i]);
	}
}

stock CheckForBeacon()
{
	if (!UseBeacon)
		return;

	new humans = 0;
	new bots = 0;

	new client = -1;

	for (new i = 1; i <= MaxClients; ++i)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i))
		{
			if (GetClientTeam(i) == TEAM_BOT)
			{
				bots++;
				client = i;
			}
			else
				humans++;
		}
	}

	if (client != -1)
	{
		if ((humans == 0 || bots == 0))
		{
			#if _DEBUG
				DebugMessage("Clear Beacon for %N", client);
			#endif
			ClearTimer(BeaconTimer[client]);
		}
		else if (humans > 0 && bots == 1 && !BeaconTimer[client])
		{
			#if _DEBUG
				DebugMessage("Set Beacon for %N", client);
			#endif
			BeaconTimer[client] = CreateTimer(1.0, Timer_Beacon, client, TIMER_REPEAT);
		}
	}
}

stock iBotsHP(winner)
{
	#if _DEBUG
		DebugMessage("iBotsHP running...");
	#endif

	new OldHealth = iBotsHealth;
	if (winner == TEAM_BOT)
	{
		#if _DEBUG
			DebugMessage("TEAM_BOT won...");
		#endif

		score_bot++;
		BotsWinStreak++;
		HumansWinStreak = 0;
		BotDifficultyChangeableBot++;
		BotDifficultyChangeableHuman = 0;

		if (BotsWinStreak > 1)
			CPrintToChatAll("%s %t", ChatPrefix, "Bot Streak", BotsWinStreak);

		if (BotsWinStreak >= BotWinningStreak)
		{
			if (UseSuperNades && NadeMultiplyer > 1.0)
			{
				NadeMultiplyer -= NadeMultiplyerDecrease;

				if (NadeMultiplyer < 1.0)
					NadeMultiplyer = 1.0;
			}

			if (ModifyHP)
			{
				iBotsHealth -= iBotsHPDecrease;

				if (iBotsHealth < MinHP)
					iBotsHealth = MinHP;
			}
		}
	}
	else if (winner == TEAM_HUMAN)
	{
		#if _DEBUG
			DebugMessage("TEAM_HUMAN won...");
		#endif

		score_human++;
		HumansWinStreak++;
		BotsWinStreak = 0;
		BotDifficultyChangeableHuman++;
		BotDifficultyChangeableBot = 0;
		
		if (HumansWinStreak > 1)
			CPrintToChatAll("%s %t", ChatPrefix, "Human Streak", HumansWinStreak);

		if (HumansWinStreak >= HumanWinningStreak)
		{
			if (ModifyHP)
			{
				iBotsHealth += iBotsHPIncrease;

				if (BotMaxHP > 0 && iBotsHealth > BotMaxHP)
					iBotsHealth = BotMaxHP;
			}

			if (UseSuperNades)
			{
				#if _DEBUG
					DebugMessage("Increasing nade multiplyer");
				#endif

				NadeMultiplyer += NadeMultiplyerIncrease;
			}
		}
	}
	else
		return;
		
	if (OldHealth != iBotsHealth)
	{
		CPrintToChatAll("%s %t", ChatPrefix, "Health changed", iBotsHealth);
		PrintHintTextToAll("%t", "Health changed hint", iBotsHealth);
	}
	
	if (!BotDiffNeedsAdjustment(BotDifficultyChangeableBot, BotDifficultyChangeableHuman))
		KickFirstBot();
}

stock bool:BotDiffNeedsAdjustment(&WinRoundsBots, &WinRoundsHumans)
{
	#if _DEBUG2
		DebugMessage("BotDiffNeedsAdjustment Runing B:%i(%i) H:%i(%i)",(BotsStreakDiff-WinRoundsBots),BotsStreakDiff,(HumansStreakDiff-WinRoundsHumans),HumansStreakDiff);
	#endif
	
	new bdiff = BotDifficulty;
	
	if (WinRoundsHumans >= HumansStreakDiff)
		bdiff++;

	if (WinRoundsBots >= BotsStreakDiff)
		bdiff--;
		
	if (bdiff != BotDifficulty)
	{
		#if _DEBUG2
			DebugMessage("BotDiffNeedsAdjustment Reset Counter");
		#endif
		
		WinRoundsBots = 0;
		WinRoundsHumans = 0;
	}
	return ChangeBotDifficulty(bdiff, false, true);
}

stock bool:ChangeBotDifficulty(diff, bool:enforce=false, bool:broadcast=false)
{
	#if _DEBUG
		DebugMessage("ChangeBotDifficulty from %i to %i, force:%b, broadcast:%b",BotDifficulty, bdiff, enforce, broadcast);
	#endif
	
	if ((diff == BotDifficulty && !enforce) || diff < 0 || diff > 3)
	{
		return false;
	}

	SetConVarInt(ibot_difficulty, diff);
	BotDifficulty = diff;
	
	if(enforce)
		KickAllBot();
	else
		KickFirstBot();
	
	if(broadcast)
	{
		CPrintToChatAll("%s %t", ChatPrefix, "Diff changed", BotDifficulty);
		PrintHintTextToAll("%t", "Diff changed hint", BotDifficulty);
	}
	
	return true;
}

stock KickFirstBot()
{
	#if _DEBUG2
		DebugMessage("Running KickFirstBot...");
	#endif
	
	new KicksNeeded = 0;
	new BotCount = GetAlivePlayers(TEAM_BOT, "bot", false);
	new BotQuota = GetConVarInt(ibot_quota);
	
	if (HumansWinStreak > 0)
		KicksNeeded = BotCount / HumansStreakDiff;
	else if (BotsWinStreak > 0)
		KicksNeeded = BotCount / BotsStreakDiff;
	
	if (KicksNeeded >= BotCount)
		KicksNeeded = BotCount-1;
	
	if (KicksNeeded < 1)
		KicksNeeded = 1;

	KicksNeeded += GetAlivePlayers(TEAM_HUMAN,"bot",false);

	new BotArray[MaxClients];
	new BotID=-1;
	BotCount = 0;
	
	for (new i = 1; (i <= MaxClients && KicksNeeded > 0); i++)
	{				
		if (!IsClientInGame(i) || !IsFakeClient(i) || IsClientSourceTV(i) || KickTimer[i] != INVALID_HANDLE)
			continue;
		
		BotCount++;
		if (GetClientTeam(i) != TEAM_BOT)
		{
			KickTimer[i] = CreateTimer(((RestartRoundTime > 0)? RestartRoundTime-0.2 : 0.0), Timer_KickFirstBot, i);
			KicksNeeded--;
			continue;
		}
		
		if (BotLevel(i) != BotDifficulty)
		{
			KickTimer[i] = CreateTimer(((RestartRoundTime > 0)? RestartRoundTime-0.2 : 0.0), Timer_KickFirstBot, i);
			KicksNeeded--;
			continue;			
		}
		
		BotID++;
		BotArray[BotID] = i;
		
		if (BotCount >= BotQuota)
			break;
	}
	
	while (KicksNeeded > 0 && BotID >= 0 && KickAnytime == 1)
	{
			KickTimer[BotArray[BotID]] = CreateTimer(((RestartRoundTime > 0)? RestartRoundTime-0.3 : 0.0), Timer_KickFirstBot, BotArray[BotID]);
			BotID--;
			KicksNeeded--;
	}
	
}

stock KickAllBot()
{
	#if _DEBUG2
		DebugMessage("Running KickAllBot...");
	#endif

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsFakeClient(i) && !IsClientSourceTV(i))
			KickClient(i,"Resetting Bots");
	}
}

stock iBotsMoney()
{
	if (GetTeamClientCount(TEAM_HUMAN) < 1)
		return;
	
	if (BotsWinStreak > BotsStreakMoney)
	{
		CPrintToChatAll("%s %t", ChatPrefix, "Paid Humans", StreakMoney);

		new team, val;

		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				team = GetClientTeam(i);
				if (team == TEAM_HUMAN)
				{
					val = GetEntProp(i, Prop_Send, "m_iAccount");
					val += StreakMoney;
					SetEntProp(i, Prop_Send, "m_iAccount", val);
				}
			}
		}
	}
	else if (HumansWinStreak > HumansStreakMoney)
	{
		CPrintToChatAll("%s %t", ChatPrefix, "Paid Bots", StreakMoney);

		new team, val;

		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				team = GetClientTeam(i);
				if (team == TEAM_BOT)
				{
					val = GetEntProp(i, Prop_Send, "m_iAccount");
					val += StreakMoney;
					SetEntProp(i, Prop_Send, "m_iAccount", val);
				}
			}
		}
	}
}

stock iBotsQuota()
{
	if (!ManageBots)
		return;

	new humans = GetTeamClientCount(TEAM_HUMAN);
	new spectators = GetTeamClientCount(CS_TEAM_SPECTATOR);
	new quota;
	new bots = GetConVarInt(ibot_quota);

	if (humans > 0)
	{
		// Set base quota based on humans multiplied by iBotsQuota cvar, rounded
		quota = RoundFloat(humans * f_iBotsQuota);

		if (quota < MinQuota)
			quota = MinQuota;
	}
	else
	{
		quota = MinQuota;
		
		if (ResetEverythingTimer == INVALID_HANDLE)
		{
			#if _DEBUG2
				DebugMessage("Start ResetEverythingTimer iBotsQuota");
			#endif
			ResetEverythingTimer = CreateTimer(RoundTime, Timer_ResetEverything);
		}
			
	}

	new difference = score_human - score_bot;

	if (difference > WinningDifference)
		quota += difference - WinningDifference;

	if (quota > MaxBots)
		quota = MaxBots;

	if ((quota + (humans += spectators)) >= MaxClients)
		quota = MaxClients - humans - ireservedslots;
	
	if (bots != quota)
	{
		CPrintToChatAll("%s %t", ChatPrefix, "Quota changed", quota);
		PrintHintTextToAll("%t", "Quota changed hint", quota);
		SetConVarInt(ibot_quota, quota);
	}
}


stock ResetEverything(bool:FromTimer = false)
{
	#if _DEBUG2
		DebugMessage("Running ResetEverything...");
	#endif

	score_bot = 0;
	score_human = 0;
	iBotsHealth = 100;
	BotsWinStreak = 0;
	HumansWinStreak = 0;
	BotDifficultyChangeableBot = 0;
	BotDifficultyChangeableHuman = 0;
	Advertisetime = 0;
	MapIsDone = false;
	NadeMultiplyer = 1.0;
	
	if(!FromTimer)
		return;
	
	AllowReset = false;
		
	if (UseMaxFrags)
	{
		#if _DEBUG2
			DebugMessage("UseMaxFrags is being used, setting mp_fraglimit to %i", MaxFrags);
		#endif
	
		SetConVarInt(mp_fraglimit, MaxFrags);
	}
	
	if (UseMaxRounds)
	{
		#if _DEBUG2
			DebugMessage("UseMaxRounds is being used, setting mp_maxrounds to %i", MaxRounds);
		#endif
	
		SetConVarInt(mp_maxrounds, MaxRounds);
	}
	
	if (UseMaxWins)
	{
		#if _DEBUG2
			DebugMessage("UseMaxWins is being used, setting mp_winlimit to %i", MaxWins);
		#endif
	
		SetConVarInt(mp_winlimit, MaxWins);
	}
	
	CPrintToChatAll("%s %t", ChatPrefix, "Resetting");

	SetConVarInt(ibot_quota, MinQuota);

	ChangeBotDifficulty(StartingBotDiff, true);
}


/***************************************************************************************************************************************\
* ======================================================================================================================================*
* 														Timer Functions																	*
* ======================================================================================================================================*
\***************************************************************************************************************************************/

public Action:Timer_Beacon(Handle:timer, any:client)
{
	if (IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == TEAM_BOT)
	{
		new Float:vec[3];
		GetClientAbsOrigin(client, vec);

		vec[2] += 10;

		TE_SetupBeamRingPoint(vec, 10.0, 300.0, g_BeamSprite, g_HaloSprite, 0, 15, 1.0, 5.0, 0.0, {0, 0, 255, 255}, 10, 0);
		TE_SendToAll();

		EmitAmbientSound(SOUND_BEEP, vec, client, SNDLEVEL_RAIDSIREN);

		CreateTimer(0.5, Timer_Blip, client);
	}
	else
	{
		ClearTimer(BeaconTimer[client]);
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public Action:Timer_Blip(Handle:timer, any:client)
{
	if (IsClientInGame(client))
	{
		new Float:vec[3];
		GetClientAbsOrigin(client, vec);

		vec[2] += 10;

		EmitAmbientSound(SOUND_BLIP, vec, client, SNDLEVEL_RAIDSIREN);
	}
	else
		return Plugin_Stop;

	return Plugin_Continue;
}

public Action:Timer_SetTeams(Handle:timer, any:newTeam)
{
	SetTeams(newTeam);
	return Plugin_Continue;
}

public Action:Timer_MapHasEnded(Handle:timer, any:client)
{
	if (client > 0)
	{
		// Announce player who won by achieving maxfrags first
		if (!b_MapIsOver)
		{
			CPrintToChatAll("%s %t", ChatPrefix, "Player Won", client, GetClientFrags(client));
			LogEventToGame("iBots_win",client);
		}
		else
			// This will fire if the map ended because time ran out and no one achieved the mp_fraglimit
			CPrintToChatAll("%s %t", ChatPrefix, "No Win", MaxFrags);
	}
	else
	{
		// Find player(s) with highest score
		new temptopscore = 0;
		new score = 0;
		new temptopplayer = 0;
		new tied[MAXPLAYERS+1] = 0;

		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && GetClientTeam(i) > CS_TEAM_SPECTATOR)
			{
				score = FragCount[i];

				if (0 < score && score >= temptopscore)
				{
					if (score == temptopscore)
					{
						tied[i] = temptopplayer; // I'm tied with this player
						tied[temptopplayer] = i; // This player tied with me
					}
					else
					{
						temptopplayer = i; // I'm the new top player
						temptopscore = score; // My score is the new top score
						tied[i] = 0; // I'm not tied with anyone, yet
					}
				}
				else
					tied[i] = 0;
			}
		}

		
		if (temptopplayer > 0)
		{
			new top_winner = temptopplayer;
			new tied_winner = tied[top_winner]; // Player I'm tied with, if any
			new topscore = FragCount[top_winner];

			if (tied_winner > 0)
			{
				CPrintToChatAll("%s %t", ChatPrefix, "Tie", top_winner, tied_winner, topscore);
				LogEventToGame("iBots_win",tied_winner);
			}
			else
				CPrintToChatAll("%s %t", ChatPrefix, "No Tie", top_winner, topscore);
			
			LogEventToGame("iBots_win",top_winner);
		}
	}

	ClearTimer(BotQuotaTimer);
}

public Action:Timer_JoinAdvertise(Handle:timer, any:client)
{
	h_ClientAdvertise[client] = INVALID_HANDLE;

	#if _DEBUG
		DebugMessage("Running Timer_JoinAdvertise timer code...");
	#endif

	if (IsClientInGame(client) && GetClientTeam(client) > CS_TEAM_NONE)
	{
		CPrintToChat(client, "%s v%s %s", ChatPrefix, PLUGIN_VERSION, PLUGIN_ANNOUNCE);
		CPrintToChatAll("%s %t", ChatPrefix, "Advertise");
		CPrintToChat(client, "%t", "Bots Info", iBotsHealth, BotDifficulty);
	}
}

public Action:Timer_KickFirstBot(Handle:timer, any:client)
{
	if (client != 0 && IsClientInGame(client) && IsFakeClient(client))
	{
		ClearTimer(KickTimer[client]);
		KickClient(client, "Adjusting Bot Difficulty");
	}
}

public Action:Timer_ResetPlayer(Handle:timer, any:serial)
{
	new client = GetClientFromSerial(serial);	
	
	if (!IsValidClient(client))
		return Plugin_Continue;	

	SetEntityModel(client, PlayerOldSkin[client]);
	ClientHP[client] = 0;
	IsControllingBot[client] = false;
	
	if (AllowBotControl && GetClientTeam(client) == TEAM_BOT)
		CS_SwitchTeam(client, TEAM_HUMAN);
	
	if (!IsPlayerAlive(client))
		return Plugin_Continue;	
	
	CS_RemoveAllWeapons(client);
	CS_RespawnPlayer(client);
	
	return Plugin_Continue;
}

public Action:Timer_ResetEverything(Handle:timer)
{
	#if _DEBUG2
		DebugMessage("Run Timer_ResetEverything %s", (AllowReset) ? "AllowReset" : "");
	#endif
	
	if (AllowReset)
	{
		ResetEverything(true);
	}
	
	ClearTimer(ResetEverythingTimer);
	
	return Plugin_Continue;
}

public Action:Timer_SetScore(Handle:timer)
{
	SetTeamScore(TEAM_BOT, score_bot);
	SetTeamScore(TEAM_HUMAN, score_human);
}

public Action:Timer_Advertise(Handle:timer)
{
	#if _DEBUG
		DebugMessage("Running Timer_Advertise");
	#endif

	// Advertises to every client every X rounds if enabled
	//Client_PrintKeyHintTextToAll("%s %s %t", ChatPrefix, PLUGIN_ANNOUNCE, "Advertise2", iBotsHealth, BotDifficulty);	// aus weil doppelt
	CPrintToChatAll("%s %s", ChatPrefix, PLUGIN_ANNOUNCE);
	CPrintToChatAll("%s %t", ChatPrefix, "Advertise");
}

public Action:Timer_AdvertiseBotControl(Handle:timer, any:serial)
{
	new client = GetClientFromSerial(serial);

	if (!IsValidClient(client) || !IsClientInGame(client) || IsFakeClient(client) || IsPlayerAlive(client)
		|| !AllowedToControlBot[client] || !AllowBotControl || !GetAlivePlayers(TEAM_BOT) || !GetAlivePlayers(TEAM_HUMAN))
		return Plugin_Stop;

	// Find out who the player is spectating.
	new target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
	if (!IsValidClient(target))
		return Plugin_Continue;
		
	if (IsFakeClient(target))	// Player is spectating a bot
	{
			PrintHintText(client, "%t", "Press Key Bot hint", target);
			StopSound(client, SNDCHAN_STATIC, "UI/hint.wav");
	}
	else						// Player is spectating a human
	{
			PrintHintText(client, "%t", "No Human Takeover hint");
			StopSound(client, SNDCHAN_STATIC, "UI/hint.wav");
	}

	return Plugin_Continue;
}

public Action:Timer_DestroyRagdoll(Handle:timer, any:serial)
{
	new client = GetClientFromSerial(serial);

	if (client == 0)
		return Plugin_Continue;

	new ragdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
	HideDeath[client] = false;

	if (ragdoll < 0)
		return Plugin_Continue;

	AcceptEntityInput(ragdoll, "kill");

	return Plugin_Continue;
}

public Action:Timer_UpdateQuota(Handle:timer)
{
	ClearTimer(BotQuotaTimer);

	iBotsQuota();
}

public Action:Timer_UpdateQuotaDisconnect(Handle:timer)
{
	iBotsQuota();
}



/***************************************************************************************************************************************\
* ======================================================================================================================================*
* 														All about CMDs																	*
* ======================================================================================================================================*
\***************************************************************************************************************************************/

public Action:Cmd_itest(client, args)
{
	decl String:arg[3];
	arg[0] = '\0';
	GetCmdArg(1, arg, sizeof(arg));
	new bot = StringToInt(arg);
	
	ReplyToCommand(client, "Suche Waffen von %N", bot);
	
	return Plugin_Handled;
}

public Action:Cmd_SwitchTeams(client, args)
{
	if (!IsValidClient(client))
	{
		ReplyToCommand(client, "%t", "Ingame CMD");
		return Plugin_Handled;
	}

	if (TEAM_BOT == CS_TEAM_T)
		SetTeams(CS_TEAM_CT);
	else
		SetTeams(CS_TEAM_T);

	CreateTimer(2.5, Timer_SetScore);

	CPrintToChat(client, "%s %t", ChatPrefix, "Switched");

	return Plugin_Handled;
}

public Action:Cmd_iBotsHP(client, args)
{
	if (args != 1)
	{
		ReplyToCommand(client, "%s Usage: sm_iBots_hp <amount>", CleanPrefix);
		return Plugin_Handled;
	}

	decl String:arg[10];
	arg[0] = '\0';

	GetCmdArg(1, arg, sizeof(arg));
	new bothp = StringToInt(arg);

	if (bothp < MinHP || bothp > BotMaxHP)
	{
		ReplyToCommand(client, "%s %t", CleanPrefix, "Wrong Value", MinHP, BotMaxHP);
		return Plugin_Handled;
	}

	iBotsHealth = bothp;
	CPrintToChatAllEx(client, "%s %t", ChatPrefix, "HP set by player", bothp, client);

	return Plugin_Handled;
}


public Action:Cmd_iBotsDiff(client, args)
{
	if (args != 1)
	{
		ReplyToCommand(client, "%s Usage: sm_iBots_diff <amount>", CleanPrefix);
		return Plugin_Handled;
	}

	decl String:arg[10];
	arg[0] = '\0';

	GetCmdArg(1, arg, sizeof(arg));
	new bdiff = StringToInt(arg);

	if(ChangeBotDifficulty(bdiff, true))
		CPrintToChatAllEx(client, "%s %t", ChatPrefix, "Diff set by player", bdiff, client);
	else
		ReplyToCommand(client, "%s %t", CleanPrefix, "Wrong Value", 0, 3);

	return Plugin_Handled;
}

public Action:Cmd_ibots(client, args)
{
	#if _DEBUG
		DebugMessage("%L requesting iBots information", client);
	#endif

	if (!IsValidClient(client))
	{
		ReplyToCommand(client, "%s %s - %t", CleanPrefix, PLUGIN_ANNOUNCE, "Cmd1");
		ReplyToCommand(client, "%t", "Cmd2", iBotsHealth, BotDifficulty, NadeMultiplyer);
		return Plugin_Handled;
	}

	new humans = GetTeamClientCount(TEAM_HUMAN);
	new quota = RoundFloat(humans * f_iBotsQuota);

	CPrintToChat(client, "%s v%s %s\n%t", ChatPrefix, PLUGIN_VERSION, PLUGIN_ANNOUNCE, "Cmd1");
	CPrintToChat(client, "%t", "Cmd2", iBotsHealth, BotDifficulty, NadeMultiplyer);

	if (quota < MinQuota)
	{
		CPrintToChat(client, "%t", "MinQuota", f_iBotsQuota, MinQuota);
	}
	else
	{
		CPrintToChat(client, "%t", "Quota", f_iBotsQuota, quota);
	}

	return Plugin_Handled;
}


/***************************************************************************************************************************************\
* ======================================================================================================================================*
* 														All about CVars																	*
* ======================================================================================================================================*
\***************************************************************************************************************************************/

stock CreateMyCVars()
{
	new bool:appended;

	// Set the file for the include
	AutoExecConfig_SetFile("plugin.iBots");

	HookConVarChange((CreateConVar("iBots_version", PLUGIN_VERSION,
	"The version of iBots", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_PLUGIN | FCVAR_DONTRECORD)), z_CvarVersionChanged);

	new Handle:hRandom; // KyleS HATES Handles

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_quota_min", "2",
	"Minimum number of iBots to have in-game at any given time.", _, true, 2.0, true, 64.0)), z_CvarMinQuotaChange);
	MinQuota = GetConVarInt(hRandom);
	SetAppend(appended);
	
	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_bot_MinHP", "70",
	"Lowest Health for iBots (they will always start with 100 on map start)", _, true, 1.0, true, 100.0)), z_CvarMinHPChange);
	MinHP = GetConVarInt(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_bot_increaseHP", "10",
	"Amount of HP to add to bot's health as humans maintain a winning streak at or above iBots_streak_humans_hp", _, true, 5.0, true, 100.0)), z_CvariBotsHPIncreaseChange);
	iBotsHPIncrease = GetConVarInt(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_bot_decreaseHP", "15",
	"Amount of HP to take from bot's health as bots maintain a winning streak at or above iBots_streak_bots_hp", _, true, 5.0, true, 100.0)), z_CvariBotsHPDecreaseChange);
	iBotsHPDecrease = GetConVarInt(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_MaxFrags", "75",
	"Number of frags to declare a player a winner - this will set mp_fraglimit to the value specified here", _, true, 10.0, true, 100.0)), z_CvarMaxFragsChange);
	MaxFrags = GetConVarInt(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_MaxRounds", "30",
	"Max number of rounds to play before server changes maps - this will set mp_maxrounds to the value specified here", _, true, 1.0, true, 100.0)), z_CvarMaxRoundsChange);
	MaxRounds = GetConVarInt(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_MaxWins", "20",
	"Max number of rounds a team win before server changes maps - this will set mp_winlimit to the value specified here", _, true, 1.0, true, 100.0)), z_CvarMaxWinsChange);
	MaxWins = GetConVarInt(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_use_MaxFrags", "1",
	"Use the iBots_MaxFrags?\n0 = NO\n1 = YES", _, true, 0.0, true, 1.0)), z_CvarMaxFragsChange);
	UseMaxFrags = GetConVarBool(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_use_MaxRounds", "1",
	"Use the iBots_MaxRounds?\n0 = NO\n1 = YES", _, true, 0.0, true, 1.0)), z_CvarMaxRoundsChange);
	UseMaxRounds = GetConVarBool(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_use_MaxWins", "1",
	"Use the iBots_MaxWins?\n0 = NO\n1 = YES", _, true, 0.0, true, 1.0)), z_CvarMaxWinsChange);
	UseMaxWins = GetConVarBool(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_ManageBots", "1",
	"Should iBots manage the bots?\n0 = NO\n1 = YES", _, true, 0.0, true, 1.0)), z_CvarManageBotsChange);
	ManageBots = GetConVarBool(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_quota", "2.2",
	"Number of bots for each human player (will be rounded to nearest whole number after calculation)", _, true, 1.0, true, 10.0)), z_CvariBotsQuotaChange);
	f_iBotsQuota = GetConVarFloat(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_MaxBots", "24",
	"Maximum number of bots allowed - should be higher than iBots_quota_min", _, true, 0.0, true, 64.0)), z_CvarMaxBotsChange);
	MaxBots = GetConVarInt(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_Kick", "0",
	"Should each round bots will be renewed?\n0 = NO\n1 = YES", _, true, 0.0, true, 1.0)), z_CvarKickAnytime);
	KickAnytime = GetConVarInt(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_streak_humans_hp", "2",
	"How many rounds humans have to win in a row to start increasing the bot's HP", _, true, 1.0, true, 20.0)), z_CvarHumanWinningStreakChange);
	HumanWinningStreak = GetConVarInt(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_streak_humans_cash", "4",
	"Number of wins in a row humans must get before bots are paid (iBots_streak_money)", _, true, 1.0, true, 10.0)), z_CvarHumansStreakMoneyChange);
	HumansStreakMoney = GetConVarInt(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_streak_humans_diff", "3",
	"Number of wins in a row humans must get before bots have their difficulty increased", _, true, 1.0, true, 20.0)), z_CvarHumansStreakDiffChange);
	HumansStreakDiff = GetConVarInt(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_streak_bots_hp", "2",
	"How many rounds bots have to win in a row to start having their HP reduced", _, true, 1.0, true, 20.0)), z_CvarBotWinningStreakChange);
	BotWinningStreak = GetConVarInt(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_streak_bots_cash", "4",
	"Number of wins in a row bots must get before humans are paid (iBots_streak_money)", _, true, 1.0, true, 10.0)), z_CvarBotsStreakMoneyChange);
	BotsStreakMoney = GetConVarInt(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_streak_bots_diff", "2",
	"Number of wins in a row bots must get before their difficulty is reduced", _, true, 1.0, true, 10.0)), z_CvarBotsStreakDiffChange);
	BotsStreakDiff = GetConVarInt(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_streak_money", "2500",
	"Amount of money to pay the loosing team after iBots_streak_<team>_cash is reached", _, true, 100.0, true, 16000.0)), z_CvarStreakMoneyChange);
	StreakMoney = GetConVarInt(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_score_difference", "4",
	"Number of wins the humans have over the bots before additional bots (beyond the quota formula) start joining", _, true, 1.0, true, 8.0)), z_CvarWinningDifferenceChange);
	WinningDifference = GetConVarInt(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_final_diff_bots", "2",
	"If bots win the map by this many rounds, the bot_difficulty will be lowered by 1", _, true, 1.0, true, 15.0)), z_CvarFinalDiff_BotsChange);
	FinalDiff_Bots = GetConVarInt(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_final_diff_humans", "7",
	"If humnas win the map by this many rounds, the bot_difficulty will be raised by 1", _, true, 1.0, true, 15.0)), z_CvarFinalDiff_HumansChange);
	FinalDiff_Humans = GetConVarInt(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_advertise", "5",
	"The number of rounds in between advertisement of iBots (0 to disable)", _, true, 0.0, true, 15.0)), z_CvarAdvertiseIntervalChange);
	AdvertiseInterval = GetConVarInt(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_bot_team", "1",
	"Team number for bots (1 is random, 2 is T, 3 is CT)", _, true, 1.0, true, 3.0)), z_CvarTeamsChange);
	TEAM_BOT = GetConVarInt(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_Bonus_Easy", "5",
	"The amount of HP to award a player for killing an Easy level bot", _, true, 0.0, true, 50.0)), z_CvarEasyBonusChange);
	EasyBonus = GetConVarInt(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_Bonus_Fair", "5",
	"The amount of HP to award a player for killing a Fair level bot", _, true, 0.0, true, 50.0)), z_CvarFairBonusChange);
	FairBonus = GetConVarInt(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_Bonus_Normal", "5",
	"The amount of HP to award a player for killing a Normal level bot", _, true, 0.0, true, 50.0)), z_CvarNormalBonusChange);
	NormalBonus = GetConVarInt(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_Bonus_Tough", "10",
	"The amount of HP to award a player for killing a Tough level bot", _, true, 0.0, true, 50.0)), z_CvarToughBonusChange);
	ToughBonus = GetConVarInt(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_Bonus_Hard", "10",
	"The amount of HP to award a player for killing a Hard level bot", _, true, 0.0, true, 50.0)), z_CvarHardBonusChange);
	HardBonus = GetConVarInt(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_Bonus_VeryHard", "15",
	"The amount of HP to award a player for killing a Very Hard level bot", _, true, 0.0, true, 50.0)), z_CvarVeryHardBonusChange);
	VeryHardBonus = GetConVarInt(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_Bonus_Expert", "15",
	"The amount of HP to award a player for killing an Expert level bot", _, true, 0.0, true, 50.0)), z_CvarExpertBonusChange);
	ExpertBonus = GetConVarInt(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_Bonus_Elite", "20",
	"The amount of HP to award a player for killing an Elite level bot", _, true, 0.0, true, 50.0)), z_CvarEliteBonusChange);
	EliteBonus = GetConVarInt(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_KnifeMultiplier", "2.0",
	"The multiplier value of HP to award a player for killing a bot with a knife.", _, true, 0.0, true, 50.0)), z_CvarKnifeMultiplierBonusChange);
	KnifeBonusMultiplier = GetConVarFloat(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_use_ModifyHP", "1",
	"Use bot HP feature to increase/decrease bot's HP based on winning streaks?\n1 = YES\n0 = No", _, true, 0.0, true, 1.0)), z_CvarModifyHPChange);
	ModifyHP = GetConVarBool(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_use_HPBonus", "1",
	"Use the HP bonus for when players kill bots?\n1 = Yes\n0 = No", _, true, 0.0, true, 1.0)), z_CvarHPBonusChange);
	HPBonus = GetConVarBool(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_knife_BonusFrag", "1",
	"How many bonus frags a player get for killing a bot with a knife.", _, true, 0.0, true, 10.0)), z_CvarKnifeBonusFragChanged);
	KnifeBonusFrag = GetConVarInt(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_knife_BonusControl", "1",
	"How many bonus frags a player get for killing a bot with a knife.", _, true, 0.0, true, 10.0)), z_CvarKnifeBonusControlChanged);
	KnifeBonusControl = GetConVarInt(hRandom);
	SetAppend(appended);
	
	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_FragBomb", "0",
	"How many points(frags) a player get for planting/defusing the bomb.", _, true, 0.0, true, 10.0)), z_CvarBombFragChanged);
	BombFrag = GetConVarInt(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_JoinPartMode", "1",
	"Which method to use for adjusting bot count when humans join or leave?\n1 = Adjust on Round Start\n2 = Adjust on Round End\n3 = Adjust on Join", _, true, 1.0, true, 3.0)), z_CvarJoinPartModeChange);
	JoinPartMode = GetConVarInt(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_use_SuperNades", "1",
	"Use super grenades?\n1 = YES\n0 = No", _, true, 0.0, true, 1.0)), z_CvarUseSuperNadesChange);
	UseSuperNades = GetConVarBool(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_SuperNade_increase", "0.1",
	"Amount to increase the power of Super Nades as Bots' HP increases", _, true, 0.1, true, 10.0)), z_CvarSuperNadeIncreaseChange);
	NadeMultiplyerIncrease = GetConVarFloat(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_SuperNade_decrease", "0.2",
	"Amount to decrease the power of Super Nades as Bots' HP decreases", _, true, 0.1, true, 10.0)), z_CvarSuperNadeDecreaseChange);
	NadeMultiplyerDecrease = GetConVarFloat(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_use_IgnitedNades", "0",
	"Use ignited nades for VIP players?\nCurrent flag is \"a\", use admin_overrides to change it by over-ridding command \"ibots_vip\" to whatever flag you want\n1 = YES\n0 = No", _, true, 0.0, true, 1.0)), z_CvarUseIgnitedNadesChange);
	UseIgnitedNades = GetConVarBool(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_FFMode", "2",
	"Combine the following modes for your choice of FF:\n0 = iBots doesn't manage FF,\n1 = No FF for Humans,\n2 = No FF for Bots,\n4 = No FF for ViPs\nEx. 3 would mean no FF for anyone, 6 would mean no FF for bots and VIPs.\nThis will change mp_friendlyfire.", _, true, 0.0, true, 6.0)), z_CvarFFModeChanged);
	FFMode = GetConVarInt(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_botdiff_start", "1",
	"Starting bot difficulty level", _, true, 0.0, true, 3.0)), z_CvarStartBotDiffChanged);
	StartingBotDiff = GetConVarInt(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_botdiff_adjust", "2",
	"Which mode to use to adjust bot_difficulty when the map ends?\n0 = Don't adjust\n1 = Reset to iBots_start_botdiff\n2 = Adjust based on score", _, true, 0.0, true, 2.0)), z_CvarAdjustBotDiffChanged);
	AdjustBotDiff = GetConVarInt(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_use_BotControl", "1",
	"Allow dead humans to take control of bots to fight against humans?\n1=yes\n0=no", _, true, 0.0, true, 1.0)), z_CvarAllowBotControlChanged);
	AllowBotControl = GetConVarBool(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_BotControl_vip", "20",
	"How many times to allow VIP players to take control of a bot during a map", _, true, 0.0, true, 1000.0)), z_CvarBotControlVIPChanged);
	BotControlTimesVIP = GetConVarInt(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_BotControl_reg", "10",
	"How many times to allow non-VIP players to take control of a bot during a map", _, true, 0.0, true, 1000.0)), z_CvarBotControlREGChanged);
	BotControlTimesREG = GetConVarInt(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_use_beacon", "1",
	"Use the beacon on the last surviving bot?\n1=yes\n0=no", _, true, 0.0, true, 1.0)), z_CvarUseBeaconChanged);
	UseBeacon = GetConVarBool(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_bot_MaxHP", "150",
	"Maximum HP bots are allowed to reach\nUse 0 to have no limit", _, true, 0.0, true, 999.0)), z_CvarBotMaxHPChanged);
	BotMaxHP = GetConVarInt(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_human_MaxHP", "200",
	"Maximum HP humans are allowed to reach", _, true, 100.0, true, 500.0)), z_CvarHumanMaxHPChange);
	HumanMaxHP = GetConVarInt(hRandom);
	SetAppend(appended);

	HookConVarChange((hRandom = AutoExecConfig_CreateConVar("iBots_BotControl_msg", "2",
	"Who to inform when a player takes control of a bot (choose one)?\n0 = No message\n1 = Admins Only\n2 = Everyone", _, true, 0.0, true, 2.0)), z_CvarBotControlMsgChanged);
	BotControlMsg = GetConVarInt(hRandom);
	SetAppend(appended);

	CloseHandle(hRandom);
	
	ibot_bot_team = FindConVar("iBots_bot_team");
	if (ibot_bot_team == INVALID_HANDLE)
		SetFailState("[iBots] Unable to hook ibot_bot_team");
	
	HookConVarChange((mp_roundtime = FindConVar("mp_roundtime")), z_CvarRoundTimeChange);
	if (mp_roundtime == INVALID_HANDLE)
		SetFailState("[iBots] Unable to hook mp_roundtime");
	RoundTime = GetConVarFloat(mp_roundtime) * 60.0;
	
	HookConVarChange((mp_round_restart_delay = FindConVar("mp_round_restart_delay")), z_CvarRestartRoundTimeChange);
	if (mp_round_restart_delay == INVALID_HANDLE)
		SetFailState("[iBots] Unable to hook mp_round_restart_delay");
	RestartRoundTime = GetConVarFloat(mp_round_restart_delay);

	
	NoEndRoundHandle = FindConVar("mp_ignore_round_win_conditions");
	if (NoEndRoundHandle == INVALID_HANDLE)
		SetFailState("[iBots] Unable to find CVar mp_ignore_round_win_conditions");

	HookConVarChange((botsprefix = FindConVar("bot_prefix")), z_CvarBotPrefixChange);
	if (botsprefix == INVALID_HANDLE)
 		SetFailState("[iBots] Unable to hook bot_prefix");
	GetConVarString(botsprefix, OrgPrefix, sizeof(OrgPrefix));

	HookConVarChange((ibot_quota = FindConVar("bot_quota")), z_CvarBotQuotaChange);
	if (ibot_quota == INVALID_HANDLE)
		SetFailState("[iBots] Unable to hook bot_quota");
	Orgbotquota = GetConVarInt(ibot_quota);
	
	HookConVarChange((ibot_quota_mode = FindConVar("bot_quota_mode")), z_CvarBotQuotaModeChange);
	if (ibot_quota_mode == INVALID_HANDLE)
		SetFailState("[iBots] Unable to hook bot_quota_mode");
	GetConVarString(ibot_quota_mode, Orgbotquotamode, sizeof(Orgbotquotamode));

	HookConVarChange((mp_fraglimit = FindConVar("mp_fraglimit")), z_CvarMaxFragsChange);
	if (mp_fraglimit == INVALID_HANDLE)
		SetFailState("[iBots] Unable to hook mp_fraglimit");
	Orgfraglimit = GetConVarInt(mp_fraglimit);

	HookConVarChange((mp_maxrounds = FindConVar("mp_maxrounds")), z_CvarMaxRoundsChange);
	if (mp_maxrounds == INVALID_HANDLE)
		SetFailState("[iBots] Unable to hook mp_maxrounds");
	Orgmaxrounds = GetConVarInt(mp_maxrounds);

	HookConVarChange((mp_winlimit = FindConVar("mp_winlimit")), z_CvarMaxWinsChange);
	if (mp_winlimit == INVALID_HANDLE)
		SetFailState("[iBots] Unable to hook mp_winlimit");
	Orgwinlimit = GetConVarInt(mp_winlimit);

	HookConVarChange((mp_limitteams = FindConVar("mp_limitteams")), z_CvarLimitTeamsChange);
	if (mp_limitteams == INVALID_HANDLE)
		SetFailState("[iBots] Unable to hook mp_limitteams");
	Orglimitteams = GetConVarInt(mp_limitteams);

	HookConVarChange((mp_autoteambalance = FindConVar("mp_autoteambalance")), z_CvarAutoteambalanceChange);
	if (mp_autoteambalance == INVALID_HANDLE)
		SetFailState("[iBots] Unable to hook mp_autoteambalance");
	Orgautoteambalance = GetConVarInt(mp_autoteambalance);

	HookConVarChange((mp_friendlyfire = FindConVar("mp_friendlyfire")), z_CvarFriendlyFireChange);
	if (mp_friendlyfire == INVALID_HANDLE)
		SetFailState("[iBots] Unable to hook mp_friendlyfire");
	Orgfriendlyfire = GetConVarInt(mp_friendlyfire);
	
	HookConVarChange((ibot_difficulty = FindConVar("bot_difficulty")), z_CvarBotDifficultyChange);
	if (ibot_difficulty == INVALID_HANDLE)
		SetFailState("[iBots] Unable to hook bot_difficulty");
	Orgbotdifficulty = GetConVarInt(ibot_difficulty);
	
	mp_restartgame = FindConVar("mp_restartgame");
	if (mp_restartgame == INVALID_HANDLE)
		SetFailState("[iBots] Unable to hook mp_restartgame");

	HookConVarChange((mp_forcecamera = FindConVar("mp_forcecamera")), z_CvarForceCameraChange);
	if (mp_forcecamera == INVALID_HANDLE)
		SetFailState("[iBots] Unable to hook mp_forcecamera");
	Orgforcecamera = GetConVarInt(mp_forcecamera);

	HookConVarChange((botteam = FindConVar("bot_join_team")), z_CvarTeamsChange);
	if (botteam == INVALID_HANDLE)
		SetFailState("[iBots] Unable to hook bot_join_team CVar");
	GetConVarString(botteam, Orgbotteam, sizeof(Orgbotteam));

	HookConVarChange((humanteam = FindConVar("mp_humanteam")), z_CvarTeamsChange);
 	if (humanteam == INVALID_HANDLE)
		SetFailState("[iBots] Unable to hook mp_humanteam CVar");
	GetConVarString(humanteam, Orghumanteam, sizeof(Orghumanteam));

	new String:gdir[PLATFORM_MAX_PATH];
	GetGameFolderName(gdir,sizeof(gdir));
	if (StrEqual(gdir,"csgo",false))
		IsCSGO = true;
	else
		IsCSGO = false;

	AutoExecConfig(true, "plugin.iBots");

	// Cleaning is an expensive operation and should be done at the end
	if (appended)
		AutoExecConfig_CleanFile();
}

stock SetAppend(&appended)
{
	if (AutoExecConfig_GetAppendResult() == AUTOEXEC_APPEND_SUCCESS)
	{
		appended = true;
	}
}

public z_CvarVersionChanged(Handle:cvar, const String:oldValue[], const String:newValue[])
{
	if (!StrEqual(newValue, PLUGIN_VERSION))
	{
		SetConVarString(cvar, PLUGIN_VERSION);
	}
}

public z_CvarRestartRoundTimeChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	RestartRoundTime = GetConVarFloat(cvar);
}

public z_CvarKickAnytime(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	KickAnytime = GetConVarInt(cvar);
}

public z_CvarRoundTimeChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	RoundTime = GetConVarFloat(cvar)*60;
}

public z_CvarMinQuotaChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	MinQuota = GetConVarInt(cvar);
}

public z_CvarBotDifficultyChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	ReplyToCommand(0, "%s controls the value for bot_difficulty. Have a look at sm_iBots_diff", CleanPrefix);
}

public z_CvarBotPrefixChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{	
	if (!StrEqual(NewPrefix, newVal))
		GetConVarString(botsprefix, OrgPrefix, sizeof(OrgPrefix));
	
	if (HPBonus)
	{
		Format(NewPrefix, sizeof(NewPrefix), ((strlen(OrgPrefix) == 0) ? "%s<difficulty>" : "%s <difficulty>"), OrgPrefix);
		SetConVarString(botsprefix, NewPrefix);
	}
	else
		SetConVarString(botsprefix, OrgPrefix);
}

//NOTE: bot_quota ChangeHandler überarbeiten
public z_CvarBotQuotaChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	ReplyToCommand(0, "%s controls the value for bot_quota", CleanPrefix);
}

//NOTE: bot_quota_mode ChangeHandler überarbeiten
public z_CvarBotQuotaModeChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	ReplyToCommand(0, "%s controls the value for bot_quota_mode", CleanPrefix);
	SetConVarString(ibot_quota_mode, "normal");
}

public z_CvarMinHPChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	MinHP = GetConVarInt(cvar);
}

public z_CvariBotsHPIncreaseChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	iBotsHPIncrease = GetConVarInt(cvar);
}

public z_CvariBotsHPDecreaseChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	iBotsHPDecrease = GetConVarInt(cvar);
}

public z_CvarMaxFragsChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	decl String:cvarName[MAX_BUFFER_LENGTH];
	cvarName[0] = '\0';
	GetConVarName(cvar, cvarName, sizeof(cvarName));
	new value = StringToInt(newVal);		
	
	if (StrEqual(cvarName, "iBots_use_MaxFrags", false))
	{
		if (value)
		{
			UseMaxFrags = true;
			SetConVarInt(mp_fraglimit, MaxFrags);
		}
		else
		{
			UseMaxFrags = false;
			SetConVarInt(mp_fraglimit, 0);
		}
	}
	else
	{
		MaxFrags = value;
		
		if (UseMaxFrags)
			SetConVarInt(mp_fraglimit, MaxFrags);
		else
		{
			ReplyToCommand(0, "%s iBots_use_MaxFrags must be set to 1", CleanPrefix);
			SetConVarInt(mp_fraglimit, 0);
		}
	}
}

public z_CvarMaxRoundsChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	decl String:cvarName[MAX_BUFFER_LENGTH];
	cvarName[0] = '\0';
	GetConVarName(cvar, cvarName, sizeof(cvarName));
	new value = StringToInt(newVal);		
	
	if (StrEqual(cvarName, "iBots_use_MaxRounds", false))
	{
		if (value)
		{
			UseMaxRounds = true;
			SetConVarInt(mp_maxrounds, MaxRounds);
		}
		else
		{
			UseMaxRounds = false;
			SetConVarInt(mp_maxrounds, 0);
		}
	}
	else
	{
		MaxRounds = value;
		
		if (UseMaxRounds)
			SetConVarInt(mp_maxrounds, MaxRounds);
		else
		{
			ReplyToCommand(0, "%s iBots_use_MaxRounds must be set to 1", CleanPrefix);
			SetConVarInt(mp_maxrounds, 0);
		}
	}
}

public z_CvarMaxWinsChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	decl String:cvarName[MAX_BUFFER_LENGTH];
	cvarName[0] = '\0';
	GetConVarName(cvar, cvarName, sizeof(cvarName));
	new value = StringToInt(newVal);		
	
	if (StrEqual(cvarName, "iBots_use_MaxWins", false))
	{
		if (value)
		{
			UseMaxWins = true;
			SetConVarInt(mp_winlimit, MaxWins);
		}
		else
		{
			UseMaxWins = false;
			SetConVarInt(mp_winlimit, 0);
		}
	}
	else
	{
		MaxWins = value;
		
		if (UseMaxWins)
			SetConVarInt(mp_winlimit, MaxWins);
		else
		{
			ReplyToCommand(0, "%s iBots_use_MaxWins must be set to 1", CleanPrefix);
			SetConVarInt(mp_winlimit, 0);
		}
	}
}

public z_CvarLimitTeamsChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
		Orglimitteams = GetConVarInt(cvar);
		ReplyToCommand(0,"%s controls the value for mp_limitteams.", CleanPrefix);
		SetConVarInt(mp_limitteams, 0);
}

public z_CvarAutoteambalanceChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
		Orgautoteambalance = GetConVarInt(cvar);
		ReplyToCommand(0,"%s controls the value for mp_autoteambalance.", CleanPrefix);
		SetConVarInt(mp_autoteambalance, 0);
}

public z_CvarFriendlyFireChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	Orgfriendlyfire = GetConVarInt(cvar);
	if (0 < FFMode < 6)
	{
		ReplyToCommand(0,"%s controls the value for mp_friendlyfire. Have a look at iBots_FFMode.", CleanPrefix);
		SetConVarInt(mp_friendlyfire, 1);
	}
}

public z_CvarForceCameraChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	Orgforcecamera = GetConVarInt(cvar);
	if (AllowBotControl)
	{
		ReplyToCommand(0,"%s controls the value for mp_forcecamera. Have a look at iBots_use_BotControl.", CleanPrefix);
		SetConVarInt(mp_forcecamera, 0);
	}
}

public z_CvariBotsQuotaChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	f_iBotsQuota = GetConVarFloat(cvar);
}

public z_CvarManageBotsChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	ManageBots = GetConVarBool(cvar);
}

public z_CvarMaxBotsChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	MaxBots = GetConVarInt(cvar);
}

public z_CvarHumanWinningStreakChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	HumanWinningStreak = GetConVarInt(cvar);
}

public z_CvarHumansStreakMoneyChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	HumansStreakMoney = GetConVarInt(cvar);
}

public z_CvarBotWinningStreakChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	BotWinningStreak = GetConVarInt(cvar);
}

public z_CvarBotsStreakMoneyChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	BotsStreakMoney = GetConVarInt(cvar);
}

public z_CvarStreakMoneyChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	StreakMoney = GetConVarInt(cvar);
}

public z_CvarWinningDifferenceChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	WinningDifference = GetConVarInt(cvar);
}

public z_CvarFinalDiff_BotsChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	FinalDiff_Bots = GetConVarInt(cvar);
}

public z_CvarFinalDiff_HumansChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	FinalDiff_Humans = GetConVarInt(cvar);
}

public z_CvarAdvertiseIntervalChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	AdvertiseInterval = GetConVarInt(cvar);
}

public z_CvarEasyBonusChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	EasyBonus = GetConVarInt(cvar);
}

public z_CvarFairBonusChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	FairBonus = GetConVarInt(cvar);
}

public z_CvarNormalBonusChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	NormalBonus = GetConVarInt(cvar);
}

public z_CvarToughBonusChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	ToughBonus = GetConVarInt(cvar);
}

public z_CvarHardBonusChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	HardBonus = GetConVarInt(cvar);
}

public z_CvarVeryHardBonusChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	VeryHardBonus = GetConVarInt(cvar);
}

public z_CvarExpertBonusChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	ExpertBonus = GetConVarInt(cvar);
}

public z_CvarEliteBonusChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	EliteBonus = GetConVarInt(cvar);
}

public z_CvarKnifeMultiplierBonusChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	KnifeBonusMultiplier = GetConVarFloat(cvar);
}

public z_CvarModifyHPChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	ModifyHP = GetConVarBool(cvar);
}

public z_CvarJoinPartModeChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	JoinPartMode = GetConVarInt(cvar);
}

public z_CvarHPBonusChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	HPBonus = GetConVarBool(cvar);
	if (HPBonus)	SetConVarString(botsprefix, NewPrefix);
	else			SetConVarString(botsprefix, OrgPrefix);
}

public z_CvarReservedSlotsChanged(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	ireservedslots = GetConVarInt(cvar);
}

public z_CvarUseSuperNadesChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	UseSuperNades = GetConVarBool(cvar);

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if (UseSuperNades || (0 < FFMode <= 6))
				SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
			else
				SDKUnhook(i, SDKHook_OnTakeDamage, OnTakeDamage);
		}
	}
}

public z_CvarSuperNadeIncreaseChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	NadeMultiplyerIncrease = GetConVarFloat(cvar);
}

public z_CvarSuperNadeDecreaseChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	NadeMultiplyerDecrease = GetConVarFloat(cvar);
}

public z_CvarUseIgnitedNadesChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	UseIgnitedNades = GetConVarBool(cvar);
}

public z_CvarTeamsChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	decl String:cvarName[MAX_BUFFER_LENGTH];
	cvarName[0] = '\0';
	GetConVarName(cvar, cvarName, sizeof(cvarName));
	
	if (StrEqual(cvarName, "iBots_bot_team", false))
	{
		new newTeam = StringToInt(newVal);
		if (newTeam == 1)
		{
			PrintToServer("%t", "Bots on Random");
			TEAM_BOT = newTeam;			
		}
		else if (newTeam == CS_TEAM_T)
		{
			PrintToServer("%t", "Bots on T");
			TEAM_BOT = CS_TEAM_T;
		}
		else if (newTeam == CS_TEAM_CT)
		{
			PrintToServer("%t", "Bots on CT");
			TEAM_BOT = CS_TEAM_CT;
		}
	}
	else if (StrEqual(cvarName, "bot_join_team", false))
	{		
		if (StrEqual(newVal, oldVal, false))
			return;			
		else if (StrEqual(newVal, "T", false))
			TEAM_BOT = CS_TEAM_T;
		else if (StrEqual(newVal, "CT", false))
			TEAM_BOT = CS_TEAM_CT;
		else
			TEAM_BOT = 1;
	}
	else if (StrEqual(cvarName, "mp_humanteam", false))
	{
		if (StrEqual(newVal, oldVal))
			return;			
		else if (StrEqual(newVal, "T" ,false))
			TEAM_BOT = CS_TEAM_CT;
		else if (StrEqual(newVal, "CT", false))
			TEAM_BOT = CS_TEAM_T;
		else
			TEAM_BOT = 1;
	}
	else
		return;
	
	SetTeams();
}

public z_CvarFFModeChanged(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	FFMode = GetConVarInt(cvar);
	if(0 < FFMode <= 6)
		SetConVarInt(mp_friendlyfire, 1);
	else
		SetConVarInt(mp_friendlyfire, Orgfriendlyfire);
		
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if (UseSuperNades || (0 < FFMode <= 6))
				SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
			else
				SDKUnhook(i, SDKHook_OnTakeDamage, OnTakeDamage);
		}
	}
}

public z_CvarAdjustBotDiffChanged(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	AdjustBotDiff = GetConVarInt(cvar);
}

public z_CvarStartBotDiffChanged(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	StartingBotDiff = GetConVarInt(cvar);
}

public z_CvarAllowBotControlChanged(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	AllowBotControl = GetConVarBool(cvar);
	if (AllowBotControl)	SetConVarInt(mp_forcecamera, 0);
	else					SetConVarInt(mp_forcecamera, Orgforcecamera);
}

public z_CvarHumansStreakDiffChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	HumansStreakDiff = GetConVarInt(cvar);
}

public z_CvarBotsStreakDiffChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	BotsStreakDiff = GetConVarInt(cvar);
}

public z_CvarBotControlVIPChanged(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	BotControlTimesVIP = GetConVarInt(cvar);
}

public z_CvarBotControlREGChanged(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	BotControlTimesREG = GetConVarInt(cvar);
}

public z_CvarUseBeaconChanged(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	UseBeacon = GetConVarBool(cvar);
}

public z_CvarBotMaxHPChanged(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	BotMaxHP = GetConVarInt(cvar);
}

public z_CvarHumanMaxHPChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	HumanMaxHP = GetConVarInt(cvar);
}

public z_CvarBotControlMsgChanged(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	BotControlMsg = GetConVarInt(cvar);
}

public z_CvarKnifeBonusFragChanged(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	KnifeBonusFrag = GetConVarInt(cvar);
}

public z_CvarKnifeBonusControlChanged(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	KnifeBonusControl = GetConVarInt(cvar);
}

public z_CvarBombFragChanged(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	BombFrag = GetConVarInt(cvar);
}



/***************************************************************************************************************************************\
* ======================================================================================================================================*
* 														Debugging																		*
* ======================================================================================================================================*
\***************************************************************************************************************************************/

stock DebugMessage(const String:msg[], any:...)
{
	decl String:buffer[MAX_BUFFER_LENGTH];
	buffer[0] = '\0';
	CRemoveTags(buffer, sizeof(buffer));
	VFormat(buffer, sizeof(buffer), msg, 2);
	LogMessage("[DEBUG] %s", buffer);
	if (IsValidClient(DebugUser)) PrintToChat(DebugUser, "[iBots DEBUG] %s", buffer);
}

// **************************************************
// SMLib Functions (thanks to berni)
// **************************************************
/**
 * Prints white text to the right-center side of the screen
 * for one client. Does not work in all games.
 * Line Breaks can be done with "\n".
 *
 * @param client		Client Index.
 * @param format		Formatting rules.
 * @param ...			Variable number of format parameters.
 * @return				True on success, false if this usermessage doesn't exist.
 *
*stock bool:Client_PrintKeyHintText(client, const String:format[], any:...)
*{
*	if (IsCSGO)
*	{
*		return false;
*	}
*
*	new Handle:userMessage = StartMessageOne("KeyHintText", client);
*
*	if (userMessage == INVALID_HANDLE)
*	{
*		return false;
*	}
*
*	decl String:buffer[MAX_BUFFER_LENGTH];
*	buffer[0] = '\0';
*
*	SetGlobalTransTarget(client);
*	
*	VFormat(buffer, sizeof(buffer), format, 3);
*	CRemoveTags(buffer, sizeof(buffer));
*
*	if (GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available
*		&& GetUserMessageType() == UM_Protobuf)
*	{
*		PbSetString(userMessage, "hints", format);
*	}
*	else
*	{
*		BfWriteByte(userMessage, 1);
*		BfWriteString(userMessage, buffer);
*	}
*
*	EndMessage();
*
*	return true;
*}
**/
/**
 * Prints white text to the right-center side of the screen
 * for all clients. Does not work in all games.
 * Line Breaks can be done with "\n".
 *
 * @param format		Formatting rules.
 * @param ...			Variable number of format parameters.
 * @noreturn
 *
*stock Client_PrintKeyHintTextToAll(const String:format[], any:...)
*{
*	decl String:buffer[254];
*	buffer[0] = '\0';
*
*	for (new client=1; client <= MaxClients; client++)
*	{
*
*		if (!IsClientInGame(client))
*		{
*			continue;
*		}
*
*		SetGlobalTransTarget(client);
*		VFormat(buffer, sizeof(buffer), format, 2);
*		Client_PrintKeyHintText(client, buffer);
*	}
*}
**/