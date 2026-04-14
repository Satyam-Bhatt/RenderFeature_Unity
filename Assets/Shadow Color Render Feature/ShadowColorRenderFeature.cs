using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

public class ColoredShadowData : ContextItem
{
    public TextureHandle coloredShadowTexture;
    public override void Reset() => coloredShadowTexture = TextureHandle.nullHandle;
}

public class ShadowColorRenderFeature : ScriptableRendererFeature
{
    class ShadowColorPass : ScriptableRenderPass
    {
        private Material _material;
        private Vector4 _shadowColor = new Vector4(1,0,0,1);

        public UniversalLightData UniversalLightData { get; private set; }

        public void Setup(Material material)
        {
            _material = material;
        }

        private class PassData
        {
            // Add any data needed for your render pass here
            public TextureHandle shadowMap;
            public Vector4 shadowColor;
            public Material material;
        }

        static void ExecutePass(PassData data, RasterGraphContext context)
        {
            Blitter.BlitTexture(context.cmd, data.shadowMap, new Vector4(1, 1, 0, 0), data.material, 0);
        }

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            const string passName = "Shadow Color Pass";
            UniversalResourceData resourceData = frameData.Get<UniversalResourceData>();
            UniversalLightData  = frameData.Get<UniversalLightData>();
            UniversalCameraData cameraData = frameData.Get<UniversalCameraData>();

            // URP exposes the shadow map handle directly via resource data
            TextureHandle shadowMap = resourceData.mainShadowsTexture;

            if (!shadowMap.IsValid())
            {
                Debug.LogWarning("Shadow Map is Invalid");
                return;
            }

            using (var builder = renderGraph.AddRasterRenderPass<PassData>(passName, out var passData))
            {
                passData.shadowMap = shadowMap;
                passData.shadowColor = _shadowColor;
                passData.material = _material;

                builder.UseTexture(shadowMap,AccessFlags.Read); // Declare read dependency

                // Create output RT
                RenderTextureDescriptor desc = cameraData.cameraTargetDescriptor;
                TextureHandle coloredShadow = UniversalRenderer.CreateRenderGraphTexture(renderGraph, desc, "ColoredShadowTecture", false);

                builder.SetRenderAttachment(coloredShadow,0,AccessFlags.Write);

                builder.SetRenderFunc((PassData data, RasterGraphContext context) =>
                {
                    ExecutePass(data, context);
                });
            }
        }
    }

    ShadowColorPass shadowColorPass;
    public RenderPassEvent renderPassEvent_Custom = RenderPassEvent.AfterRenderingShadows;
    public Material shadowColorMaterial;

    public override void Create()
    {
        shadowColorPass = new ShadowColorPass();

        shadowColorPass.renderPassEvent = renderPassEvent_Custom;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if(shadowColorMaterial == null)
        {
            Debug.LogWarning("ShadowColorRenderFeature material is null and will be skipped");
            return;
        }
        shadowColorPass._material = shadowColorMaterial;

        renderer.EnqueuePass(shadowColorPass);
    }
}
