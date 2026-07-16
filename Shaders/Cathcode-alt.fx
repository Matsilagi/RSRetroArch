#include "ReShade.fxh"

//Cathode by nimitz (twitter: @stormoid)
//2017 nimitz All rights reserved

/*
	CRT simulation shadowmask style, I also have a trinitron version
	optimized for 4X scaling on a ~100ppi display.

	The "Scanlines" seen in the simulated picture are only a side effect of the phoshor placement
	and decay, instead of being artificially added on at the last step. This has the advantage

	I have done some testing and it performs especially well with "hard" input such a faked
	(dither based) transparency and faked specular highlights as seen in the bigger sprite.
	A version tweaked and made for 4k displays could look pretty close to the real thing.
*/

// Phosphor kernel radius
// 0 = 1 sample
// 1 = 3 samples
// 2 = 5 samples

#define KERNEL_X 	1
#define KERNEL_XX 	1
#define KERNEL_Y 		1
#define KERNEL_YY 	1

#define mod(x,y) (x-y*floor(x/y))

uniform float resSize <
	ui_type = "drag";
	ui_min = 1.0;
	ui_max = 7.0;
	ui_step = 1;
	ui_label = "Resolution x-Size";
	ui_tooltip = "Size of scanlines.";
> = 3.0;

uniform float ScanlineStrength <
    ui_type = "drag";
    ui_label = "Scanline Strength";
    ui_min = 0.75;
    ui_max = 1.75;
    ui_step = 0.01;
> = 1.01;

uniform float RedGain <
	ui_type = "drag";
	ui_label = "Red Phosphor Strength";
	ui_min = 0.5;
	ui_max = 1.5;
	ui_step = 0.01;
> = 1.0;

uniform float RedOffsetY <
	ui_type = "drag";
	ui_label = "Red Phosphor Offset";
	ui_tooltip = "Vertical position of the red phosphor.";
	ui_min = -0.5;
	ui_max = 0.5;
	ui_step = 0.01;
> = 0;

uniform float RGBOffsetX <
	ui_type = "drag";
	ui_label = "Green/Blue Phosphor Offset";
	ui_tooltip = "Horizontal distance between green and blue phosphors.";
	ui_min = -1.0;
	ui_max = 1;
	ui_step = 0.01;
> = 0;

uniform float phosphorsgain <
    ui_type = "drag";
    ui_label = "Phosphors gain";
	ui_tooltip = "Brightness all phosphor.";
    ui_min = 0.5;
    ui_max = 1.5;
    ui_step = 0.01;
> = 1.08;

uniform float3 WhiteBalance <
    ui_type = "drag";
    ui_label = "RGB Balance";
    ui_min = 0.6;
    ui_max = 1.2;
	ui_step = 0.01;
> = float3(1.0, 1.0, 1.0);

		//		Phosphor decay
float decay(float d)
{
    d *= ScanlineStrength;

    float d2 = d*d;

    return lerp(
        exp2(-d2*2.5-.3),
        0.05/(d2*d*0.45+0.055),
        .65
    ) * 0.99;
}

		//		Phosphor shape
float sqd(in float2 a, in float2 b)
{
    a -= b;
    a *= float2(1.25,1.8)*.905;
    float d = max(abs(a.x), abs(a.y));
	d = lerp(d, dot(a,a)*0.85, .3);
    return d;
}

float3 phosphors(in float2 p, sampler2D tex, float2 frgCoord)
{   
    float3 col = float3(0.0,0.0,0.0);
    p -= 0.25;
    p.y += mod(frgCoord.x,2.)<1.?.03:-0.03;
    p.y += mod(frgCoord.x,4.)<2.?.02:-0.02;
    
	float3 src = tex2D(tex, frgCoord.xy).rgb;
	src = pow(src,float3(1.12,1.12,1.12)) * phosphorsgain;
	
		//		3x3 kernel (fragment can be affected by a pixel that is # game pixels away)
		//     x. < -LeftRadius)  >  RightRadius) 
		//     y. < -DownRadius)  >  UpRadius)    
for (int i = -KERNEL_X; i <= KERNEL_XX; i++)
for (int j = -KERNEL_Y; j <= KERNEL_YY; j++)
    {
	float MaskPhase = 0.5 + (1.0 - ScanlineStrength) * 0.5;
	float2 tap = floor(p + MaskPhase) + 0.5 + float2(i,j);
	float3 rez = src;
        
		//center points ... alt replace: float rd = sqd(tap, p);
	float rd = sqd(tap, p + float2(0.0, RedOffsetY));//distance to red dot
	float gd = sqd(tap, p + float2(RGBOffsetX,0.0));//distance to green dot
	float bd = sqd(tap, p + float2(-RGBOffsetX,0.0));//distance to blue dot
		
        rez.r *= decay(rd) * RedGain;
        rez.g *= decay(gd);
        rez.b *= decay(bd);
        col += rez;
    }
	col *= WhiteBalance;
    return col;
}

void PS_Cathode(in float4 pos : SV_POSITION, in float2 txcoord : TEXCOORD0, out float4 frgcol : COLOR0)
{
	float2 uv = txcoord.xy * ReShade::ScreenSize.xy;
	float2 p = uv.xy/ReShade::ScreenSize.xy;
    float2 f = uv.xy;
    
    float3 col = phosphors(uv.xy/resSize, ReShade::BackBuffer, txcoord.xy);
	frgcol = float4(col, 1.0);
}

technique Cathode {
	pass Cathode
	{	
		VertexShader = PostProcessVS;
		PixelShader = PS_Cathode;
	}
}
