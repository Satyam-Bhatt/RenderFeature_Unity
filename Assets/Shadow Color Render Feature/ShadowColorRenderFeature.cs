using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

public class ShadowColorRenderFeature : ScriptableRendererFeature
{
    class ShadowColorPass : ScriptableRenderPass
    {
        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            
        }
    }

    ShadowColorPass shadowColorPass;
    RenderPassEvent renderPassEvent_Custom = RenderPassEvent.AfterRenderingOpaques;

    public override void Create()
    {
        shadowColorPass = new ShadowColorPass();

        shadowColorPass.renderPassEvent = renderPassEvent_Custom;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(shadowColorPass);
    }
}
