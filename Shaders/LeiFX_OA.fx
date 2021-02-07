// "LeiFX" shader - Pixel filtering process
// 
// 	Copyright (C) 2013-2015 leilei
// 
// This program is free software; you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by the Free
// Software Foundation; either version 2 of the License, or (at your option)
// any later version.

// New undither version

#include "ReShade.fxh";

//16-BIT DITHER VARIABLES

uniform int DITHERAMOUNT <
	ui_type = "drag";
	ui_min = -16;
	ui_max = 16;
	ui_label = "Dither Amount [3DFX]";
> = 0;

uniform int DITHERBIAS <
	ui_type = "drag";
	ui_min = -16;
	ui_max = 16;
	ui_label = "Dither Bias [3DFX]";
> = 0;

//3DFX VARIABLES

#ifndef BOXFILTER
	#define BOXFILTER 0 //[0 or 1] Enables a Box Filter for the 3DFX effect.
#endif

#if BOXFILTER
	#define 	PIXELWIDTH 	1.0f
	#define		FILTCAP		(32.0f / 255)	// filtered pixel should not exceed this 
	#define		FILTCAPG	(FILTCAP / 2)
  
	static const float filtertable_x[4] = {
		1, -1,-1,1   
	};

	static const float filtertable_y[4] = {
		-1,1,-1,1   
	};
  
#else
	#define 	PIXELWIDTH 	1.0f
	#define		FILTCAP		(64.0f / 255)	// filtered pixel should not exceed this 
	#define		FILTCAPG	(FILTCAP / 2)

	static const float filtertable_x[4] = {
		1,-1,1,1  
	};

	static const float filtertable_y[4] = {
		0,0,0,0   
	};
#endif

//ACTUAL CODE
#define mod2(x,y) (x-y*floor(x/y))

float fmod(float a, float b)
{
  float c = frac(abs(a/b))*abs(b);
  return (a < 0) ? -c : c;   /* if ( a < 0 ) c = 0-c */
}

void PS_LeiFX_Dither(in float4 pos : SV_POSITION, in float2 uv : TEXCOORD0, out float4 col : COLOR0)
{	
	float erroredtable[16] = {
		16,4,13,1,   
		8,12,5,9,
		14,2,15,3,
		6,10,7,11		
	};
	
    // Sampling The Texture And Passing It To The Frame Buffer 
	col = tex2D(ReShade::BackBuffer, uv); 

	float3 what;

	float aht = 1.0f;

	what.x = aht;	// shut
	what.y = aht;	// up
	what.z = aht;	// warnings
	float3 huh;

	// *****************
	// STAGE 0
	// Grab our sampled pixels for processing......
	// *****************
	float2 px;	// shut
	float egh = 1.0f;
	px.x = (1 / ReShade::ScreenSize.x);
	px.y = (1 / ReShade::ScreenSize.y);
	
	float3 pe1 = tex2D(ReShade::BackBuffer, uv); // first pixel...
	
	// *****************
	// STAGE 2
	// Reduce color depth of sampled pixels....
	// *****************

	{
		float3 reduct;		// 16 bits per pixel (5-6-5)
		reduct.r = 32;
		reduct.g = 64;	// gotta be 16bpp for that green!
		reduct.b = 32;
		pe1 = pow(pe1, what);  	
		pe1 *= reduct;  	
		pe1 = floor(pe1);	
		pe1 = pe1 / reduct;  	
		pe1 = pow(pe1, what);
	}
	
	col = float4(pe1,1.0);
}

void PS_LeiFX_Gamma(in float4 pos : SV_POSITION, in float2 uv : TEXCOORD0, out float4 col : COLOR0)
{
	float2 px;	// shut
	px.x = 1 / ReShade::ScreenSize.x;
	px.y = 1 / ReShade::ScreenSize.x;
	//px.y = 1 / ReShade::ScreenSize.y;
	float gammaed = 0.3;
	float leifx_linegamma = gammaed;
	float leifx_liney =  0.0078125;0.01568 / 2; // 0.0390625

    // Sampling The Texture And Passing It To The Frame Buffer 
    col = tex2D(ReShade::BackBuffer, uv); 

	
 	float lines = fmod(col.y, 2.0);	// I realize the 3dfx doesn't actually line up the picture in the gamma process

	//if (lines < 1.0) leifx_linegamma = 0;
	if (lines < 1.0) 	leifx_liney = 0;

//	gl_FragColor.r += leifx_liney;	// it's a slight purple line.
//	gl_FragColor.b += leifx_liney;	// it's a slight purple line.

	float leifx_gamma = 1.0 + gammaed;// + leifx_linegamma;

	col.r = pow(col.r, 1.0 / leifx_gamma);
	col.g = pow(col.g, 1.0 / leifx_gamma);
	col.b = pow(col.b, 1.0 / leifx_gamma);
}

float3 leifx_filter(float2 uv, int passnum)
{
	float2 px;	// shut
	
	float2 res;
	res.x = ReShade::ScreenSize.x;
	res.y = ReShade::ScreenSize.y;
	px.x = uv.x * res.x;
	px.y = uv.y * res.y;
	
	float PIXELWIDTHH = (1 / ReShade::ScreenSize.x);
	float2 texture_coordinate = uv;

	px.x = (1 / ReShade::ScreenSize.x) / 1.5;
	px.y = (1 / ReShade::ScreenSize.y) / 1.5; 
	
    // Sampling The Texture And Passing It To The Frame Buffer 
    float3 color = tex2D(ReShade::BackBuffer, texture_coordinate); 
	
	float3 pixel1 = tex2D(ReShade::BackBuffer, texture_coordinate + float2(px.x * (filtertable_x[passnum] * PIXELWIDTH), px.y * (PIXELWIDTH * filtertable_y[passnum]))).rgb;
	float3 pixel2 = tex2D(ReShade::BackBuffer, texture_coordinate + float2(-px.x * (filtertable_x[passnum] * PIXELWIDTH), px.y * (PIXELWIDTH * filtertable_y[passnum]))).rgb; 

	float3 pixeldiff;			// Pixel difference for the dither check
	float3 pixelmake;			// Pixel to make for adding to the buffer
	float3 pixeldiffleft;		// Pixel to the left
	float3 pixelblend;
	{
		pixelmake.rgb = 0;
		pixeldiff.rgb = pixel2.rgb-color.rgb;

		if (pixeldiff.r > FILTCAP) 		pixeldiff.r = FILTCAP;
		if (pixeldiff.g > FILTCAPG) 	pixeldiff.g = FILTCAPG;
		if (pixeldiff.b > FILTCAP) 		pixeldiff.b = FILTCAP;

		if (pixeldiff.r < -FILTCAP) 		pixeldiff.r = -FILTCAP;
		if (pixeldiff.g < -FILTCAPG) 		pixeldiff.g = -FILTCAPG;
		if (pixeldiff.b < -FILTCAP) 		pixeldiff.b = -FILTCAP;

		pixelmake.rgb = (pixeldiff.rgb / 4);
		color.rgb= (color.rgb + pixelmake.rgb);
	}
	
	return color;
}

void PS_LeiFX_Filter_1(in float4 pos : SV_POSITION, in float2 uv : TEXCOORD0, out float4 col : COLOR0)
{
	col.rgb = leifx_filter(uv,0);
	col.w = 1;
}	

void PS_LeiFX_Filter_2(in float4 pos : SV_POSITION, in float2 uv : TEXCOORD0, out float4 col : COLOR0)
{
	col.rgb = leifx_filter(uv,1);
	col.w = 1;
}	

void PS_LeiFX_Filter_3(in float4 pos : SV_POSITION, in float2 uv : TEXCOORD0, out float4 col : COLOR0)
{
	col.rgb = leifx_filter(uv,2);
	col.w = 1;
}	

void PS_LeiFX_Filter_4(in float4 pos : SV_POSITION, in float2 uv : TEXCOORD0, out float4 col : COLOR0)
{
	col.rgb = leifx_filter(uv,3);
	col.w = 1;
}

technique LeiFx_OA
{
	pass LeiFX_Dither
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_LeiFX_Dither;
	}
	pass LeiFX_Filter1
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_LeiFX_Filter_1;
	}
	pass LeiFX_Filter2
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_LeiFX_Filter_2;
	}
	pass LeiFX_Filter3
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_LeiFX_Filter_3;
	}
	pass LeiFX_Filter4
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_LeiFX_Filter_4;
	}
	pass LeiFX_Gamma
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_LeiFX_Gamma;
	}
}
