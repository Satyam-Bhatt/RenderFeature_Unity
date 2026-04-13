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
        private Vector4 shadowColor = new Vector4(1,0,0,1);
        RenderingData renderingData;

        private class PassData
        {
            // Add any data needed for your render pass here
            public TextureHandle shadowMap;
            public Vector4 shadowColor;
            public TextureHandle outputTexture;
        }

        static void ExecutePass(PassData data, RasterGraphContext context)
        {
            // Add your rendering commands here
            // Example: context.cmd.DrawMesh(...);
        }

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            const string passName = "Shadow Color Pass";
            UniversalResourceData resourceData = frameData.Get<UniversalResourceData>();
            UniversalLightData ligghtData = frameData.Get<UniversalLightData>();

            // URP exposes the shadow map handle directly via resource data
            TextureHandle shadowMap = resourceData.mainShadowsTexture;

            using (var builder = renderGraph.AddRasterRenderPass<PassData>(passName, out var passData))
            {
                passData.shadowMap = shadowMap;
                passData.shadowColor = shadowColor;

                builder.UseTexture(shadowMap,AccessFlags.Read); // Declare read dependency

                // Create output RT
                RenderTextureDescriptor desc = renderingData.cameraData.cameraTargetDescriptor;
                TextureHandle coloredShadow = UniversalRenderer.CreateRenderGraphTexture(renderGraph, desc, "ColoredShadowTecture", false);

                passData.outputTexture = coloredShadow;
                builder.SetRenderAttachment(coloredShadow,0,AccessFlags.Write);

                builder.SetRenderFunc((PassData data, RasterGraphContext context) =>
                {
                    ExecutePass(data, context);
                });
            }
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
