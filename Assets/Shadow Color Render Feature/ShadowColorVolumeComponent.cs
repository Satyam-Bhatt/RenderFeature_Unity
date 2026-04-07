using System;
using UnityEngine;
using UnityEngine.Rendering;

[Serializable]
[VolumeComponentMenu("Custom/ShadowColorVolumeComponent")]
public class ShadowColorVolumeComponent : VolumeComponent, IPostProcessComponent
{
    public ClampedFloatParameter intensity = new ClampedFloatParameter(0, 0, 1, true);

    public bool IsActive()
    {
        return intensity.value > 0f;
    }
}
