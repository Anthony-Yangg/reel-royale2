using System;
using System.Diagnostics;
using Unity.Jobs;

namespace PokemonGo.Jobs
{
    /// <summary>
    /// Tiny helper that drains a list of in-flight <see cref="JobHandle"/>s
    /// while respecting a per-frame millisecond budget. Used by terrain
    /// generation hot paths to keep mobile frame times consistent.
    /// </summary>
    public struct JobBudget
    {
        private Stopwatch _sw;
        public float BudgetMs;

        public static JobBudget New(float budgetMs)
            => new() { BudgetMs = budgetMs, _sw = Stopwatch.StartNew() };

        public bool Exceeded => _sw != null && _sw.ElapsedMilliseconds >= BudgetMs;

        public void Complete(ref JobHandle handle)
        {
            handle.Complete();
        }

        public bool TryFlush(ref JobHandle handle)
        {
            if (Exceeded) { handle.Complete(); return false; }
            if (handle.IsCompleted) { handle.Complete(); return true; }
            return true;
        }
    }
}
