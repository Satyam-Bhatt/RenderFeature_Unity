using UnityEngine;
using UnityEngine.Rendering.Universal;

public class ShadowColorRenderFeature : ScriptableRendererFeature
{
    class ShadowColorPass : ScriptableRenderPass
    {

    }

    ShadowColorPass shadowColorPass;
    RenderPassEvent renderPassEvent_Custom = RenderPassEvent.AfterRenderingOpaques;

    public override void Create()
    {
        shadowColorPass = new ShadowColorPass();

        shadowColorPass.renderPassEvent = renderPassEvent_Custom;
    }


}
