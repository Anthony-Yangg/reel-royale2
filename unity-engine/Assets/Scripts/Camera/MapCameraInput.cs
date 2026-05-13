using PokemonGo.Core;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.EnhancedTouch;
using TouchInput = UnityEngine.InputSystem.EnhancedTouch.Touch;

namespace PokemonGo.Camera
{
    /// <summary>
    /// Touch + mouse input controller for the map camera. Implements:
    /// <list type="bullet">
    ///   <item>single-finger pan</item>
    ///   <item>two-finger pinch zoom</item>
    ///   <item>two-finger twist rotate</item>
    ///   <item>mouse drag (editor)</item>
    ///   <item>scroll wheel zoom</item>
    /// </list>
    /// </summary>
    [DefaultExecutionOrder(-50)]
    public sealed class MapCameraInput : MonoBehaviour
    {
        private IMapCameraService _camera;
        private bool _twoFingerActive;
        private float _prevPinchDist;
        private float _prevPinchAngle;
        private Vector2 _prevSingle;
        private Vector2 _prevMouse;

        [SerializeField] private float _panWorldPerPixel = 0.15f;
        [SerializeField] private float _rotateDegPerPixel = 0.4f;
        [SerializeField] private float _zoomGain = 0.005f;
        [SerializeField] private float _scrollGain = 0.1f;

        private void OnEnable()
        {
            EnhancedTouchSupport.Enable();
        }

        private void OnDisable()
        {
            EnhancedTouchSupport.Disable();
        }

        private void Start()
        {
            var runtime = EngineRuntime.Active;
            if (runtime == null || !runtime.IsBooted)
            {
                if (runtime != null) runtime.BootCompleted += BindCamera;
                else enabled = false;
            }
            else BindCamera();
        }

        private void BindCamera()
        {
            var runtime = EngineRuntime.Active;
            if (runtime != null) runtime.BootCompleted -= BindCamera;
            _camera = ServiceLocator.Instance.Resolve<IMapCameraService>();
        }

        private void OnDestroy()
        {
            var runtime = EngineRuntime.Active;
            if (runtime != null) runtime.BootCompleted -= BindCamera;
        }

        private void Update()
        {
            if (_camera == null) return;
            int active = TouchInput.activeTouches.Count;

            // --- Touch path ---------------------------------------------------
            if (active >= 2)
            {
                var t0 = TouchInput.activeTouches[0];
                var t1 = TouchInput.activeTouches[1];
                Vector2 a = t0.screenPosition, b = t1.screenPosition;
                float dist = Vector2.Distance(a, b);
                float ang = Mathf.Atan2(b.y - a.y, b.x - a.x) * Mathf.Rad2Deg;

                if (!_twoFingerActive)
                {
                    _twoFingerActive = true;
                    _prevPinchDist = dist;
                    _prevPinchAngle = ang;
                }
                else
                {
                    float ddist = dist - _prevPinchDist;
                    float dang = Mathf.DeltaAngle(_prevPinchAngle, ang);
                    if (Mathf.Abs(ddist) > 0.5f)
                        _camera.NudgeZoom(1f - ddist * _zoomGain);
                    if (Mathf.Abs(dang) > 0.05f)
                        _camera.NudgeRotate(-dang);
                    _prevPinchDist = dist;
                    _prevPinchAngle = ang;
                }
                return;
            }
            else _twoFingerActive = false;

            if (active == 1)
            {
                var t = TouchInput.activeTouches[0];
                if (t.phase == UnityEngine.InputSystem.TouchPhase.Began)
                {
                    _prevSingle = t.screenPosition;
                }
                else if (t.phase == UnityEngine.InputSystem.TouchPhase.Moved)
                {
                    Vector2 d = t.screenPosition - _prevSingle;
                    _camera.NudgePan(new Vector2(-d.x * _panWorldPerPixel,
                                                -d.y * _panWorldPerPixel));
                    _prevSingle = t.screenPosition;
                }
                return;
            }

            // --- Mouse fallback for editor ----------------------------------
            var mouse = Mouse.current;
            if (mouse == null) return;
            Vector2 mPos = mouse.position.ReadValue();
            if (mouse.leftButton.wasPressedThisFrame)
            {
                _prevMouse = mPos;
            }
            else if (mouse.leftButton.isPressed)
            {
                Vector2 d = mPos - _prevMouse;
                _camera.NudgePan(new Vector2(-d.x * _panWorldPerPixel,
                                             -d.y * _panWorldPerPixel));
                _prevMouse = mPos;
            }
            if (mouse.rightButton.isPressed)
            {
                Vector2 d = mPos - _prevMouse;
                _camera.NudgeRotate(-d.x * _rotateDegPerPixel);
                _prevMouse = mPos;
            }
            float scroll = mouse.scroll.ReadValue().y;
            if (Mathf.Abs(scroll) > 0.01f)
            {
                _camera.NudgeZoom(1f - scroll * _scrollGain * 0.01f);
            }
        }
    }
}
