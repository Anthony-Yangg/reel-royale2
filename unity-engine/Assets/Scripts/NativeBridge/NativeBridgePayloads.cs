using System;
using UnityEngine;

namespace PokemonGo.NativeBridge
{
    // ---------------------------------------------------------------------
    // Wire format shared with the iOS Swift host.
    //
    // Unity's built-in JsonUtility is the cheapest deserializer that ships
    // with the engine; it does not support polymorphism or top-level arrays,
    // so every payload below uses a wrapper object even for collections.
    //
    // Field names match the Swift encoder exactly. Do not rename without
    // updating ReelRoyale/Bridges/UnityBridge/UnityMessages.swift.
    // ---------------------------------------------------------------------

    [Serializable]
    public struct PlayerPositionPayload
    {
        public double lat;
        public double lng;
        public float headingDeg;
        public float speedMps;
        public float accuracyM;
    }

    [Serializable]
    public struct SpotPayload
    {
        public string id;
        public string name;
        public double lat;
        public double lng;
        public string kingId;        // empty string == vacant
        public string kingColorHex;  // "#RRGGBB", empty when vacant
        public bool isCurrentUserKing;
        public int crowns;
    }

    [Serializable]
    public struct SpotsPayload
    {
        public SpotPayload[] spots;
    }

    [Serializable]
    public struct RegionVertex
    {
        public double lat;
        public double lng;
    }

    [Serializable]
    public struct RegionPayload
    {
        public string id;
        public string name;
        public string rulerId;
        public string rulerColorHex;
        public bool isCurrentUserRuler;
        public bool isVacant;
        public RegionVertex[] polygon;
    }

    [Serializable]
    public struct RegionsPayload
    {
        public RegionPayload[] regions;
    }

    [Serializable]
    public struct UserPayload
    {
        public string userId;
        public string userColorHex;
    }

    [Serializable]
    public struct RecenterPayload
    {
        public bool animate;
    }
}
