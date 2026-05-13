using PokemonGo.Core;
using UnityEngine;

namespace PokemonGo.Rendering
{
    /// <summary>
    /// Pool for <see cref="Mesh"/> and <see cref="MeshData"/> instances.
    /// Reusing the underlying Mesh saves expensive GraphicsBuffer churn on
    /// mobile GPUs (each Mesh creation involves a Vulkan/Metal allocation).
    /// </summary>
    public interface IMeshPool : IService
    {
        Mesh RentMesh();
        void ReturnMesh(Mesh mesh);
        MeshData RentMeshData();
        void ReturnMeshData(MeshData data);
        int LiveMeshes { get; }
        int PooledMeshes { get; }
    }
}
