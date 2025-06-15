#ifndef __HAIR_CALCULATE_COLOR_AND_ROUGHNESS_HLSL__
#define __HAIR_CALCULATE_COLOR_AND_ROUGHNESS_HLSL__

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Random.hlsl"

/*
 * melanin conversions taken from HDRP (Hair.hlsl), except AbsorptionFromMelanin which uses the same source article but is mapped to 0,1 range
 */
// Require an inverse mapping, as we parameterize the LUTs by reflectance wavelength (or for approximation that rely on diffuse).
float3 ReflectanceFromAbsorptionCopy(float3 absorption, float azimuthalRoughness)
{
    float beta = azimuthalRoughness;
    float beta2 = beta * beta;
    float beta3 = beta2 * beta;
    float beta4 = beta3 * beta;
    float beta5 = beta4 * beta;

    // Least squares fit of an inverse mapping between scattering parameters and scattering albedo.
    float denom = 5.969 - (0.215 * beta) + (2.532 * beta2) - (10.73 * beta3) + (5.574 * beta4) + (0.245 * beta5);

    float3 t = -sqrt(absorption) * denom;
    return exp(t);
}

//https://docs.blender.org/manual/en/latest/render/shader_nodes/shader/hair_principled.html
float3 AbsorptionFromMelanin01(float eumelanin, float pheomelanin)
{
    const float3 eA = float3(0.506, 0.841, 1.653);
    const float3 eP = float3(0.343, 0.733, 1.924);

    return (eumelanin * eA) + (pheomelanin * eP);
}

float3 ReflectanceFromMelaninCopy(float eumelanin, float pheomelanin, float azimuthalRoughness)
{
    return ReflectanceFromAbsorptionCopy(AbsorptionFromMelanin01(eumelanin, pheomelanin), azimuthalRoughness);
}

float mapToActualMelaninAmount(float melanin01)
{
    const float exp2eInv = 0.693147181f;
    return -log2(max(1.f - melanin01, 0.0001f)) * exp2eInv;
}

//randomly discard segments based on weights. Different parameters for shadows and other passes
void CalculateColorAndRoughness_float(in float melanin, in float melaninRedness, in float smoothness, in float azimuthalSmoothness, in float randomSeed, in float smoothnessRandomAmount, in float melaninRandomAmount,
                       out float3 colorOut, out float smoothnessOut)
{
    float melaninFactor = 1.0f + 2.f * (GenerateHashedRandomFloat(randomSeed) - 0.5f) * melaninRandomAmount;
    float smoothnessFactor = 1.0f + 2.f * (GenerateHashedRandomFloat(randomSeed + 1) - 0.5f) * smoothnessRandomAmount;

    float overallMelanin = mapToActualMelaninAmount(saturate(melanin * melaninFactor));
    
    float eumelanin = overallMelanin * (1.f - melaninRedness);
    float pheomelanin = overallMelanin * melaninRedness;

    colorOut = ReflectanceFromMelaninCopy(eumelanin, pheomelanin, saturate(1.f - azimuthalSmoothness));
    smoothnessOut =  saturate(smoothness * smoothnessFactor); 
    
}

#endif//__HAIR_CALCULATE_COLOR_AND_ROUGHNESS_HLSL__
