using PokemonGo.Camera;
using PokemonGo.Core;
using PokemonGo.GIS;
using PokemonGo.GPS;
using PokemonGo.Rendering;
using PokemonGo.Streaming;
using PokemonGo.Terrain;
using PokemonGo.VectorTiles;
using UnityEngine;

namespace PokemonGo.Bootstrap
{
    /// <summary>
    /// Single static entry point that wires every concrete service into the
    /// <see cref="ServiceLocator"/>. Lives in the Bootstrap assembly so it
    /// can freely reference every subsystem without forcing Core to know
    /// about them. Registers itself with <see cref="EngineRuntime"/> at
    /// load time.
    /// </summary>
    public static class EngineBootstrap
    {
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
        private static void InstallRegistrar()
        {
            EngineRuntime.ServiceRegistrar = RegisterServices;
        }

        public static void RegisterServices(EngineBootContext ctx)
        {
            var loc = ServiceLocator.Instance;

            // Foundation -------------------------------------------------------
            loc.Register<ICoordinateService>(new CoordinateService(ctx.Settings));
            loc.Register<IEventBus>(new EventBus());

            // Networking + decoding -------------------------------------------
            loc.Register<ITileDownloader>(new HttpTileDownloader(ctx.Settings));
            loc.Register<ITileCache>(new HybridTileCache(ctx.Settings));
            loc.Register<IVectorTileDecoder>(new MapboxVectorTileDecoder());

            // World streaming --------------------------------------------------
            loc.Register<IMaterialLibrary>(new MaterialLibrary(ctx.Settings));
            loc.Register<IMeshPool>(new MeshPool());
            loc.Register<ITerrainBuilder>(new TerrainBuilder(ctx.Settings));
            loc.Register<IChunkManager>(new ChunkManager(ctx.Settings, ctx.Root.transform));
            loc.Register<ITileStreamer>(new TileStreamer(ctx.Settings));

            // Player I/O -------------------------------------------------------
            if (ctx.Settings.useSimulatedGPS)
                loc.Register<IGpsService>(new SimulatedGpsService(ctx.Settings));
            else
                loc.Register<IGpsService>(new DeviceGpsService(ctx.Settings));

            loc.Register<IMapCameraService>(new MapCameraService(ctx.Settings));

            // Stylization / time-of-day ---------------------------------------
            loc.Register<IAtmosphereService>(new AtmosphereService(ctx.Settings));
        }
    }
}
