using PokemonGo.Core;
using PokemonGo.GIS;
using UnityEngine;

namespace PokemonGo.Camera
{
    /// <summary>
    /// High-level camera controller for the Pokémon-GO style isometric map view.
    /// Owns the camera rig, pivot, target lat/lng and gesture state.
    /// </summary>
    public interface IMapCameraService : IService, ITickable, ILateTickable
    {
        UnityEngine.Camera Camera { get; }
        Transform Pivot { get; }
        Transform Rig { get; }

        float TiltDegrees { get; set; }
        float YawDegrees { get; set; }
        float Distance { get; set; }

        GeoCoordinate TargetCoord { get; }
        void SetTarget(in GeoCoordinate coord, bool snap);
        void NudgePan(Vector2 worldDelta);
        void NudgeZoom(float multiplier);
        void NudgeRotate(float yawDelta);

        /// <summary>Set tracking source — when null, camera is free-pan only.</summary>
        void SetFollowTarget(Transform t);
    }
}
