using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;
using UnityEngine.UIElements;

public class ShadowColorRenderFeature : ScriptableRendererFeature
{
    class ShadowColorPass : ScriptableRenderPass
    {
        private Material _shadowColorMaterial;
        private RTHandle _coloredShadowTexture;

        private class PassData
        {
            // Add any data needed for your render pass here
        }

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            const string passName = "Shadow Color Pass";

            using (var builder = renderGraph.AddRasterRenderPass<PassData>(passName, out var passData))
            {

            }
        }
    }

    RenderingData renderingData; // passed into Execute()
                                 // The shadow map is already a global texture set by URP:
                                 // _MainLightShadowmapTexture  (screen-space shadow map after URP resolves it)
                                 // _ScreenSpaceShadowmapTexture (if Screen Space Shadows feature is active)

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
