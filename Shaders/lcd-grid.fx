// LCD Grid Shader for ReShade
// Safe build - works with all ReShade versions (DX9–DX12/Vulkan)
//------------------------------------------------------------------------------

#include "ReShade.fxh"

// =====================
// ==  User Controls  ==
// =====================
uniform float display_sizeX <
    ui_type = "drag";
    ui_min = 1.0;
    ui_max = BUFFER_WIDTH;
    ui_step = 1.0;
    ui_label = "Screen Width [LCD-Grid]";
> = 320.0;

uniform float display_sizeY <
    ui_type = "drag";
    ui_min = 1.0;
    ui_max = BUFFER_HEIGHT;
    ui_step = 1.0;
    ui_label = "Screen Height [LCD-Grid]";
> = 240;

uniform float GRID_STRENGTH <
    ui_type = "drag";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.01;
    ui_label = "LCD Grid Strength [LCD-Grid]";
> = 0.05;

uniform float gamma <
    ui_type = "drag";
    ui_min = 1.0;
    ui_max = 5.0;
    ui_step = 0.1;
    ui_label = "LCD Gamma [LCD-Grid]";
> = 2.2;

// ====================
// ==  Helper Macros  ==
// ====================
#define display_size float2(display_sizeX, display_sizeY)
#define round(x) floor((x) + 0.5)
#define mod(x, y) ((x) - (y) * floor((x) / (y)))

// properly define backbuffer texture
texture BackBufferTex : COLOR;
sampler BackBufferSampler
{
    Texture = BackBufferTex;
    SRGBTexture = false;
};

// use safe pow that avoids NaN
float4 SafePow(float4 base, float4 exp)
{
    return pow(abs(base) + 1e-6, exp);
}

#define TX2D(c) SafePow(tex2D(BackBufferSampler, (c)), float4(gamma, gamma, gamma, gamma))

// ===================
// ==  Math Helpers  ==
// ===================
float intsmear_func(float z)
{
    float z2 = z * z;
    float z4 = z2 * z2;
    float z8 = z4 * z4;
    // explicit finite constants - prevents compiler from folding into NaN
    return z
         - (2.0 / 3.0) * z * z2
         - (1.0 / 5.0) * z * z4
         + (4.0 / 7.0) * z * z2 * z4
         - (1.0 / 9.0) * z * z8
         - (2.0 / 11.0) * z * z2 * z8
         + (1.0 / 13.0) * z * z4 * z8;
}

float intsmear(float x, float dx)
{
    const float d = 1.5;
    float zl = clamp((x - dx) / d, -1.0, 1.0);
    float zh = clamp((x + dx) / d, -1.0, 1.0);
    return d * (intsmear_func(zh) - intsmear_func(zl)) / (2.0 * dx + 1e-6);
}

// =====================
// ==  Main Pixel FX  ==
// =====================
float4 PS_LCDGrid(float4 pos : SV_Position, float2 texcoord : TEXCOORD0) : SV_Target
{
    float2 texelSize = 1.0 / display_size;
    float2 subtexelSize = texelSize / float2(3.0, 1.0);

    float left   = texcoord.x - texelSize.x * 0.5;
    float top    = texcoord.y + texelSize.y * 0.5;
    float right  = texcoord.x + texelSize.x * 0.5;
    float bottom = texcoord.y - texelSize.y * 0.5;

    float subpix = mod(texcoord.x / subtexelSize.x + 1.5, 3.0);
    float rsubpix = texelSize.x / subtexelSize.x;

    float4 lcol = float4(
        intsmear(subpix + 1.0, rsubpix),
        intsmear(subpix, rsubpix),
        intsmear(subpix - 1.0, rsubpix),
        0.0
    );

    float4 rcol = float4(
        intsmear(subpix - 2.0, rsubpix),
        intsmear(subpix - 3.0, rsubpix),
        intsmear(subpix - 4.0, rsubpix),
        0.0
    );

    float4 topLeftColor     = TX2D((floor(float2(left, top) / texelSize) + 0.5) * texelSize) * lcol;
    float4 bottomRightColor = TX2D((floor(float2(right, bottom) / texelSize) + 0.5) * texelSize) * rcol;
    float4 bottomLeftColor  = TX2D((floor(float2(left, bottom) / texelSize) + 0.5) * texelSize) * lcol;
    float4 topRightColor    = TX2D((floor(float2(right, top) / texelSize) + 0.5) * texelSize) * rcol;

    float2 border = round(texcoord.xy / subtexelSize);
    float2 bordert = clamp((border + float2(0.0, +GRID_STRENGTH)) * subtexelSize, float2(left, bottom), float2(right, top));
    float2 borderb = clamp((border + float2(0.0, -GRID_STRENGTH)) * subtexelSize, float2(left, bottom), float2(right, top));

    float totalArea = max(2.0 * texelSize.y, 1e-6);

    float4 averageColor = 0.0;
    averageColor += ((top - bordert.y) / totalArea) * topLeftColor;
    averageColor += ((borderb.y - bottom) / totalArea) * bottomRightColor;
    averageColor += ((borderb.y - bottom) / totalArea) * bottomLeftColor;
    averageColor += ((top - bordert.y) / totalArea) * topRightColor;

    float4 frgCol = SafePow(averageColor, float4(1.0 / gamma, 1.0 / gamma, 1.0 / gamma, 1.0 / gamma));
    return saturate(frgCol);
}

// ======================
// ==  Technique Setup ==
// ======================
technique LCDGrid
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_LCDGrid;
    }
}
