#ifndef CUSTOM_LIGHTING_INCLUDED
#define CUSTOM_LIGHTING_INCLUDED

struct CustomLightingData
{
    float3 albedo;
};

float3 CalculateCustomLighting(CustomLightingData d)
{
    return d.albedo;
}

// To use it in shader graph

#endif