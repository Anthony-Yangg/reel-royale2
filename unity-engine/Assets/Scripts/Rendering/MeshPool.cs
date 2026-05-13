using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using PokemonGo.Core;
using UnityEngine;

namespace PokemonGo.Rendering
{
    public sealed class MeshPool : IMeshPool
    {
        public string ServiceName => "MeshPool";
        public int InitOrder => -360;

        private readonly Stack<Mesh> _meshes = new(128);
        private readonly Stack<MeshData> _datas = new(64);
        private int _live;

        public int LiveMeshes => _live;
        public int PooledMeshes => _meshes.Count;

        public Task InitializeAsync(CancellationToken ct) => Task.CompletedTask;
        public void OnAllServicesReady() { }

        public Mesh RentMesh()
        {
            _live++;
            if (_meshes.Count > 0)
            {
                var m = _meshes.Pop();
                m.Clear();
                return m;
            }
            return new Mesh { name = "ChunkMesh", indexFormat = UnityEngine.Rendering.IndexFormat.UInt32 };
        }

        public void ReturnMesh(Mesh mesh)
        {
            if (mesh == null) return;
            _live--;
            mesh.Clear();
            _meshes.Push(mesh);
        }

        public MeshData RentMeshData()
        {
            if (_datas.Count > 0)
            {
                var d = _datas.Pop(); d.Clear(); return d;
            }
            return new MeshData();
        }

        public void ReturnMeshData(MeshData data)
        {
            if (data == null) return;
            data.Clear();
            _datas.Push(data);
        }

        public void Dispose()
        {
            while (_meshes.Count > 0) Object.Destroy(_meshes.Pop());
            _datas.Clear();
        }
    }
}
