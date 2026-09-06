#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

public Plugin myinfo =
{
	name        = "AxialBevelRemover",
	author      = "Lojka",
	description = "Removes axial bevels which break brush collision",
	version     = "1.0.0",
	url         = "https://github.com/L0jk4/AxialBevelRemover"
};

#define GAMEDATA_FILE		"AxialBevelRemover.games"

// ---------------------------------------------------------------------
// Offsets - loaded once from gamedata at startup
// ---------------------------------------------------------------------

enum struct Offsets
{
	// cplane_t
	int CPlane_normal;

	// cbrushside_t
	int CBrushSide_plane;
	int CBrushSide_surfaceIndex;
	int CBrushSide_bBevel;
	int CBrushSide_size;

	// cbrush_t
	int CBrush_contents;
	int CBrush_numsides;
	int CBrush_firstbrushside;
	int CBrush_size;

	// CCollisionBSPData
	int CCollisionBSPData_numbrushes;
	int CCollisionBSPData_map_brushes;
	int CCollisionBSPData_map_brushsides;

	void Load(GameData hGameData)
	{
		this.CPlane_normal              = this.Fetch(hGameData, "CPlane::normal");

		this.CBrushSide_plane           = this.Fetch(hGameData, "CBrushSide::plane");
		this.CBrushSide_surfaceIndex    = this.Fetch(hGameData, "CBrushSide::surfaceIndex");
		this.CBrushSide_bBevel          = this.Fetch(hGameData, "CBrushSide::bBevel");
		this.CBrushSide_size            = this.Fetch(hGameData, "CBrushSide::size");

		this.CBrush_contents            = this.Fetch(hGameData, "CBrush::contents");
		this.CBrush_numsides            = this.Fetch(hGameData, "CBrush::numsides");
		this.CBrush_firstbrushside      = this.Fetch(hGameData, "CBrush::firstbrushside");
		this.CBrush_size                = this.Fetch(hGameData, "CBrush::size");

		this.CCollisionBSPData_numbrushes      = this.Fetch(hGameData, "CCollisionBSPData::numbrushes");
		this.CCollisionBSPData_map_brushes     = this.Fetch(hGameData, "CCollisionBSPData::map_brushes");
		this.CCollisionBSPData_map_brushsides  = this.Fetch(hGameData, "CCollisionBSPData::map_brushsides");
	}

	int Fetch(GameData hGameData, const char[] key)
	{
		int value = hGameData.GetOffset(key);
		if (value == -1)
		{
			SetFailState("AxialBevelRemover: missing offset \"%s\" in gamedata", key);
		}
		return value;
	}
}

Offsets g_Offsets;

// ---------------------------------------------------------------------
// Base wrapper
// ---------------------------------------------------------------------

methodmap MemStruct
{
	public MemStruct(Address addr)
	{
		return view_as<MemStruct>(addr);
	}

	property Address Address
	{
		public get() { return view_as<Address>(this); }
	}

	property bool IsValid
	{
		public get() { return view_as<Address>(this) != Address_Null; }
	}
}

// ---------------------------------------------------------------------
// cplane_t
// ---------------------------------------------------------------------

methodmap CPlane < MemStruct
{
	public CPlane(Address addr)
	{
		return view_as<CPlane>(addr);
	}

	property float normal_x
	{
		public get() { return view_as<float>(LoadFromAddress(this.Address + view_as<Address>(g_Offsets.CPlane_normal + 0), NumberType_Int32)); }
		public set(float value) { StoreToAddress(this.Address + view_as<Address>(g_Offsets.CPlane_normal + 0), view_as<int>(value), NumberType_Int32); }
	}

	property float normal_y
	{
		public get() { return view_as<float>(LoadFromAddress(this.Address + view_as<Address>(g_Offsets.CPlane_normal + 4), NumberType_Int32)); }
		public set(float value) { StoreToAddress(this.Address + view_as<Address>(g_Offsets.CPlane_normal + 4), view_as<int>(value), NumberType_Int32); }
	}

	property float normal_z
	{
		public get() { return view_as<float>(LoadFromAddress(this.Address + view_as<Address>(g_Offsets.CPlane_normal + 8), NumberType_Int32)); }
		public set(float value) { StoreToAddress(this.Address + view_as<Address>(g_Offsets.CPlane_normal + 8), view_as<int>(value), NumberType_Int32); }
	}

	public bool IsAxial()
	{
		if (!this.IsValid)
		{
			return false;
		}

		float x = this.normal_x, y = this.normal_y, z = this.normal_z;
		return (x == 1.0 || x == -1.0 || 
                y == 1.0 || y == -1.0 || 
                z == 1.0 || z == -1.0);
	}
}

// ---------------------------------------------------------------------
// cbrushside_t
// ---------------------------------------------------------------------

methodmap CBrushSide < MemStruct
{
	public CBrushSide(Address addr)
	{
		return view_as<CBrushSide>(addr);
	}

	property CPlane plane
	{
		public get() { return view_as<CPlane>(LoadFromAddress(this.Address + view_as<Address>(g_Offsets.CBrushSide_plane), NumberType_Int32)); }
		public set(CPlane value) { StoreToAddress(this.Address + view_as<Address>(g_Offsets.CBrushSide_plane), view_as<int>(value), NumberType_Int32); }
	}

	property int surfaceIndex
	{
		public get() { return LoadFromAddress(this.Address + view_as<Address>(g_Offsets.CBrushSide_surfaceIndex), NumberType_Int16) & 0xFFFF; }
		public set(int value) { StoreToAddress(this.Address + view_as<Address>(g_Offsets.CBrushSide_surfaceIndex), value, NumberType_Int16); }
	}

	property int bBevel
	{
		public get() { return LoadFromAddress(this.Address + view_as<Address>(g_Offsets.CBrushSide_bBevel), NumberType_Int16) & 0xFFFF; }
		public set(int value) { StoreToAddress(this.Address + view_as<Address>(g_Offsets.CBrushSide_bBevel), value, NumberType_Int16); }
	}

	public void CopyFrom(CBrushSide other)
	{
		this.plane        = other.plane;
		this.surfaceIndex = other.surfaceIndex;
		this.bBevel       = other.bBevel;
	}
}

// ---------------------------------------------------------------------
// cbrush_t
// ---------------------------------------------------------------------

#define NUMSIDES_BOXBRUSH	0xFFFF
methodmap CBrush < MemStruct
{
	public CBrush(Address addr)
	{
		return view_as<CBrush>(addr);
	}

	property int contents
	{
		public get() { return LoadFromAddress(this.Address + view_as<Address>(g_Offsets.CBrush_contents), NumberType_Int32); }
		public set(int value) { StoreToAddress(this.Address + view_as<Address>(g_Offsets.CBrush_contents), value, NumberType_Int32); }
	}

	property int numsides
	{
		public get() { return LoadFromAddress(this.Address + view_as<Address>(g_Offsets.CBrush_numsides), NumberType_Int16) & 0xFFFF; }
		public set(int value) { StoreToAddress(this.Address + view_as<Address>(g_Offsets.CBrush_numsides), value, NumberType_Int16); }
	}

	property int firstbrushside
	{
		public get() { return LoadFromAddress(this.Address + view_as<Address>(g_Offsets.CBrush_firstbrushside), NumberType_Int16) & 0xFFFF; }
		public set(int value) { StoreToAddress(this.Address + view_as<Address>(g_Offsets.CBrush_firstbrushside), value, NumberType_Int16); }
	}

	public bool IsBox()
	{
		return this.numsides == NUMSIDES_BOXBRUSH;
	}

	public int GetBox()
	{
		return this.firstbrushside;
	}

	public void SetBox(int boxID)
	{
		this.numsides = NUMSIDES_BOXBRUSH;
		this.firstbrushside = boxID;
	}
}

// ---------------------------------------------------------------------
// CCollisionBSPData
// ---------------------------------------------------------------------

methodmap CCollisionBSPData < MemStruct
{
	public CCollisionBSPData(Address addr)
	{
		return view_as<CCollisionBSPData>(addr);
	}

	property Address map_brushsides
	{
		public get() { return view_as<Address>(LoadFromAddress(this.Address + view_as<Address>(g_Offsets.CCollisionBSPData_map_brushsides), NumberType_Int32)); }
	}

	property int numbrushes
	{
		public get() { return LoadFromAddress(this.Address + view_as<Address>(g_Offsets.CCollisionBSPData_numbrushes), NumberType_Int32); }
	}

	property Address map_brushes
	{
		public get() { return view_as<Address>(LoadFromAddress(this.Address + view_as<Address>(g_Offsets.CCollisionBSPData_map_brushes), NumberType_Int32)); }
	}


	public CBrush GetBrush(int index)
	{
		return view_as<CBrush>(this.map_brushes + view_as<Address>(index * g_Offsets.CBrush_size));
	}

	public CBrushSide GetBrushSide(int index)
	{
		return view_as<CBrushSide>(this.map_brushsides + view_as<Address>(index * g_Offsets.CBrushSide_size));
	}
}

// ---------------------------------------------------------------------
// Plugin
// ---------------------------------------------------------------------

CCollisionBSPData g_BSPData = view_as<CCollisionBSPData>(Address_Null);

public void OnPluginStart()
{
    GameData hGameData = new GameData(GAMEDATA_FILE);
	if (hGameData == null)
	{
	    delete hGameData;
		SetFailState("AxialBevelRemover: could not read gamedata file \"%s.txt\"", GAMEDATA_FILE);
	}

    g_BSPData = view_as<CCollisionBSPData>(hGameData.GetAddress("g_BSPData"));
	if (!g_BSPData.IsValid)
	{
        delete hGameData;
		SetFailState("AxialBevelRemover: failed to resolve g_BSPData address");
	}

	g_Offsets.Load(hGameData);
    delete hGameData;
    
	RemoveAxialBevels(); // covers lateload
}

public void OnMapStart()
{
	RemoveAxialBevels();
}

void RemoveAxialBevels()
{
	int numBrushes = g_BSPData.numbrushes;
	int brushesPatched = 0;

     // "remove" axial bevels by overriding map_brushsides array and decreasing numsides
	for (int i = 0; i < numBrushes; i++)
	{
		CBrush brush = g_BSPData.GetBrush(i);

		if (brush.IsBox()) continue;

		int numSides = brush.numsides;
		if (numSides <= 6) continue;

		int firstSideIndex  = brush.firstbrushside;

        // first 6 sides are axial
		int sidesKept  = 6;
		int writeIndex = firstSideIndex + 6;
		bool patched = false;

		for (int readIndex = firstSideIndex + 6; readIndex < firstSideIndex + numSides; readIndex++)
		{
			CBrushSide side = g_BSPData.GetBrushSide(readIndex);

			if (side.bBevel == 0 || !side.plane.IsAxial())
			{
				if (writeIndex != readIndex)
					g_BSPData.GetBrushSide(writeIndex).CopyFrom(side);
				writeIndex++;
				sidesKept++;
			}
			else // skip: axial bevel
			{
				patched = true;
			}
            
		}
		brush.numsides = sidesKept;

		if (patched) brushesPatched++;
	}

	LogMessage("AxialBevelRemover: scanned %d brushes, modified %d", numBrushes, brushesPatched);
}