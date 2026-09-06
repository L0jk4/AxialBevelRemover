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
	int cplane_t__normal;

	int cbrushside_t__plane;
	int cbrushside_t__surfaceIndex;
	int cbrushside_t__bBevel;
	int cbrushside_t__size;

	int cbrush_t__contents;
	int cbrush_t__numsides;
	int cbrush_t__firstbrushside;
	int cbrush_t__size;

	int CCollisionBSPData__numbrushes;
	int CCollisionBSPData__map_brushes;
	int CCollisionBSPData__map_brushsides;

	void Load(GameData hGameData)
	{
		this.cplane_t__normal              = this.Fetch(hGameData, "cplane_t::normal");

		this.cbrushside_t__plane           = this.Fetch(hGameData, "cbrushside_t::plane");
		this.cbrushside_t__surfaceIndex    = this.Fetch(hGameData, "cbrushside_t::surfaceIndex");
		this.cbrushside_t__bBevel          = this.Fetch(hGameData, "cbrushside_t::bBevel");
		this.cbrushside_t__size            = this.Fetch(hGameData, "cbrushside_t::size");

		this.cbrush_t__contents            = this.Fetch(hGameData, "cbrush_t::contents");
		this.cbrush_t__numsides            = this.Fetch(hGameData, "cbrush_t::numsides");
		this.cbrush_t__firstbrushside      = this.Fetch(hGameData, "cbrush_t::firstbrushside");
		this.cbrush_t__size                = this.Fetch(hGameData, "cbrush_t::size");

		this.CCollisionBSPData__numbrushes      = this.Fetch(hGameData, "CCollisionBSPData::numbrushes");
		this.CCollisionBSPData__map_brushes     = this.Fetch(hGameData, "CCollisionBSPData::map_brushes");
		this.CCollisionBSPData__map_brushsides  = this.Fetch(hGameData, "CCollisionBSPData::map_brushsides");
	}

	int Fetch(GameData hGameData, const char[] key)
	{
		int value = hGameData.GetOffset(key);
		if (value == -1)
		{
			SetFailState("missing offset \"%s\" in gamedata", key);
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
// cplane_t_t
// ---------------------------------------------------------------------

methodmap M_cplane_t < MemStruct
{
	public M_cplane_t(Address addr)
	{
		return view_as<M_cplane_t>(addr);
	}

	property float normal_x
	{
		public get() { return view_as<float>(LoadFromAddress(this.Address + view_as<Address>(g_Offsets.cplane_t__normal + 0), NumberType_Int32)); }
		public set(float value) { StoreToAddress(this.Address + view_as<Address>(g_Offsets.cplane_t__normal + 0), view_as<int>(value), NumberType_Int32); }
	}

	property float normal_y
	{
		public get() { return view_as<float>(LoadFromAddress(this.Address + view_as<Address>(g_Offsets.cplane_t__normal + 4), NumberType_Int32)); }
		public set(float value) { StoreToAddress(this.Address + view_as<Address>(g_Offsets.cplane_t__normal + 4), view_as<int>(value), NumberType_Int32); }
	}

	property float normal_z
	{
		public get() { return view_as<float>(LoadFromAddress(this.Address + view_as<Address>(g_Offsets.cplane_t__normal + 8), NumberType_Int32)); }
		public set(float value) { StoreToAddress(this.Address + view_as<Address>(g_Offsets.cplane_t__normal + 8), view_as<int>(value), NumberType_Int32); }
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
// cbrushside_t_t
// ---------------------------------------------------------------------

methodmap M_cbrushside_t < MemStruct
{
	public M_cbrushside_t(Address addr)
	{
		return view_as<M_cbrushside_t>(addr);
	}

	property M_cplane_t plane
	{
		public get() { return view_as<M_cplane_t>(LoadFromAddress(this.Address + view_as<Address>(g_Offsets.cbrushside_t__plane), NumberType_Int32)); }
		public set(M_cplane_t value) { StoreToAddress(this.Address + view_as<Address>(g_Offsets.cbrushside_t__plane), view_as<int>(value), NumberType_Int32); }
	}

	property int surfaceIndex
	{
		public get() { return LoadFromAddress(this.Address + view_as<Address>(g_Offsets.cbrushside_t__surfaceIndex), NumberType_Int16) & 0xFFFF; }
		public set(int value) { StoreToAddress(this.Address + view_as<Address>(g_Offsets.cbrushside_t__surfaceIndex), value, NumberType_Int16); }
	}

	property bool bBevel
	{
		public get() { return LoadFromAddress(this.Address + view_as<Address>(g_Offsets.cbrushside_t__bBevel), NumberType_Int16) & 0xFFFF; }
		public set(bool value) { StoreToAddress(this.Address + view_as<Address>(g_Offsets.cbrushside_t__bBevel), value, NumberType_Int16); }
	}

	public void CopyFrom(M_cbrushside_t other)
	{
		this.plane        = other.plane;
		this.surfaceIndex = other.surfaceIndex;
		this.bBevel       = other.bBevel;
	}
}

// ---------------------------------------------------------------------
// cbrush_t__t
// ---------------------------------------------------------------------

#define NUMSIDES_BOXBRUSH	0xFFFF
methodmap M_cbrush_t < MemStruct
{
	public M_cbrush_t(Address addr)
	{
		return view_as<M_cbrush_t>(addr);
	}

	property int contents
	{
		public get() { return LoadFromAddress(this.Address + view_as<Address>(g_Offsets.cbrush_t__contents), NumberType_Int32); }
		public set(int value) { StoreToAddress(this.Address + view_as<Address>(g_Offsets.cbrush_t__contents), value, NumberType_Int32); }
	}

	property int numsides
	{
		public get() { return LoadFromAddress(this.Address + view_as<Address>(g_Offsets.cbrush_t__numsides), NumberType_Int16) & 0xFFFF; }
		public set(int value) { StoreToAddress(this.Address + view_as<Address>(g_Offsets.cbrush_t__numsides), value, NumberType_Int16); }
	}

	property int firstbrushside
	{
		public get() { return LoadFromAddress(this.Address + view_as<Address>(g_Offsets.cbrush_t__firstbrushside), NumberType_Int16) & 0xFFFF; }
		public set(int value) { StoreToAddress(this.Address + view_as<Address>(g_Offsets.cbrush_t__firstbrushside), value, NumberType_Int16); }
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
		public get() { return view_as<Address>(LoadFromAddress(this.Address + view_as<Address>(g_Offsets.CCollisionBSPData__map_brushsides), NumberType_Int32)); }
	}

	property int numbrushes
	{
		public get() { return LoadFromAddress(this.Address + view_as<Address>(g_Offsets.CCollisionBSPData__numbrushes), NumberType_Int32); }
	}

	property Address map_brushes
	{
		public get() { return view_as<Address>(LoadFromAddress(this.Address + view_as<Address>(g_Offsets.CCollisionBSPData__map_brushes), NumberType_Int32)); }
	}


	public M_cbrush_t GetBrush(int index)
	{
		return view_as<M_cbrush_t>(this.map_brushes + view_as<Address>(index * g_Offsets.cbrush_t__size));
	}

	public M_cbrushside_t GetBrushSide(int index)
	{
		return view_as<M_cbrushside_t>(this.map_brushsides + view_as<Address>(index * g_Offsets.cbrushside_t__size));
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
		SetFailState("could not read gamedata file \"%s.txt\"", GAMEDATA_FILE);
	}

    g_BSPData = view_as<CCollisionBSPData>(hGameData.GetAddress("g_BSPData"));
	if (!g_BSPData.IsValid)
	{
        delete hGameData;
		SetFailState("failed to resolve g_BSPData address");
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
		M_cbrush_t brush = g_BSPData.GetBrush(i);

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
			M_cbrushside_t side = g_BSPData.GetBrushSide(readIndex);

			if (side.bBevel && side.plane.IsAxial())
			{
				patched = true; // skip: axial bevel
			}
			else 
			{
				if (writeIndex != readIndex)
					g_BSPData.GetBrushSide(writeIndex).CopyFrom(side);
				writeIndex++;
				sidesKept++;
			}
            
		}
		brush.numsides = sidesKept;

		if (patched) brushesPatched++;
	}

	LogMessage("AxialBevelRemover: scanned %d brushes, modified %d", numBrushes, brushesPatched);
}