#include <sourcemod>
#include <sdktools>

#define PLUGIN_AUTHOR "Leeson, BallGanda"
#define PLUGIN_VERSION "2.00"

#pragma semicolon 1
#pragma newdecls required

EngineVersion g_Game;
bool holiday;
ConVar g_CvarNoGifts = null;

public Plugin myinfo =  {
	name = "Gift Grab Achievement Fix",
	author = PLUGIN_AUTHOR,
	description = "Enables gift drops. Picked up drops will count towards the Gift Grab achievement.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Ballganda/GiftGrab"
};

public void OnPluginStart() {
	g_Game = GetEngineVersion();
    g_CvarNoGifts = FindConVar("mp_holiday_nogifts");
    if (g_CvarNoGifts == null)
    {
    SetFailState("Required cvar mp_holiday_nogifts not found");
    }
    
	if (g_Game != Engine_CSS) {
		SetFailState("This plugin is for CSS only.");	
	}
	
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("christmas_gift_grab", Event_GiftGrab);
	
	PrintToServer("[Gift Grab] Plugin Loaded");
}

public void OnMapStart() {
	char month[30];
	char dayOfYear[30];
	FormatTime(month, sizeof(month), "%b", GetTime());
	FormatTime(dayOfYear, sizeof(dayOfYear), "%j", GetTime());
	int day = StringToInt(dayOfYear);

	if ((strcmp(month, "Dec") == 0) || day == 1) {
		PrintToServer("[Gift Grab] Holiday Active");
		holiday = true;
	} else {
		PrintToServer("[Gift Grab] Holiday Inactive");
		holiday = false;
	}
}

public void OnMapEnd() {
	holiday = false;
}

public bool IsHolidayActive() {
	return holiday;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	// Fast reject: not holiday
	if (!IsHolidayActive()){
		return;
    }
	// Fast reject: gifts disabled
	if (g_CvarNoGifts.BoolValue){
		return;
    }
    // Fast reject: not selected by drop percent
    if (GetRandomInt(1, 100) > 20){
		return;
    }
	int client = GetClientOfUserId(event.GetInt("userid"));

    //Check for valid client
    if (client <= 0 || !IsClientInGame(client)){
		return;
    }
	float deathPos[3];
	GetClientAbsOrigin(client, deathPos);
    SpawnGift(deathPos);
}

public void Event_GiftGrab(Event event, const char[] name, bool dontBroadcast) {
	if (IsHolidayActive()) {
		int userid = event.GetInt("userid");
		int client = GetClientOfUserId(userid);
        
        if (client <= 0 || !IsClientInGame(client))
            return;
		
		Handle bf = StartMessageOne("AchievementEvent", client, USERMSG_RELIABLE);
		BfWriteNum(bf, 5039);
		EndMessage();
	}
}

public void SpawnGift(float position[3])
{
    int gift = CreateEntityByName("holiday_gift");
    if (gift == -1)
        return;

    float start[3];
    float end[3];
    float ground[3];

    start[0] = position[0];
    start[1] = position[1];
    start[2] = position[2] + 32.0;

    end[0] = position[0];
    end[1] = position[1];
    end[2] = position[2] - 2048.0;

    TR_TraceRayFilter(start, end, MASK_SOLID, RayType_EndPoint, TraceFilter_WorldOnly, 0);

    if (TR_DidHit())
    {
        TR_GetEndPosition(ground);
    }
    else
    {
        ground[0] = position[0];
        ground[1] = position[1];
        ground[2] = position[2];
    }

    // Hover height
    ground[2] += 18.0;

    DispatchSpawn(gift);
    TeleportEntity(gift, ground, NULL_VECTOR, NULL_VECTOR);

    // Freeze so it never sinks
    SetEntityMoveType(gift, MOVETYPE_NONE);

    // Spin via timer (spam-free)
    CreateTimer(0.05, Timer_SpinGift, EntIndexToEntRef(gift),
        TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}


public Action Timer_SpinGift(Handle timer, any ref)
{
    int ent = EntRefToEntIndex(ref);
    if (ent == INVALID_ENT_REFERENCE)
        return Plugin_Stop;

    float ang[3];
    GetEntPropVector(ent, Prop_Data, "m_angRotation", ang);

    ang[1] += 10.0; // degrees per tick (0.05s). 10 = 200 deg/sec
    if (ang[1] >= 360.0)
        ang[1] -= 360.0;

    TeleportEntity(ent, NULL_VECTOR, ang, NULL_VECTOR);
    return Plugin_Continue;
}

public bool TraceFilter_WorldOnly(int entity, int contentsMask, any data)
{
    // Only collide with world (ignore entities)
    return (entity == 0);
}
