using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;

// To manage the lifecycle and configuration of the passes. There can be multiple passes in a single feature.
public class DitherEffectRendererFeature : ScriptableRendererFeature
{
    // Defines the rendering logic. What the render pass does.
    class DitherEffectPass : ScriptableRenderPass
    {
        const string m_PassName = "DitherEffectPass"; // Useful for debugging.
        Material m_BlitMaterial; // Contains the shader that will be applied to the current state of the rendered image

        // To allow render feature to setup material for our dither effect
        public void Setup(Material mat)
        {
            m_BlitMaterial = mat;
            // We need to read the current color texture, everything that is rendered so far
            // We generally want to apply the effect on top of the final output
            // But we can't use the final output(backbuffer) as input, so we need an intermediate texture
            // This line just tells unity to create a working copy for us
            requiresIntermediateTexture = true;
        }

        // RecordRenderGraph is where the RenderGraph handle can be accessed, through which render passes can be added to the graph.
        // FrameData is a context container through which URP resources can be accessed and managed.
        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            // We want the dither effect to only happen in a volume
            var stack = VolumeManager.instance.stack;
            var customEffect = stack.GetComponent<SphereVolumeComponent>();

            // If the effect is not active, we skip the pass
            if(!customEffect.IsActive())
                return;

            // We store current camera color buffer to a temporary texture
            // Then we apply our dither effect shader to it, and output to the destination texture

            // This helps us access all the renders texture handles like render targets, depth information, shadows etc
            var resourceData = frameData.Get<UniversalResourceData>();

            // Back Buffer = The final display framebuffer that goes directly to your screen. It's a special render target with limitations.
            // When isActiveTargetBackBuffer is true, it means URP is rendering directly to the screen without an intermediate texture.
            // And we cannot directly read/write to the back buffer as a texture input/output in a render pass.
            if (resourceData.isActiveTargetBackBuffer)
            {
                Debug.Log($"Skippingg render pass. ditherEffectRendererFeature requires an intermediate ColorTexture, we can't use the BackBuffer as a texture input");
                return;
            }

            // We need camera color buffer for our source
            var source = resourceData.activeColorTexture; // Current camera color buffer

            // Render textures have their properties defined by a RenderTextureDescriptor struct
            // We want the dimensions of our texture to match the source texture
            var destinationDesc = renderGraph.GetTextureDesc(source);
            destinationDesc.name = $"CameraColor-{m_PassName}"; // Change the name as per pass for debugging
            destinationDesc.clearBuffer = false; // We don't want a blank slate, we want to modify existing image

            // Create the destination texture handle with the custom parameters
            TextureHandle destination = renderGraph.CreateTexture(destinationDesc);

            // All the data we need to blit, the source, destination and the material with the shader
            // We use the first pass of the material = 0 (default)
            RenderGraphUtils.BlitMaterialParameters para = new(source, destination, m_BlitMaterial, 0);
            // Now we want to add the pass
            // This will execute the blit operation with our material shader
            renderGraph.AddBlitPass(para, passName: m_PassName);

            // Here we swap out the camera color buffer with the modified texture
            // Future operations will then use this modified texture
            resourceData.cameraColor = destination;
        }
    }

    public RenderPassEvent injectionPoint = RenderPassEvent.AfterRenderingPostProcessing;
    public Material material;

    DitherEffectPass m_ScriptablePass;

    public override void Create()
    {
        m_ScriptablePass = new DitherEffectPass();

        // Configures where the render pass should be injected.
        m_ScriptablePass.renderPassEvent = injectionPoint;
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if(material == null)
        {
            Debug.LogWarning("DitherEffectRendererFeature material is null and will be skipped.");
            return;
        }

        m_ScriptablePass.Setup(material);
        renderer.EnqueuePass(m_ScriptablePass);
    }
}