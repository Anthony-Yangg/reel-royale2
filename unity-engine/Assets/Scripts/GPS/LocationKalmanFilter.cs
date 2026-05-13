using System;
using UnityEngine;

namespace PokemonGo.GPS
{
    /// <summary>
    /// Simplified 1-D Kalman filter applied independently per axis. Tracks
    /// the position with an estimated uncertainty that grows over time and
    /// shrinks on each measurement. Good enough for smoothing noisy mobile
    /// GPS without the complexity of a full state-space EKF.
    ///
    /// Tuning: <see cref="ProcessVariance"/> is the expected drift per second.
    /// </summary>
    public sealed class LocationKalmanFilter
    {
        public float ProcessVariance = 0.6f;
        private double _x, _p;
        private double _lastTime;
        private bool _initialized;

        public void Reset() { _initialized = false; }

        public double Filter(double measurement, double measurementVariance, double nowSec)
        {
            if (!_initialized)
            {
                _x = measurement;
                _p = measurementVariance;
                _lastTime = nowSec;
                _initialized = true;
                return _x;
            }

            double dt = Math.Max(nowSec - _lastTime, 0.001);
            _lastTime = nowSec;
            _p += ProcessVariance * dt;

            double k = _p / (_p + measurementVariance);
            _x += k * (measurement - _x);
            _p *= (1 - k);
            return _x;
        }
    }
}
