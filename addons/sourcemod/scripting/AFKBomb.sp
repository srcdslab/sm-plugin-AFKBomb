/**
	Credits :
	dalto - botdropbomb plugin for drop bomb code
	http://forums.alliedmods.net/showthread.php?p=523188

	AltPluzF4 - for sig-scanning thread which helped me correct the sdk-call crash problem in botdropbomb plugin
	http://forums.alliedmods.net/archive/index.php/t-78309.html

	AtomicStryker - for having in the past the same problem as me and posting in forums :
	http://forums.alliedmods.net/showthread.php?t=121145

	Dr!fter - for his 2nd sig-function that help me get this to work with CSS:DM
	http://forums.alliedmods.net/showthread.php?t=153765
	https://bugs.alliedmods.net/show_bug.cgi?id=4732 (his bug report)
	for 1.3.1 --> 4th & 5th argument to true --> drop bomb further (weapon restrict plugin)

	psychonic for telling me about my memory leak

	Testers : sinblaster (CSS:DM bug report)

	for 1.4.2 : Whole Sourcemod crew  --> no more need for SDKCall since SM 1.4.0; so no more gamedata needed
*/
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <cstrike>

#define PLUGIN_VERSION "1.5.1-srcdslab"

public Plugin myinfo =
{
	name = "Afk Bomb",
	author = "RedSword / Bob Le Ponge, .Rushaway",
	description = "Drop the bomb if the player appears afk. Also possible to give to a random T since 1.4.0.",
	version = PLUGIN_VERSION,
	url = "https://github.com/srcdslab/sm-plugin-AFKBomb"
};

//Cvars
ConVar g_afkBomb;
ConVar g_afkBomb_addFreeze;
ConVar g_afkBomb_action;

ConVar g_afkBomb_displayMsg;

ConVar g_afkBomb_lateCheckNumber; // 0 = late check disabled
ConVar g_afkBomb_lateCheckDelay; // 0 = late check disabled
ConVar g_afkBomb_lateCheckAction; //since 1.5; 1=drop, 0=givetorandomT

ConVar g_cvFreezeTime;

//Round number
//Avoid a possible (rare) glitch where the same player would spawn with the bomb at the same place with a high CVar "afkbomb" value
int g_roundNumber = 0;

//Tons of information to compare to see if bomber is afk
int g_bombId; //Seems dumb to keep id but another player might respawn exactly at the same spot
int g_bombMoney;
int g_bombArmor;
int g_bombGuns[ 4 ]; // GetPlayerWeaponSlot()
int g_bombButtons;
float g_bombEye[ 3 ]; // bool:GetClientEyeAngles()
float g_bombAngle[ 3 ]; // GetClientAbsAngles()
float g_bombOrigin[ 3 ]; // GetClientAbsOrigin()
float g_bombVelocity[ 3 ]; // GetEntPropVector()

//Prevent re-running a function
int g_iAccount;
int g_iVelocityOffset;

//Only msg once for dropping bomb
bool g_shouldMsgBombDrop;

//If the first drop si the next one(to change delay things)
bool g_firstBombDrop;

//To count the number of check done for lateCheck
int g_lateCheckCount;

public void OnPluginStart()
{
	//CVARs
	CreateConVar( "afkbombversion", PLUGIN_VERSION, "Afk Bomb version", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD );

	g_afkBomb = CreateConVar( "afkbomb", "2", "How long will it takes before the afk drop the bomb, in seconds. 0 = disabled, 1+ = enabled. Def. 2.",
		FCVAR_NOTIFY, true, 0.0 );
	g_afkBomb_addFreeze = CreateConVar( "afkbomb_freezetime", "0", "If mp_freezetime value is added to the time before bomb drop. 0 = no, 1 = yes. Def. 0.",
		FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_afkBomb_action = CreateConVar( "afkbomb_action", "0",
	"What to do when someone is considered afk at the beginning of a round. 1=Drop. 0=Give to random player. Def. 0.",
		FCVAR_NOTIFY, true, 0.0, true, 1.0 );

	g_afkBomb_displayMsg = CreateConVar( "afkbomb_msg", "1",
		"Notify team when bomb is dropped (action or latecheckaction = 1) / Notify everyone when bomb is given to a random terrorist (action or latecheckaction = 0). 0 = no, 1 = yes. Def. 1.",
		FCVAR_NOTIFY, true, 0.0, true, 1.0 );

	g_afkBomb_lateCheckNumber = CreateConVar( "afkbomb_latecheck", "2", "Number of latechecks to do before dropping the bomb. 0 = disabled. Def. 2.",
		FCVAR_NOTIFY, true, 0.0 );
	g_afkBomb_lateCheckDelay = CreateConVar( "afkbomb_latecheckdelay", "5.0", "Time between 2 latechecks to drop the bomb, in seconds. Min. 1. Def. 5.",
		FCVAR_NOTIFY, true, 1.0 );
	g_afkBomb_lateCheckAction = CreateConVar( "afkbomb_latecheckaction", "1",
	"What to do when someone is considered afk after the beginning of a round. 1=Drop. 0=Give to random player (not recommended since it could be exploited). Def. 1.",
		FCVAR_NOTIFY, true, 0.0, true, 1.0 );

	AutoExecConfig( true, "afkbomb" );

	g_cvFreezeTime = FindConVar( "mp_freezetime" );

	//Hooks on events
	HookEvent( "round_start", Event_RoundStart );

	//Translation file
	LoadTranslations( "AFKBomb.phrases" );

	//Prevent re-running a function
	g_iAccount = FindSendPropInfo( "CCSPlayer", "m_iAccount" );
	g_iVelocityOffset = FindSendPropInfo("CBasePlayer", "m_vecVelocity[0]");
}

public void Event_RoundStart( Event event, const char[] name, bool dontBroadcast )
{
	if ( g_afkBomb.IntValue >= 1 )
	{
		++g_roundNumber;
		g_firstBombDrop = true;

		CreateTimer( 1.0, CheckForBomber, g_roundNumber, TIMER_FLAG_NO_MAPCHANGE );
	}
}

//Check who has the bomb; Needs to be delayed to work
public Action CheckForBomber( Handle timer, any roundNumber )
{
	//Avoid 2 timers identical
	if ( roundNumber != g_roundNumber )
		return Plugin_Stop;

	//If we're to look for the bomber, that means he's not found yet and that he won't repeat his speech
	g_shouldMsgBombDrop = true;
	g_lateCheckCount = 0;

	for ( int i = MaxClients; i >= 1; --i )
	{
		if ( IsClientInGame( i ) &&
				IsPlayerAlive( i ) &&
				GetPlayerWeaponSlot( i, 4 ) != -1 ) //if the player is carrying the bomb
		{
			FirstScan( i );
			return Plugin_Stop; //We found the bomber, no need to rerun the function
		}
	}

	//We rerun the function if not found
	if ( g_afkBomb_lateCheckNumber.IntValue > 0 )
	{
		g_firstBombDrop = false;
		CreateTimer( g_afkBomb_lateCheckDelay.FloatValue, CheckForBomber, roundNumber, TIMER_FLAG_NO_MAPCHANGE );
	}

	return Plugin_Stop;
}

//Record bomber initial state
void FirstScan( int iBomber )
{
	if ( g_afkBomb.IntValue >= 1 )
	{
		//We consider that by default, we're late-checking
		float timeUntilScan = g_afkBomb_lateCheckDelay.FloatValue;

		if ( g_firstBombDrop ) //If we're not late-checking
		{
			timeUntilScan = g_afkBomb.FloatValue;

			if ( g_afkBomb_addFreeze.IntValue == 1 && g_cvFreezeTime != null )
				timeUntilScan += g_cvFreezeTime.FloatValue;
		}

		getState( iBomber ); //Save state (various stats in globals)

		DataPack bombUserIdAndRoundNumberData; //CreateDataPack() not needed !!
		CreateDataTimer( timeUntilScan, SecondScan, bombUserIdAndRoundNumberData, TIMER_FLAG_NO_MAPCHANGE );
		bombUserIdAndRoundNumberData.WriteCell( GetClientUserId( iBomber ) );
		bombUserIdAndRoundNumberData.WriteCell( g_roundNumber );
	}
}

//Check if bomber's state changed
public Action SecondScan( Handle timer, DataPack bombUserIdAndRoundNumberData ) //UserId used to prevent a possible problem if someone would leave and take bomber's "state" within 0.5 sec (lol)
{
	//Using the pack right now so it's cleaner to read the rest of the code
	bombUserIdAndRoundNumberData.Reset();
	int bomberUserId = bombUserIdAndRoundNumberData.ReadCell();
	int roundNumber = bombUserIdAndRoundNumberData.ReadCell();

	float lateCheckDelay = g_afkBomb_lateCheckDelay.FloatValue;

	int iBomber = GetClientOfUserId( bomberUserId );

	if ( g_roundNumber == roundNumber ) //If we're in the same round
	{
		if ( iBomber != 0 && //Prevent a disconnecting player between first & second scan
				IsClientInGame( iBomber ) &&
				IsPlayerAlive( iBomber ) &&
				sameState( iBomber ) ) //state changed ?
		{
			if ( g_firstBombDrop || ++g_lateCheckCount >= g_afkBomb_lateCheckNumber.IntValue )
			{
				//Starts 1.5 changes
				if ( ( g_firstBombDrop && g_afkBomb_action.IntValue == 1 ) ||
						( !g_firstBombDrop && g_afkBomb_lateCheckAction.IntValue == 1 ) )
				{
					CS_DropWeapon( iBomber, GetPlayerWeaponSlot( iBomber, 4 ), true, true );
				}
				else
				{
					stripAndGive2RandomTBomb( iBomber ); //The function takes care of its own verbose
					CheckForBomber( null, roundNumber ); //lets start next check right now
					return Plugin_Stop; //no latecheck problem are possible so

				}
				//End 1.5 changes
				lateCheckDelay = 1.5;

				if ( g_shouldMsgBombDrop ) //Do not repeat !
				{
					if ( g_afkBomb_displayMsg.IntValue == 1 )
					{
						FakeClientCommand( iBomber, "say_team [Afk Bomb] %t", "Drop Bomb" );
					}
					g_shouldMsgBombDrop = false;
				}
			}
			//If we're latechecking, we must relaunch timer if the bomber is in the same state
			//Reusing the datapack
			DataPack newData;
			CreateDataTimer( lateCheckDelay, SecondScan, newData, TIMER_FLAG_NO_MAPCHANGE ); //if bomb is dropped then taken (happen sometimes; ex. de_dust T near the 3 boxes; may never end)
			newData.WriteCell( GetClientUserId( iBomber ) );
			newData.WriteCell( roundNumber );
		}
		else if ( g_afkBomb_lateCheckNumber.IntValue > 0 )//if bomber is lost, find him again (if we want to lateCheck)
		{
			g_firstBombDrop = false;
			CreateTimer( lateCheckDelay, CheckForBomber, roundNumber, TIMER_FLAG_NO_MAPCHANGE );
		}
	}

	return Plugin_Stop;
}

//========== Privates ===========

//===== 1fct
//return true if bomb was given to someone else (useless :$)
bool stripAndGive2RandomTBomb( int iOldBomber ) //Since 1.4.0 (Change 2/2) ; changed in 1.5 (priorize moving players)
{
	//1- Count Ts (exit if needed)
	int[] terrorists = new int[ MaxClients ];
	int[] movTerrorists = new int[ MaxClients ];
	int sizeT;
	int sizeMovT;

	float velocX; //no real need for Y & Z

	for ( int i = 1; i <= MaxClients; ++i )
	{
		if ( IsClientInGame( i ) &&
				GetClientTeam( i ) == CS_TEAM_T &&
				IsPlayerAlive( i ) &&
				i != iOldBomber )
		{
			terrorists[ sizeT++ ] = i;
			velocX = GetEntDataFloat( i, g_iVelocityOffset );
			if ( velocX != 0.0 )
			{
				movTerrorists[ sizeMovT++ ] = i;
			}
		}
	}

	if ( sizeT == 0 )
		return false;

	//2- Strip c4
	char sClassName[ MAX_NAME_LENGTH ];

	int iEntIndex = GetPlayerWeaponSlot( iOldBomber, 4 );

	if ( iEntIndex != -1 )
	{
		GetEdictClassname( iEntIndex, sClassName, sizeof(sClassName) );
		if ( StrEqual( sClassName, "weapon_c4", false ) )
		{
			RemovePlayerItem( iOldBomber, iEntIndex );
			AcceptEntityInput( iEntIndex, "kill" );
		}
	}

	//3- Get Random T and give
	if ( sizeMovT > 0 ) //priorize moving players
	{
		GivePlayerItem( movTerrorists[ GetRandomInt( 0, sizeMovT - 1 ) ], "weapon_c4" );
	}
	else
	{
		GivePlayerItem( terrorists[ GetRandomInt( 0, sizeT - 1 ) ], "weapon_c4" );
	}

	//4- Verbose
	if ( g_afkBomb_displayMsg.IntValue == 1 )
	{
		PrintToChatAll( "\x04[SM] \x01%t", "StripNGive Bomb", "\x04", iOldBomber, "\x01" );
	}

	return true;
}

//=====State-related

//Put state in global vars
void getState( int iClient, bool lateCheck=false )
{
	//Cid
	g_bombId = iClient;

	if ( !lateCheck )
	{
		//Money
		g_bombMoney = GetEntData( iClient, g_iAccount );

		//Armor
		g_bombArmor = GetClientArmor( iClient );

		//Buttons pressed
		g_bombButtons = GetClientButtons( iClient );
	}

	//Guns
	for ( int i = 3; i >= 0; --i )
		g_bombGuns[ i ] = GetPlayerWeaponSlot( iClient, i + 1 );

	//Vectors
	GetClientEyeAngles( iClient, g_bombEye );
	GetClientAbsAngles( iClient, g_bombAngle );
	GetClientAbsOrigin( iClient, g_bombOrigin );
	GetEntPropVector( iClient, Prop_Data, "m_vecVelocity", g_bombVelocity );
}

//Compare current state from those in the global vars
bool sameState( int iClient, bool lateCheck=false )
{
	//Cid
	if ( g_bombId != iClient )
		return false;

	if ( !lateCheck )
	{
		//Money
		if ( g_bombMoney != GetEntData( iClient, g_iAccount ) )
			return false;

		//Armor
		if ( g_bombArmor != GetClientArmor( iClient ) )
			return false;

		//Buttons pressed
		if ( g_bombButtons != GetClientButtons( iClient ) )
			return false;
	}

	//Guns
	for ( int i = 3; i >= 0; --i )
		if ( g_bombGuns[ i ] != GetPlayerWeaponSlot( iClient, i + 1 ) )
			return false;

	//Vectors
	float eyeVec[ 3 ];
	float absAngVec[ 3 ];
	float absOriVec[ 3 ];
	float absVloVec[ 3 ];
	GetClientEyeAngles( iClient, eyeVec );
	GetClientAbsAngles( iClient, absAngVec );
	GetClientAbsOrigin( iClient, absOriVec );
	GetEntPropVector( iClient, Prop_Data, "m_vecVelocity", absVloVec );

	for ( int i = 2; i >= 0; --i )
		if ( eyeVec[ i ] != g_bombEye[ i ] ||
				absAngVec[ i ] != g_bombAngle[ i ] ||
				absOriVec[ i ] != g_bombOrigin[ i ] ||
				absVloVec[ i ] != g_bombVelocity[ i ] )
			return false;

	return true;
}
