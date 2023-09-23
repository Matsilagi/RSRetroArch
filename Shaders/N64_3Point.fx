// to use on shadertoy.com
// DKO's 3point GLSL shader
// Ported to ReShade by Matsilagi

#include "ReShade.fxh"

uniform float texture_sizeX <
	ui_type = "drag";
	ui_min = 1.0;
	ui_max = BUFFER_WIDTH;
	ui_label = "Screen Width [N64-3Point]";
> = 320.0;

uniform float texture_sizeY <
	ui_type = "drag";
	ui_min = 1.0;
	ui_max = BUFFER_HEIGHT;
	ui_label = "Screen Height [N64-3Point]";
> = 240.0;

uniform bool FLIP_DIAGONAL <
	ui_type = "bool";
	ui_label = "Flip Diagonal Axis [N64-3Point]";
> = true;

float2 norm2denorm(sampler tex, float2 uv)
{
    return uv * float2(texture_sizeX,texture_sizeY) - 0.5;
}

int2 denorm2idx(float2 d_uv)
{
    return int2(floor(d_uv));
}

int2 norm2idx(sampler tex, float2 uv)
{
    return denorm2idx(norm2denorm(tex, uv));
}

float2 idx2norm(sampler tex, int2 idx)
{
    float2 denorm_uv = float2(idx) + 0.5;
    float2 size = float2(texture_sizeX,texture_sizeY);
    return denorm_uv / size;
}

float4 texel_fetch(sampler tex, int2 idx)
{
    float2 uv = idx2norm(tex, idx);
    return tex2D(tex, uv);
}

#if 0
float find_mipmap_level(in float2 texture_coordinate) // in texel units
{
    float2  dx_vtc = dFdx(texture_coordinate);
    float2  dy_vtc = dFdy(texture_coordinate);
    float delta_max_sqr = max(dot(dx_vtc, dx_vtc), dot(dy_vtc, dy_vtc));
    float mml = 0.5 * log2(delta_max_sqr);
    return max( 0, mml ); // Thanks @Nims
}
#endif


/*
 * Unlike Nintendo's documentation, the N64 does not use
 * the 3 closest texels.
 * The texel grid is triangulated:
 *
 *     0 .. 1        0 .. 1
 *   0 +----+      0 +----+
 *     |   /|        |\   |
 *   . |  / |        | \  |
 *   . | /  |        |  \ |
 *     |/   |        |   \|
 *   1 +----+      1 +----+
 *
 * If the sampled point falls above the diagonal,
 * The top triangle is used; otherwise, it's the bottom.
 */

float4 texture_3point(sampler tex, float2 uv)
{
    float2 denorm_uv = norm2denorm(tex, uv);
    int2 idx_low = denorm2idx(denorm_uv);
    float2 ratio = denorm_uv - float2(idx_low);
	
	int2 corner0 = int2(0,0);
	int2 corner1 = int2(0,0);
	int2 corner2 = int2(0,0);
	bool lower_flag = 0;
	
	if (FLIP_DIAGONAL == 0) {
		// using step() function, might be faster
		lower_flag = int(step(1.0, ratio.s + ratio.t));
		corner0 = int2(lower_flag, lower_flag);
		corner1 = int2(0, 1);
		corner2 = int2(1, 0);
	} else {
		// orient the triangulated mesh diagonals the other way
		lower_flag = int(step(0.0, ratio.s - ratio.t));
		corner0 = int2(lower_flag, 1 - lower_flag);
		corner1 = int2(0, 0);
		corner2 = int2(1, 1);
	}
	
    int2 idx0 = idx_low + corner0;
    int2 idx1 = idx_low + corner1;
    int2 idx2 = idx_low + corner2;

    float4 t0 = texel_fetch(tex, idx0);
    float4 t1 = texel_fetch(tex, idx1);
    float4 t2 = texel_fetch(tex, idx2);

    // This is standard (Crammer's rule) barycentric coordinates calculation.
    float2 v0 = float2(corner1 - corner0);
    float2 v1 = float2(corner2 - corner0);
    float2 v2 = ratio   - float2(corner0);
    float den = v0.x * v1.y - v1.x * v0.y;
    /*
     * Note: the abs() here is necessary because we don't guarantee
     * the proper order of vertices, so some signed areas are negative.
     * But since we only interpolate inside the triangle, the areas
     * are guaranteed to be positive, if we did the math more carefully.
     */
    float lambda1 = abs((v2.x * v1.y - v1.x * v2.y) / den);
    float lambda2 = abs((v0.x * v2.y - v2.x * v0.y) / den);
    float lambda0 = 1.0 - lambda1 - lambda2;

    return lambda0*t0 + lambda1*t1 + lambda2*t2;
}


void PS_N64Filter(in float4 pos : SV_POSITION, in float2 txcoord : TEXCOORD0, out float4 fragColor : COLOR0)
{
	float2 fragCoord = txcoord * ReShade::ScreenSize; //this is because the original shader uses OpenGL's fragCoord, which is in texels rather than pixels
    float2 uv = txcoord/ReShade::ScreenSize.y/2.0;
    // 3-point filtering
    float3 col = texture_3point(ReShade::BackBuffer, txcoord).rgb;
    fragColor = float4(col, 1.0);
}

technique N64Filter {
    pass N64Filter {
        VertexShader=PostProcessVS;
        PixelShader=PS_N64Filter;
    }
}
